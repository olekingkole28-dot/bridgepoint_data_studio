import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Clean V2 map implementation. Keeps radar timing slow enough for mobile WMS tiles to render,
// keeps state labels human-readable, and uses category pictograms for opportunity markers.
class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() => _BridgePointMapWeatherV2State();
}

class _BridgePointMapWeatherV2State extends State<BridgePointMapWeatherV2> {
  final MapController _mapController = MapController();

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _propertyLoadMinZoom = 6.35;
  static const _stateLabelMaxZoom = 6.15;
  static const _radarMaxHonestZoom = 10.5;

  static const Map<String, LatLng> _stateCenters = {
    'AL': LatLng(32.806671, -86.791130), 'AK': LatLng(61.370716, -152.404419), 'AZ': LatLng(33.729759, -111.431221),
    'AR': LatLng(34.969704, -92.373123), 'CA': LatLng(36.116203, -119.681564), 'CO': LatLng(39.059811, -105.311104),
    'CT': LatLng(41.597782, -72.755371), 'DE': LatLng(39.318523, -75.507141), 'DC': LatLng(38.897438, -77.026817),
    'FL': LatLng(27.766279, -81.686783), 'GA': LatLng(33.040619, -83.643074), 'HI': LatLng(21.094318, -157.498337),
    'ID': LatLng(44.240459, -114.478828), 'IL': LatLng(40.349457, -88.986137), 'IN': LatLng(39.849426, -86.258278),
    'IA': LatLng(42.011539, -93.210526), 'KS': LatLng(38.526600, -96.726486), 'KY': LatLng(37.668140, -84.670067),
    'LA': LatLng(31.169546, -91.867805), 'ME': LatLng(44.693947, -69.381927), 'MD': LatLng(39.063946, -76.802101),
    'MA': LatLng(42.230171, -71.530106), 'MI': LatLng(43.326618, -84.536095), 'MN': LatLng(45.694454, -93.900192),
    'MS': LatLng(32.741646, -89.678696), 'MO': LatLng(38.456085, -92.288368), 'MT': LatLng(46.921925, -110.454353),
    'NE': LatLng(41.125370, -98.268082), 'NV': LatLng(38.313515, -117.055374), 'NH': LatLng(43.452492, -71.563896),
    'NJ': LatLng(40.298904, -74.521011), 'NM': LatLng(34.840515, -106.248482), 'NY': LatLng(42.165726, -74.948051),
    'NC': LatLng(35.630066, -79.806419), 'ND': LatLng(47.528912, -99.784012), 'OH': LatLng(40.388783, -82.764915),
    'OK': LatLng(35.565342, -96.928917), 'OR': LatLng(44.572021, -122.070938), 'PA': LatLng(40.590752, -77.209755),
    'RI': LatLng(41.680893, -71.511780), 'SC': LatLng(33.856892, -80.945007), 'SD': LatLng(44.299782, -99.438828),
    'TN': LatLng(35.747845, -86.692345), 'TX': LatLng(31.054487, -97.563461), 'UT': LatLng(40.150032, -111.862434),
    'VT': LatLng(44.045876, -72.710686), 'VA': LatLng(37.769337, -78.169968), 'WA': LatLng(47.400902, -121.490494),
    'WV': LatLng(38.491226, -80.954453), 'WI': LatLng(44.268543, -89.616508), 'WY': LatLng(42.755966, -107.302490),
  };

