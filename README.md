# json_render

[![pub package](https://img.shields.io/pub/v/json_render.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/json_render)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://pub.dartlang.org/packages/json_render)
[![Dart CI](https://github.com/gmpassos/json_render/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/gmpassos/json_render/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/json_render?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/json_render/latest?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/json_render?logo=git&logoColor=white)](https://github.com/gmpassos/json_render/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/json_render?logo=github&logoColor=white)](https://github.com/gmpassos/json_render/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/json_render?logo=github&logoColor=white)](https://github.com/gmpassos/json_render)
[![License](https://img.shields.io/github/license/gmpassos/json_render?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/json_render/blob/master/LICENSE)

JSON Web Render Framework

Automatically renders a JSON tree using rich components.

## Usage

A simple usage example:

```dart
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
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/json_render/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
