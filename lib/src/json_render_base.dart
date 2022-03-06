import 'dart:convert' as dart_convert;
import 'dart:html';

import 'package:dom_tools/dom_tools.dart';
import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_collection.dart';
import 'json_render_css.dart';
import 'json_render_date.dart';
import 'json_render_geo.dart';
import 'json_render_media.dart';
import 'json_render_types.dart';

/// Enum for render modes.
enum JSONRenderMode { input, view }

String? convertToJSONAsString(dynamic jsonNode, [String indent = '  ']) {
  if (jsonNode == null) return null;

  if (indent.isNotEmpty) {
    return encodeJSON(jsonNode, withIndent: true);
  } else {
    return encodeJSON(jsonNode);
  }
}

dynamic normalizeJSONValuePrimitive(dynamic value, [bool forceString = false]) {
  if (value == null) return null;

  if (value is String) {
    if (forceString) return value;

    if (RegExp(r'^-?\d+$').hasMatch(value)) {
      return int.parse(value);
    } else if (RegExp(r'^-?\d+\.\d+$').hasMatch(value)) {
      return double.parse(value);
    } else if (value == 'true') {
      return true;
    } else if (value == 'false') {
      return false;
    }
  }

  return value;
}

num? normalizeJSONValueNumber(dynamic value) {
  if (value == null) return null;

  if (value is num) return value;

  var s = '$value';
  if (s.isEmpty) return null;

  return num.parse(s);
}

typedef ValueProvider = dynamic Function(dynamic parent);

dynamic valueProviderNull(parent) => null;

class ValueProviderReference {
  ValueProvider valueProvider;

  ValueProviderReference(this.valueProvider);

  dynamic call(dynamic parent) => valueProvider(parent);

  ValueProvider asValueProvider() {
    return (parent) => valueProvider(parent);
  }
}

class JSONValueSet {
  bool listMode;

  JSONValueSet([this.listMode = false]);

  final Map<NodeKey, ValueProvider> values = {};

  void put(NodeKey key, ValueProvider? val) {
    values[key] = val ?? valueProviderNull;
  }

  String? buildJSONAsString(dynamic parent) {
    return convertToJSONAsString(buildJSON(parent));
  }

  dynamic buildJSON(dynamic parent) {
    if (listMode) {
      return _buildJSONList(parent);
    } else {
      return _buildJSONObject(parent);
    }
  }

  List _buildJSONList(dynamic parent) {
    var json = [];

    for (var val in values.values) {
      var value = _callValueProvider(val, json);
      json.add(value);
    }

    return json;
  }

  Map _buildJSONObject(dynamic parent) {
    var json = {};

    for (var entry in values.entries) {
      var value = _callValueProvider(entry.value, json);
      var leafKey = entry.key.leafKey;

      if (!json.containsKey(leafKey)) {
        json[leafKey] = value;
      } else {
        var prevVal = json[leafKey];
        print(
            "[JSONRender] Can't build entry '${entry.key}' since it's already set! Discarting generated value: <$value> and keeping current value <$prevVal>");
      }
    }

    return json;
  }

  dynamic _callValueProvider(ValueProvider valueProvider, dynamic parent) {
    var value = valueProvider(parent);
    return value;
  }

  ValueProvider asValueProvider() {
    return (parent) => buildJSON(parent);
  }
}

/// The JSON Render.
class JSONRender {
  /// The JSON root node to render.
  Object? _json;

  JSONRender.fromJSON(this._json);

  JSONRender.fromJSONAsString(String jsonAsString) {
    _json = dart_convert.json.decode(jsonAsString);
  }

  dynamic get json {
    if (_json == null) return null;
    if (_json is Map) return Map.unmodifiable(_json as Map<dynamic, dynamic>);
    if (_json is List) return List.unmodifiable(_json as Iterable<dynamic>);
    return _json;
  }

  Map? get jsonObject => json as Map?;

  List? get jsonList => json as List?;

  num? get jsonNumber => parseNum(_json);

