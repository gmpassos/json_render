
import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:dom_tools/dom_tools.dart';
import 'package:mercury_client/mercury_client.dart';

import 'json_render_base.dart';

TrackElementInViewport _TRACK_ELEMENTS_IN_VIEWPORT = TrackElementInViewport() ;

bool isDataURLBase64(String s) {
  return s != null && s.length > 5 && RegExp(r'^data:.*?;base64,').hasMatch(s) ;
}


abstract class TypeMediaRender extends TypeRender {

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

bool isHTTPURL(node) {
  return node is String && RegExp(r'^https?://').hasMatch(node) ;
}


MapEntry findKey(Map map, List keys) {
  if (map == null || keys == null) return null ;
  for (var k in keys) {
    if ( map.containsKey(k) ) return MapEntry(k, map[k]) ;
  }
  return null ;
}

dynamic findKeyValue(Map map, List keys) {
  var entry = findKey(map, keys) ;
  return entry != null ? entry.value : null ;
}

num _parseNum(dynamic n) {
  if (n == null) return 0 ;
  if (n is num) return n ;
  var s = 'n'.trim() ;
  return num.parse(s) ;
}

class TypeImageURLRender extends TypeMediaRender {

  final FilterURL filterURL  ;
  final bool lazyLoad  ;

  TypeImageURLRender( { this.filterURL , bool lazyLoad } ) : lazyLoad = lazyLoad ?? true ;

