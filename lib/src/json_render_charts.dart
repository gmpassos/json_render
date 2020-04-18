

import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:chartjs/chartjs.dart' as chartjs ;
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'json_render_base.dart';


final random = Random();

int rand(int min, int max) => random.nextInt(max - min) + min;

class TypeChartsRender extends TypeRender {

  //final ChartEngine engine = ChartEngineModernCharts() ;
  final ChartEngine _engine ;

  TypeChartsRender( this._engine ) : super('charts-render') ;

  //////////

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if ( node is Map ) {
      if ( node.length < 2 ) return false ;

      var notAllSeries = listNotMatchesAll(node.values , (e) => (e is List && e.length > 1 ) ) ;
      if ( notAllSeries ) return false ;

      var notAllSeriesWithValues = node.values.firstWhere( (l) => l is List && listNotMatchesAll(l , (e) => e is String || e is num) , orElse: () => null ) ;
      if ( notAllSeriesWithValues ) return false ;
    }
    else if ( node is List ) {
      var notAllSeries = listNotMatchesAll( node , (e) => (e is Map && e.length > 1) ) ;
      if ( notAllSeries ) return false ;

      var columns = getCollectionColumns( List.from(node) ) ;
      if (columns == null) return false ;
      columns.sort();

      var notAllSeriesWithColumns = listNotMatchesAll( node , (e) => (e is Map && isEquivalentList( columns, List.from(e.keys)..sort() ) ) ) ;
      if ( notAllSeriesWithColumns ) return false ;

      var notAllSeriesWithValues = listNotMatchesAll( node , (e) => (e is Map && listMatchesAll( e.values , (v) => (v is String || v is num) ) ) ) ;
      if ( notAllSeriesWithValues ) return false ;

      return true ;
    }
    return false ;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node, dynamic nodeOriginal, NodeKey nodeKey) {
    var valueSet = JSONValueSet(true) ;

    var chartSeries = ChartSeries.from(node) ;

    _engine.render(output, chartSeries) ;

    return valueSet.asValueProvider() ;
  }

}

List<String> getCollectionColumns(List<Map> list) {
  // ignore: omit_local_variable_types
  Map<String,bool> columns = {} ;
  list.forEach( (e) => _extractColumns(e,columns) ) ;
  return columns.keys.toList() ;
}


void _extractColumns(Map map, Map<String,bool> columns) {
  if (map == null) return ;
  map.entries.forEach( (entry) {
    var key = entry.key ;
    var val = entry.value ;

    var containsValue = val != null || ( columns[key] ?? false ) ;
    return columns[key] = containsValue ;
  } ) ;
}

enum SeriesType {
  DATE,
  CATEGORY,
  NUM,
  UNKNOWN,
}

SeriesType getSeriesType(List series) {
  if ( listMatchesAll( series , (e) => e is num ) ) {
    if ( listMatchesAll( series , (e) => TypeUnixEpochRender().isInUnixEpochRange(e) ) ) {
      return SeriesType.DATE ;
    }

    return SeriesType.NUM ;
  }
  else if ( listMatchesAll( series , (e) => e is String ) ) {
    return SeriesType.CATEGORY ;
  }

  return SeriesType.UNKNOWN ;
}

class ChartSeries {

  final List<String> _seriesNames ;
  final List<List> _seriesSet ;
  List<SeriesType> _seriesTypes ;

  int _seriesLength ;
  int _seriesEntriesLength ;

  factory ChartSeries.from(dynamic series) {
    if ( series is Map ) {
      return ChartSeries.fromMap( series ) ;
    }
    else if ( series is List ) {
      return ChartSeries.fromList( series ) ;
    }
    return null ;
  }

  ChartSeries.fromMap( Map series ) : this( series.keys.toList().cast() , series.values.cast() ) ;

