import 'dart:html';

import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';

/// A geolocation pair value in [_latitude] and [_longitude].
class Geolocation {
  static Future<Geolocation> getCurrentGeolocation() async {
    print('Geolocation.getCurrentGeolocation> ...');
    var geolocation = window.navigator.geolocation;
    var currentPosition = await geolocation.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: Duration(seconds: 30),
        maximumAge: Duration(minutes: 10));
    print('Geolocation.getCurrentGeolocation> $currentPosition');
    var coords = currentPosition.coords!;
    return Geolocation(coords.latitude!, coords.longitude!);
  }

  static final RegExp _geolocationFormat =
      RegExp(r'([-=]?)(\d+[,.]?\d*)\s*[°o]?\s*(\w)');

  static num? parseLatitudeOrLongitudeValue(String s,
      [bool onlyWithCardinals = false]) {
    var match = _geolocationFormat.firstMatch(s);
    if (match == null) return null;

    var signal = match.group(1);
    var number = match.group(2);
    var cardinal = match.group(3);

    if (signal != null && signal.isNotEmpty) {
      if (onlyWithCardinals) return null;
      return double.parse('$signal$number');
    } else if (cardinal != null && cardinal.isNotEmpty) {
      cardinal = cardinal.toUpperCase();

      switch (cardinal) {
        case 'N':
          return double.parse('$number');
        case 'S':
          return double.parse('-$number');
        case 'E':
          return double.parse('$number');
        case 'W':
          return double.parse('-$number');
      }
    }

    if (onlyWithCardinals) return null;
    return double.parse(number!);
  }

  static String formatLatitude(num lat) {
    return lat >= 0 ? '$lat°E' : '$lat°W';
  }

  static String formatLongitude(num long) {
    return long >= 0 ? '$long°N' : '$long°S';
  }

  static String formatGeolocation(Point geo) {
    return '${formatLatitude(geo.x)} ${formatLongitude(geo.y)}';
  }

  /// The latitude of the coordinate.
  final num latitude;

  /// The longitude of the coordinate.
  final num longitude;

  Geolocation(this.latitude, this.longitude);

  static Geolocation? fromCoords(String coords, [bool? onlyWithCardinals]) {
    coords = coords.trim();

    var parts = coords.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    var lat = parseLatitudeOrLongitudeValue(parts[0], onlyWithCardinals!);
    var long = parseLatitudeOrLongitudeValue(parts[1], onlyWithCardinals);

    return lat != null && long != null ? Geolocation(lat, long) : null;
  }

  Point<num> asPoint() => Point(latitude, longitude);

  @override
  String toString() {
    return formatGeolocation(asPoint());
  }

  String windowID(String prefix) {
    return '${prefix}__${latitude}__$longitude';
  }

  String googleMapsURL() {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  Future<String> googleMapsDirectionsURL() async {
    var currentGeo = await getCurrentGeolocation();

    return 'https://www.google.com/maps/dir/?api=1&origin=${currentGeo.latitude},${currentGeo.longitude}&destination=$latitude,$longitude';
  }

  String openGoogleMaps() {
    var url = googleMapsURL();
    print('Geolocation.openGoogleMaps> $url');
    // ignore: unsafe_html
    window.open(url, windowID('googlemaps'));
    return url;
  }

  Future<String> openGoogleMapsDirections() async {
    print('Geolocation.openGoogleMapsDirections> ...');
    var url = await googleMapsDirectionsURL();
    print('Geolocation.openGoogleMapsDirections> $url');
    // ignore: unsafe_html
    window.open(url, windowID('googlemaps_directions'));
    return url;
  }
}

/// Renders a Geo location coordinate.
class TypeGeolocationRender extends TypeRender {
  final bool openDirections;

  TypeGeolocationRender([this.openDirections = false])
      : super('geolocation-render');

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    return parseLatitudeLongitude(node) != null;
  }

  Geolocation? parseLatitudeLongitude(dynamic node) {
    if (node is Map) {
      var latitudeEntry = findKeyEntry(node, ['latitude']);
      var longitudeEntry = findKeyEntry(node, ['longitude']);

      if (latitudeEntry != null && longitudeEntry != null) {
        var lat = latitudeEntry.value;
        var long = longitudeEntry.value;

        if (lat is num && long is num) {
          return Geolocation(lat, long);
        } else if (lat is String && long is String) {
          var lat2 = Geolocation.parseLatitudeOrLongitudeValue(lat)!;
          var long2 = Geolocation.parseLatitudeOrLongitudeValue(long)!;
          return Geolocation(lat2, long2);
        }
      }
    } else if (node is String) {
      return Geolocation.fromCoords(node, true);
    }

    return null;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var geo = parseLatitudeLongitude(node);
    var nodeIsMap = node is Map;

    Element geoElem;
    ValueProvider valueProvider;

    if (render.renderMode == JSONRenderMode.input) {
      var geoStr = geo.toString();

      var input = InputElement()
        ..value = geoStr
        ..type = 'text';

      input.onDoubleClick.listen((e) {
        var geo2 = Geolocation.fromCoords(input.value!);
        openGoogleMaps(geo2);
      });

      var button = SpanElement()
        ..innerHtml = ' &#8853;'
        ..style.fontSize = '125%'
        ..style.cursor = 'pointer';

      button.onClick.listen((e) async {
        print('Getting CurrentGeolocation...');
        var myGeolocation = await Geolocation.getCurrentGeolocation();
        print('CurrentGeolocation: $myGeolocation');
        input.value = myGeolocation.toString();
      });

      geoElem = createDivInline();

      geoElem.children.add(input);
      geoElem.children.add(button);

      valueProvider = (parent) {
        final value = input.value!;
        var geo2 = Geolocation.fromCoords(value)!;

        if (nodeIsMap) {
          return {'latitude': geo2.latitude, 'longitude': geo2.longitude};
        } else {
          return geo2;
        }
      };
    } else {
      var geoStr = geo.toString();

      var elem = SpanElement()..text = geoStr;

      elem.onClick.listen((e) {
        copyElementToClipboard(elem);
        openGoogleMaps(geo);
      });

      geoElem = elem;

      valueProvider = (parent) => nodeOriginal;
    }

    output.children.add(SpanElement()..innerHtml = '&#x1F4CD;');
    output.children.add(geoElem);

    this.applyCSS(render, output, extraElements: [geoElem]);

    return valueProvider;
  }

  void openGoogleMaps(Geolocation? geolocation) {
    if (geolocation == null) return;

    print('openGoogleMaps> openDirections: $openDirections');

    if (openDirections) {
      geolocation.openGoogleMapsDirections();
    } else {
      geolocation.openGoogleMaps();
    }
  }
}