  static bool matchesNode(node) {
    if ( !(node is String) ) return false ;

    if ( isDataURLBase64(node) ) {
      return true ;
    }
    else if ( isHTTPURL(node) ) {
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
  bool matches(node) {
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

  ViewerValue<Rectangle<num>> parseClip(node) {
    if (node is Map) {
      var clipEntry = findKey(node, ['clip', 'clipArea', 'cliparea']) ;

      if (clipEntry != null) {
        var clip = clipEntry.value ;

        if (clip == null) {
          return CanvasImageViewer.clipViewerValue(null)
            ..key = clipEntry.key
          ;
        }
        else if (clip is Map) {
          var x = findKeyValue(clip, ['x', 'left']) ;
          var y = findKeyValue(clip, ['y', 'top']) ;
          var w = findKeyValue(clip, ['width', 'w']) ;
          var h = findKeyValue(clip, ['height', 'h']) ;
          //return Rectangle(x, y, w, h) ;

          return CanvasImageViewer.clipViewerValue( Rectangle(x, y, w, h) )
            ..key = clipEntry.key
          ;
        }
        else if (clip is List) {
          var x = clip[0] ;
          var y = clip[1] ;
          var w = clip[2] ;
          var h = clip[3] ;

          return CanvasImageViewer.clipViewerValue( Rectangle(x, y, w, h) )
            ..key = clipEntry.key
          ;
        }
      }
    }

    return null ;
  }

  List<dynamic> parseClipKeys(node) {
    if (node is Map) {
      var clipEntry = findKey(node, ['clip','clipArea','cliparea']);

      if (clipEntry != null) {
        var clip = clipEntry.value ;

        if (clip == null) {
          return [ clipEntry.key , 0,1,2,3 ] ;
        }
        else if (clip is Map) {
          var xKey = findKeyValue(clip, ['x','left']) ;
          var yKey = findKeyValue(clip, ['y','top']) ;
          var wKey = findKeyValue(clip, ['width','w']) ;
          var hKey = findKeyValue(clip, ['height','h']) ;

          return [ clipEntry.key , xKey, yKey, wKey, hKey ] ;
        }
        else if (clip is List) {
          return [ clipEntry.key , 0,1,2,3 ] ;
        }
      }
    }
    return null ;
  }

  ViewerValue< List<Rectangle<num>> > parseRectangles(node) {
    if (node is Map) {
      var rectsEntry = findKey(node, ['rectangles', 'rects']) ;

      if (rectsEntry != null) {
        var rects = rectsEntry.value ;

        if (rects == null) {
          return CanvasImageViewer.rectanglesViewerValue(null)
            ..key = rectsEntry.key
          ;
        }
        else if (rects is List) {
          var list = rects.map((e) {
            if (e is List) {
              return Rectangle<num>(
                  _parseNum(e[0]), _parseNum(e[1]), _parseNum(e[2]),
                  _parseNum(e[3]));
            }
            else if (e is Map) {
              var x = findKeyValue(e, ['x', 'left']);
              var y = findKeyValue(e, ['y', 'top']);
              var w = e['width'];
              var h = e['height'];
              return Rectangle<num>(
                  _parseNum(x), _parseNum(y), _parseNum(w), _parseNum(h));
            }
            else if (e is String) {
              var parts = e.trim().split(RegExp(r'\s*,\s*'));
              return Rectangle<num>(
                  _parseNum(parts[0]), _parseNum(parts[1]), _parseNum(parts[2]),
                  _parseNum(parts[3]));
            }
            else {
              return null;
            }
          }).toList();

          return CanvasImageViewer.rectanglesViewerValue(list)
            ..key = rectsEntry.key
          ;
        }
      }
    }

    return null ;
  }

  ViewerValue< List<Point<num>> > parsePoints(node) {
    if (node is Map) {
      var pointsEntry = findKey(node, ['points']) ;

      if (pointsEntry != null) {
        var points = pointsEntry.value ;

        if (points == null) {
          return CanvasImageViewer.pointsViewerValue( null )
            ..key = pointsEntry.key
          ;
        }
        else if (points is List) {
          var list = points.map( (e) {
            if (e is List) {
              return Point<num>( _parseNum(e[0]), _parseNum(e[1]) ) ;
            }
            else if (e is Map) {
              var x = findKeyValue(e, ['x','left']) ;
              var y = findKeyValue(e, ['y','top']) ;
              return Point<num>( _parseNum(x), _parseNum(y) ) ;
            }
            else if (e is String) {
              var parts = e.trim().split(RegExp(r'\s*,\s*'));
              return Point<num>( _parseNum(parts[0]), _parseNum(parts[1]) ) ;
            }
            else {
              return null ;
            }
          } ).toList();

          return CanvasImageViewer.pointsViewerValue( list )
            ..key = pointsEntry.key
          ;
        }

      }

    }
    return null ;
  }

  ViewerValue< List<Point<num>> > parsePerspectiveFilter(node) {
    if (node is Map) {
      var pointsEntry = findKey(node, ['perspectiveFilter', 'perspectivefilter', 'perspective']) ;

      if (pointsEntry != null) {
        var points = pointsEntry.value ;

        if (points == null) {
          return CanvasImageViewer.perspectiveViewerValue( null )
            ..key = pointsEntry.key
          ;
        }
        else if (points is List) {
          var list = points.map( (e) {
            if (e is List) {
              return [ _parseNum(e[0]), _parseNum(e[1]), _parseNum(e[2]), _parseNum(e[3]), _parseNum(e[4]), _parseNum(e[5]), _parseNum(e[6]), _parseNum(e[7]) ] ;
            }
            else if (e is String) {
              var parts = e.trim().split(RegExp(r'\s*,\s*'));
              return [ _parseNum(parts[0]), _parseNum(parts[1]), _parseNum(parts[2]), _parseNum(parts[3]), _parseNum(parts[4]), _parseNum(parts[5]), _parseNum(parts[6]), _parseNum(parts[7]) ] ;
            }
            else {
              return null ;
            }
          } ).first ;

          return CanvasImageViewer.perspectiveViewerValueFromNums( list )
            ..key = pointsEntry.key
          ;
        }

      }

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

  //////////

  @override
  bool matches(node) {
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

    var imageFilter ;
    if (perspectiveFilter != null) {
      imageFilter = (img, w, h) {
        return applyPerspective(imageElement, perspectiveFilter.value, false) ;
      };
    }

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
    var canvasImageViewer = CanvasImageViewer(canvas, image: imageElement,
        //imageFilter: imageFilter,
        perspective: perspectiveFilter , gridSize: (perspectiveFilter != null ? CanvasImageViewer.gridSizeViewerValue(0.05) : null ) ,
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

        var pointsCoords = points.map( (p) => [p.x, p.y] ).expand( (p) => p ).toList();
        nodeEdited[pointsKey] = pointsCoords ;
        return nodeEdited;
      };
    }
    else if ( editionType == EditionType.PERSPECTIVE ) {
      valueProviderRef.valueProvider = (parent) {
        var perspectiveKey = canvasImageViewer.perspectiveKey ;
        var perspective = canvasImageViewer.perspective ?? [] ;

        var nodeEdited = Map.from(node) ;

        var perspectiveCoords = perspective.map( (p) => [p.x, p.y] ).expand( (p) => p ).toList();
        nodeEdited[perspectiveKey] = perspectiveCoords ;
        return nodeEdited;
      };
    }

    canvasImageViewer.render();

    canvas.style.maxWidth = '70vw';
    canvas.style.maxHeight = '40vw';

    parent.children.clear();
    parent.children.add(canvas) ;
  }

  @override
  CssStyleDeclaration defaultCSS() {
    return CssStyleDeclaration()
      ..borderColor = 'rgba(255,255,255, 0.30)'
    ;
  }


}


