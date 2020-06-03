# json_render

[![pub package](https://img.shields.io/pub/v/json_render.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/json_render)
[![CI](https://img.shields.io/github/workflow/status/gmpassos/json_render/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/gmpassos/json_render/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/json_render?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/json_render/latest?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/json_render?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/json_render?logo=github&logoColor=white)](https://github.com/gmpassos/json_render/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/json_render?logo=github&logoColor=white)](https://github.com/gmpassos/json_render)
[![License](https://img.shields.io/github/license/gmpassos/json_render?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/json_render/blob/master/LICENSE)
[![Funding](https://img.shields.io/badge/Donate-yellow?labelColor=666666&style=plastic&logo=liberapay)](https://liberapay.com/gmpassos/donate)
[![Funding](https://img.shields.io/liberapay/patrons/gmpassos.svg?logo=liberapay)](https://liberapay.com/gmpassos/donate)


JSON Web Render Framework

Automatically renders a JSON using rich components.

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
