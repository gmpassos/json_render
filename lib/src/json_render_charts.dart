import 'dart:html';

import 'package:chart_engine/chart_engine_chartjs.dart' as chart;
import 'package:json_render/json_render.dart';

import 'json_render_base.dart';

/// Renders Charts, detecting series in JSON.
///
/// Tries to identify the best chart for each kind of data.
/// Uses default behavior of package `chart_engine`.
class TypeChartsRender extends TypeRender {
  chart.ChartEngine _chartEngine;

  TypeChartsRender() : super('charts-render') {
    _chartEngine = chart.ChartEngineChartJS();
    _chartEngine.load();
  }

  @override
  bool matches(node, dynamic nodeParent, NodeKey nodeKey) {
    if (node is Map) {
      return chart.ChartData.matchesChartData(node);
    }
    return false;
  }

  @override
  ValueProvider render(JSONRender render, DivElement output, dynamic node,
      dynamic nodeOriginal, NodeKey nodeKey) {
    var valueSet = JSONValueSet(true);

    var chartData = chart.ChartData.from(node);

    _chartEngine.renderAsync(output, chartData);

    return valueSet.asValueProvider();
  }
}
