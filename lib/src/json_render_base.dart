
import 'dart:convert' as dart_convert ;
import 'dart:html';
import 'dart:math';

import 'package:dom_tools/dom_tools.dart';
import 'package:intl/intl.dart';
import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_media.dart';

import 'json_render_css.dart';

enum JSONRenderMode {
  INPUT,
  VIEW
}

String convertToJSONAsString(dynamic jsonNode, [String ident = '  ']) {
  if (jsonNode == null) return null;

  if ( ident != null && ident.isNotEmpty ) {
    return dart_convert.JsonEncoder.withIndent('  ').convert( jsonNode ) ;
  }
  else {
    return dart_convert.json.encode( jsonNode ) ;
  }
}

dynamic normalizeJSONValuePrimitive(dynamic value, [bool forceString]) {
  if (value == null) return null ;
  forceString ??= false;

  if ( value is String ) {
    if (forceString) return value ;

    if ( RegExp(r'^-?\d+$').hasMatch(value) ) {
      return int.parse(value) ;
    }
    else if ( RegExp(r'^-?\d+\.\d+$').hasMatch(value) ) {
      return double.parse(value) ;
    }
    else if ( value == 'true' ) {
      return true ;
    }
    else if ( value == 'false' ) {
      return false ;
    }
  }

  return value;
}

num normalizeJSONValueNumber(dynamic value) {
  if (value == null) return null ;

  if (value is num) return value ;

  var s = '$value' ;
  if (s.isEmpty) return null ;

  return num.parse(s) ;
}

typedef ValueProvider = dynamic Function(dynamic parent) ;

ValueProvider VALUE_PROVIDER_NULL = (parent) => null ;

class ValueProviderReference {

  ValueProvider _valueProvider ;

  ValueProviderReference(this._valueProvider);

  ValueProvider get valueProvider => _valueProvider;

  set valueProvider(ValueProvider value) {
    _valueProvider = value;
  }

  dynamic call(dynamic parent) => _valueProvider(parent);

  ValueProvider asValueProvider() {
    return (parent) => _valueProvider(parent) ;
  }

}

class JSONValueSet {

  bool listMode ;

  JSONValueSet( [this.listMode = false] );

  final Map<NodeKey , ValueProvider> values = {} ;

  void put(NodeKey key, ValueProvider val) {
    if (key != null) {
      values[key] = val ?? VALUE_PROVIDER_NULL ;
    }
  }

  String buildJSONAsString(dynamic parent) {
    return convertToJSONAsString( buildJSON(parent) ) ;
  }

  dynamic buildJSON(dynamic parent) {
    if (listMode) {
      return _buildJSONList(parent) ;
    }
    else {
      return _buildJSONObject(parent) ;
    }
  }

  List _buildJSONList(dynamic parent) {
    var json = [] ;

    for (var val in values.values) {
      var value = _callValueProvider(val, json);
      json.add( value ) ;
    }

    return json ;
  }

  Map _buildJSONObject(dynamic parent) {
    var json = {} ;

    for (var entry in values.entries) {
      var value = _callValueProvider(entry.value, json);
      var leafKey = entry.key.leafKey;

      if ( !json.containsKey( leafKey ) ) {
        json[ leafKey ] = value ;
      }
      else {
        var prevVal = json[ leafKey ] ;
        print("[JSONRender] Can't build entry '${ entry.key }' since it's already set! Discarting generated value: <$value> and keeping current value <$prevVal>") ;
      }
    }

    return json ;
  }


  dynamic _callValueProvider(ValueProvider valueProvider, dynamic parent) {
    if (valueProvider == null) return null ;

    var value = valueProvider(parent);
    return value ;
  }

  ValueProvider asValueProvider() {
    return (parent) => buildJSON(parent) ;
  }

}

class JSONRender {

  dynamic _json ;

  JSONRender.fromJSON(this._json) ;

  JSONRender.fromJSONAsString(String jsonAsString) {
    _json = dart_convert.json.decode(jsonAsString) ;
  }

  dynamic get json {
    if (_json == null) return null ;
    if (_json is Map) return Map.unmodifiable(_json) ;
    if (_json is List) return List.unmodifiable(_json) ;
    return _json ;
  }

  Map get jsonObject => json as Map ;
  List get jsonList => json as List ;
  num get jsonNumber => _json is String ? _json : '$_json' ;
  bool get jsonBoolean => _json is bool ? _json : '$_json'.trim().toLowerCase() == 'true' ;
  String get jsonString => '$_json' ;

  JSONRenderMode _renderMode = JSONRenderMode.VIEW ;

  JSONRenderMode get renderMode => _renderMode;

  bool get isInputRenderMode => _renderMode == JSONRenderMode.INPUT ;

  set renderMode(JSONRenderMode value) {
    if (value == null) return ;
    _renderMode = value;
  }

  dynamic buildJSON() {
    if (_treeValueProvider == null) return null;
    return _treeValueProvider(null) ;
  }

  String buildJSONAsString([String ident = '  ']) {
    return convertToJSONAsString( buildJSON() , ident ) ;
  }

  DivElement render() {
    var output = DivElement() ;
    renderToDiv(output) ;
    return output ;
  }

  ValueProvider _treeValueProvider ;

  void renderToDiv( DivElement output ) {
    output.children.clear() ;

    var nodeKey = NodeKey() ;

    try {
      var valueProvider = renderNode(output, _json, null, nodeKey);
      _treeValueProvider = valueProvider;
    }
    catch (e,s) {
      print(e);
      print(s);
    }
  }

  ValueProvider renderNode( DivElement output , dynamic node , dynamic parent, NodeKey nodeKey ) {
    output.style.display = 'inline-block';

    _attachActions(output, node, parent, nodeKey);

    bool valid = validateNode(node, parent, nodeKey) ;
    if (!valid) return null ;

    var nodeMapping = _mapNode( node , parent, nodeKey ) ;

    for (var typeRender in _extendedTypeRenders) {
      if ( typeRender.matches( nodeMapping.nodeMapped, parent, nodeKey ) ) {
        var valueProvider = _callRender(typeRender, output, nodeMapping.nodeMapped, nodeMapping.nodeOriginal, nodeKey);
        return nodeMapping.unmapValueProvider(valueProvider) ;
      }
    }

    for (var typeRender in _defaultTypeRenders) {
      if ( typeRender.matches( nodeMapping.nodeMapped , parent, nodeKey ) ) {
        var valueProvider = _callRender(typeRender, output, nodeMapping.nodeMapped, nodeMapping.nodeOriginal, nodeKey);
        return nodeMapping.unmapValueProvider(valueProvider) ;
      }
    }

    return null ;
  }

  dynamic _attachActions(DivElement output, dynamic node, dynamic parent, NodeKey nodeKey) {
    if ( _typeActions.isEmpty ) return node ;

    for (var typeAction in _typeActions) {
      if ( typeAction.matches(node, parent, nodeKey) ) {

        output.style.cursor = 'pointer' ;

        output.onClick.listen( (e) {
          typeAction.doAction(node, parent, nodeKey);
        }) ;

      }
    }

    return node ;
  }

