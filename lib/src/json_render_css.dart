
import 'package:dom_tools/dom_tools.dart';

////////////////////////////////////////////////////////////////////////////////

const JSON_RENDER_THEME_DARK = {
  'list-render': TextStyle(color: StyleColor.fromHex('808080'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.07') , borderRadius: '10px', padding: '4px' ),
  'object-render': TextStyle(color: StyleColor.fromHex('808080'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.07') , borderRadius: '10px' ),

  'text-render': TextStyle(color: StyleColor.fromHex('a6a233'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'number-render': TextStyle(color: StyleColor.fromHex('35a633'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'bool-render': TextStyle(color: StyleColor.fromHex('a63333'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'null-render': TextStyle(color: StyleColor.fromHex('808080'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'url-render': TextStyle(color: StyleColor.fromHex('3385a6'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'unix-epoch-render': TextStyle(color: StyleColor.fromHex('9733a6'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'time-render': TextStyle(color: StyleColor.fromHex('a63389'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'percentage-render': TextStyle(color: StyleColor.fromHex('33a66b'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'geolocation-render': TextStyle(color: StyleColor.fromHex('336ba6'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'select-render': TextStyle(color: StyleColor.fromHex('a6a233'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'table-render': TextStyle( backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'table-header-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.15') ) ,
  'table-row1-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.02') ),
  'table-row2-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.10') ),

  'image-url-Render': TextStyle( borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'image-viewer-render': TextStyle( borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
};

const JSON_RENDER_THEME_LIGHT = {
  'list-render': TextStyle(color: StyleColor.fromHex('363636'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.07') , borderRadius: '12px', padding: '4px' ),
  'object-render': TextStyle(color: StyleColor.fromHex('363636'), backgroundColor: StyleColor.fromRGBa('0,0,0, 0.07') , borderRadius: '12px', padding: '6px' ),

  'text-render': TextStyle(color: StyleColor.fromHex('574f44'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'number-render': TextStyle(color: StyleColor.fromHex('216b20'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'bool-render': TextStyle(color: StyleColor.fromHex('6e2222'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'null-render': TextStyle(color: StyleColor.fromHex('595959'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'url-render': TextStyle(color: StyleColor.fromHex('1d4859'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'unix-epoch-render': TextStyle(color: StyleColor.fromHex('762682'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'time-render': TextStyle(color: StyleColor.fromHex('752461'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'percentage-render': TextStyle(color: StyleColor.fromHex('217349'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'geolocation-render': TextStyle(color: StyleColor.fromHex('2f6499'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'select-render': TextStyle(color: StyleColor.fromHex('545219'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),

  'table-render': TextStyle( backgroundColor: StyleColor.fromRGBa('0,0,0, 0.05'), borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'table-header-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.15') ) ,
  'table-row1-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.02') ),
  'table-row2-render': TextStyle( backgroundColor: StyleColor.fromRGBa('128,128,128, 0.10') ),

  'image-url-Render': TextStyle( borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
  'image-viewer-render': TextStyle( borderColor: StyleColor.fromRGBa('255,255,255, 0.30') ),
};

final CSSThemeSet JSON_RENDER_DEFAULT_THEME_SET = CSSThemeSet('json_render__', [JSON_RENDER_THEME_DARK, JSON_RENDER_THEME_LIGHT]) ;

