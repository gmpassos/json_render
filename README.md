# json_render

JSON Web Render Framework

## Usage

A simple usage example:

```dart
import 'dart:html';
import 'package:json_render/json_render.dart';

main() {

    var jsonStr = '{ "user": "Joe Smith", "creationDate": 1581296519401, "picture": "http://host/path/to/image.jpeg", "enabled": true , "homepage": "http://www.geocities.com/awesome-home-page" }';
    
    JSONRender jsonRender = JSONRender.fromJSONAsString(jsonStr)
      // Show input elements:
      ..renderMode = JSONRenderMode.INPUT
      // Renders Strings with image URL as image elements in lazyload mode (only loads image when viewed, reducing bandwidth usage):
      ..addTypeRender( TypeImageURLRender( lazyload: true ) )
      // Renders numbers in unix epoch time-millis range as dates:   
      ..addTypeRender( TypeTimeMillisRender() )
      // Renders URL string as links.
      ..addTypeRender( TypeURLRender() )
    ;

    var divOutput = querySelector("#output");

    jsonRender.renderToDiv(divOutput) ;

    divOutput.onClick.listen( (e) {
      // Generates JSON from rendered elements in input mode and print to console:
      print( jsonRender.buildJSONAsString() ) ;
    } ); 

    
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/json_render/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
