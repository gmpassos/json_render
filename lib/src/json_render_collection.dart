import 'dart:html';

import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';

typedef SizeProvider = int Function();

DivElement _createClosableContent(
    JSONRender render,
    DivElement output,
    String textOpener,
    String textCloser,
    bool simpleContent,
    SizeProvider sizeProvider,
    String cssClass) {
  output.style.textAlign = 'left';

  var container = createDivInline();
  var mainContent = createDivInline();
  var subContent = createDivInline();
  var contentWhenHidden = createDivInline();
  var contentClipboard = createDivInline();

  contentClipboard.style.width = '0px';
  contentClipboard.style.height = '0px';
  contentClipboard.style.lineHeight = '0px';

  if (cssClass != null && cssClass.isNotEmpty) {
    mainContent.classes.add(cssClass);
    contentWhenHidden.classes.add(cssClass);
  }

  container.style.verticalAlign = 'top';

  contentWhenHidden.style.display = 'none';
  contentWhenHidden.text = '$textOpener ..${sizeProvider()}.. $textCloser';

  var arrowDown = '&#5121;';
  var arrowRight = '&#5125;';

  var elemArrow = SpanElement()..innerHtml = '$arrowDown ';

  elemArrow.onClick.listen((e) {
    // if content already hidden, show it:
    if (mainContent.style.display == 'none') {
      elemArrow.innerHtml = '$arrowDown ';
      contentWhenHidden.style.display = 'none';
      mainContent.style.display = null;
    }
    // Hide content:
    else {
      elemArrow.innerHtml = '$arrowRight ';
      contentWhenHidden.style.display = null;
      mainContent.style.display = 'none';
    }

    var jsonStr = render.buildJSONAsString();

    print('-------------------------------------------------');
    print(jsonStr);

    contentClipboard.innerHtml = '<pre>${jsonStr}</pre>';
    copyElementToClipboard(contentClipboard);
    contentClipboard.text = '';
  });

  output.children.add(elemArrow);
  output.children.add(container);
  container.children.add(mainContent);
  container.children.add(contentWhenHidden);
  container.children.add(contentClipboard);

  if (render.showNodeOpenerAndCloser) {
    var elemOpen = SpanElement()
      ..innerHtml = simpleContent ? ' $textOpener' : ' $textOpener<br>'
      ..style.verticalAlign = 'top';
    ;

    var elemClose = SpanElement()
      ..innerHtml =
          simpleContent ? '&nbsp; $textCloser' : '<br>$textCloser<br>';

    mainContent.children.add(elemOpen);
    mainContent.children.add(subContent);
    mainContent.children.add(elemClose);
  } else {
    mainContent.children.add(subContent);
  }

  return subContent;
}

DivElement _createContent(
    JSONRender render,
    DivElement output,
    String textOpener,
    String textCloser,
    bool simpleContent,
    SizeProvider sizeProvider,
    String cssClass) {
  output.style.textAlign = 'left';

  var container = createDivInline();
  var mainContent = createDivInline();
  var subContent = createDivInline();

  if (cssClass != null && cssClass.isNotEmpty) {
    mainContent.classes.add(cssClass);
  }

  container.style.verticalAlign = 'top';

  output.children.add(container);
  container.children.add(mainContent);

  if (render.showNodeOpenerAndCloser) {
    var elemOpen = SpanElement()
      ..innerHtml = simpleContent ? ' $textOpener' : ' $textOpener<br>'
      ..style.verticalAlign = 'top';
    ;

    var elemClose = SpanElement()
      ..innerHtml =
          simpleContent ? '&nbsp; $textCloser' : '<br>$textCloser<br>';

    mainContent.children.add(elemOpen);
    mainContent.children.add(subContent);
    mainContent.children.add(elemClose);
  } else {
    mainContent.children.add(subContent);
  }

  return subContent;
}

