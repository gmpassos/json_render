## 1.3.5

- Fix typo.
- dartfmt.
- mercury_client: ^1.1.10
- dom_tools: ^1.3.8
- swiss_knife: ^2.5.10
- chart_engine: ^1.1.4
- CI: dartfmt + dartanalyzer.

## 1.3.4

- dom_tools: ^1.3.4
- mercury_client: ^1.1.8
- swiss_knife: ^2.5.5
- chart_engine: ^1.1.3

## 1.3.3

- dom_tools: ^1.3.2

## 1.3.2

- Added example.
- Better package description.

## 1.3.1

- dom_tools: ^1.3.1
- chart_engine: ^1.0.11
- dartfmt.

## 1.3.0

- Removes dependency `chartjs`.
- Now using package `chart_engine` for Charts.
- Hidden nodes.
- TypeSelectRender, TypeMapper, TypeGeolocationRender.
- Added API Documentation.

## 1.2.8

- TypeEmailRender
- TypeDateRender
- TypePaging: show sub elements with paging handling.
- TypeChartsRender: render data as charts.
- mercury_client: ^1.1.5
- dom_tools: ^1.2.8
- swiss_knife: ^2.3.10
- chartjs: ^0.5.1

## 1.2.7

- mercury_client: ^1.1.4
- dom_tools: ^1.2.7
- swiss_knife: ^2.3.9

## 1.2.6

- mercury_client: ^1.1.3
- dom_tools: ^1.2.6

## 1.2.5

- swiss_knife: ^2.3.7

## 1.2.4

- JSONRender.showNodeArrow
- Change CSS to use CSSThemeSet.

## 1.2.3

- TypeTimeMillisRender renamed to TypeUnixEpochRender.
- TypeTimeRender, TypePercentageRender
- Fix TypeTableRender: now checks if entry node is valid.
- mercury_client: ^1.1.1
- swiss_knife: ^2.3.0

## 1.2.2

- JSONRender.addTypeRender( overwrite )
- JSONRender.addAllKnownTypeRenders()
- TypeGeolocation
- mercury_client: ^1.0.9

## 1.2.1

- TypeImageViewerRender: clean code and fix parsing of parameters. Ensure that always returns int values (not doubles).

## 1.2.0

- TypeTableRender: a table that shows a list of objects.
- TypeImageURLRender: shows an image from an URL or dataURL (Base64).
- TypeImageViewerRender: show/edit an image with infos: clip, rectangles, points and perspective.

## 1.0.1

- Now TypeTimeMillisRender, in JSONRenderMode.VIEW, shows date in format: yyyy/MM/dd HH:mm:ss

## 1.0.0

- Initial version, created by Stagehand