  dynamic validateNode(dynamic node, dynamic parent, NodeKey nodeKey) {
    if ( ignoreNullNodes && node == null ) return false ;

    if ( _nodeValidators.isEmpty ) return true ;

    for (var validator in _nodeValidators) {
      if ( validator(node, parent, nodeKey) ) {
        return true ;
      }
    }

    return false ;
  }


  _NodeMapping _mapNode(dynamic node, dynamic parent, NodeKey nodeKey) {
    if ( _typeMappers.isEmpty ) return _NodeMapping(null, node, node, parent, nodeKey) ;

    for (var typeMapper in _typeMappers) {
      if ( typeMapper.matches(node, parent, nodeKey) ) {
        var nodeMapped = typeMapper.map(node, parent, nodeKey);
        return _NodeMapping(typeMapper, node, nodeMapped, parent, nodeKey) ;
      }
    }

    return _NodeMapping(null, node, node, parent, nodeKey) ;
  }

  ValueProvider _callRender(TypeRender typeRender, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var valueProvider = typeRender.render(this, output, node, nodeOriginal, nodeKey) ;
    return valueProvider ;
  }

  ////

  List<TypeRender> get allRenders => [ ..._extendedTypeRenders , ..._defaultTypeRenders ] ;

  final List<TypeRender> _defaultTypeRenders = [
    TypeTextRender(), TypeNumberRender(), TypeObjectRender() , TypeListRender(), TypeBoolRender(), TypeNullRender()
  ] ;

  final List<TypeRender> _extendedTypeRenders = [] ;

  bool addTypeRender(TypeRender typeRender, [bool overwrite = false]) {
    if (typeRender == null) return false ;

    if ( _extendedTypeRenders.contains(typeRender) ) {
      if (overwrite ?? false) {
        _extendedTypeRenders.remove(typeRender) ;
      }
      else {
        return false;
      }
    }

    _extendedTypeRenders.add(typeRender) ;

    return true ;
  }

  void addAllTypeRender( List<TypeRender> typeRenders) {
    typeRenders.forEach(  addTypeRender ) ;
  }

  void addAllKnownTypeRenders( ) {

    addTypeRender( TypePaging() ) ;
    addTypeRender( TypeTableRender(false) ) ;
    addTypeRender( TypeDateRender() ) ;
    addTypeRender( TypeUnixEpochRender() ) ;
    addTypeRender( TypeSelectRender() ) ;
    addTypeRender( TypeEmailRender() ) ;
    addTypeRender( TypeURLRender() ) ;
    addTypeRender( TypeGeolocationRender() ) ;
    addTypeRender( TypeImageURLRender() ) ;
    addTypeRender( TypeImageViewerRender() ) ;

  }


  bool removeTypeRender(TypeRender typeRender) {
    if (typeRender == null ) return false ;
    return _extendedTypeRenders.remove(typeRender) ;
  }

  TypeRender getTypeRender(Type type) {
    for (var typeRender in _extendedTypeRenders) {
      var runtimeType = typeRender.runtimeType;
      if ( runtimeType == type ) {
        return typeRender ;
      }
    }

    for (var typeRender in _defaultTypeRenders) {
      if ( typeRender.runtimeType == type ) {
        return typeRender ;
      }
    }

    return null ;
  }

  ////

  bool _ignoreNullNodes = false ;
  bool get ignoreNullNodes => _ignoreNullNodes;

  set ignoreNullNodes(bool value) {
    _ignoreNullNodes = value ?? false ;
  }

  bool _showNodeArrow = true ;
  bool get showNodeArrow => _showNodeArrow;

  set showNodeArrow(bool value) {
    _showNodeArrow = value ?? true ;
  }

  bool _showNodeOpenerAndCloser = true ;
  bool get showNodeOpenerAndCloser => _showNodeOpenerAndCloser;

  set showNodeOpenerAndCloser(bool value) {
    _showNodeOpenerAndCloser = value ?? true ;
  }

  final List<NodeValidator> _nodeValidators = [] ;

  bool addNodeValidator(NodeValidator validator) {
    if (validator == null || _nodeValidators.contains(validator)) return false ;
    _nodeValidators.add(validator) ;
    return true ;
  }

  void addAllNodeValidator( List<NodeValidator> validators ) {
    validators.forEach( addNodeValidator ) ;
  }

  bool removeNodeValidator(NodeValidator validator) {
    if (validator == null ) return false ;
    return _nodeValidators.remove(validator) ;
  }

  ////

  final List<TypeMapper> _typeMappers = [] ;

  bool addTypeMapper(TypeMapper typeMapper) {
    if (typeMapper == null || _typeMappers.contains(typeMapper)) return false ;
    _typeMappers.add(typeMapper) ;
    return true ;
  }

  void addAllTypeMapper( List<TypeMapper> typeMappers ) {
    typeMappers.forEach(  addTypeMapper ) ;
  }

  bool removeTypeMapper(TypeMapper typeMapper) {
    if (typeMapper == null ) return false ;
    return _typeMappers.remove(typeMapper) ;
  }

  ////

  final List<TypeAction> _typeActions = [] ;

  bool addTypeAction(TypeAction typeAction) {
    if (typeAction == null || _typeActions.contains(typeAction)) return false ;
    _typeActions.add(typeAction) ;
    return true ;
  }

  void addAllTypeAction( List<TypeAction> typeActions ) {
    typeActions.forEach(  addTypeAction ) ;
  }

  bool removeTypeAction(TypeAction typeAction) {
    if (typeAction == null ) return false ;
    return _typeActions.remove(typeAction) ;
  }

  CSSThemeSet _cssThemeSet = JSON_RENDER_DEFAULT_THEME_SET ;
  CSSThemeSet get cssThemeSet => _cssThemeSet ;

  set cssThemeSet(CSSThemeSet value) {
    _cssThemeSet = value ?? JSON_RENDER_DEFAULT_THEME_SET ;
  }

  String get cssThemePrefix => _cssThemeSet.cssPrefix ;

  void applyCSS(TypeRender typeRender, Element output, [ List<Element> extraElements ]) {
    _cssThemeSet.ensureThemeLoaded() ;
  }

  static final HttpCache DEFAULT_HTTP_CACHE = HttpCache( maxCacheMemory: 1024*1024*16, timeout: Duration(minutes: 5) ) ;

  HttpCache _httpCache = DEFAULT_HTTP_CACHE ;

  HttpCache get httpCache => _httpCache;

  set httpCache(HttpCache value) {
    _httpCache = value ?? DEFAULT_HTTP_CACHE ;
  }

}

////////////////////////////////////////

class URLFiltered {
  final String url ;
  final String target ;
  final String _label ;
  final String type ;

  URLFiltered(this.url, {this.target, String label , this.type}) : _label = label ;

  String get label => _label ?? url ;

  @override
  String toString() {
    return 'URLLink{url: $url, target: $target, label: $_label}';
  }
}

typedef FilterURL = URLFiltered Function(String URL) ;

void copyElementToClipboard(Element elem) {
  var selection = window.getSelection();
  var range = document.createRange();

  range.selectNodeContents(elem);
  selection.removeAllRanges();
  selection.addRange(range);

  var selectedText = selection.toString();

  document.execCommand('copy');

  if (selectedText != null) {
    window.getSelection().removeAllRanges();
  }
}

////////////////////////////////////////