  bool? get jsonBoolean => parseBool(_json);

  String get jsonString => '$_json';

  /// Returns [true] if this is in input mode: [JSONRenderMode.input]
  JSONRenderMode renderMode = JSONRenderMode.view;

  bool get isInputRenderMode => renderMode == JSONRenderMode.input;

  /// Rebuilds JSON from current rendered tree. If in [JSONRenderMode.input]
  /// it will update tree values.
  dynamic buildJSON() {
    if (_treeValueProvider == null) return null;
    return _treeValueProvider!(null);
  }

  /// Same as [buildJSON], but returns as [String].
  String? buildJSONAsString([String indent = '  ']) {
    return convertToJSONAsString(buildJSON(), indent);
  }

  /// Renders JSON to a new [DivElement] and returns it.
  DivElement render() {
    var output = DivElement();
    renderToDiv(output);
    return output;
  }

  ValueProvider? _treeValueProvider;

  /// Renders JSON to div [output].
  void renderToDiv(DivElement output) {
    output.children.clear();

    var nodeKey = NodeKey();

    try {
      var valueProvider = renderNode(output, _json, null, nodeKey);
      _treeValueProvider = valueProvider;
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  ValueProvider? renderNode(
      DivElement output, dynamic node, dynamic parent, NodeKey nodeKey) {
    output.style.display = 'inline-block';

    _attachActions(output, node, parent, nodeKey);

    bool valid = validateNode(node, parent, nodeKey);
    if (!valid) return null;

    var nodeMapping = _mapNode(node, parent, nodeKey);

    for (var typeRender in _extendedTypeRenders) {
      if (typeRender.matches(nodeMapping.nodeMapped, parent, nodeKey)) {
        var valueProvider = _callRender(typeRender, output,
            nodeMapping.nodeMapped, nodeMapping.nodeOriginal, nodeKey);
        return nodeMapping.unmapValueProvider(valueProvider);
      }
    }

    for (var typeRender in _defaultTypeRenders) {
      if (typeRender.matches(nodeMapping.nodeMapped, parent, nodeKey)) {
        var valueProvider = _callRender(typeRender, output,
            nodeMapping.nodeMapped, nodeMapping.nodeOriginal, nodeKey);
        return nodeMapping.unmapValueProvider(valueProvider);
      }
    }

    return null;
  }

  dynamic _attachActions(
      DivElement output, dynamic node, dynamic parent, NodeKey nodeKey) {
    if (_typeActions.isEmpty) return node;

    for (var typeAction in _typeActions) {
      if (typeAction.matches(node, parent, nodeKey)) {
        output.style.cursor = 'pointer';

        output.onClick.listen((e) {
          typeAction.doAction(node, parent, nodeKey);
        });
      }
    }

    return node;
  }

  dynamic validateNode(dynamic node, dynamic parent, NodeKey nodeKey) {
    if (ignoreNullNodes && node == null) return false;

    if (_nodeValidators.isEmpty) return true;

    for (var validator in _nodeValidators) {
      if (validator(node, parent, nodeKey)) {
        return true;
      }
    }

    return false;
  }

  _NodeMapping _mapNode(dynamic node, dynamic parent, NodeKey nodeKey) {
    if (_typeMappers.isEmpty) {
      return _NodeMapping(null, node, node, parent, nodeKey);
    }

    for (var typeMapper in _typeMappers) {
      if (typeMapper.matches(node, parent, nodeKey)) {
        var nodeMapped = typeMapper.map(node, parent, nodeKey);
        return _NodeMapping(typeMapper, node, nodeMapped, parent, nodeKey);
      }
    }

    return _NodeMapping(null, node, node, parent, nodeKey);
  }

  ValueProvider _callRender(TypeRender typeRender, DivElement output,
      dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var valueProvider =
        typeRender.render(this, output, node, nodeOriginal, nodeKey);
    return valueProvider;
  }

  List<TypeRender> get allRenders =>
      [..._extendedTypeRenders, ..._defaultTypeRenders];

  final List<TypeRender> _defaultTypeRenders = [
    TypeTextRender(),
    TypeNumberRender(),
    TypeObjectRender(),
    TypeListRender(),
    TypeBoolRender(),
    TypeNullRender()
  ];

  final List<TypeRender> _extendedTypeRenders = [];

  /// Adds a new [typeRender].
  ///
  /// [overwrite] If true substitutes current render of same type.
  bool addTypeRender(TypeRender typeRender, [bool overwrite = false]) {
    if (_extendedTypeRenders.contains(typeRender)) {
      if (overwrite) {
        _extendedTypeRenders.remove(typeRender);
      } else {
        return false;
      }
    }

    _extendedTypeRenders.add(typeRender);

    return true;
  }

  /// Add all [typeRenders] to current capable renders list.
  void addAllTypeRender(List<TypeRender> typeRenders) {
    typeRenders.forEach(addTypeRender);
  }

  /// Add all known [TypeRender] to capable render list.
  void addAllKnownTypeRenders() {
    addTypeRender(TypePaging());
    addTypeRender(TypeTableRender(false));
    addTypeRender(TypeDateRender());
    addTypeRender(TypeUnixEpochRender());
    addTypeRender(TypeSelectRender());
    addTypeRender(TypeEmailRender());
    addTypeRender(TypeURLRender());
    addTypeRender(TypeGeolocationRender());
    addTypeRender(TypeImageURLRender());
    addTypeRender(TypeImageViewerRender());
  }

  /// Removes a [typeRender] from capable render list.
  bool removeTypeRender(TypeRender typeRender) {
    return _extendedTypeRenders.remove(typeRender);
  }

  /// Gets a [TypeRender] by [type] from capable render list.
  TypeRender? getTypeRender(Type type) {
    for (var typeRender in _extendedTypeRenders) {
      var runtimeType = typeRender.runtimeType;
      if (runtimeType == type) {
        return typeRender;
      }
    }

    for (var typeRender in _defaultTypeRenders) {
      if (typeRender.runtimeType == type) {
        return typeRender;
      }
    }

    return null;
  }

  /// If [true] will ignore [null] nodes and ignore them to render.
  bool ignoreNullNodes = false;

  /// If [true] shows an arrow for each node entry.
  bool showNodeArrow = true;

  /// If [true] renders an opener `{` and closer `}` characters for each node.
  bool showNodeOpenerAndCloser = true;

  final List<NodeValidator> _nodeValidators = [];

  /// Adds a node [validator]. Invalid nodes are ignored.
  bool addNodeValidator(NodeValidator validator) {
    if (_nodeValidators.contains(validator)) return false;
    _nodeValidators.add(validator);
    return true;
  }

  /// Add all [validators].
  void addAllNodeValidator(List<NodeValidator> validators) {
    validators.forEach(addNodeValidator);
  }

  /// Removes a node [validator].
  bool removeNodeValidator(NodeValidator validator) {
    return _nodeValidators.remove(validator);
  }

  final List<TypeMapper> _typeMappers = [];

  /// Adds a [typeMapper]. A [TypeMapper] is able to convert a node to another
  /// structure, allowing to match different types from original behavior.
  bool addTypeMapper(TypeMapper typeMapper) {
    if (_typeMappers.contains(typeMapper)) return false;
    _typeMappers.add(typeMapper);
    return true;
  }

  void addAllTypeMapper(List<TypeMapper> typeMappers) {
    typeMappers.forEach(addTypeMapper);
  }

  bool removeTypeMapper(TypeMapper typeMapper) {
    return _typeMappers.remove(typeMapper);
  }

  final Set<Pattern> _hiddenNodes = {};

  bool addHiddenNode(Pattern hiddenNodePattern) {
    if (_hiddenNodes.contains(hiddenNodePattern)) {
      return false;
    }
    _hiddenNodes.add(hiddenNodePattern);
    return true;
  }

  void addAllHiddenNode(List<Pattern> hiddenNodesPatterns) {
    hiddenNodesPatterns.forEach(addHiddenNode);
  }

  bool removeHiddenNode(Pattern hiddenNodePattern) {
    return _hiddenNodes.remove(hiddenNodePattern);
  }

  bool isHiddenNode(NodeKey nodeKey) {
    if (_hiddenNodes.isEmpty) return false;
    return isHiddenNodePath(nodeKey.toString());
  }

  bool isHiddenNodePath(String nodePath) {
    if (_hiddenNodes.isEmpty) return false;

    for (var pattern in _hiddenNodes) {
      if (pattern is RegExp) {
        if (pattern.hasMatch(nodePath)) return true;
      } else if (pattern is String) {
        if (pattern == nodePath) return true;
      } else {
        var allMatches = pattern.allMatches(nodePath);
        if (allMatches.isNotEmpty) return true;
      }
    }

    return false;
  }

  final List<TypeAction> _typeActions = [];

  bool addTypeAction(TypeAction typeAction) {
    if (_typeActions.contains(typeAction)) return false;
    _typeActions.add(typeAction);
    return true;
  }

  void addAllTypeAction(List<TypeAction> typeActions) {
    typeActions.forEach(addTypeAction);
  }

  bool removeTypeAction(TypeAction typeAction) {
    // ignore: unnecessary_null_comparison
    if (typeAction == null) return false;
    return _typeActions.remove(typeAction);
  }

  CSSThemeSet cssThemeSet = jsonRenderDefaultThemeSet;

  String get cssThemePrefix => cssThemeSet.cssPrefix;

  void applyCSS(TypeRender typeRender, Element output,
      [List<Element>? extraElements]) {
    cssThemeSet.ensureThemeLoaded();
  }

  static final HttpCache defaultHttpCache = HttpCache(
      maxCacheMemory: 1024 * 1024 * 16, timeout: Duration(minutes: 5));

  HttpCache httpCache = defaultHttpCache;
}

class URLFiltered {
  final String url;

  final String? target;

  final String? _label;

  final String? type;

  URLFiltered(this.url, {this.target, String? label, this.type})
      : _label = label;

  String get label => _label ?? url;

  @override
  String toString() {
    return 'URLLink{url: $url, target: $target, label: $_label}';
  }
}

typedef FilterURL = URLFiltered Function(String? url);

class NodeKey {
  final List<String> path;

  NodeKey.fromFullKey(String fullKey)
      : path = List.from(
            fullKey.trim().split('/').map((e) => e.trim()).toList(),
            growable: false);

  NodeKey([List<String>? path])
      : path = List.from(path ?? [''], growable: false);

  NodeKey append(String appendKey) => NodeKey([...path, appendKey]);

  bool matches(RegExp regExp) {
    return regExp.hasMatch(fullKey);
  }

  String get fullKey => toString();

  String get rootKey => path[0];

  String? get parentKey => path.length > 1 ? path[path.length - 2] : null;

  String get leafKey => path[path.length - 1];

  NodeKey? get parent =>
      path.length > 1 ? NodeKey(List.from(path)..removeLast()) : null;

  String? _pathString;

  @override
  String toString() {
    _pathString ??= path.join('/');
    return _pathString!;
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

/// Abstract class for type renders.
abstract class TypeRender {
  final String cssClass;

  TypeRender(this.cssClass) {
    if (cssClass.isEmpty) {
      throw ArgumentError('Invalid cssClass');
    }
  }

  bool matches(dynamic node, dynamic nodeParent, NodeKey nodeKey);

  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey);

  void applyCSS(JSONRender render, Element output,
      {String? cssClass, List<Element>? extraElements}) {
    if (cssClass == null || cssClass.isEmpty) {
      cssClass = this.cssClass;
    }

    var classPrefixed = '${render.cssThemePrefix}$cssClass';

    output.classes.add(classPrefixed);

    if (extraElements != null) {
      for (var elem in extraElements) {
        elem.classes.add(classPrefixed);
      }
    }

    render.applyCSS(this, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeRender &&
          runtimeType == other.runtimeType &&
          cssClass == other.cssClass;

  @override
  int get hashCode => cssClass.hashCode;
}

class _NodeMapping {
  final TypeMapper? typeMapper;

  final dynamic nodeOriginal;

  final dynamic nodeMapped;

  final dynamic nodeParent;

  final NodeKey nodeKey;

  _NodeMapping(this.typeMapper, this.nodeOriginal, this.nodeMapped,
      this.nodeParent, this.nodeKey);

  dynamic unmap(dynamic node, dynamic nodeParent) {
    if (typeMapper != null) {
      return typeMapper!.unmap(node, nodeOriginal, nodeParent, nodeKey);
    } else {
      return node;
    }
  }

  ValueProvider unmapValueProvider(ValueProvider valueProvider) {
    return (parent) => unmap(valueProvider(parent), parent);
  }
}

typedef NodeMatcher = bool Function(
    dynamic node, dynamic parent, NodeKey nodeKey);
typedef NodeMap = dynamic Function(
    dynamic node, dynamic parent, NodeKey nodeKey);
typedef NodeUnmap = dynamic Function(
    dynamic node, dynamic nodeOriginal, dynamic parent, NodeKey nodeKey);

/// Represents a node type mapper. Allows to change node tree for a better
/// [TypeRender] matching of visualization.
class TypeMapper {
  /// Identifies a node to map.
  final NodeMatcher matcher;

  /// Performs the node mapping process.
  final NodeMap mapper;

  /// Performs the node unmapping process. Used to rebuild the JSON tree
  /// from the current rendered tree.
  ///
  /// Needed to update the generated JSON
  /// with tree inputs.
  final NodeUnmap? unmapper;

  static TypeMapper? from(dynamic matcher, dynamic mapper, [dynamic unmapper]) {
    NodeMatcher? matcherOk;
    NodeMap? mapperOk;
    NodeUnmap? unmapperOk;

    if (matcher is NodeMatcher) {
      matcherOk = matcher;
    } else if (matcher is RegExp) {
      matcherOk = (n, p, k) {
        var keyPath = k.toString();
        var hasMatch = matcher.hasMatch(keyPath);
        return hasMatch;
      };
    }

    if (mapper is NodeMap) {
      mapperOk = mapper;
    }

    if (unmapper is NodeUnmap) {
      unmapperOk = unmapper;
    }

    if (matcherOk != null && mapperOk != null) {
      return TypeMapper(matcherOk, mapperOk, unmapperOk);
    }

    return null;
  }

  TypeMapper(this.matcher, this.mapper, [this.unmapper]);

  bool matches(dynamic node, dynamic parent, NodeKey nodeKey) =>
      matcher(node, parent, nodeKey);

  dynamic map(dynamic node, dynamic parent, NodeKey nodeKey) =>
      mapper(node, parent, nodeKey);

  dynamic unmap(
      dynamic node, dynamic nodeOriginal, dynamic parent, NodeKey nodeKey) {
    if (unmapper != null) {
      return unmapper!(node, nodeOriginal, parent, nodeKey);
    } else {
      return node;
    }
  }
}

typedef NodeValidator = bool Function(
    dynamic node, dynamic parent, NodeKey nodeKey);

typedef NodeAction = void Function(
    dynamic node, dynamic parent, NodeKey nodeKey);

/// Action to perform when clicking in the node.
class TypeAction {
  final NodeMatcher matcher;

  final NodeAction action;

  TypeAction(this.matcher, this.action);

  bool matches(dynamic node, dynamic parent, NodeKey nodeKey) =>
      matcher(node, parent, nodeKey);

  void doAction(dynamic node, dynamic parent, NodeKey nodeKey) {
    try {
      action(node, parent, nodeKey);
    } catch (e, s) {
      print(e);
      print(s);
    }
  }
}
