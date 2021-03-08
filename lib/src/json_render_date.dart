import 'dart:html';

import 'package:dom_tools/dom_tools.dart' show copyElementToClipboard;
import 'package:intl/intl.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';

final DATE_FORMAT_DATETIME_LOCAL =
    DateFormat('yyyy-MM-ddTHH:mm:ss', Intl.getCurrentLocale());

final DATE_FORMAT_YYYY_MM_DD =
    DateFormat('yyyy/MM/dd', Intl.getCurrentLocale());

final DATE_FORMAT_YYYY_MM_DD_HH_MM_SS =
    DateFormat('yyyy/MM/dd HH:mm:ss', Intl.getCurrentLocale());

final DATE_REGEXP_YYYY_MM_DD =
    RegExp(r'(?:\d\d\d\d/\d\d/\d\d|\d\d\d\d-\d\d-\d\d)');

final DATE_REGEXP_YYYY_MM_DD_HH_MM_SS =
    RegExp(r'(?:\d\d\d\d/\d\d/\d\d|\d\d\d\d-\d\d-\d\d) \d\d:\d\d:\d\d');

/// Renders a Date value.
class TypeDateRender extends TypeRender {
  TypeDateRender() : super('date-render');

  @override
  bool matches(node, nodeParent, NodeKey nodeKey) {
    if (node is String) {
      if (DATE_REGEXP_YYYY_MM_DD.hasMatch(node)) return true;
      if (DATE_REGEXP_YYYY_MM_DD_HH_MM_SS.hasMatch(node)) return true;
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, node, nodeOriginal,
      NodeKey nodeKey) {
    var s = node as String;
    var showHour = DATE_REGEXP_YYYY_MM_DD_HH_MM_SS.hasMatch(s);
    var dateTime = DateTime.parse(s).toLocal();

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var dateTimeLocal = DATE_FORMAT_DATETIME_LOCAL.format(dateTime);

      elem = InputElement()
        ..value = dateTimeLocal
        ..type = 'datetime-local';

      valueProvider = (parent) {
        var time = DateTime.parse((elem as InputElement).value!);
        var dateTimeStr = showHour
            ? DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(time)
            : DATE_FORMAT_YYYY_MM_DD.format(time);
        return dateTimeStr;
      };
    } else {
      var dateTimeStr = showHour
          ? DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(dateTime)
          : DATE_FORMAT_YYYY_MM_DD.format(dateTime);

      elem = SpanElement()..text = dateTimeStr;

      elem.onClick.listen((e) {
        copyElementToClipboard(elem);
      });

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a Unix time [inMilliseconds] or in seconds.
class TypeUnixEpochRender extends TypeRender {
  final bool inMilliseconds;

  TypeUnixEpochRender([bool inMilliseconds = true])
      : inMilliseconds = inMilliseconds,
        super('unix-epoch-render');

  bool get inSeconds => !inMilliseconds;

  bool isValueUnixEpochRange(num val) {
    return isNumInUnixEpochRange(val, inMilliseconds);
  }

  static bool isNumInUnixEpochRange(num val, [bool inMilliseconds = true]) {
    if (inMilliseconds) {
      return val > 946692000000 && val < 32503690800000;
    } else {
      return val > 946692000 && val < 32503690800;
    }
  }

  int? parseUnixEpoch(node) {
    if (node is num) {
      return isValueUnixEpochRange(node) ? node.toInt() : null;
    } else if (node is String) {
      var s = node.trim();
      if (RegExp(r'^\d+$').hasMatch(s)) {
        var n = int.parse(s);

        if (isValueUnixEpochRange(n)) {
          return inMilliseconds ? n : n * 1000;
        }
      }
    }
    return null;
  }

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseUnixEpoch(node) != null;
  }

  DateTime toDateTime(int unixEpoch, bool alreadyInMilliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(
        alreadyInMilliseconds ? unixEpoch : unixEpoch * 1000);
  }

  int? toUnixEpoch(String? value) {
    if (value == null) return null;
    value = value.trim();
    if (value.isEmpty) return null;

    if (RegExp(r'^\d+$').hasMatch(value)) return int.parse(value);

    return DateTime.parse(value).millisecondsSinceEpoch;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var unixEpoch = parseUnixEpoch(node)!;
    var dateTime = toDateTime(unixEpoch, true).toLocal();

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var dateTimeLocal = DATE_FORMAT_DATETIME_LOCAL.format(dateTime);

      elem = InputElement()
        ..value = dateTimeLocal
        ..type = 'datetime-local';
      valueProvider = (parent) {
        var time = toUnixEpoch((elem as InputElement).value)!;

        var timeDiff = unixEpoch - time;
        if (timeDiff > 0 && timeDiff <= 1000) {
          time += timeDiff;
        }

        return time;
      };
    } else {
      var dateTimeStr = DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(dateTime);

      elem = SpanElement()..text = dateTimeStr;

      elem.onClick.listen((e) {
        copyElementToClipboard(elem);

        var val = '${elem.text}';
        if (RegExp(r'^\d+$').hasMatch(val)) {
          elem.text = dateTimeStr;
        } else {
          elem.text = '$unixEpoch';
        }
      });

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders time: seconds, minutes, hours and days in [inMilliseconds] or seconds.
class TypeTimeRender extends TypeRender {
  final bool inMilliseconds;

  final List<String>? _allowedKeys;

  TypeTimeRender([bool inMilliseconds = true, this._allowedKeys])
      : inMilliseconds = inMilliseconds,
        super('time-render');

  bool get inSeconds => !inMilliseconds;

  List<String> get allowedKeys => List.from(_allowedKeys!).cast();

  bool isTimeInRange(num val) {
    if (inMilliseconds) {
      return val > -86400000000 && val < 86400000000;
    } else {
      return val > -86400000 && val < 86400000;
    }
  }

  int? parseTime(node) {
    if (node is num) {
      return isTimeInRange(node) ? node.toInt() : null;
    } else if (node is String) {
      var s = node.trim();
      if (RegExp(r'^\d+$').hasMatch(s)) {
        var n = int.parse(s);
        if (isTimeInRange(n)) {
          return inMilliseconds ? n : n * 1000;
        }
      }
    }
    return null;
  }

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseTime(node) != null && _isAllowedKey(nodeKey);
  }

  bool _isAllowedKey(NodeKey nodeKey) {
    if (allowedKeys.isEmpty) return false;

    var leafKey = nodeKey.leafKey.toLowerCase();

    for (var k in allowedKeys) {
      if (k.toLowerCase() == leafKey) return true;
    }

    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var time = parseTime(node)!;
    var timeOriginal = inMilliseconds ? time : time / 1000;

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$timeOriginal'
        ..type = 'number';

      valueProvider = (parent) {
        var time = parseInt((elem as InputElement).value);
        return time;
      };
    } else {
      var dateTimeStr = formatTimeMillis(time);

      elem = SpanElement()..text = dateTimeStr;

      elem.onClick.listen((e) {
        copyElementToClipboard(elem);

        var val = '${elem.text}';
        if (RegExp(r'^\d+$').hasMatch(val)) {
          elem.text = dateTimeStr;
        } else {
          elem.text = '$timeOriginal';
        }
      });

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}