typedef SizeProvider = int Function() ;

DivElement _createClosableContent( JSONRender render, DivElement output , String textOpener , String textCloser , bool simpleContent, SizeProvider sizeProvider , String cssClass) {
  output.style.textAlign = 'left';

  var container = createDivInlineBlock() ;
  var mainContent = createDivInlineBlock() ;
  var subContent = createDivInlineBlock() ;
  var contentWhenHidden = createDivInlineBlock() ;
  var contentClipboard = createDivInlineBlock() ;

  contentClipboard.style.width = '0px' ;
  contentClipboard.style.height = '0px' ;
  contentClipboard.style.lineHeight = '0px' ;

  if (cssClass != null && cssClass.isNotEmpty) {
    mainContent.classes.add(cssClass) ;
    contentWhenHidden.classes.add(cssClass) ;
  }

  container.style.verticalAlign = 'top' ;

  contentWhenHidden.style.display = 'none' ;
  contentWhenHidden.text = '$textOpener ..${ sizeProvider() }.. $textCloser' ;

  var arrowDown = '&#5121;' ;
  var arrowRight = '&#5125;' ;

  var elemArrow = SpanElement()..innerHtml = '$arrowDown ' ;

  elemArrow.onClick.listen( (e) {
    // if content already hidden, show it:
    if ( mainContent.style.display == 'none' ) {
      elemArrow.innerHtml = '$arrowDown ' ;
      contentWhenHidden.style.display = 'none' ;
      mainContent.style.display = null ;
    }
    // Hide content:
    else {
      elemArrow.innerHtml = '$arrowRight ' ;
      contentWhenHidden.style.display = null ;
      mainContent.style.display = 'none' ;
    }

    var jsonStr = render.buildJSONAsString();

    print('-------------------------------------------------');
    print(jsonStr);

    contentClipboard.innerHtml = '<pre>${jsonStr}</pre>' ;
    copyElementToClipboard(contentClipboard) ;
    contentClipboard.text = '';

  } );


  output.children.add(elemArrow) ;
  output.children.add(container) ;
  container.children.add(mainContent) ;
  container.children.add(contentWhenHidden) ;
  container.children.add(contentClipboard) ;

  if ( render.showNodeOpenerAndCloser ) {
    var elemOpen = SpanElement()
      ..innerHtml = simpleContent ? ' $textOpener' : ' $textOpener<br>'
      ..style.verticalAlign = 'top' ;
    ;

    var elemClose = SpanElement()
      ..innerHtml = simpleContent ? '&nbsp; $textCloser' : '<br>$textCloser<br>'
    ;

    mainContent.children.add(elemOpen) ;
    mainContent.children.add(subContent) ;
    mainContent.children.add(elemClose) ;
  }
  else {
    mainContent.children.add(subContent) ;
  }

  return subContent ;

}


DivElement _createContent( JSONRender render, DivElement output , String textOpener , String textCloser , bool simpleContent, SizeProvider sizeProvider , String cssClass) {
  output.style.textAlign = 'left';

  var container = createDivInlineBlock() ;
  var mainContent = createDivInlineBlock() ;
  var subContent = createDivInlineBlock() ;

  if (cssClass != null && cssClass.isNotEmpty) {
    mainContent.classes.add(cssClass) ;
  }

  container.style.verticalAlign = 'top' ;

  output.children.add(container) ;
  container.children.add(mainContent) ;

  if ( render.showNodeOpenerAndCloser ) {
    var elemOpen = SpanElement()
      ..innerHtml = simpleContent ? ' $textOpener' : ' $textOpener<br>'
      ..style.verticalAlign = 'top' ;
    ;

    var elemClose = SpanElement()
      ..innerHtml = simpleContent ? '&nbsp; $textCloser' : '<br>$textCloser<br>'
    ;

    mainContent.children.add(elemOpen) ;
    mainContent.children.add(subContent) ;
    mainContent.children.add(elemClose) ;
  }
  else {
    mainContent.children.add(subContent) ;
  }

  return subContent ;
}


///////////////////////////////////////

class NodeKey {
  final List<String> path ;

  NodeKey.fromFullKey(String fullKey) : path = List.from( fullKey.trim().split('/').map( (e) => e.trim() ).toList() , growable: false) ;

  NodeKey( [ List<String> path ] ) : path = List.from(path ?? [''] , growable: false) ;

  NodeKey append(String appendKey) => NodeKey( [ ...path , appendKey ] ) ;

  bool matches(RegExp regExp) {
    return regExp.hasMatch(fullKey) ;
  }

  String get fullKey => toString() ;

  String get rootKey => path[0] ;
  String get parentKey => path.length > 1 ? path[ path.length-2 ] : null ;
  String get leafKey => path[ path.length-1 ] ;

  NodeKey get parent => path.length > 1 ? NodeKey( List.from(path)..removeLast() ) : null ;

