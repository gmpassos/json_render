
import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:dom_tools/dom_tools.dart';
import 'package:intl/intl.dart';
import 'package:mercury_client/mercury_client.dart';

enum JSONRenderMode {
  INPUT,
  VIEW
}

String convertToJSONAsString(dynamic jsonNode, [String ident = '  ']) {
  if (jsonNode == null) return null;

  if ( ident != null && ident.isNotEmpty ) {
    return JsonEncoder.withIndent('  ').convert( jsonNode ) ;
  }
  else {
    return json.encode( jsonNode ) ;
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

typedef _ValueProvider = dynamic Function() ;

class _JSONValueSet {

  bool listMode ;

  _JSONValueSet( [this.listMode = false] );

  final Map<NodeKey , _ValueProvider> values = {} ;

  void put(NodeKey key, _ValueProvider val) {
    if (key != null && val != null) {
      values[key] = val ;
    }
  }

  String buildJSONAsString() {
    return convertToJSONAsString( buildJSON() ) ;
  }

  dynamic buildJSON() {
    if (listMode) {
      return _buildJSONList() ;
    }
    else {
      return _buildJSONObject() ;
    }
  }

  List _buildJSONList() {
    var json = [] ;

    for (var val in values.values) {
      json.add( _callValueProvider(val) ) ;
    }

    return json ;
  }

  Map _buildJSONObject() {
    var json = {} ;

    for (var entry in values.entries) {
      json[ entry.key.leafKey ] = ( entry.value() ) ;
    }

    return json ;
  }


  dynamic _callValueProvider(_ValueProvider valueProvider) {
    if (valueProvider == null) return valueProvider ;

    var value = valueProvider();
    return value ;
  }

  _ValueProvider asValueProvider() {
    return () => buildJSON() ;
  }

}


class JSONRender {

  dynamic _json ;

  JSONRender.fromJSON(this._json) ;

  JSONRender.fromJSONAsString(String jsonAsString) {
    _json = json.decode(jsonAsString) ;
  }

  JSONRenderMode _renderMode = JSONRenderMode.VIEW ;

  JSONRenderMode get renderMode => _renderMode;

  set renderMode(JSONRenderMode value) {
    if (value == null) return ;
    _renderMode = value;
  }

  DivElement render() {
    var output = DivElement() ;
    renderToDiv(output) ;
    return output ;
  }

  _ValueProvider _treeValueProvider ;

  dynamic buildJSON() {
    if (_treeValueProvider == null) return null;
    return _treeValueProvider() ;
  }

  String buildJSONAsString([String ident = '  ']) {
    return convertToJSONAsString( buildJSON() , ident ) ;
  }

  void renderToDiv( DivElement output ) {
    output.children.clear() ;

    var nodeKey = NodeKey() ;

    var valueProvider = _render( output , _json , nodeKey ) ;

    _treeValueProvider = valueProvider ;
  }

  _ValueProvider _render( DivElement output , dynamic node , NodeKey nodeKey ) {
    output.style.display = 'inline-block';

    var valueSet = _JSONValueSet() ;

    for (var typeRender in _extendedTypeRenders) {
      if ( typeRender.matches(node) ) {
        return _callRender(typeRender, output, node, nodeKey, valueSet) ;
      }
    }

    for (var typeRender in _defaultTypeRenders) {
      if ( typeRender.matches(node) ) {
        return _callRender(typeRender, output, node, nodeKey, valueSet) ;
      }
    }

    return null ;
  }


  _ValueProvider _callRender(TypeRender typeRender, DivElement output, node, NodeKey nodeKey, _JSONValueSet valueSet) {
    var valueProvider = typeRender.render(this, output, node, nodeKey) ;
    valueSet.put(nodeKey, valueProvider) ;
    return valueProvider ;
  }

  List<TypeRender> get allRenders => [ ..._extendedTypeRenders , ..._defaultTypeRenders ] ;

  final List<TypeRender> _defaultTypeRenders = [
    TypeTextRender(), TypeNumberRender(), TypeObjectRender() , TypeListRender(), TypeBoolRender(), TypeNullRender()
  ] ;

  final List<TypeRender> _extendedTypeRenders = [] ;

  bool addTypeRender(TypeRender typeRender) {
    if (typeRender == null || _extendedTypeRenders.contains(typeRender)) return false ;
    _extendedTypeRenders.add(typeRender) ;
    _setAllRendersDefaultCSS();
    return true ;
  }

  void addAllTypeRender( List<TypeRender> typeRenders) {
    typeRenders.forEach(  addTypeRender ) ;
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

  TypeRender setTypeRenderCSS(Type type, CssStyleDeclaration css) {
    var typeRender = getTypeRender(type) ;
    if (typeRender == null) return null ;

    typeRender.css = css ;
    return typeRender ;
  }


  CssStyleDeclaration _defaultCss ;

  CssStyleDeclaration get defaultCss => _defaultCss ;

  set defaultCss(CssStyleDeclaration css) {
    _defaultCss = css ?? CssStyleDeclaration() ;
    _setAllRendersDefaultCSS();
  }

  void _setAllRendersDefaultCSS() {
    if (!hasDefaultCss) return ;

    for ( var typeRender in _extendedTypeRenders ) {
      typeRender.css.cssText = _defaultCss.cssText ;
    }

    for ( var typeRender in _defaultTypeRenders ) {
      typeRender.css = _defaultCss ;
    }

  }

  bool get hasDefaultCss => _defaultCss != null && _defaultCss.cssText.trim().isNotEmpty ;

  static final HttpCache DEFAULT_HTTP_CACHE = HttpCache(1024*1024*16, 1000*60*5) ;

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

void _copyElementToClipboard(Element elem) {
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

DivElement _createClosableContent( JSONRender render, DivElement output , String textOpener , String textCloser , SizeProvider sizeProvider, CssStyleDeclaration css ) {
  output.style.textAlign = 'left';

  var container = createDivInlineBlock() ;
  var mainContent = createDivInlineBlock() ;
  var subContent = createDivInlineBlock() ;
  var contentWhenHidden = createDivInlineBlock() ;
  var contentClipboard = createDivInlineBlock() ;

  contentClipboard.style.width = '0px' ;
  contentClipboard.style.height = '0px' ;

  if (css != null) {
    mainContent.style.cssText = css.cssText;
    contentWhenHidden.style.cssText = css.cssText;
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

    contentClipboard.innerHtml = '<pre>${render.buildJSONAsString()}</pre>' ;
    _copyElementToClipboard(contentClipboard) ;
    contentClipboard.text = '';

  } );


  output.children.add(elemArrow) ;
  output.children.add(container) ;
  container.children.add(mainContent) ;
  container.children.add(contentWhenHidden) ;
  container.children.add(contentClipboard) ;

  var elemOpen = SpanElement()..innerHtml = ' $textOpener<br>' ;
  var elemClose = SpanElement()..innerHtml = '<br>$textCloser<br>' ;

  mainContent.children.add(elemOpen) ;

  mainContent.children.add(subContent) ;
  mainContent.children.add(elemClose) ;

  return subContent ;

}

///////////////////////////////////////

class NodeKey {
  final List<String> path ;

  NodeKey.fromFullKey(String fullKey) : path = List.from( fullKey.trim().split('/').map( (e) => e.trim() ).toList() , growable: false) ;

  NodeKey( [ List<String> path ] ) : path = List.from(path ?? [''] , growable: false) ;

  NodeKey append(String appendKey) => NodeKey( [ ...path , appendKey ] ) ;

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

  CssStyleDeclaration _css ;

  TypeRender( [CssStyleDeclaration css] ) {
    this.css = css ;
  }

  CssStyleDeclaration get css => _css ;

  set css(CssStyleDeclaration css) {
    if ( css == null && _css == null ) {
      _css = defaultCSS() ?? CssStyleDeclaration() ;
    }
    else if ( css == null ) {
      _css ??= defaultCSS() ?? CssStyleDeclaration();
    }
    else {
      _css.cssText = _css.cssText +' ; '+ css.cssText ;
    }
  }

  bool get hasCSS => css != null && css.cssText.trim().isNotEmpty ;

  bool matches(dynamic node) ;

  _ValueProvider render( JSONRender render, DivElement output , dynamic node, NodeKey nodeKey) ;

  CssStyleDeclaration defaultCSS() {
    return null ;
  }

  void applyCSS(DivElement output, [List<Element> extraElements]) {
    if (!hasCSS) return ;
    var newCss = output.style.cssText +' ; '+ css.cssText;
    output.style.cssText = newCss ;

    if (extraElements != null) {
      for (var elem in extraElements) {
        var newCss = elem.style.cssText +' ; '+ css.cssText;
        elem.style.cssText = newCss ;
      }
    }
  }

}


////////////////////////////////////////////////////////////////////////////////

class TypeListRender extends TypeRender {
  @override
  bool matches(node) {
    return node is List ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var list = (node as List) ?? [] ;

    var listContent = _createClosableContent( render, output , '[' , ']' , () => list.length, css) ;

    var valueSet = _JSONValueSet(true) ;

    for (var i = 0; i < list.length; ++i) {
      var elem = list[i];

      var elemIdx = SpanElement()..innerHtml = ' &nbsp; &nbsp; #$i: &nbsp; ' ;
      var elemContent = createDivInlineBlock();

      listContent.children.add(elemIdx) ;
      listContent.children.add(elemContent) ;
      listContent.children.add( BRElement() ) ;

      var elemNodeKey = nodeKey.append('$i');
      var elemValueProvider = render._render(elemContent, elem, elemNodeKey) ;

      valueSet.put(elemNodeKey, elemValueProvider) ;
    }

    applyCSS(output) ;

    return valueSet.asValueProvider() ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#808080'
      ..backgroundColor = 'rgba(0,0,0, 0.07)'
      ..borderRadius = '10px'
      ..padding = '4px'
    ;
  }

}


class TypeObjectRender extends TypeRender {
  @override
  bool matches(node) {
    return node is Map ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var map = (node as Map) ?? {} ;

    var objContent = _createClosableContent( render, output, '{', '}', () => map.length, css) ;

    var valueSet = _JSONValueSet() ;

    for (var entry in map.entries) {
      var key = entry.key ;

      var elemKey = SpanElement()..innerHtml = ' &nbsp; &nbsp; $key: &nbsp; ' ;
      var elemContent = createDivInlineBlock();

      elemContent.style.verticalAlign = 'top' ;

      objContent.children.add(elemKey) ;
      objContent.children.add(elemContent) ;
      objContent.children.add( BRElement() ) ;

      var elemNodeKey = nodeKey.append(key);
      var elemValueProvider = render._render(elemContent, entry.value, elemNodeKey) ;

      valueSet.put(elemNodeKey, elemValueProvider) ;
    }

    applyCSS(output) ;

    return valueSet.asValueProvider() ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#808080'
      //..backgroundColor = 'rgba(0,0,0, 0.07)'
      ..backgroundColor = 'rgba(0,0,0, 0.07)'
      ..borderRadius = '10px'
      ..padding = '4px'
    ;
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

  @override
  bool matches(node) {
    return node is String ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {

    Element elem ;
    var valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'text'
      ;
      _adjustInputWidthByValueOnKeyPress(elem) ;
      valueProvider = () => normalizeJSONValuePrimitive( (elem as InputElement).value , true ) ;
    }
    else {
      elem = SpanElement()..text = '"$node"' ;
      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#a6a233'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

class TypeNumberRender extends TypeRender {
  @override
  bool matches(node) {
    return node is num ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {

    Element elem ;
    var valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..value = '$node'
        ..type = 'number'
      ;
      _adjustInputWidthByValueOnKeyPress(elem) ;
      valueProvider = () => normalizeJSONValueNumber(  (elem as InputElement).value ) ;
    }
    else {
      elem = SpanElement()..text = '$node' ;
      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#35a633'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

class TypeBoolRender extends TypeRender {
  @override
  bool matches(node) {
    return node is bool ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var val = node is bool ? node : false ;

    Element elem ;
    var valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      elem = InputElement()
        ..checked = val
        ..type = 'checkbox'
      ;
      valueProvider = () => (elem as InputElement).checked ;
    }
    else {
      elem = SpanElement()..text = '$val' ;
      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#a63333'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

class TypeNullRender extends TypeRender {
  @override
  bool matches(node) {
    return node == null ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var elem = SpanElement()..text = 'null' ;
    output.children.add(elem) ;
    var valueProvider = () => null ;

    applyCSS(output) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#808080'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

////////////////////////////////////////////////////////////////////////////////

class TypeURLRender extends TypeRender {

  final FilterURL filterURL  ;

  TypeURLRender( { this.filterURL } );

  @override
  bool matches(node) {
    if (node is String) {
      return RegExp(r'^\s*https?://').hasMatch(node) ;
    }
    return false ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
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
    var valueProvider ;

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

      valueProvider = () => (elem as InputElement).value ;
    }
    else {
      var a = AnchorElement(href: url)
        ..text = urlLabel
      ;

      if (target != null) {
        a.target = target ;
      }

      elem = a ;

      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#3385a6'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }


}


class TypeTimeMillisRender extends TypeRender {

  static bool isTimeMillisInRange(num val) {
    return val > 946692000000 && val < 32503690800000 ;
  }
  
  static int parseTimeMillisInRange(node) {
    if (node is num ) {
      return isTimeMillisInRange(node) ? node : null ;
    }
    else if (node is String) {
      var s = node.trim() ;
      if ( RegExp(r'^\d+$').hasMatch(s) ) {
        var n = int.parse(s) ;
        return  isTimeMillisInRange(n) ? n : null ;
      }
    }
    return null ;
  }

  ///////////////////////

  @override
  bool matches(node) {
    return parseTimeMillisInRange(node) != null ;
  }

  static final DATE_FORMAT_DATETIME_LOCAL = DateFormat('yyyy-MM-ddTHH:mm:ss', Intl.getCurrentLocale()) ;
  static final DATE_FORMAT_YYYY_MM_DD_HH_MM_SS = DateFormat('yyyy/MM/dd HH:mm:ss', Intl.getCurrentLocale()) ;

  int parseToTimeMillis(String value) {
    if ( value == null ) return null ;
    value = value.trim() ;
    if ( value.isEmpty ) return null ;

    if ( RegExp(r'^\d+$').hasMatch(value) ) return int.parse(value) ;

    return DateTime.parse(value).millisecondsSinceEpoch ;
  }
  
  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var timeMillis = parseTimeMillisInRange(node) ;
    var dateTime = DateTime.fromMillisecondsSinceEpoch(timeMillis).toLocal() ;

    Element elem ;
    var valueProvider ;

    if (render.renderMode == JSONRenderMode.INPUT) {
      var dateTimeLocal = DATE_FORMAT_DATETIME_LOCAL.format(dateTime) ;

      elem = InputElement()
        ..value = dateTimeLocal
        ..type = 'datetime-local'
      ;
      valueProvider = () {
        var time = parseToTimeMillis( (elem as InputElement).value );

        var timeDiff = timeMillis - time ;
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
        _copyElementToClipboard(elem);

        var val = '${ elem.text }' ;
        if ( RegExp(r'^\d+$').hasMatch(val) ) {
          elem.text = dateTimeStr ;
        }
        else {
          elem.text = '$timeMillis' ;
        }
      } ) ;

      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }


  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..color = '#9733a6'
      ..backgroundColor = 'rgba(0,0,0, 0.05)'
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

TrackElementInViewport _TRACK_ELEMENTS_IN_VIEWPORT = TrackElementInViewport() ;

abstract class TypeMediaRender extends TypeRender {

  static bool isDataURLBase64(String s) {
    return s != null && s.length > 5 && RegExp(r'^data:.*?;base64,').hasMatch(s) ;
  }

  Future<HttpResponse> getURL(JSONRender render, String url) {
    return render.httpCache.getURL(url) ;
  }

  HttpResponse getURLCached(JSONRender render, String url) {
    return render.httpCache.getCachedRequestURL( HttpMethod.GET, url ) ;
  }

  Element createImageElementFromURL(JSONRender render, bool lazyLoad, String url, [String urlType]) {

    if ( isDataURLBase64(urlType) ) {
      var div = createDivInlineBlock() ;
      var loadingElem = SpanElement()
        ..innerHtml = _randomPictureEntity()
        ..style.fontSize = '120%'
      ;
      div.children.add( loadingElem );

      var imgElem = ImageElement() ;

      var cachedResponse = getURLCached(render, url) ;

      if (cachedResponse != null && cachedResponse.isOK) {
        imgElem.src = '${urlType}${ cachedResponse.body }' ;
        return imgElem ;
      }

      if (lazyLoad) {
        _TRACK_ELEMENTS_IN_VIEWPORT.track(imgElem, onEnterViewport: (elem) {
          _loadElementBase64(render, imgElem, url, urlType, loadingElem);
        });
      }
      else {
        _loadElementBase64(render, imgElem, url, urlType, loadingElem);
      }

      imgElem.style.maxWidth = '100%';
      imgElem.style.maxHeight = '100%';

      div.children.add(imgElem);

      return div ;
    }
    else {
      var imgElem = ImageElement() ;
      imgElem.src = url ;
      return imgElem ;
    }

  }

  void _loadElementBase64(JSONRender render, ImageElement imgElem, String url, String urlType, Element loadingElement) {
    getURL(render, url).then( (response) {
      if ( response.isOK ) {
        imgElem.src = '${urlType}${ response.body }' ;
        if (loadingElement != null) loadingElement.remove() ;
      }
    } );
  }

}

Random _RANDOM = Random() ;

List<String> _PICTURE_CODES = '1F304 1F305 1F306'.split(RegExp(r'\s+'));

String _randomPictureEntity() {
  var code = _PICTURE_CODES[ _RANDOM.nextInt(_PICTURE_CODES.length) ] ;
  var entity = '&#x$code;';
  return entity ;
}

class TypeImageURLRender extends TypeMediaRender {

  final FilterURL filterURL  ;
  final bool lazyLoad  ;

  TypeImageURLRender( { this.filterURL , bool lazyLoad } ) : lazyLoad = lazyLoad ?? true ;

  @override
  bool matches(node) {
    if ( node is String && RegExp(r'^https?://').hasMatch(node) ) {
      var url = node.trim() ;
      if ( node.contains('?') ) {
        url = node.split('?')[0] ;
      }
      
      var match = RegExp(r'(?:png|jpe?g|gif|webp)$' , caseSensitive: false).hasMatch(url);

      return match ;
    }
    return false ;
  }

  @override
  _ValueProvider render( JSONRender render, DivElement output, node, NodeKey nodeKey) {
    var url = '$node' ;
    String urlType ;

    if (filterURL != null) {
      var ret = filterURL(url) ;
      if (ret != null) {
        url = ret.url ;
        urlType = ret.type ;
      }
    }

    Element elem ;
    var valueProvider ;

    if ( render.renderMode == JSONRenderMode.INPUT && false ) {
      elem = ImageElement()..src = url ;
      valueProvider = () => node ;
    }
    else {
      elem = createImageElementFromURL(render, lazyLoad, url, urlType) ;
      elem.style.maxWidth = '40vw';

      valueProvider = () => node ;
    }

    output.children.add(elem) ;

    applyCSS(output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}


