import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';

void _adjustInputWidthByValueOnKeyPress(InputElement elem,
    [int maxWidth = 800]) {
  elem.onKeyUp.listen((e) {
    _adjustInputWidthByValue(elem);
  });

  elem.onChange.listen((e) {
    _adjustInputWidthByValue(elem);
  });

  _adjustInputWidthByValue(elem);
}

void _adjustInputWidthByValue(InputElement elem, [int maxWidth = 800]) {
  var widthChars = elem.value.length + 1.5;
  if (widthChars < 2) widthChars = 2;

  elem.style.width = '${widthChars}ch';
  elem.style.maxWidth = '${maxWidth}px';
}

/// Renders a JSON text.
class TypeTextRender extends TypeRender {
  bool renderQuotes;

  TypeTextRender([bool renderQuotes = true])
      : renderQuotes = renderQuotes ?? true,
        super('text-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is String;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'text';
      _adjustInputWidthByValueOnKeyPress(elem);
      valueProvider = (parent) =>
          normalizeJSONValuePrimitive((elem as InputElement).value, true);
    } else {
      elem = SpanElement()..text = renderQuotes ? '"$node"' : '$node';
      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a JSON number.
class TypeNumberRender extends TypeRender {
  TypeNumberRender() : super('number-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is num;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'number';
      _adjustInputWidthByValueOnKeyPress(elem);
      valueProvider =
          (parent) => normalizeJSONValueNumber((elem as InputElement).value);
    } else {
      elem = SpanElement()..text = '$node';
      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a JSON boolean.
class TypeBoolRender extends TypeRender {
  TypeBoolRender() : super('bool-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is bool;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var val = node is bool ? node : false;

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..checked = val
        ..type = 'checkbox';
      valueProvider = (parent) => (elem as InputElement).checked;
    } else {
      elem = SpanElement()..text = '$val';
      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a JSON null value.
class TypeNullRender extends TypeRender {
  TypeNullRender() : super('null-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node == null;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var elem = SpanElement()..text = 'null';
    output.children.add(elem);
    var valueProvider = VALUE_PROVIDER_NULL;

    applyCSS(render, output);

    return valueProvider;
  }
}

/// Renders an URL.
class TypeURLRender extends TypeRender {
  final FilterURL filterURL;

  TypeURLRender({this.filterURL}) : super('url-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if (isHttpURL(node)) {
      return true;
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var urlLabel = '$node';
    var url = urlLabel.trim();
    var target;

    if (filterURL != null) {
      var ret = filterURL(url);
      if (ret != null) {
        url = ret.url;
        urlLabel = ret.label;
        target = ret.target;
      }
    }

    if (target != null && target.trim().isEmpty) target = null;

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var input = InputElement()
        ..value = urlLabel
        ..type = 'url';

      elem = input;

      _adjustInputWidthByValueOnKeyPress(elem);

      elem.onDoubleClick.listen((e) {
        var inputURL = input.value;

        if (inputURL == urlLabel) {
          window.open(url, target);
        } else {
          window.open(inputURL, target);
        }
      });

      valueProvider = (parent) => (elem as InputElement).value;
    } else {
      var a = AnchorElement(href: url)..text = urlLabel;

      if (target != null) {
        a.target = target;
      }

      elem = a;

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders an e-mail.
class TypeEmailRender extends TypeRender {
  TypeEmailRender() : super('email-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if (isEmail(node)) {
      return true;
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var emailLabel = '$node';
    var email = emailLabel.trim();

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var input = InputElement()
        ..value = emailLabel
        ..type = 'email';

      elem = input;

      _adjustInputWidthByValueOnKeyPress(elem);

      elem.onDoubleClick.listen((e) {
        var inputEmail = input.value;

        if (inputEmail == emailLabel) {
          window.open('mailto:$email', null);
        } else {
          window.open('mailto:$inputEmail', null);
        }
      });

      valueProvider = (parent) => (elem as InputElement).value;
    } else {
      var a = AnchorElement(href: 'mailto:$email')..text = emailLabel;

      elem = a;

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a percentage value.
class TypePercentageRender extends TypeRender {
  final int precision;

  final List<String> _allowedKeys;

  TypePercentageRender([int precision, this._allowedKeys])
      : precision = precision != null && precision >= 0 ? precision : 2,
        super('percentage-render');

  List<String> get allowedKeys => List.from(_allowedKeys).cast();

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is num && _isAllowedKey(nodeKey);
  }

  bool _isAllowedKey(NodeKey nodeKey) {
    if (allowedKeys == null || allowedKeys.isEmpty) return false;

    var leafKey = nodeKey.leafKey.toLowerCase();

    for (var k in allowedKeys) {
      if (k.toLowerCase() == leafKey) return true;
    }

    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var percent = parsePercent(node);

    Element elem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$percent'
        ..type = 'range';

      valueProvider = (parent) {
        var n = parsePercent((elem as InputElement).value);
        return n;
      };
    } else {
      var percentStr = formatPercent(percent, precision);

      elem = SpanElement()..text = percentStr;

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}

/// Renders a select element.
class TypeSelectRender extends TypeRender {
  TypeSelectRender() : super('select-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if (node is List) {
      var valueMapEntriesSize = node
          .whereType<Map>()
          .map((entry) =>
              entry.length == 2 &&
              entry.containsKey('value') &&
              entry.containsKey('label'))
          .length;
      return valueMapEntriesSize == node.length;
    }

    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    // ignore: omit_local_variable_types
    List<Map> options = (node as List).cast();

    var elem = SelectElement();

    for (var opt in options) {
      var optionElement =
          OptionElement(value: opt['value'], data: opt['label']);
      elem.add(optionElement, null);
    }

    ValueProvider valueProvider = (parent) {
      return elem.options.map((opt) {
        // ignore: omit_local_variable_types
        Map<String, dynamic> map = {'value': opt.value, 'label': opt.label};
        if (opt.selected) {
          map['selected'] = true;
        }
        return map;
      }).toList();
    };

    if (render.renderMode != JSONRenderMode.INPUT) {
      elem.disabled = true;
    }

    output.children.add(elem);

    applyCSS(render, output, extraElements: [elem]);

    return valueProvider;
  }
}