  @override
  String toString() {
    return path.join('/') ;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeKey &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

abstract class TypeRender {

  final String cssClass ;

  TypeRender(this.cssClass) {
    if (cssClass == null || cssClass.isEmpty) throw ArgumentError('Invalid cssClass') ;
  }

  bool matches(dynamic node, dynamic nodeParent, NodeKey nodeKey) ;

  ValueProvider render( JSONRender render, DivElement output , dynamic node, dynamic nodeOriginal, NodeKey nodeKey) ;

  void applyCSS(JSONRender render, Element output, { String cssClass, List<Element> extraElements } ) {
    if (cssClass == null || cssClass.isEmpty) {
      cssClass = this.cssClass ;
    }

    var classPrefixed = '${ render.cssThemePrefix }$cssClass' ;

    output.classes.add(  classPrefixed ) ;

    if (  extraElements != null ) {
      for (var elem in extraElements) {
        elem.classes.add( classPrefixed ) ;
      }
    }

    render.applyCSS(this, output) ;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeRender && runtimeType == other.runtimeType;

}


////////////////////////////////////////////////////////////////////////////////


class _NodeMapping {

  final TypeMapper typeMapper ;
  final dynamic nodeOriginal ;
  final dynamic nodeMapped ;
  final dynamic nodeParent ;
  final NodeKey nodeKey ;

  _NodeMapping(this.typeMapper, this.nodeOriginal, this.nodeMapped, this.nodeParent, this.nodeKey);

  dynamic unmap(dynamic node, dynamic nodeParent) {
    if (typeMapper != null) {
      return typeMapper.unmap(node, nodeOriginal, nodeParent, nodeKey) ;
    }
    else {
      return node ;
    }
  }

  ValueProvider unmapValueProvider(ValueProvider valueProvider) {
    return (parent) => unmap( valueProvider(parent) , parent ) ;
  }

}


typedef NodeMatcher = bool Function(dynamic node, dynamic parent, NodeKey nodeKey) ;
typedef NodeMap = dynamic Function(dynamic node, dynamic parent, NodeKey nodeKey) ;
typedef NodeUnmap = dynamic Function(dynamic node, dynamic nodeOriginal, dynamic parent, NodeKey nodeKey) ;

class TypeMapper {

  final NodeMatcher matcher ;
  final NodeMap mapper ;
  final NodeUnmap unmapper ;

  TypeMapper(this.matcher, this.mapper, [this.unmapper]);

  bool matches(dynamic node, dynamic parent, NodeKey nodeKey) => matcher(node, parent, nodeKey) ;

  dynamic map(dynamic node, dynamic parent, NodeKey nodeKey) => mapper(node, parent, nodeKey) ;

  dynamic unmap(dynamic node, dynamic nodeOriginal, dynamic parent, NodeKey nodeKey) {
    if (unmapper != null) {
      return unmapper(node, nodeOriginal, parent, nodeKey);
    }
    else {
      return node ;
    }
  }

}

typedef NodeValidator = bool Function(dynamic node, dynamic parent, NodeKey nodeKey) ;

typedef NodeAction = void Function(dynamic node, dynamic parent, NodeKey nodeKey) ;

class TypeAction {

  final NodeMatcher matcher ;
  final NodeAction action ;

  TypeAction(this.matcher, this.action) {
    if ( matcher == null ) throw ArgumentError.notNull('matcher') ;
    if ( action == null ) throw ArgumentError.notNull('action') ;
  }

  bool matches(dynamic node, dynamic parent, NodeKey nodeKey) => matcher(node, parent, nodeKey) ;

  void doAction(dynamic node, dynamic parent, NodeKey nodeKey) {
    try {
      action(node, parent, nodeKey) ;
    }
    catch (e,s) {
      print(e);
      print(s);
    }
  }

}

////////////////////////////////////////////////////////////////////////////////

class TypeListRender extends TypeRender {

  TypeListRender() : super('list-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is List ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var list = (node as List) ?? [] ;

    var simpleList = isSimpleList(list, 8, 10) ;

    var listContent = _createClosableContent( render, output , '[' , ']' , simpleList, () => list.length, cssClass) ;

    var valueSet = JSONValueSet(true) ;

    for (var i = 0; i < list.length; ++i) {
      var elem = list[i];

      var elemIdx = SpanElement()..innerHtml = simpleList ? ' &nbsp; #$i: &nbsp; ' : ' &nbsp; &nbsp; #$i: &nbsp; ' ;
      var elemContent = createDivInlineBlock();

      var elemNodeKey = nodeKey.append('$i');
      var elemValueProvider = render.renderNode(elemContent, elem, node, elemNodeKey) ;

      valueSet.put(elemNodeKey, elemValueProvider) ;

      if (elemValueProvider == null) continue ;

      listContent.children.add(elemIdx) ;
      listContent.children.add(elemContent) ;

      if (!simpleList) {
        listContent.children.add(BRElement());
      }
    }

    this.applyCSS(render, output) ;

    return valueSet.asValueProvider() ;
  }

  bool isSimpleList(List list, int elementsLimit, int stringLimit) {
    if ( list.length <= elementsLimit ) {
      if ( list.where( (e) => (e is num) || (e is bool) || (e is String && e.length <= stringLimit) ).length == list.length ) {
        var listStr = '$list' ;
        return listStr.length < elementsLimit * stringLimit ;
      }
    }
    return false ;
  }

}


class TypeObjectRender extends TypeRender {

  TypeObjectRender() : super('object-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is Map ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var obj = (node as Map) ?? {} ;

    var simpleObj = isSimpleObject(obj, 5, 10) ;

    var showNodeArrow = render.showNodeArrow ;

    var objContent = showNodeArrow ?
      _createClosableContent( render, output, '{', '}', simpleObj, () => obj.length, cssClass)
      :
      _createContent( render, output, '{', '}', simpleObj, () => obj.length, cssClass)
    ;

    var valueSet = JSONValueSet() ;


    var entryI = 0 ;
    for (var entry in obj.entries) {
      var key = entry.key ;

      var elemNodeKey = nodeKey.append(key);

      var elemContent = createDivInlineBlock();
      var elemValueProvider = render.renderNode(elemContent, entry.value, node, elemNodeKey) ;

      valueSet.put(elemNodeKey, elemValueProvider) ;

      if (elemValueProvider == null) continue ;

      var elemKey = SpanElement()..innerHtml = showNodeArrow ? ' &nbsp; &nbsp; $key: &nbsp; ' : '&nbsp;$key: &nbsp; ' ;

      elemContent.style.verticalAlign = 'top' ;

      objContent.children.add(elemKey) ;
      objContent.children.add(elemContent) ;

      var isLastEntry = entryI == obj.length-1 ;

      if (!isLastEntry) {
        objContent.children.add(
            HRElement()
              ..style.border = 'none'
              ..style.margin = '8px 0 0 0'
              ..style.backgroundColor = 'none'
              ..style.backgroundImage = 'none'
        );
      }

      entryI++ ;
    }

    this.applyCSS(render, output) ;

    return valueSet.asValueProvider() ;
  }

  bool isSimpleObject(Map obj, int elementsLimit, int stringLimit) {
    if ( obj.length <= elementsLimit ) {
      if (
        obj.keys.where( (e) => (e is String && e.length <= stringLimit) ).length == obj.length
        &&
        obj.values.where( (e) => (e is num) || (e is bool) || (e is String && e.length <= stringLimit) ).length == obj.length
      ) return true ;
    }
    return false ;
  }

}

////////////////////////////////////////////////////////////////////////////////

void _adjustInputWidthByValueOnKeyPress( InputElement elem , [int maxWidth = 800] ) {
  elem.onKeyUp.listen( (e) {
    _adjustInputWidthByValue(elem) ;
  });

  elem.onChange.listen( (e) {
    _adjustInputWidthByValue(elem) ;
  });

  _adjustInputWidthByValue(elem) ;
}

void _adjustInputWidthByValue( InputElement elem , [int maxWidth = 800] ) {
  var widthChars = elem.value.length+1.5 ;
  if (widthChars < 2) widthChars = 2 ;

  elem.style.width = '${widthChars}ch' ;
  elem.style.maxWidth = '${maxWidth}px' ;
}

////////////////////////////////////////////////////////////////////////////////

class TypeTextRender extends TypeRender {

  bool renderQuotes ;

  TypeTextRender( [ bool renderQuotes = true ] ) :
        renderQuotes = renderQuotes ?? true ,
        super('text-render')
  ;

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is String ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'text'
      ;
      _adjustInputWidthByValueOnKeyPress(elem) ;
      valueProvider = (parent) => normalizeJSONValuePrimitive( (elem as InputElement).value , true ) ;
    }
    else {
      elem = SpanElement()..text = renderQuotes ? '"$node"' : '$node' ;
      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeNumberRender extends TypeRender {

  TypeNumberRender() : super('number-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is num ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'number'
      ;
      _adjustInputWidthByValueOnKeyPress(elem) ;
      valueProvider = (parent) => normalizeJSONValueNumber(  (elem as InputElement).value ) ;
    }
    else {
      elem = SpanElement()..text = '$node' ;
      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeBoolRender extends TypeRender {

  TypeBoolRender() : super('bool-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is bool ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var val = node is bool ? node : false ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..checked = val
        ..type = 'checkbox'
      ;
      valueProvider = (parent) => (elem as InputElement).checked ;
    }
    else {
      elem = SpanElement()..text = '$val' ;
      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeNullRender extends TypeRender {

  TypeNullRender() : super('null-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node == null ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var elem = SpanElement()..text = 'null' ;
    output.children.add(elem) ;
    var valueProvider = VALUE_PROVIDER_NULL ;

    this.applyCSS(render, output) ;

    return valueProvider ;
  }

}

////////////////////////////////////////////////////////////////////////////////

class TypeURLRender extends TypeRender {

  final FilterURL filterURL  ;

  TypeURLRender( { this.filterURL } ) : super('url-render') ;

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( isHttpHURL(node) ) {
      return true ;
    }
    return false ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var urlLabel = '$node';
    var url = urlLabel.trim() ;
    var target ;

    if (filterURL != null) {
      var ret = filterURL(url) ;
      if (ret != null) {
        url = ret.url ;
        urlLabel = ret.label ;
        target = ret.target ;
      }
    }

    if (target != null && target.trim().isEmpty) target = null ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var input = InputElement()
        ..value = urlLabel
        ..type = 'url'
      ;

      elem = input ;

      _adjustInputWidthByValueOnKeyPress(elem) ;

      elem.onDoubleClick.listen( (e) {
        var inputURL = input.value ;

        if (inputURL == urlLabel) {
          window.open(url, target) ;
        }
        else {
          window.open(inputURL, target) ;
        }
      }) ;

      valueProvider = (parent) => (elem as InputElement).value ;
    }
    else {
      var a = AnchorElement(href: url)
        ..text = urlLabel
      ;

      if (target != null) {
        a.target = target ;
      }

      elem = a ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeEmailRender extends TypeRender {

  TypeEmailRender() : super('email-render') ;

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( isEmail(node) ) {
      return true ;
    }
    return false ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var emailLabel = '$node';
    var email = emailLabel.trim() ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var input = InputElement()
        ..value = emailLabel
        ..type = 'email'
      ;

      elem = input ;

      _adjustInputWidthByValueOnKeyPress(elem) ;

      elem.onDoubleClick.listen( (e) {
        var inputEmail = input.value ;

        if (inputEmail == emailLabel) {
          window.open('mailto:$email', null) ;
        }
        else {
          window.open('mailto:$inputEmail', null) ;
        }
      }) ;

      valueProvider = (parent) => (elem as InputElement).value ;
    }
    else {
      var a = AnchorElement(href: 'mailto:$email')
        ..text = emailLabel
      ;

      elem = a ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

final DATE_FORMAT_DATETIME_LOCAL = DateFormat('yyyy-MM-ddTHH:mm:ss', Intl.getCurrentLocale()) ;
final DATE_FORMAT_YYYY_MM_DD = DateFormat('yyyy/MM/dd', Intl.getCurrentLocale()) ;
final DATE_FORMAT_YYYY_MM_DD_HH_MM_SS = DateFormat('yyyy/MM/dd HH:mm:ss', Intl.getCurrentLocale()) ;

final DATE_REGEXP_YYYY_MM_DD = RegExp(r'(?:\d\d\d\d/\d\d/\d\d|\d\d\d\d-\d\d-\d\d)') ;
final DATE_REGEXP_YYYY_MM_DD_HH_MM_SS = RegExp(r'(?:\d\d\d\d/\d\d/\d\d|\d\d\d\d-\d\d-\d\d) \d\d:\d\d:\d\d') ;

class TypeDateRender extends TypeRender {

  TypeDateRender() : super('date-render');

  @override
  bool matches(node, nodeParent, NodeKey nodeKey) {
    if (node is String) {
      if ( DATE_REGEXP_YYYY_MM_DD.hasMatch(node) ) return true ;
      if ( DATE_REGEXP_YYYY_MM_DD_HH_MM_SS.hasMatch(node) ) return true ;
    }
    return false ;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, node, nodeOriginal, NodeKey nodeKey) {
    var s = node as String ;
    var showHour = DATE_REGEXP_YYYY_MM_DD_HH_MM_SS.hasMatch(s) ;
    var dateTime = DateTime.parse(s).toLocal() ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var dateTimeLocal = DATE_FORMAT_DATETIME_LOCAL.format(dateTime) ;

      elem = InputElement()
        ..value = dateTimeLocal
        ..type = 'datetime-local'
      ;

      valueProvider = (parent) {
        var time = DateTime.parse( (elem as InputElement).value );
        var dateTimeStr = showHour ? DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(time) : DATE_FORMAT_YYYY_MM_DD.format(time) ;
        return dateTimeStr ;
      } ;
    }
    else {
      var dateTimeStr = showHour ? DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(dateTime) : DATE_FORMAT_YYYY_MM_DD.format(dateTime) ;

      elem = SpanElement()..text = dateTimeStr ;

      elem.onClick.listen( (e) {
        copyElementToClipboard(elem);
      } ) ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeUnixEpochRender extends TypeRender {

  final bool inMilliseconds ;
  TypeUnixEpochRender( [bool inMilliseconds] ) :
        inMilliseconds = inMilliseconds ?? true ,
        super('unix-epoch-render')
  ;

  bool get inSeconds => !inMilliseconds ;

  bool isInUnixEpochRange(num val) {
    if (inMilliseconds) {
      return val > 946692000000 && val < 32503690800000 ;
    }
    else {
      return val > 946692000 && val < 32503690800 ;
    }
  }

  int parseUnixEpoch(node) {
    if (node is num) {
      return isInUnixEpochRange(node) ? node.toInt() : null ;
    }
    else if (node is String) {
      var s = node.trim() ;
      if ( RegExp(r'^\d+$').hasMatch(s) ) {
        var n = int.parse(s) ;

        if ( isInUnixEpochRange(n) ) {
          return inMilliseconds ? n : n*1000 ;
        }
      }
    }
    return null ;
  }

  ///////////////////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseUnixEpoch(node) != null ;
  }

  DateTime toDateTime(int unixEpoch, bool alreadyInMilliseconds) {
    return DateTime.fromMillisecondsSinceEpoch( alreadyInMilliseconds ? unixEpoch : unixEpoch*1000 ) ;
  }

  int toUnixEpoch(String value) {
    if ( value == null ) return null ;
    value = value.trim() ;
    if ( value.isEmpty ) return null ;

    if ( RegExp(r'^\d+$').hasMatch(value) ) return int.parse(value) ;

    return DateTime.parse(value).millisecondsSinceEpoch ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var unixEpoch = parseUnixEpoch(node) ;
    var dateTime = toDateTime(unixEpoch, true).toLocal() ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var dateTimeLocal = DATE_FORMAT_DATETIME_LOCAL.format(dateTime) ;

      elem = InputElement()
        ..value = dateTimeLocal
        ..type = 'datetime-local'
      ;
      valueProvider = (parent) {
        var time = toUnixEpoch( (elem as InputElement).value );

        var timeDiff = unixEpoch - time ;
        if (timeDiff > 0 && timeDiff <= 1000) {
          time += timeDiff ;
        }

        return time ;
      } ;
    }
    else {
      var dateTimeStr = DATE_FORMAT_YYYY_MM_DD_HH_MM_SS.format(dateTime) ;

      elem = SpanElement()..text = dateTimeStr ;

      elem.onClick.listen( (e) {
        copyElementToClipboard(elem);

        var val = '${ elem.text }' ;
        if ( RegExp(r'^\d+$').hasMatch(val) ) {
          elem.text = dateTimeStr ;
        }
        else {
          elem.text = '$unixEpoch' ;
        }
      } ) ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}

class TypeTimeRender extends TypeRender {

  final bool inMilliseconds ;

  final List<String> _allowedKeys ;

  TypeTimeRender( [bool inMilliseconds , this._allowedKeys ] ) :
        inMilliseconds = inMilliseconds ?? true ,
        super('time-render')
  ;

  bool get inSeconds => !inMilliseconds ;

  List<String> get allowedKeys => List.from(_allowedKeys).cast() ;

  bool isTimeInRange(num val) {
    if (inMilliseconds) {
      return val > -86400000000 && val < 86400000000 ;
    }
    else {
      return val > -86400000 && val < 86400000 ;
    }
  }

  int parseTime(node) {
    if (node is num) {
      return isTimeInRange(node) ? node.toInt() : null ;
    }
    else if (node is String) {
      var s = node.trim() ;
      if ( RegExp(r'^\d+$').hasMatch(s) ) {
        var n = int.parse(s) ;
        if (isTimeInRange(n)) {
          return inMilliseconds ? n : n*1000 ;
        }
      }
    }
    return null ;
  }

  ///////////////////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseTime(node) != null && _isAllowedKey(nodeKey) ;
  }

  bool _isAllowedKey(NodeKey nodeKey) {
    if (allowedKeys == null || allowedKeys.isEmpty) return false ;

    var leafKey = nodeKey.leafKey.toLowerCase() ;

    for (var k in allowedKeys) {
      if ( k.toLowerCase() == leafKey ) return true ;
    }

    return false ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var time = parseTime(node) ;
    var timeOriginal = inMilliseconds ? time : time/1000 ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$timeOriginal'
        ..type = 'number'
      ;

      valueProvider = (parent) {
        var time = parseInt( (elem as InputElement).value );
        return time ;
      } ;
    }
    else {
      var dateTimeStr = formatTimeMillis(time) ;

      elem = SpanElement()..text = dateTimeStr ;

      elem.onClick.listen( (e) {
        copyElementToClipboard(elem);

        var val = '${ elem.text }' ;
        if ( RegExp(r'^\d+$').hasMatch(val) ) {
          elem.text = dateTimeStr ;
        }
        else {
          elem.text = '$timeOriginal' ;
        }
      } ) ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}


class TypePercentageRender extends TypeRender {

  final int precision ;
  final List<String> _allowedKeys ;

  TypePercentageRender( [int precision , this._allowedKeys ] ) :
        precision = precision != null && precision >= 0 ? precision : 2 ,
        super('percentage-render')
  ;

  List<String> get allowedKeys => List.from(_allowedKeys).cast() ;

  ///////////////////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return node is num && _isAllowedKey(nodeKey) ;
  }

  bool _isAllowedKey(NodeKey nodeKey) {
    if (allowedKeys == null || allowedKeys.isEmpty) return false ;

    var leafKey = nodeKey.leafKey.toLowerCase() ;

    for (var k in allowedKeys) {
      if ( k.toLowerCase() == leafKey ) return true ;
    }

    return false ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var percent = parsePercent(node) ;

    Element elem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$percent'
        ..type = 'range'
      ;

      valueProvider = (parent) {
        var n = parsePercent( (elem as InputElement).value );
        return n ;
      } ;
    }
    else {
      var percentStr = formatPercent(percent, precision) ;

      elem = SpanElement()..text = percentStr ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}


////////////////////////////////////////////////////////////////////////////////

class Geolocation {

  static Future<Geolocation> getCurrentGeolocation() async {
      print('Geolocation.getCurrentGeolocation> ...') ;
      var geolocation = window.navigator.geolocation ;
      if (geolocation == null) return null ;
      var currentPosition = await geolocation.getCurrentPosition( enableHighAccuracy: true , timeout: Duration(seconds: 30) , maximumAge: Duration( minutes: 10 ) ) ;
      print('Geolocation.getCurrentGeolocation> $currentPosition') ;
      var coords = currentPosition.coords;
      return Geolocation( coords.latitude , coords.longitude ) ;
  }

  static final RegExp GEOLOCATION_FORMAT = RegExp(r'([-=]?)(\d+[,.]?\d*)\s*[°o]?\s*(\w)') ;

  static num parseLatitudeOrLongitudeValue(String s, [bool onlyWithCardinals = false]) {
    onlyWithCardinals ??= false ;

    var match = GEOLOCATION_FORMAT.firstMatch(s) ;
    if ( match == null ) return null ;

    var signal = match.group(1) ;
    var number = match.group(2) ;
    var cardinal = match.group(3) ;

    if ( signal != null && signal.isNotEmpty ) {
      if (onlyWithCardinals) return null ;
      return double.parse('$signal$number') ;
    }
    else if ( cardinal != null && cardinal.isNotEmpty ) {
      cardinal = cardinal.toUpperCase() ;

      switch (cardinal) {
        case 'N': return double.parse('$number') ;
        case 'S': return double.parse('-$number') ;
        case 'E': return double.parse('$number') ;
        case 'W': return double.parse('-$number') ;
      }
    }

    if (onlyWithCardinals) return null ;
    return double.parse(number) ;
  }

  static String formatLatitude(num lat) {
    return lat >= 0 ? '$lat°E' : '$lat°W' ;
  }

  static String formatLongitude(num long) {
    return long >= 0 ? '$long°N' : '$long°S' ;
  }

  static String formatGeolocation(Point geo) {
    return formatLatitude( geo.x ) +' '+ formatLongitude( geo.y ) ;
  }

  ///////////////////////////////////////////////////

  num _latitude ;
  num _longitude ;

  Geolocation(this._latitude, this._longitude) {
    if (_latitude == null || _longitude == null) throw ArgumentError('Invalid coords: $_latitude $longitude') ;
  }

  factory Geolocation.fromCoords(String coords, [bool onlyWithCardinals]) {
    coords = coords.trim() ;

    var parts = coords.split(RegExp(r'\s+')) ;
    if (parts.length < 2) return null ;

    var lat = parseLatitudeOrLongitudeValue(parts[0] , onlyWithCardinals) ;
    var long = parseLatitudeOrLongitudeValue(parts[1] , onlyWithCardinals) ;

    return lat != null && long != null ? Geolocation(lat, long) : null ;
  }

  num get latitude => _latitude;
  num get longitude => _longitude;

  Point<num> asPoint() => Point(_latitude, _longitude) ;

  @override
  String toString() {
    return formatGeolocation( asPoint() ) ;
  }

  String windowID(String prefix) {
    return '${prefix}__${latitude}__${longitude}';
  }

  String googleMapsURL() {
    return 'https://www.google.com/maps/search/?api=1&query=$_latitude,$longitude' ;
  }

  Future<String> googleMapsDirectionsURL() async {
    var currentGeo = await getCurrentGeolocation() ;
    if (currentGeo == null) return null ;
    return 'https://www.google.com/maps/dir/?api=1&origin=${ currentGeo.latitude },${ currentGeo.longitude }&destination=$_latitude,$longitude' ;
  }


  String openGoogleMaps() {
    var url = googleMapsURL();
    print('Geolocation.openGoogleMaps> $url') ;
    window.open(url, windowID('googlemaps'));
    return url ;
  }

  Future<String> openGoogleMapsDirections() async {
    print('Geolocation.openGoogleMapsDirections> ...') ;
    var url = await googleMapsDirectionsURL();
    print('Geolocation.openGoogleMapsDirections> $url') ;
    window.open(url, windowID('googlemaps_directions'));
    return url ;
  }


}

class TypeGeolocationRender extends TypeRender {

  final bool openDirections ;

  TypeGeolocationRender( [ this.openDirections = false ]) : super('geolocation-render') ;

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseLatitudeLongitude(node) != null ;
  }

  Geolocation parseLatitudeLongitude(dynamic node) {
    if ( node is Map ) {
      var latitudeEntry = findKeyEntry(node, ['latitude'] ) ;
      var longitudeEntry = findKeyEntry(node, ['longitude'] ) ;

      if ( latitudeEntry != null && longitudeEntry != null ) {

        if ( latitudeEntry.value is num && longitudeEntry.value is num ) {
          return Geolocation( latitudeEntry.value , longitudeEntry.value ) ;
        }
        else if ( latitudeEntry.value is String && longitudeEntry.value is String ) {
          var lat = Geolocation.parseLatitudeOrLongitudeValue(latitudeEntry.value) ;
          var long = Geolocation.parseLatitudeOrLongitudeValue(longitudeEntry.value) ;
          return Geolocation( lat, long ) ;
        }
      }
    }
    else if ( node is String ) {
      return Geolocation.fromCoords(node , true) ;
    }

    return null ;
  }


  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var geo = parseLatitudeLongitude(node) ;
    var nodeIsMap = node is Map ;

    Element geoElem ;
    ValueProvider valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var geoStr = geo.toString() ;

      var input = InputElement()
        ..value = geoStr
        ..type = 'text'
      ;

      input.onDoubleClick.listen( (e) {
        var geo2 = Geolocation.fromCoords( input.value ) ;
        openGoogleMaps(geo2) ;
      } ) ;

      var button = SpanElement()
        ..innerHtml = ' &#8853;'
        ..style.fontSize = '125%'
        ..style.cursor = 'pointer'
      ;

      button.onClick.listen( (e) async {
        print('Getting CurrentGeolocation...');
        var myGeolocation = await Geolocation.getCurrentGeolocation() ;
        print('CurrentGeolocation: $myGeolocation');
        input.value = myGeolocation.toString();
      } ) ;

      geoElem = createDivInlineBlock() ;

      geoElem.children.add(input) ;
      geoElem.children.add(button) ;

      valueProvider = (parent) {
        final value = input.value;
        var geo2 = Geolocation.fromCoords(value);

        if (nodeIsMap) {
          return {'latitude': geo2.latitude, 'longitude': geo2.longitude} ;
        }
        else {
          return geo2 ;
        }
      } ;
    }
    else {
      var geoStr = geo.toString() ;

      var elem = SpanElement()..text = geoStr ;

      elem.onClick.listen( (e) {
        copyElementToClipboard(elem);
        openGoogleMaps(geo) ;
      } ) ;

      geoElem = elem ;

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add( SpanElement()..innerHtml = '&#x1F4CD;' ) ;
    output.children.add( geoElem ) ;

    this.applyCSS(render, output, extraElements: [geoElem]) ;

    return valueProvider ;
  }

  void openGoogleMaps( Geolocation geolocation ) {
    if (geolocation == null) return ;

    print('openGoogleMaps> openDirections: $openDirections') ;

    if ( openDirections ) {
      geolocation.openGoogleMapsDirections() ;
    }
    else {
      geolocation.openGoogleMaps() ;
    }
  }

}


////////////////////////////////////////////////////////////////////////////////

class TypeSelectRender extends TypeRender {

  TypeSelectRender() : super('select-render') ;

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( node is List ) {
      var valueMapEntriesSize = node.whereType<Map>().map( (entry) => entry.length == 2 && entry.containsKey('value') && entry.containsKey('label')  ).length ;
      return valueMapEntriesSize == node.length ;
    }

    return false ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    // ignore: omit_local_variable_types
    List<Map> options = (node as List).cast() ;

    var elem = SelectElement();

    for (var opt in options) {
      var optionElement = OptionElement( value: opt['value'] , data: opt['label'] ) ;
      elem.add(optionElement, null) ;
    }

    ValueProvider valueProvider = (parent) {
      return elem.options.map( (opt) {
        // ignore: omit_local_variable_types
        Map<String, dynamic> map = { 'value': opt.value , 'label': opt.label };
        if (opt.selected) {
          map['selected'] = true ;
        }
        return map;
      } ).toList() ;
    } ;

    if (render.renderMode != JSONRenderMode.INPUT) {
      elem.disabled = true ;
    }

    output.children.add(elem) ;

    this.applyCSS(render, output, extraElements: [elem]) ;

    return valueProvider ;
  }

}


////////////////////////////////////////////////////////////////////////////////

class TypePaging extends TypeRender {

  TypePaging() : super('paging-render');

  @override
  bool matches(node, nodeParent, NodeKey nodeKey) {
    if ( node is Map ) {
      var paging = JSONPaging.from(node) ;
      return paging != null ;
    }
    return false ;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, node, nodeOriginal, NodeKey nodeKey) {
    var paging = JSONPaging.from(node) ;

    var needsPaging = paging.needsPaging ;

    var valueSet = JSONValueSet(true) ;

    var table = TableElement() ;

    if (needsPaging) {
      var tHeader = table.createTHead() ;
      var headerRow = tHeader.addRow();

      this.applyCSS(render, headerRow) ;

      var cell = headerRow.addCell();
      cell.style.fontWeight = 'bold' ;

      var pagingDiv = _createPagingDiv(render, output, node , nodeOriginal, nodeKey, paging);
      cell.children.add( pagingDiv ) ;
    }

    {
      var tbody = table.createTBody();

      var entry = paging.elements ;
      var entryNodeKey = nodeKey.append( paging.elementsEntryKey );

      bool valid = render.validateNode(entry, node, entryNodeKey) ;

      if (valid) {
        var valueSetEntry = JSONValueSet() ;

        valueSet.put(entryNodeKey, valueSetEntry.asValueProvider()) ;

        var row = tbody.addRow();

        this.applyCSS(render, row) ;

        var cell = row.addCell() ;

        var elemContent = createDivInlineBlock();
        var elemValueProvider = render.renderNode(elemContent, entry, node, entryNodeKey) ;

        valueSetEntry.put(entryNodeKey, elemValueProvider) ;

        if (elemValueProvider != null) {
          elemContent.style.verticalAlign = 'top' ;
          cell.children.add(elemContent) ;
        }
      }
      else {
        valueSet.put(entryNodeKey, null) ;
      }

    }

    if (needsPaging) {
      var tFoot = table.createTFoot() ;
      var footRow = tFoot.addRow();

      this.applyCSS(render, footRow) ;

      var cell = footRow.addCell();
      cell.style.fontWeight = 'bold' ;

      var pagingDiv = _createPagingDiv(render, output, node , nodeOriginal, nodeKey, paging);
      cell.children.add( pagingDiv ) ;
    }

    output.children.add(table) ;

    this.applyCSS(render, output, extraElements: [table]) ;

    return valueSet.asValueProvider() ;
  }

  DivElement _createPagingDiv(JSONRender render, DivElement output, node, nodeOriginal, NodeKey nodeKey, JSONPaging paging) {
    var pagingDiv = createDivInline() ;

    var prev = SpanElement()
      ..style.cursor = 'pointer'
      ..innerHtml = '&#x2190; '
    ;

    var current = SpanElement()
      ..text = '${ paging.currentPage+1 }'
    ;

    var next = SpanElement()
      ..style.cursor = 'pointer'
      ..innerHtml = ' &#x2192;'
    ;

    prev.onClick.listen((e) async {
      prev.text = '... ' ;
      var prevPaging = await paging.requestPreviousPage() ;
      if (prevPaging != null) {
        output.children.clear();
        this.render(render, output, prevPaging, nodeOriginal, nodeKey);
      }
    });

    next.onClick.listen((e) async {
      next.innerHtml = ' ...' ;
      var nextPaging = await paging.requestNextPage() ;
      if (nextPaging != null) {
        output.children.clear();
        this.render(render, output, nextPaging, nodeOriginal, nodeKey);
      }
    });

    if (paging.isFirstPage) {
      pagingDiv.children.add( current ) ;
      pagingDiv.children.add( next ) ;
    }
    else if (paging.isLastPage) {
      pagingDiv.children.add( prev ) ;
      pagingDiv.children.add( current ) ;
    }
    else {
      pagingDiv.children.add( prev ) ;
      pagingDiv.children.add( current ) ;
      pagingDiv.children.add( next ) ;
    }

    return pagingDiv ;
  }

}

class TypeTableRender extends TypeRender {

  bool _ignoreNullColumns ;

  TypeTableRender([bool ignoreNullColumns]) : super('table-render') {
    this.ignoreNullColumns = ignoreNullColumns ;
  }

  bool get ignoreNullColumns => _ignoreNullColumns;

  set ignoreNullColumns(bool value) {
    _ignoreNullColumns = value ?? false ;
  }

  final Set<String> _ignoredColumns = {} ;

  List<String> get ignoredColumns => _ignoredColumns.toList() ;

  List<String> clearIgnoreColumns() {
    var list = _ignoredColumns.toList() ;
    _ignoredColumns.clear() ;
    return list ;
  }

  bool ignoreColumn(String column, [bool ignore]) {
    if (column == null) return false ;
    column = column.trim() ;
    if (column.isEmpty) return false ;

    ignore ??= true ;

    if (ignore) {
      _ignoredColumns.add(column);
      return true ;
    }
    else {
      _ignoredColumns.remove(column);
      return false ;
    }
  }

  bool isIgnoredColumn(String column) {
    if (column == null || _ignoredColumns.isEmpty ) return false ;
    return _ignoredColumns.contains(column) ;
  }

  //////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( node is List ) {
      var nonMap = node.firstWhere( (e) => !(e is Map) , orElse: () => null) ;
      return nonMap == null ;
    }
    return false ;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    // ignore: omit_local_variable_types
    List<Map> list = (node as List).cast() ?? [] ;

    var valueSet = JSONValueSet(true) ;

    var columns = getCollectionColumns(list) ;

    var contentClipboard = createDivInlineBlock()
        ..style.width = '0px'
        ..style.height = '0px'
        ..style.display = 'none'
    ;

    output.style.maxWidth = '98vw' ;
    output.style.overflow = 'auto' ;

    var table = TableElement() ;

    {
      var tHeader = table.createTHead() ;

      var headerRow = tHeader.addRow();

      this.applyCSS(render, headerRow) ;

      headerRow.onClick.listen( (e) {
        var jsonStr = render.buildJSONAsString();

        print('-------------------------------------------------');
        print(jsonStr);

        contentClipboard.style.display = null ;

        contentClipboard.innerHtml = '<pre>${jsonStr}</pre>' ;
        copyElementToClipboard(contentClipboard) ;
        contentClipboard.text = '';

        contentClipboard.style.display = 'none' ;
      } );

      for (var columnEntry in columns.entries) {
        var columnKey = columnEntry.key ;
        var columnWithValue = columnEntry.value ;

        if ( (ignoreNullColumns && !columnWithValue) || isIgnoredColumn(columnKey) ) continue ;

        var cell = headerRow.addCell();
        cell.text = columnKey;
        cell.style.fontWeight = 'bold' ;
      }
    }

    {
      var tbody = table.createTBody();

      for (var i = 0; i < list.length; ++i) {
        var entry = list[i];
        var entryNodeKey = nodeKey.append('$i');

        bool valid = render.validateNode(entry, node, entryNodeKey) ;
        if (!valid) {
          valueSet.put(entryNodeKey, null) ;
          continue ;
        }

        var valueSetEntry = JSONValueSet() ;

        valueSet.put(entryNodeKey, valueSetEntry.asValueProvider()) ;

        var row = tbody.addRow();

        var rowCSS = i % 2 == 0 ? 'table-row1-render' : 'table-row2-render' ;

        this.applyCSS(render, row, cssClass: rowCSS) ;

        for (var columnEntry in columns.entries) {
          var columnKey = columnEntry.key ;
          var columnWithValue = columnEntry.value ;

          if ( ignoreNullColumns && !columnWithValue ) {
            if ( entry.containsKey(columnKey) ) {
              assert( entry[columnKey] == null , 'Not null: ${ entry[columnKey] }' ) ;
              var elemNodeKey = entryNodeKey.append(columnKey);
              valueSetEntry.put(elemNodeKey, VALUE_PROVIDER_NULL);
            }
            continue ;
          }
          else if ( isIgnoredColumn(columnKey) ) {
            if ( entry.containsKey(columnKey) ) {
              var val = entry[columnKey] ;
              var elemNodeKey = entryNodeKey.append(columnKey);
              valueSetEntry.put(elemNodeKey, (parent) => val);
            }
            continue ;
          }

          var cell = row.addCell() ;

          if ( entry.containsKey(columnKey) ) {
            var val = entry[columnKey] ;

            var elemNodeKey = entryNodeKey.append(columnKey);

            var elemContent = createDivInlineBlock();
            var elemValueProvider = render.renderNode(elemContent, val, entry, elemNodeKey) ;

            valueSetEntry.put(elemNodeKey, elemValueProvider) ;

            if (elemValueProvider == null) continue ;

            elemContent.style.verticalAlign = 'top' ;

            cell.children.add(elemContent) ;
          }

        }

      }
    }

    output.children.add(contentClipboard);
    output.children.add(table) ;

    this.applyCSS(render, output, extraElements: [table]) ;

    return valueSet.asValueProvider() ;
  }

  Map<String,bool> getCollectionColumns(List<Map> list) {
    // ignore: omit_local_variable_types
    Map<String,bool> columns = {} ;
    list.forEach( (e) => extractColumns(e,columns) ) ;
    return columns ;
  }

  void extractColumns(Map map, Map<String,bool> columns) {
    if (map == null) return ;
    map.entries.forEach( (entry) {
      var key = entry.key ;
      var val = entry.value ;

      var containsValue = val != null || ( columns[key] ?? false ) ;
      return columns[key] = containsValue ;
    } ) ;
  }

}

