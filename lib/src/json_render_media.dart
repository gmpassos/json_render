
import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dom_tools/dom_tools.dart';
import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';

TrackElementInViewport _TRACK_ELEMENTS_IN_VIEWPORT = TrackElementInViewport() ;

abstract class TypeMediaRender extends TypeRender {

  Future<HttpResponse> getURL(JSONRender render, String url) {
    return render.httpCache.getURL(url) ;
  }

  HttpResponse getURLCached(JSONRender render, String url) {
    return render.httpCache.getCachedRequestURL( HttpMethod.GET, url ) ;
  }

  Element createImageElementFromURL(JSONRender render, bool lazyLoad, String url, [String urlType]) {

    if ( DataURLBase64.matches(urlType) ) {
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

////////////////////////////////////////////////////////////////////////////////

class TypeImageURLRender extends TypeMediaRender {

  final FilterURL filterURL  ;
  final bool lazyLoad  ;

  TypeImageURLRender( { this.filterURL , bool lazyLoad } ) : lazyLoad = lazyLoad ?? true ;

  static bool matchesNode(node) {
    if ( !(node is String) ) return false ;

    if ( DataURLBase64.matches(node) ) {
      return true ;
    }
    else if ( isHttpHURL(node) ) {
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
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return matchesNode(node) ;
  }

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
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
    ValueProvider valueProvider ;

    if ( render.renderMode == JSONRenderMode.INPUT && false ) {
      elem = ImageElement()..src = url ;
      valueProvider = (parent) => node ;
    }
    else {
      elem = createImageElementFromURL(render, lazyLoad, url, urlType) ;
      elem.style.maxWidth = '40vw';

      valueProvider = (parent) => nodeOriginal ;
    }

    output.children.add(elem) ;

    applyCSS(css, output, [elem]) ;

    return valueProvider ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }

}

class TypeImageViewerRender extends TypeMediaRender {

  final FilterURL filterURL  ;
  final bool lazyLoad  ;

  TypeImageViewerRender( { this.filterURL , bool lazyLoad } ) : lazyLoad = lazyLoad ?? true ;

  String parseImageURL(node) {
    if (node is Map) {
      var url = findKeyValue(node, ['url', 'image', 'imageURL']) ;
      return url != null ? '$url' : null ;
    }
    return null ;
  }

  DateTime parseTime(node) {
    if (node is Map) {
      var time = findKeyValue(node, ['time', 'imageTime']) ;

      if (time != null) {
        if ( time is num ) return DateTime.fromMillisecondsSinceEpoch( time ) ;
        if ( time is String ) {
          if ( RegExp(r'^\d+$').hasMatch(time) ) return DateTime.fromMillisecondsSinceEpoch( int.parse(time) ) ;
          return DateTime.parse(time) ;
        }
      }
    }
    return null ;
  }

  List<dynamic> parseClipKeys(node) {
    if (node is Map) {
      var clipEntry = findKeyEntry(node, ['clip','clipArea','cliparea']);

      if (clipEntry != null) {
        var clip = clipEntry.value ;

        if (clip == null) {
          return [ clipEntry.key , 0,1,2,3 ] ;
        }
        else if (clip is Map) {
          var xKey = findKeyName(clip, ['x','left']) ;
          var yKey = findKeyName(clip, ['y','top']) ;
          var wKey = findKeyName(clip, ['width','w']) ;
          var hKey = findKeyName(clip, ['height','h']) ;

          return [ clipEntry.key , xKey, yKey, wKey, hKey ] ;
        }
        else if (clip is List) {
          return [ clipEntry.key , 0,1,2,3 ] ;
        }
      }
    }
    return null ;
  }

  /////////////////////////////////////////////////////

  // ignore: use_function_type_syntax_for_parameters
  ViewerValue<T> _parseViewerValue<T>(node, List<String> keys , { ViewerValue<T> constructorNull() , ViewerValue<T> constructorValue(T value) , T mapperList(List value) , T mapperMap(Map value) } ) {
    if (node is Map) {
      var entry = findKeyEntry(node, keys) ;

      if (entry != null) {
        var entryValue = entry.value ;

        if (entryValue == null) {
          var viewerValue = constructorNull != null ? constructorNull() : constructorValue(null) ;
          return viewerValue
            ..key = entry.key
          ;
        }
        else if (entryValue is List) {
          if (mapperList == null) return null ;
          var value = mapperList(entryValue) ;
          return constructorValue(value)
            ..key = entry.key
          ;
        }
        else if (entryValue is Map) {
          if (mapperMap == null) return null ;
          var value = mapperMap(entryValue) ;
          return constructorValue(value)
            ..key = entry.key
          ;
        }
      }
    }

    return null ;
  }

  ///////////////////////////////////

  ViewerValue< Rectangle<num> > parseClip(node) {
    return _parseViewerValue(
        node, ['clip', 'clipArea', 'cliparea'],
        constructorValue: CanvasImageViewer.clipViewerValue  ,
        mapperList: parseRectangleFromList,
        mapperMap: parseRectangleFromMap
    );
  }

  ViewerValue< List<Rectangle<num>> > parseRectangles(node) {
    return _parseViewerValue(
        node, ['rectangles', 'rects'],
        constructorValue: CanvasImageViewer.rectanglesViewerValue ,
        mapperList: (list) => list.map( parseRectangle ).toList()
    );
  }

  ViewerValue< List<Point<num>> > parsePoints(node) {
    return _parseViewerValue(
        node, ['points'],
        constructorValue: CanvasImageViewer.pointsViewerValue ,
        mapperList: (list) => list.map( parsePoint ).toList()
    );
  }

  ViewerValue< List<Point<num>> > parsePerspectiveFilter(node) {
    return _parseViewerValue(
        node, ['perspectiveFilter', 'perspectivefilter', 'perspective'],
        constructorValue: (value) => CanvasImageViewer.perspectiveViewerValue(value) ,
        mapperList: (list) => numsToPoints( parseNumsFromList(list) )
    );
  }

  //////////////////////////////////////////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( node is Map ) {
      var imageURL = parseImageURL(node) ;
      if (imageURL == null) return false ;

      var clip = parseClip(node) ;
      var rectangles = parseRectangles(node) ;
      var points = parsePoints(node) ;
      var perspectiveFilter = parsePerspectiveFilter(node) ;

      if (clip != null || rectangles != null || points != null || perspectiveFilter != null ) {
        return TypeImageURLRender.matchesNode(imageURL) ;
      }
    }

    return false ;
  }

  /////////

  @override
  ValueProvider render( JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var imageURL = parseImageURL(node) ;
    var perspectiveFilter = parsePerspectiveFilter(node) ;
    var clip = parseClip(node) ;
    var rectangles = parseRectangles(node) ;
    var points = parsePoints(node) ;

    var time = parseTime(node) ;

    String urlType ;

    if (filterURL != null) {
      var ret = filterURL(imageURL) ;
      if (ret != null) {
        imageURL = ret.url ;
        urlType = ret.type ;
      }
    }

    Element elem = createDivInlineBlock() ;

    var imgElemContainer = createImageElementFromURL(render, lazyLoad, imageURL, urlType) ;
    imgElemContainer.style.maxWidth = '70vw';
    imgElemContainer.style.maxHeight = '40vw';

    ImageElement imgElem = imgElemContainer is ImageElement ? imgElemContainer : imgElemContainer.querySelector('img') ;

    var valueProviderOriginal = (parent) => nodeOriginal;
    // ignore: omit_local_variable_types
    ValueProviderReference valueProviderRef = ValueProviderReference( valueProviderOriginal ) ;

    imgElem.onLoad.listen((e) {
      renderLoadedImage(render, node, elem, imgElem, perspectiveFilter, clip, rectangles, points, time, valueProviderRef) ;
    });

    elem.children.add(imgElemContainer) ;

    output.children.add(elem) ;

    applyCSS(css, output, [elem]) ;

    return valueProviderRef.asValueProvider() ;
  }

  void renderLoadedImage(JSONRender render, dynamic node, Element parent, ImageElement imageElement, ViewerValue< List<Point<num>> > perspectiveFilter, ViewerValue<Rectangle<num>> clip, ViewerValue<List<Rectangle<num>>> rectangles, ViewerValue<List<Point<num>>> points, DateTime time, ValueProviderReference valueProviderRef) {
    var w = imageElement.naturalWidth;
    var h = imageElement.naturalHeight;

    var inputMode = render.isInputRenderMode ;

    EditionType editionType ;
    if (inputMode) {
      if (clip != null) {
        editionType = EditionType.CLIP;
      }
      else if (points != null) {
        editionType = EditionType.POINTS;
      }
      else if (perspectiveFilter != null) {
        editionType = EditionType.PERSPECTIVE;
      }
    }

    var canvas = CanvasElement(width: w, height: h);
    var gridSize = editionType == EditionType.PERSPECTIVE ? CanvasImageViewer.gridSizeViewerValue(0.05) : null ;

    var canvasImageViewer = CanvasImageViewer(canvas, image: imageElement,
        perspective: perspectiveFilter , gridSize: gridSize ,
        clip: clip, rectangles: rectangles, points: points, time: time, editable: editionType
    ) ;

    if ( editionType == EditionType.CLIP ) {
      var clipKeys = parseClipKeys(node);

      if (clipKeys != null) {
        valueProviderRef.valueProvider = (parent) {
          var clipKey = clipKeys[0] ;
          var xKey = clipKeys[1] ;
          var yKey = clipKeys[2] ;
          var wKey = clipKeys[3] ;
          var hKey = clipKeys[4] ;

          var clip = canvasImageViewer.clip;
          clip = Rectangle<int>( clip.left.toInt() , clip.top.toInt() , clip.width.toInt() , clip.height.toInt() ) ;

          var nodeEdited = Map.from(node) ;

          if (xKey is num && yKey is num) {
            nodeEdited[clipKey] = [
              clip.left ,
              clip.top ,
              clip.width ,
              clip.height
            ] ;
          }
          else {
            nodeEdited[clipKey] = {
              xKey: clip.left ,
              yKey: clip.top ,
              wKey: clip.width ,
              hKey: clip.height
            } ;
          }

          return nodeEdited;
        };
      }
    }
    else if ( editionType == EditionType.POINTS ) {
      valueProviderRef.valueProvider = (parent) {
        var pointsKey = canvasImageViewer.pointsKey ;
        var points = canvasImageViewer.points ?? [] ;

        var nodeEdited = Map.from(node) ;

        var pointsCoords = points.map( (p) => [p.x, p.y] ).expand( (p) => p ).map( (n) => n.toInt() ).toList();
        nodeEdited[pointsKey] = pointsCoords ;
        return nodeEdited;
      };
    }
    else if ( editionType == EditionType.PERSPECTIVE ) {
      valueProviderRef.valueProvider = (parent) {
        var perspectiveKey = canvasImageViewer.perspectiveKey ;
        var perspective = canvasImageViewer.perspective ?? [] ;

        var nodeEdited = Map.from(node) ;

        var perspectiveCoords = perspective.map( (p) => [p.x, p.y] ).expand( (p) => p ).map( (n) => n.toInt() ).toList() ;
        nodeEdited[perspectiveKey] = perspectiveCoords ;
        return nodeEdited;
      };
    }

    canvas.style.maxWidth = '70vw';
    canvas.style.maxHeight = '40vw';

    parent.children.clear();
    parent.children.add(canvas) ;
    
    canvasImageViewer.render();

  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }


}


