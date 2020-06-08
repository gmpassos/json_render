import 'dart:html';
import 'package:json_render/json_render.dart';

void main() {

  var jsonStr = '{ "user": "Joe Smith", "creationDate": 1581296519401, "picture": "http://host/path/to/image.jpeg", "enabled": true , "homepage": "http://www.geocities.com/awesome-home-page" }';

  var jsonRender = JSONRender.fromJSONAsString(jsonStr)
  // Show input elements:
    ..renderMode = JSONRenderMode.INPUT
  // Renders Strings with image URL as image elements in lazyload mode (only loads image when viewed, reducing bandwidth usage):
    ..addTypeRender( TypeImageURLRender( lazyLoad: true ) )
  // Renders numbers in unix epoch time-millis range as dates:
    ..addTypeRender( TypeUnixEpochRender() )
  // Renders URL string as links.
    ..addTypeRender( TypeURLRender() )
  ;

  var divOutput = querySelector('#output');

  jsonRender.renderToDiv(divOutput) ;

  divOutput.onClick.listen( (e) {
    // Generates JSON from rendered elements in input mode and print to console:
    print( jsonRender.buildJSONAsString() ) ;
  } );

}