/// Renders a JSON List.
class TypeListRender extends TypeRender {
  TypeListRender() : super('list-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is List;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var list = (node as List) ?? [];

    var simpleList = isSimpleList(list, 8, 10);

    var listContent = _createClosableContent(
        render, output, '[', ']', simpleList, () => list.length, cssClass);

    var valueSet = JSONValueSet(true);

    for (var i = 0; i < list.length; ++i) {
      var elem = list[i];

      var elemIdx = SpanElement()
        ..innerHtml =
            simpleList ? ' &nbsp; #$i: &nbsp; ' : ' &nbsp; &nbsp; #$i: &nbsp; ';
      var elemContent = createDivInline();

      var elemNodeKey = nodeKey.append('$i');

      if (render.isHiddenNode(elemNodeKey)) {
        valueSet.put(elemNodeKey, (p) => nodeOriginal);
        continue;
      }

      var elemValueProvider =
          render.renderNode(elemContent, elem, node, elemNodeKey);

      valueSet.put(elemNodeKey, elemValueProvider);

      if (elemValueProvider == null) continue;

      listContent.children.add(elemIdx);
      listContent.children.add(elemContent);

      if (!simpleList) {
        listContent.children.add(BRElement());
      }
    }

    this.applyCSS(render, output);

    return valueSet.asValueProvider();
  }

  bool isSimpleList(List list, int elementsLimit, int stringLimit) {
    if (list.length <= elementsLimit) {
      if (list
              .where((e) =>
                  (e is num) ||
                  (e is bool) ||
                  (e is String && e.length <= stringLimit))
              .length ==
          list.length) {
        var listStr = '$list';
        return listStr.length < elementsLimit * stringLimit;
      }
    }
    return false;
  }
}

/// Renders a JSON Object.
class TypeObjectRender extends TypeRender {
  TypeObjectRender() : super('object-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is Map;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var obj = (node as Map) ?? {};

    var simpleObj = isSimpleObject(obj, 5, 10);

    var showNodeArrow = render.showNodeArrow;

    var objContent = showNodeArrow
        ? _createClosableContent(
            render, output, '{', '}', simpleObj, () => obj.length, cssClass)
        : _createContent(
            render, output, '{', '}', simpleObj, () => obj.length, cssClass);

    var valueSet = JSONValueSet();

    var entryI = 0;
    for (var entry in obj.entries) {
      var key = entry.key;

      var elemNodeKey = nodeKey.append(key);

      if (render.isHiddenNode(elemNodeKey)) {
        valueSet.put(elemNodeKey, (p) => nodeOriginal);
        continue;
      }

      var elemContent = createDivInline();
      var elemValueProvider =
          render.renderNode(elemContent, entry.value, node, elemNodeKey);

      valueSet.put(elemNodeKey, elemValueProvider);

      if (elemValueProvider == null) continue;

      var elemKey = SpanElement()
        ..innerHtml = showNodeArrow
            ? ' &nbsp; &nbsp; $key: &nbsp; '
            : '&nbsp;$key: &nbsp; ';

      elemContent.style.verticalAlign = 'top';

      objContent.children.add(elemKey);
      objContent.children.add(elemContent);

      var isLastEntry = entryI == obj.length - 1;

      if (!isLastEntry) {
        objContent.children.add(HRElement()
          ..style.border = 'none'
          ..style.margin = '8px 0 0 0'
          ..style.backgroundColor = 'none'
          ..style.backgroundImage = 'none');
      }

      entryI++;
    }

    this.applyCSS(render, output);

    return valueSet.asValueProvider();
  }

  bool isSimpleObject(Map obj, int elementsLimit, int stringLimit) {
    if (obj.length <= elementsLimit) {
      if (obj.keys
                  .where((e) => (e is String && e.length <= stringLimit))
                  .length ==
              obj.length &&
          obj.values
                  .where((e) =>
                      (e is num) ||
                      (e is bool) ||
                      (e is String && e.length <= stringLimit))
                  .length ==
              obj.length) return true;
    }
    return false;
  }
}

/// Renders a paging result JSON tree.
class TypePaging extends TypeRender {
  TypePaging() : super('paging-render');