  factory ChartSeries.fromList( List series ) {
    var columns = getCollectionColumns( series.cast() ) ;

    // ignore: omit_local_variable_types
    List<List> seriesSet = [] ;

    for (var column in columns) {
      var values = series.map( (m) => m[column] ).toList() ;
      seriesSet.add(values) ;
    }

    return ChartSeries(columns , seriesSet);
  }

  ChartSeries( this._seriesNames, this._seriesSet ) {
    _checkSeries();
  }

  void _checkSeries() {
    var lengths = _seriesSet.map( (s) => s.length ).toList() ;
    lengths.sort();

    var maxLength = lengths.last ;

    _seriesEntriesLength = maxLength ;
    _seriesLength = seriesSet.length ;

    for (var series in _seriesSet) {
      var nullValue = _nullValue(series.last) ;

      while (series.length < maxLength) {
        series.add(nullValue) ;
      }
    }

    if ( _seriesSet.length != _seriesNames.length ) {
      throw StateError('Wrong series names length: ${ _seriesSet.length } != ${ _seriesNames.length }') ;
    }

    _seriesTypes = _seriesSet.map( (s) => getSeriesType(s) ).toList() ;

    var dateIdx = _seriesTypes.indexOf( SeriesType.DATE ) ;

    if (dateIdx >= 0) {
      _setMainSeries(dateIdx) ;
    }

    var categoryIdx = _seriesTypes.indexOf( SeriesType.CATEGORY ) ;

    if (categoryIdx >= 0) {
      _setMainSeries(categoryIdx) ;
    }

  }

  void normalizeDateSeries() {

    for (var i = 0; i < _seriesTypes.length; ++i) {
      var type = _seriesTypes[i];

      if (type == SeriesType.DATE) {
        // ignore: omit_local_variable_types
        List<String> listDates = _seriesSet[i].map( (e) => DateTime.fromMillisecondsSinceEpoch(e).toString() ).toList();

        if ( listMatchesAll<String>(listDates, (e) => e.endsWith('00:00:00.000') ) ) {
          listDates = listDates.map( (e) => e.replaceFirst('00:00:00.000', '') ).toList() ;
        }

        _seriesSet[i] = listDates ;
      }
    }

  }

  void _setMainSeries(int index) {
    if (index <= 0) return ;

    var name = _seriesNames.removeAt(index) ;
    var set = _seriesSet.removeAt(index) ;
    var type = _seriesTypes.removeAt(index) ;

    _seriesNames.insert(0, name);
    _seriesSet.insert(0, set);
    _seriesTypes.insert(0, type);
  }

  dynamic _nullValue(dynamic reference) {
    var nullValue ;

    if (reference is String) {
      nullValue = '' ;
    }
    else if (reference is double) {
      nullValue = 0.0 ;
    }
    else if (reference is int) {
      nullValue = 0 ;
    }
    else if (reference is num) {
      nullValue = 0 ;
    }
    else if (reference is bool) {
      nullValue = false ;
    }

    return nullValue ;
  }

  List<List> get seriesSet => _seriesSet;
  List<String> get seriesNames => _seriesNames;
  List<SeriesType> get seriesTypes => _seriesTypes;

  Map<String, List> get series {
    // ignore: omit_local_variable_types
    Map<String, List> map = {} ;

    for (var i = 0 ; i < _seriesLength ; i++) {
      map[ _seriesNames[i] ] = _seriesSet[i] ;
    }

    return map ;
  }

  int get seriesLength => _seriesLength;
  int get seriesEntriesLength => _seriesEntriesLength;

  @override
  String toString() {
    return 'ChartSeries{seriesLength: $_seriesEntriesLength}';
  }

  List<List> invertDataAxis() {
    var seriesSet2 = [ List.from(_seriesNames) ] ;

    for (var eI = 0 ; eI < _seriesEntriesLength ; eI++) {
      var series = [] ;

      for (var sI = 0 ; sI < _seriesLength ; sI++) {
        var val = _seriesSet[sI][eI] ;
        series.add(val) ;
      }

      seriesSet2.add(series) ;
    }

    return seriesSet2 ;
  }


}

