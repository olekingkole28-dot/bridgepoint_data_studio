from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""  Timer? _radarRefreshTimer;
  int _radarRevision=0;
""",
"""  Timer? _radarRefreshTimer;
  int _radarRevision=0;
  Timer? _viewportRefreshTimer;
  LatLngBounds? _viewportBounds=LatLngBounds(const LatLng(40.75,-74.25),const LatLng(43.25,-70.80));
  double _viewportZoom=6.3;
""",
'viewport-state')

replace_once(
"""  void dispose(){
    _radarRefreshTimer?.cancel();
    super.dispose();
  }
""",
"""  void dispose(){
    _radarRefreshTimer?.cancel();
    _viewportRefreshTimer?.cancel();
    super.dispose();
  }
""",
'viewport-dispose')

old_load="""  Future<Map<String, dynamic>> _load() async {
    final results=await Future.wait<Object>([
      http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_intelligence_map_v57'),
        headers: _apiHeaders(),
        body: jsonEncode({
          'p_model_key': widget.modelKey,
          'p_min_lat': null,'p_max_lat': null,'p_min_lng': null,'p_max_lng': null,
          'p_min_score': _minimumScore,'p_limit': 250,
        }),
      ).timeout(const Duration(seconds: 30)),
      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}),
      _callRpc('bridgepoint_flutter_signal_map_v80',{
        'p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,'p_limit':120,
      }),
    ]);
"""
new_load="""  Future<Map<String, dynamic>> _load() async {
    final bounds=_viewportBounds;
    final showPropertyIntelligence=_viewportZoom>=5.8;
    final opportunityLimit=_viewportZoom>=12?350:_viewportZoom>=9?220:_viewportZoom>=7?140:80;
    final signalLimit=_viewportZoom>=12?180:_viewportZoom>=9?120:_viewportZoom>=7?80:45;
    final mapBody={
      'p_model_key':widget.modelKey,
      'p_min_lat':showPropertyIntelligence?bounds?.southWest.latitude:null,
      'p_max_lat':showPropertyIntelligence?bounds?.northEast.latitude:null,
      'p_min_lng':showPropertyIntelligence?bounds?.southWest.longitude:null,
      'p_max_lng':showPropertyIntelligence?bounds?.northEast.longitude:null,
      'p_min_score':_minimumScore,
      'p_limit':opportunityLimit,
    };
    final signalBody={
      'p_min_lat':showPropertyIntelligence?bounds?.southWest.latitude:null,
      'p_max_lat':showPropertyIntelligence?bounds?.northEast.latitude:null,
      'p_min_lng':showPropertyIntelligence?bounds?.southWest.longitude:null,
      'p_max_lng':showPropertyIntelligence?bounds?.northEast.longitude:null,
      'p_limit':signalLimit,
    };
    final results=await Future.wait<Object>([
      showPropertyIntelligence
        ? http.post(
            Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_intelligence_map_v57'),
            headers:_apiHeaders(),body:jsonEncode(mapBody),
          ).timeout(const Duration(seconds:30))
        : Future.value(http.Response(jsonEncode({'complete':true,'points':[],'returned_points':0,'viewport_applied':true,'map_mode':'WEATHER_OVERVIEW'}),200)),
      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}),
      showPropertyIntelligence
        ? _callRpc('bridgepoint_flutter_signal_map_v80',signalBody)
        : Future.value(<String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'map_mode':'WEATHER_OVERVIEW'}),
    ]);
"""
replace_once(old_load,new_load,'viewport-load')

replace_once(
"""                        options: const MapOptions(
                          initialCenter: LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 3,
                          maxZoom: 18,
                          interactionOptions: InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                        ),
""",
"""                        options: MapOptions(
                          initialCenter: const LatLng(42.15, -72.90),
                          initialZoom: 6.3,
                          minZoom: 3,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.scrollWheelZoom,
                          ),
                          onPositionChanged:(camera,hasGesture){
                            _viewportRefreshTimer?.cancel();
                            _viewportRefreshTimer=Timer(const Duration(milliseconds:450),(){
                              if(!mounted)return;
                              final nextBounds=camera.visibleBounds;
                              final nextZoom=camera.zoom;
                              final prior=_viewportBounds;
                              final zoomChanged=(nextZoom-_viewportZoom).abs()>=0.12;
                              final boundsChanged=prior==null||
                                (nextBounds.southWest.latitude-prior.southWest.latitude).abs()>=0.015||
                                (nextBounds.southWest.longitude-prior.southWest.longitude).abs()>=0.015||
                                (nextBounds.northEast.latitude-prior.northEast.latitude).abs()>=0.015||
                                (nextBounds.northEast.longitude-prior.northEast.longitude).abs()>=0.015;
                              if(!zoomChanged&&!boundsChanged)return;
                              setState((){
                                _viewportBounds=nextBounds;
                                _viewportZoom=nextZoom;
                                _request=_load();
                              });
                            });
                          },
                        ),
""",
'viewport-map-options')

# Add a visible explanation at national zoom so an empty property layer looks intentional.
needle="""                      FlutterMap(
                        mapController: _mapController,
"""
if text.count(needle)!=1:
    raise SystemExit(f'weather-overview-overlay: expected exactly 1 map, found {text.count(needle)}')

# Insert overlay immediately before the existing map controls stack where the public/weather button exists.
controls="""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
"""
replacement="""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
"""
# Keep the control itself; the progressive-load behavior is tied to camera zoom.
if text.count(controls)!=1:
    raise SystemExit(f'US weather control missing: found {text.count(controls)}')
text=text.replace(controls,replacement,1)

if text==original:raise SystemExit('No viewport map changes applied')
path.write_text(text,encoding='utf-8')
print('Applied viewport-aware progressive intelligence map v124')