  @override
  bool matches(node, nodeParent, NodeKey nodeKey) {
    if (node is Map) {
      var paging = JSONPaging.from(node);
      return paging != null;
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, node, nodeOriginal,
      NodeKey nodeKey) {
    var paging = JSONPaging.from(node);

    var needsPaging = paging.needsPaging;

    var valueSet = JSONValueSet(true);

    var table = TableElement();

    if (needsPaging) {
      var tHeader = table.createTHead();
      var headerRow = tHeader.addRow();

      this.applyCSS(render, headerRow);

      var cell = headerRow.addCell();
      cell.style.fontWeight = 'bold';

      var pagingDiv =
          _createPagingDiv(render, output, node, nodeOriginal, nodeKey, paging);
      cell.children.add(pagingDiv);
    }

    {
      var tbody = table.createTBody();

      var entry = paging.elements;
      var entryNodeKey = nodeKey.append(paging.elementsEntryKey);

      bool valid = render.validateNode(entry, node, entryNodeKey);

      if (valid) {
        var valueSetEntry = JSONValueSet();

        valueSet.put(entryNodeKey, valueSetEntry.asValueProvider());

        var row = tbody.addRow();

        this.applyCSS(render, row);

        var cell = row.addCell();

        var elemContent = createDivInline();
        var elemValueProvider =
            render.renderNode(elemContent, entry, node, entryNodeKey);

        valueSetEntry.put(entryNodeKey, elemValueProvider);

        if (elemValueProvider != null) {
          elemContent.style.verticalAlign = 'top';
          cell.children.add(elemContent);
        }
      } else {
        valueSet.put(entryNodeKey, null);
      }
    }

    if (needsPaging) {
      var tFoot = table.createTFoot();
      var footRow = tFoot.addRow();

      this.applyCSS(render, footRow);

      var cell = footRow.addCell();
      cell.style.fontWeight = 'bold';

      var pagingDiv =
          _createPagingDiv(render, output, node, nodeOriginal, nodeKey, paging);
      cell.children.add(pagingDiv);
    }

    output.children.add(table);

    this.applyCSS(render, output, extraElements: [table]);

    return valueSet.asValueProvider();
  }

  DivElement _createPagingDiv(JSONRender render, DivElement output, node,
      nodeOriginal, NodeKey nodeKey, JSONPaging paging) {
    var pagingDiv = createDivInline();

    var prev = SpanElement()
      ..style.cursor = 'pointer'
      ..innerHtml = '&#x2190; ';

    var current = SpanElement()..text = '${paging.currentPage + 1}';

    var next = SpanElement()
      ..style.cursor = 'pointer'
      ..innerHtml = ' &#x2192;';

    prev.onClick.listen((e) async {
      prev.text = '... ';
      var prevPaging = await paging.requestPreviousPage();
      if (prevPaging != null) {
        output.children.clear();
        this.render(render, output, prevPaging, nodeOriginal, nodeKey);
      }
    });

    next.onClick.listen((e) async {
      next.innerHtml = ' ...';
      var nextPaging = await paging.requestNextPage();
      if (nextPaging != null) {
        output.children.clear();
        this.render(render, output, nextPaging, nodeOriginal, nodeKey);
      }
    });

    if (paging.isFirstPage) {
      pagingDiv.children.add(current);
      pagingDiv.children.add(next);
    } else if (paging.isLastPage) {
      pagingDiv.children.add(prev);
      pagingDiv.children.add(current);
    } else {
      pagingDiv.children.add(prev);
      pagingDiv.children.add(current);
      pagingDiv.children.add(next);
    }

    return pagingDiv;
  }
}

/// Renders a Table of data.
class TypeTableRender extends TypeRender {
  bool _ignoreNullColumns;

  TypeTableRender([bool ignoreNullColumns = true]) : super('table-render') {
    this.ignoreNullColumns = ignoreNullColumns;
  }

  bool get ignoreNullColumns => _ignoreNullColumns;

  set ignoreNullColumns(bool value) {
    _ignoreNullColumns = value ?? false;
  }

  final Set<String> _ignoredColumns = {};

  List<String> get ignoredColumns => _ignoredColumns.toList();

  List<String> clearIgnoreColumns() {
    var list = _ignoredColumns.toList();
    _ignoredColumns.clear();
    return list;
  }

  bool ignoreColumn(String column, [bool ignore]) {
    if (column == null) return false;
    column = column.trim();
    if (column.isEmpty) return false;

    ignore ??= true;

    if (ignore) {
      _ignoredColumns.add(column);
      return true;
    } else {
      _ignoredColumns.remove(column);
      return false;
    }
  }