enum ChartType {
  LINE,
  DOT,
  BAR,
  PIE
}

abstract class ChartEngine {

  ChartType identifyBestChartType() {
    return ChartType.LINE ;
  }

  void render( Element output, ChartSeries chartSeries ) {
    if ( chartSeries == null ) return ;
    var chartType = identifyBestChartType() ;
    renderByChartType(output, chartSeries, chartType) ;
  }

  void renderByChartType( Element output, ChartSeries chartSeries , ChartType chartType ) {

    if ( chartType == ChartType.LINE || chartType == null ) {
      renderLineChart(output, chartSeries) ;
    }
    else if ( chartType == ChartType.DOT ) {
      renderDotChart(output, chartSeries) ;
    }
    else if ( chartType == ChartType.BAR ) {
      renderBarChart(output, chartSeries) ;
    }
    else if ( chartType == ChartType.PIE ) {
      renderPieChart(output, chartSeries) ;
    }
    else {
      throw UnsupportedError('Unsupported ChartType: $chartType') ;
    }

  }

  void renderLineChart(Element output, ChartSeries chartSeries) {
    throw UnsupportedError('Line chart not supported') ;
  }

  void renderDotChart(Element output, ChartSeries chartSeries) {
    throw UnsupportedError('Dot chart not supported') ;
  }

  void renderBarChart(Element output, ChartSeries chartSeries) {
    throw UnsupportedError('Bar chart not supported') ;
  }

  void renderPieChart(Element output, ChartSeries chartSeries) {
    throw UnsupportedError('Pie chart not supported') ;
  }

}

class ChartEngineChartJS extends ChartEngine {

  final String chartJSPath ;


  ChartEngineChartJS(this.chartJSPath) {
    _scriptChartJS = _loadChartJS() ;
  }

  Future<bool> _scriptChartJS ;

  Future<bool> _loadChartJS() async {
    _scriptChartJS = addJScriptSource(chartJSPath) ;
    return _scriptChartJS ;
  }

  CanvasElement createContainer() {
    var e = CanvasElement(width: 600, height: 400)
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.maxWidth = '100%'
      ..style.maxHeight = '100%'
    ;
    return e;
  }

  @override
  void renderLineChart(Element output, ChartSeries chartSeries) {
    _renderChart(output, chartSeries, 'line') ;
  }

  @override
  void renderDotChart(Element output, ChartSeries chartSeries) {
    _renderChart(output, chartSeries, 'bubble') ;
  }

  @override
  void renderBarChart(Element output, ChartSeries chartSeries) {
    _renderChart(output, chartSeries, 'bar') ;
  }

  @override
  void renderPieChart(Element output, ChartSeries chartSeries) {
    _renderChart(output, chartSeries, 'pie') ;
  }

  void _renderChart(Element output, ChartSeries chartSeries, String type) {

    chartSeries.normalizeDateSeries();

    var mainSeries = chartSeries.seriesSet[0] ;
    var mainSeriesType = chartSeries.seriesTypes[0] ;

    var dataSets = chartSeries.series.map( (name, series) => MapEntry( name , chartjs.ChartDataSets(label: name, data: series) ) ).values.toList() ;
    dataSets.removeAt(0) ;

    //////////

    var chartOptions = chartjs.ChartOptions(responsive: true, scales: chartjs.ChartScales());

    chartOptions.scales.xAxes = [
      chartjs.ChartXAxe(display: true, scaleLabel: chartjs.ScaleTitleOptions(display: true, labelString: chartSeries.seriesNames[0]) ,
      ) ,
    ] ;

    var data = chartjs.LinearChartData(labels: mainSeries , datasets: dataSets) ;

    var config = chartjs.ChartConfiguration(type: 'line', data: data, options: chartOptions);

    var container = createContainer() ;
    output.children.add(container) ;

    var context = container.getContext('2d');
    chartjs.Chart(context, config);

  }

}