  bool satellite = true;
  bool radar = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = true;
  bool locating = false;
  bool viewportBusy = false;
  int frame = 0;
  int _viewportSerial = 0;
  double _zoom = 4;
  List<DateTime> _radarFrames = const [];
  Timer? _radarTimer;
  Timer? _refreshTimer;
  Timer? _viewportDebounce;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _states = const [];
  List<Map<String, dynamic>> _properties = const [];
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRadarFrames();
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && radar && playing && _radarFrames.length > 1) {
        setState(() => frame = frame >= _radarFrames.length - 1 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _loadRadarFrames();
        _loadOverview();
      }
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _refreshTimer?.cancel();
    _viewportDebounce?.cancel();
    super.dispose();
  }

  DateTime get _radarTime => _radarFrames.isEmpty ? DateTime.now().toUtc() : _radarFrames[frame.clamp(0, _radarFrames.length - 1)];
  bool get _showRadar => radar && _zoom <= _radarMaxHonestZoom;
  bool get _showStates => _zoom <= _stateLabelMaxZoom;

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try { return await Supabase.instance.client.rpc(rpc, params: params); } catch (_) { return const <String, dynamic>{}; }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['states','properties','opportunities','signals','items','rows','results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) => value is num ? value.round() : int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  double? _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
  String _short(dynamic value) { final n = _int(value); if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 1 : 2)}M'; if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K'; return '$n'; }

  String _wmsTime(DateTime value) {
    final u = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}Z';
  }

  Future<void> _loadRadarFrames() async {
    try {
      final uri = Uri.parse('https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/query').replace(queryParameters: const {'where':'1=1','outFields':'idp_validtime','returnGeometry':'false','orderByFields':'idp_validtime ASC','resultRecordCount':'300','f':'json'});
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return;
      final now = DateTime.now().toUtc();
      final buckets = <int, DateTime>{};
      for (final f in decoded['features'] as List) {
        if (f is! Map || f['attributes'] is! Map) continue;
        final raw = (f['attributes'] as Map)['idp_validtime'];
        final epoch = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
        if (epoch == null || epoch <= 0) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
        if (dt.isBefore(now.subtract(const Duration(hours: 5))) || dt.isAfter(now.add(const Duration(minutes: 15)))) continue;
        buckets[epoch ~/ 300000] = dt;
      }
      var frames = buckets.values.toList()..sort();
      if (frames.length > 18) frames = frames.sublist(frames.length - 18);
      if (frames.isEmpty || !mounted) return;
      setState(() { _radarFrames = frames; frame = frames.length - 1; });
    } catch (_) {}
  }

  Future<void> _loadOverview() async {
    final values = await Future.wait([
      _safe('bridgepoint_flutter_map_state_status_v838'),
      _safe('bridgepoint_flutter_intelligence_map_national_v346', {'p_model_key':'all','p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,'p_min_score':42,'p_opportunity_limit':120,'p_signal_limit':90}),
    ]);
    if (!mounted) return;
    setState(() {
      final s = values[0]; final i = values[1];
      _states = s is Map ? _rows(s['states']) : const [];
      _opportunities = i is Map ? _rows(i['opportunities']) : const [];
      _signals = i is Map ? _rows(i['signals']) : const [];
      _message = 'Zoom into a state for property detail. BridgePoint limits visible markers so the map stays readable.';
    });
  }

  void _scheduleViewport(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) { if (_properties.isNotEmpty && mounted) setState(() => _properties = const []); return; }
    _viewportDebounce = Timer(const Duration(milliseconds: 420), () => _loadViewport(camera.visibleBounds));
  }

  Future<void> _loadViewport(LatLngBounds bounds) async {
    final serial = ++_viewportSerial;
    if (mounted) setState(() => viewportBusy = true);
    final values = await Future.wait([
      _safe('bridgepoint_flutter_property_map_viewport_v838', {'p_min_lat':bounds.south,'p_max_lat':bounds.north,'p_min_lng':bounds.west,'p_max_lng':bounds.east,'p_limit':220}),
      _safe('bridgepoint_flutter_intelligence_map_national_v346', {'p_model_key':'all','p_min_lat':bounds.south,'p_max_lat':bounds.north,'p_min_lng':bounds.west,'p_max_lng':bounds.east,'p_min_score':42,'p_opportunity_limit':120,'p_signal_limit':80}),
    ]);
    if (!mounted || serial != _viewportSerial) return;
    final p = values[0]; final i = values[1];
    setState(() {
      _properties = p is Map ? _rows(p['properties']) : const [];
      _opportunities = i is Map ? _rows(i['opportunities']) : const [];
      _signals = i is Map ? _rows(i['signals']) : const [];
      viewportBusy = false;
    });
  }

  Future<void> _recenterToUser() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = point);
      _mapController.move(point, 12.8);
    } finally { if (mounted) setState(() => locating = false); }
  }

  Color _opportunityColor(Map<String, dynamic> row) {
    final priority = '${row['priority'] ?? ''}'.toLowerCase();
    final score = _double(row['score'] ?? row['opportunity_score']) ?? 0;
    if (priority.contains('critical') || score >= 85) return _red;
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  String _opportunityText(Map<String, dynamic> row) => '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();
  IconData _opportunityIcon(Map<String, dynamic> row) { final text = _opportunityText(row); if (text.contains('roof')) return Icons.roofing_rounded; if (text.contains('storm') || text.contains('hail') || text.contains('wind')) return Icons.thunderstorm_rounded; if (text.contains('fire')) return Icons.local_fire_department_rounded; if (text.contains('flood') || text.contains('water')) return Icons.water_damage_outlined; if (text.contains('solar')) return Icons.solar_power_rounded; if (text.contains('invest') || text.contains('sale') || text.contains('transfer')) return Icons.real_estate_agent_rounded; if (text.contains('develop')) return Icons.construction_rounded; if (text.contains('permit')) return Icons.fact_check_outlined; return Icons.location_searching_rounded; }

  List<Marker> _stateMarkers() => _states.map((row) { final code='${row['state_code'] ?? ''}'.trim().toUpperCase(); final center=_stateCenters[code]; if(center==null || _int(row['canonical_property_count'])<=0) return null; final color=_int(row['opportunity_count'])>0?_green:_int(row['signal_count'])>0?_cyan:_blue; return Marker(point:center,width:64,height:44,child:GestureDetector(onTap:()=>_mapController.move(center,7.7),child:Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:const Color(0xF2071321),borderRadius:BorderRadius.circular(12),border:Border.all(color:color,width:1.4)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(code,style:TextStyle(color:color,fontWeight:FontWeight.w900)),Text('${_short(row['canonical_property_count'])} properties',maxLines:1,style:const TextStyle(fontSize:7.3,fontWeight:FontWeight.w700))])))); }).whereType<Marker>().toList();
  List<Marker> _propertyMarkers() => _properties.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; return Marker(point:LatLng(lat,lng),width:22,height:22,child:Container(decoration:BoxDecoration(color:const Color(0xEA071321),borderRadius:BorderRadius.circular(7),border:Border.all(color:Colors.white,width:1)),child:const Icon(Icons.home_rounded,size:12,color:Colors.white))); }).whereType<Marker>().toList();
  List<Marker> _signalMarkers() => _signals.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; return Marker(point:LatLng(lat,lng),width:20,height:20,child:Container(decoration:BoxDecoration(color:const Color(0xF2071321),shape:BoxShape.circle,border:Border.all(color:_cyan,width:1.4)),child:const Icon(Icons.bolt_rounded,color:_cyan,size:12))); }).whereType<Marker>().toList();
  List<Marker> _opportunityMarkers() => _opportunities.map((row) { final lat=_double(row['latitude']); final lng=_double(row['longitude']); if(lat==null||lng==null)return null; final color=_opportunityColor(row); return Marker(point:LatLng(lat,lng),width:36,height:36,child:Container(decoration:BoxDecoration(color:const Color(0xF5071321),borderRadius:BorderRadius.circular(12),border:Border.all(color:color,width:2),boxShadow:[BoxShadow(color:color.withValues(alpha:.22),blurRadius:9)]),child:Icon(_opportunityIcon(row),color:color,size:19))); }).whereType<Marker>().toList();

  @override
  Widget build(BuildContext context) {
    final markers=<Marker>[if(_showStates)..._stateMarkers(),if(properties)..._propertyMarkers(),if(signals)..._signalMarkers(),if(opportunities)..._opportunityMarkers()];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(spacing:7,runSpacing:7,children:[
        FilterChip(selected:satellite,label:const Text('Satellite'),avatar:const Icon(Icons.satellite_alt_rounded,size:16),onSelected:(v)=>setState(()=>satellite=v)),
        FilterChip(selected:radar,label:const Text('Radar'),avatar:const Icon(Icons.radar_rounded,size:16),onSelected:(v)=>setState(()=>radar=v)),
        FilterChip(selected:properties,label:const Text('Properties'),avatar:const Icon(Icons.home_rounded,size:16),onSelected:(v)=>setState(()=>properties=v)),
        FilterChip(selected:opportunities,label:const Text('Opportunities'),avatar:const Icon(Icons.location_searching_rounded,size:16),onSelected:(v)=>setState(()=>opportunities=v)),
        FilterChip(selected:signals,label:const Text('Signals'),avatar:const Icon(Icons.bolt_rounded,size:16),onSelected:(v)=>setState(()=>signals=v)),
        ActionChip(avatar:Icon(playing?Icons.pause_rounded:Icons.play_arrow_rounded,size:16),label:Text(playing?'Pause weather':'Play weather'),onPressed:()=>setState(()=>playing=!playing)),
        ActionChip(avatar:const Icon(Icons.my_location_rounded,size:16),label:Text(locating?'Locating…':'My location'),onPressed:locating?null:_recenterToUser),
      ]),
      if(_message!=null)...[const SizedBox(height:7),Text(_message!,style:const TextStyle(color:_muted,fontSize:11.2))],
      const SizedBox(height:10),
      SizedBox(height:720,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:Stack(children:[
        FlutterMap(mapController:_mapController,options:MapOptions(initialCenter:const LatLng(39.4,-98.3),initialZoom:4,minZoom:3,maxZoom:18,onPositionChanged:(camera,hasGesture){_zoom=camera.zoom;if(hasGesture)_scheduleViewport(camera);if(mounted)setState((){});}),children:[
          TileLayer(urlTemplate:satellite?'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}':'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.bridgepoint.data_studio',maxNativeZoom:19),
          if(satellite) TileLayer(urlTemplate:'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',userAgentPackageName:'com.bridgepoint.data_studio'),
          if(_showRadar) TileLayer(key:ValueKey(_radarFrames.isEmpty?'bp-radar-latest-v2':'bp-radar-${_radarTime.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:_radarFrames.isEmpty?const <String,String>{}:{'TIME':_wmsTime(_radarTime)}),maxNativeZoom:10,userAgentPackageName:'com.bridgepoint.data_studio'),
          if(markers.isNotEmpty) MarkerLayer(markers:markers),
          if(_userLocation!=null) MarkerLayer(markers:[Marker(point:_userLocation!,width:28,height:28,child:Container(decoration:BoxDecoration(color:_green.withValues(alpha:.22),shape:BoxShape.circle,border:Border.all(color:_green,width:2)),child:const Icon(Icons.person_pin_circle_rounded,color:_green,size:17)))]),
          RichAttributionWidget(attributions:const [TextSourceAttribution('NOAA / NWS MRMS'),TextSourceAttribution('Esri / OpenStreetMap')]),
        ]),
        Positioned(left:10,top:10,child:Card(color:const Color(0xEE071321),child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:const [Text('BRIDGEPOINT MAP',style:TextStyle(fontSize:12.5,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('🏠 Property  •  ◈ Opportunity  •  ⚡ Signal',style:TextStyle(fontSize:9.5))])))),
        if(radar) Positioned(left:12,right:12,bottom:12,child:Card(color:const Color(0xF2071321),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),child:Row(children:[const Icon(Icons.radar_rounded,color:_cyan,size:18),const SizedBox(width:7),Text(_radarFrames.length>1?'NOAA • ${_radarFrames.length} frames':'NOAA • latest',style:const TextStyle(color:_cyan,fontSize:11.5,fontWeight:FontWeight.w900)),const SizedBox(width:8),Expanded(child:_radarFrames.length>1?Slider(value:frame.clamp(0,_radarFrames.length-1).toDouble(),min:0,max:(_radarFrames.length-1).toDouble(),divisions:_radarFrames.length-1,onChanged:(v)=>setState((){playing=false;frame=v.round();})):const Text('Latest reflectivity',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:10.5))),IconButton(onPressed:()=>setState(()=>playing=!playing),icon:Icon(playing?Icons.pause_rounded:Icons.play_arrow_rounded))])))),
      ]))),
      const SizedBox(height:9),
      const Text('NOAA/NWS MRMS reflectivity is regional weather context. A blank radar area can mean no measurable reflectivity in that view; BridgePoint does not treat radar pixels as proof of property damage.',style:TextStyle(color:_muted,fontSize:11.2,height:1.4)),
    ]);
  }
}
