from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

class_start = text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage> {')
class_end = text.find('\nclass _MapLegendDot', class_start)
if class_start < 0 or class_end < 0:
    raise SystemExit('Could not isolate Intelligence Map state class for viewport patch')
segment = text[class_start:class_end]


def seg_replace_once(old: str, new: str, label: str):
    global segment
    count = segment.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match in Intelligence Map state, found {count}')
    segment = segment.replace(old, new, 1)


# v789: add only the state this progressive viewport feature owns.
seg_replace_once(
    "  bool _showExpansion = !_displayPreferences.value.simplifiedViews;\n",
    "  bool _showExpansion = !_displayPreferences.value.simplifiedViews;\n"
    "  Timer? _viewportRefreshTimer;\n"
    "  LatLngBounds? _viewportBounds = LatLngBounds(\n"
    "      const LatLng(40.75, -74.25), const LatLng(43.25, -70.80));\n"
    "  double _viewportZoom = 6.3;\n",
    'viewport-state',
)

# Earlier release layers may alter initState. Cleanup belongs to this feature,
# so anchor it to the stable didUpdateWidget lifecycle hook instead.
if '_viewportRefreshTimer?.cancel();' not in segment:
    did_update = """
  @override
  void didUpdateWidget(covariant _IntelligenceMapPage oldWidget) {
"""
    if segment.count(did_update) != 1:
        raise SystemExit(
            f'viewport-dispose-anchor: expected exactly 1 didUpdateWidget hook, found {segment.count(did_update)}')
    dispose = """
  @override
  void dispose() {
    _viewportRefreshTimer?.cancel();
    super.dispose();
  }
"""
    segment = segment.replace(did_update, dispose + did_update, 1)

load_start = segment.find('  Future<Map<String, dynamic>> _load() async {')
load_end = segment.find('\n  void _reload()', load_start)
if load_start < 0 or load_end < 0:
    raise SystemExit('viewport-load: could not isolate current _load method')
new_load = r'''  Future<Map<String, dynamic>> _load() async {
    final bounds = _viewportBounds;
    final showPropertyIntelligence = _viewportZoom >= 5.8;
    final opportunityLimit = _viewportZoom >= 12
        ? 350
        : _viewportZoom >= 9
            ? 220
            : _viewportZoom >= 7
                ? 140
                : 80;
    final signalLimit = _viewportZoom >= 12
        ? 180
        : _viewportZoom >= 9
            ? 120
            : _viewportZoom >= 7
                ? 80
                : 45;
    final mapBody = {
      'p_model_key': widget.modelKey,
      'p_min_lat': showPropertyIntelligence ? bounds?.southWest.latitude : null,
      'p_max_lat': showPropertyIntelligence ? bounds?.northEast.latitude : null,
      'p_min_lng': showPropertyIntelligence ? bounds?.southWest.longitude : null,
      'p_max_lng': showPropertyIntelligence ? bounds?.northEast.longitude : null,
      'p_min_score': _minimumScore,
      'p_limit': opportunityLimit,
    };
    final signalBody = {
      'p_min_lat': showPropertyIntelligence ? bounds?.southWest.latitude : null,
      'p_max_lat': showPropertyIntelligence ? bounds?.northEast.latitude : null,
      'p_min_lng': showPropertyIntelligence ? bounds?.southWest.longitude : null,
      'p_max_lng': showPropertyIntelligence ? bounds?.northEast.longitude : null,
      'p_limit': signalLimit,
    };

    final results = await Future.wait<Object>([
      showPropertyIntelligence
          ? http
              .post(
                Uri.parse(
                    '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_intelligence_map_v57'),
                headers: _apiHeaders(),
                body: jsonEncode(mapBody),
              )
              .timeout(const Duration(seconds: 30))
          : Future.value(http.Response(
              jsonEncode({
                'complete': true,
                'points': <dynamic>[],
                'returned_points': 0,
                'viewport_applied': true,
                'map_mode': 'WEATHER_OVERVIEW',
              }),
              200)),
      _callRpc('bridgepoint_flutter_geographic_catalog_v77', const {}),
      showPropertyIntelligence
          ? _callRpc('bridgepoint_flutter_signal_map_v80', signalBody)
          : Future.value(<String, dynamic>{
              'complete': true,
              'signals': <dynamic>[],
              'returned_points': 0,
              'map_mode': 'WEATHER_OVERVIEW',
            }),
    ]);
    final response = results[0] as http.Response;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Intelligence Map API ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected Intelligence Map response.');
    }
    return <String, dynamic>{
      ...Map<String, dynamic>.from(decoded),
      'coverage_catalog': results[1],
      'signal_map': results[2],
    };
  }
'''
segment = segment[:load_start] + new_load + segment[load_end:]

old_options = """                        options: const MapOptions(
                          initialCenter: LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 4,
                          maxZoom: 18,
                          interactionOptions: InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                        ),
"""
new_options = """                        options: MapOptions(
                          initialCenter: const LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 4,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                          onPositionChanged: (camera, hasGesture) {
                            _viewportRefreshTimer?.cancel();
                            _viewportRefreshTimer =
                                Timer(const Duration(milliseconds: 450), () {
                              if (!mounted) return;
                              final nextBounds = camera.visibleBounds;
                              final nextZoom = camera.zoom;
                              final prior = _viewportBounds;
                              final zoomChanged =
                                  (nextZoom - _viewportZoom).abs() >= 0.12;
                              final boundsChanged = prior == null ||
                                  (nextBounds.southWest.latitude -
                                              prior.southWest.latitude)
                                          .abs() >=
                                      0.015 ||
                                  (nextBounds.southWest.longitude -
                                              prior.southWest.longitude)
                                          .abs() >=
                                      0.015 ||
                                  (nextBounds.northEast.latitude -
                                              prior.northEast.latitude)
                                          .abs() >=
                                      0.015 ||
                                  (nextBounds.northEast.longitude -
                                              prior.northEast.longitude)
                                          .abs() >=
                                      0.015;
                              if (!zoomChanged && !boundsChanged) return;
                              setState(() {
                                _viewportBounds = nextBounds;
                                _viewportZoom = nextZoom;
                                _request = _load();
                              });
                            });
                          },
                        ),
"""
seg_replace_once(old_options, new_options, 'viewport-map-options')

us_control = "tooltip: 'Show U.S. intelligence'"
if segment.count(us_control) != 1:
    raise SystemExit(
        f'US intelligence control missing or duplicated: found {segment.count(us_control)}')

text = text[:class_start] + segment + text[class_end:]
if text == original:
    raise SystemExit('No viewport map changes applied')
path.write_text(text, encoding='utf-8')
print('Applied viewport-aware progressive intelligence map v124/v789')