  bool isIgnoredColumn(String column) {
    if (column == null || _ignoredColumns.isEmpty) return false;
    return _ignoredColumns.contains(column);
  }

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if (node is List) {
      var nonMap = node.firstWhere((e) => !(e is Map), orElse: () => null);
      return nonMap == null;
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    // ignore: omit_local_variable_types
    List<Map> list = (node as List).cast() ?? [];

    var valueSet = JSONValueSet(true);

    var columns = getCollectionColumns(render, nodeKey, list);

    var contentClipboard = createDivInline()
      ..style.width = '0px'
      ..style.height = '0px'
      ..style.display = 'none';

    output.style.maxWidth = '98vw';
    output.style.overflow = 'auto';

    var table = TableElement();

    {
      var tHeader = table.createTHead();

      var headerRow = tHeader.addRow();

      this.applyCSS(render, headerRow);

      headerRow.onClick.listen((e) {
        var jsonStr = render.buildJSONAsString();

        print('-------------------------------------------------');
        print(jsonStr);

        contentClipboard.style.display = null;

        contentClipboard.innerHtml = '<pre>${jsonStr}</pre>';
        copyElementToClipboard(contentClipboard);
        contentClipboard.text = '';

        contentClipboard.style.display = 'none';
      });

      for (var columnEntry in columns.entries) {
        var columnKey = columnEntry.key;
        var columnWithValue = columnEntry.value;

        if ((ignoreNullColumns && !columnWithValue) ||
            isIgnoredColumn(columnKey)) continue;

        var cell = headerRow.addCell();
        cell.text = columnKey;
        cell.style.fontWeight = 'bold';
      }
    }

    {
      var tbody = table.createTBody();

      for (var i = 0; i < list.length; ++i) {
        var entry = list[i];
        var entryNodeKey = nodeKey.append('$i');

        bool valid = render.validateNode(entry, node, entryNodeKey);
        if (!valid) {
          valueSet.put(entryNodeKey, null);
          continue;
        }

        var valueSetEntry = JSONValueSet();

        valueSet.put(entryNodeKey, valueSetEntry.asValueProvider());

        var row = tbody.addRow();

        var rowCSS = i % 2 == 0 ? 'table-row1-render' : 'table-row2-render';

        this.applyCSS(render, row, cssClass: rowCSS);

        for (var columnEntry in columns.entries) {
          var columnKey = columnEntry.key;
          var columnWithValue = columnEntry.value;

          if (ignoreNullColumns && !columnWithValue) {
            if (entry.containsKey(columnKey)) {
              assert(entry[columnKey] == null, 'Not null: ${entry[columnKey]}');
              var elemNodeKey = entryNodeKey.append(columnKey);
              valueSetEntry.put(elemNodeKey, VALUE_PROVIDER_NULL);
            }
            continue;
          } else if (isIgnoredColumn(columnKey)) {
            if (entry.containsKey(columnKey)) {
              var val = entry[columnKey];
              var elemNodeKey = entryNodeKey.append(columnKey);
              valueSetEntry.put(elemNodeKey, (parent) => val);
            }
            continue;
          }

          var cell = row.addCell();

          if (entry.containsKey(columnKey)) {
            var val = entry[columnKey];

            var elemNodeKey = entryNodeKey.append(columnKey);

            if (render.isHiddenNode(elemNodeKey)) {
              valueSet.put(elemNodeKey, (p) => nodeOriginal);
              continue;
            }

            var elemContent = createDivInline();
            var elemValueProvider =
                render.renderNode(elemContent, val, entry, elemNodeKey);

            valueSetEntry.put(elemNodeKey, elemValueProvider);

            if (elemValueProvider == null) continue;

            elemContent.style.verticalAlign = 'top';

            cell.children.add(elemContent);
          }
        }
      }
    }

    output.children.add(contentClipboard);
    output.children.add(table);

    this.applyCSS(render, output, extraElements: [table]);

    return valueSet.asValueProvider();
  }

  Map<String, bool> getCollectionColumns(
      JSONRender render, NodeKey nodeKey, List<Map> list) {
    // ignore: omit_local_variable_types
    Map<String, bool> columns = {};

    var legnth = list.length;

    for (var i = 0; i < legnth; ++i) {
      var elem = list[i];

      var entryNodeKey = nodeKey.append('$i');

      extractColumns(render, elem, entryNodeKey, columns);
    }

    return columns;
  }

  void extractColumns(JSONRender render, Map map, NodeKey entryNodeKey,
      Map<String, bool> columns) {
    if (map == null) return;

    map.entries.forEach((entry) {
      var key = entry.key;
      var val = entry.value;

      if (val != null) {
        var columnNodeKey = entryNodeKey.append(key);

        if (render.isHiddenNode(columnNodeKey)) {
          return;
        }

        columns[key] = true;
      } else {
        columns[key] ??= false;
      }
    });
  }
}
