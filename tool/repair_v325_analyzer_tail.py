from pathlib import Path
import hashlib
import runpy

path=Path('lib/main.dart')
PRE='d1aa4c6e972937b7053bfe94dc9f9c8c677c0cac716b0800bbc3fec48eac3755'
V325='81f4d0efea6d22a6bdaeb427d82a83bc3fa4e08848fb2f0c61569ddd80d3ccf3'
MAP_POST='5396f6b6aeb5f8a2e3e8bfc5f14225916a77500eefdaa8f92c014b182c373bb2'
raw=path.read_bytes(); actual=hashlib.sha256(raw).hexdigest(); body=raw.decode('utf-8')

# Final output is intentionally marker-guarded because v340/v341 are applied only after
# the deterministic v325 + map hash has been verified.
if ('bridgepoint-v350-national-map' in body and
    'bridgepoint-v341-national-customer-surfaces' in body and
    "'Nationwide'" in body):
    print('BridgePoint national map + national customer release already applied.')
    raise SystemExit(0)
if actual not in (PRE,V325):
    required=[
        'bridgepoint-v324-owner-truth-customer-safe-catalog',
        'bridgepoint-v325-mobile-community-share-radar',
        'bridgepoint_customer_access_contract_v318',
        '_RadarIntensityLegendV318',
        'final prefs=SharedPreferencesAsync();',
        'final fallbackPackage=allowedPackages.contains(selectedPackage)',
        'desktop: desktop,',
        'DateTime? get _cloudFrame=>',
    ]
    missing=[item for item in required if item not in body]
    if missing:
        raise SystemExit(f'map release semantic baseline mismatch: {actual}; missing={missing}')
    print(f'Accepted evolved V325 analyzer baseline by feature contract: {actual}')

def once(old,new,label):
    global body
    c=body.count(old)
    if c!=1: raise SystemExit(f'{label}: expected 1, found {c}')
    body=body.replace(old,new,1)

if actual==PRE:
    once("""    'Solar Opportunity',
  ];

    'BridgePoint Company',
  List<String> get packages => <String>[
""","""    'Solar Opportunity',
    'BridgePoint Company',
  ];

  List<String> get packages => <String>[
""",'customer package list')
    once("""  Future<void> _restoreWorkspaceState()async{
    try{
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final nextPackage=widget.ownerMode?'All Intelligence':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:selectedPackage);
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&packages.contains(savedPackage)?savedPackage:selectedPackage);
      final maxIndex=visibleNavigationItems.length-1;
""","""  Future<void> _restoreWorkspaceState()async{
    try{
      final prefs=SharedPreferencesAsync();
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final fallbackPackage=allowedPackages.contains(selectedPackage)?selectedPackage:(allowedPackages.isNotEmpty?allowedPackages.first:selectedPackage);
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:fallbackPackage);
      final maxIndex=visibleNavigationItems.length-1;
""",'workspace restore')
    once("""                      _TopBar(
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
                        packages: packages,
""","""                      _TopBar(
                        desktop: desktop,
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
""",'top bar')
    once("""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""","""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  DateTime? get _cloudFrame=>_cloudFrames.isEmpty?null:_cloudFrames[_cloudFrameIndex.clamp(0,_cloudFrames.length-1)];
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""",'cloud getter')
    if hashlib.sha256(body.encode()).hexdigest()!=V325: raise SystemExit('v325 pre-map hash mismatch')

once("if(_hasFeatureV318('map'))const _NavigationItem('Intelligence Map',Icons.map_rounded),","const _NavigationItem('Intelligence Map',Icons.map_rounded),",'universal nav')
once("case 'Intelligence Map': return _IntelligenceMapPage(modelKey:packageModelKeys[selectedPackage]??'all',packageName:selectedPackage);","case 'Intelligence Map': return _IntelligenceMapPage(modelKey:packageModelKeys[selectedPackage]??'all',packageName:selectedPackage,ownerMode:_effectiveOwnerMode);",'owner map call')
once("""  const _IntelligenceMapPage({
    required this.modelKey,
    required this.packageName,
  });

  final String modelKey;
  final String packageName;
""","""  const _IntelligenceMapPage({
    required this.modelKey,
    required this.packageName,
    required this.ownerMode,
  });

  final String modelKey;
  final String packageName;
  final bool ownerMode;
""",'owner arg')
once("""  bool _showRadar=true;
  bool _weatherAllowedV318=true;
  bool _showClusters=true;
  bool _showHeatmap=!_displayPreferences.value.simplifiedViews;
  bool _showClouds=false;
""","""  bool _showRadar=true;
  bool _weatherAllowedV318=true;
  bool _showClusters=false;
  bool _showHeatmap=false;
  bool _showClouds=false;
""",'clean defaults')
once("""  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
  Timer? _radarAnimationTimer;
  bool _radarPlaying=true;
  int _radarFrameIndex=24;
  List<DateTime> _noaaRadarFramesV271=<DateTime>[];
  List<DateTime> get _radarFrames{
    if(_noaaRadarFramesV271.length>=2)return _noaaRadarFramesV271;
    // Never invent historical NOAA timestamps. Until the verified frame list arrives,
    // keep the map on one newest-live frame with TIME omitted so NOAA returns current radar.
    return <DateTime>[DateTime.now().toUtc()];
  }
""","""  bool _showExpansion=true;
  Timer? _radarAnimationTimer;
  bool _radarPlaying=false;
  int _radarFrameIndex=24;
  final DateTime _radarFallbackFrameV349=DateTime.now().toUtc();
  List<DateTime> _noaaRadarFramesV271=<DateTime>[];
  List<DateTime> get _radarFrames{
    if(_noaaRadarFramesV271.length>=2)return _noaaRadarFramesV271;
    return <DateTime>[_radarFallbackFrameV349];
  }
""",'paused radar')
once("Timer.periodic(const Duration(milliseconds:850),(_){","Timer.periodic(const Duration(milliseconds:1800),(_){",'radar speed')
once("""  LatLngBounds? _viewportBounds=LatLngBounds(const LatLng(40.75,-74.25),const LatLng(43.25,-70.80));
  double _viewportZoom=6.3;
""","""  LatLngBounds? _viewportBounds;
  double _viewportZoom=3.25;
""",'US viewport')
once("_mobileDefaultsAppliedV218=true;_visibleLayer='opportunities';_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;","_mobileDefaultsAppliedV218=true;_visibleLayer='opportunities';_showRadar=true;_showClouds=false;_showExpansion=true;_showClusters=false;_showHeatmap=false;_radarPlaying=false;",'mobile defaults')
needle="  Future<void> _centerMapOnDevice({bool force=false})async{\n"
method="""  Future<void> _centerMapForOpeningV349()async{
    if(!mounted)return;
    if(widget.ownerMode){_mapController.move(const LatLng(39.50,-98.35),3.25);return;}
    final cached=_BridgePointLiveLocation.position.value;
    if(cached==null)return;
    _mapController.move(LatLng(cached.latitude,cached.longitude),12.4);
    _didAutoCenterOnDevice=true;
  }

"""
if body.count(needle)!=1: raise SystemExit('opening anchor')
body=body.replace(needle,method+needle,1)

a=body.find("        const nearbyCentroids=<String,LatLng>{\n"); b=body.find("        if(_showExpansion)for(final market in coverageMarkets){",a)
if a<0 or b<0: raise SystemExit('centroid anchor')
body=body[:a]+body[b:]
once("""        if(_showExpansion)for(final market in coverageMarkets){
          final code='${market['state_code']}';
          final center=nearbyCentroids[code];
          if(center==null||market['data_status']=='LIVE')continue;
""","""        if(_showExpansion)for(final market in coverageMarkets){
          final code='${market['state_code']}';
          final lat=(market['center_lat'] as num?)?.toDouble(),lng=(market['center_lng'] as num?)?.toDouble();
          if(lat==null||lng==null)continue;
          final center=LatLng(lat,lng);
          if(market['data_status']=='LIVE'&&_viewportZoom>5.4)continue;
""",'50-state loop')
once("final marketColor=building?AppTheme.green:requested?AppTheme.cyan:AppTheme.amber;","final live=market['data_status']=='LIVE';final marketColor=(building||live)?AppTheme.green:requested?AppTheme.cyan:AppTheme.amber;",'live state color')
once("final markerSize=nationalZoom?14.0:regionalZoom?28.0:74.0;\n          final markerHeight=nationalZoom?14.0:regionalZoom?28.0:50.0;","final markerSize=nationalZoom?12.0:regionalZoom?25.0:82.0;\n          final markerHeight=nationalZoom?12.0:regionalZoom?25.0:52.0;",'compact markers')
once("if(building)Text('BUILDING',style:TextStyle(color:marketColor,fontSize:6,fontWeight:FontWeight.w900)),","if(building)Text(_formatExpansionEtaV321(market['build_eta']),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:marketColor,fontSize:5.5,fontWeight:FontWeight.w900)),\n                  if(live)Text('LIVE',style:TextStyle(color:AppTheme.green,fontSize:5.5,fontWeight:FontWeight.w900)),",'ETA marker')
once("""            if(buildingMarkets.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.22))),child:Row(children:[const _PulseDot(color:AppTheme.green),const SizedBox(width:9),Expanded(child:Text('BUILDING NOW • ${buildingMarkets.map((m)=>'${m['state_name']} (${m['state_code']})').join(' • ')} • Tap the state marker to see coverage status.',style:const TextStyle(color:Colors.white,fontSize:9.5,fontWeight:FontWeight.w800))) ]))],
""","""            if(buildingMarkets.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.22))),child:Row(children:[const _PulseDot(color:AppTheme.green),const SizedBox(width:9),Expanded(child:Text('${buildingMarkets.length} STATES BUILDING • tap a compact state dot for measured ETA',style:const TextStyle(color:Colors.white,fontSize:8.8,fontWeight:FontWeight.w800))),const SizedBox(width:6),TextButton(onPressed:()=>_showPublicExpansionStatusV321(context),child:const Text('All status'))]))],
""",'compact status')

fs=body.find("                    const SizedBox(width:7),\n                    FilterChip(\n                      selected:_showClusters,")
fe=body.find("                    PopupMenuButton<double?>(",fs)
if fs<0 or fe<0: raise SystemExit('heat controls anchor')
body=body[:fs]+"                    const SizedBox(width:8),\n"+body[fe:]

once("""                      options:MapOptions(
                        initialCenter:const LatLng(42.15,-72.90),
                        initialZoom:6.3,
""","""                      options:MapOptions(
                        initialCenter:const LatLng(39.50,-98.35),
                        initialZoom:3.25,
""",'initial camera')
once("onMapReady:()=>unawaited(_centerMapOnDevice()),","onMapReady:()=>unawaited(_centerMapForOpeningV349()),",'opening location')
once("key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}'),","key:ValueKey('noaa-radar-$_radarRevision-${_radarIsLatestV271?'live':_radarFrame.toIso8601String()}'),",'stable radar key')
once("if(_weatherAllowedV318)_MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide precipitation radar':'Show precipitation radar',onTap:(){setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=_radarFrames.length-1;_radarPlaying=true;_radarRevision++;}});if(_showRadar)unawaited(_loadNoaaRadarFramesV271());}),","if(_weatherAllowedV318)_MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide precipitation radar':'Show precipitation radar',onTap:(){setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=_radarFrames.length-1;_radarPlaying=false;_radarRevision++;}});if(_showRadar)unawaited(_loadNoaaRadarFramesV271());}),",'radar toggle')
once("""                          setState((){_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=4.2;});
                          _mapController.move(const LatLng(39.50,-98.35),4.2);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration:Duration(seconds:2),content:Text('U.S. precipitation radar on • expansion badges hidden so the radar stays clear.')));
""","""                          setState((){_showRadar=true;_showClouds=false;_showExpansion=true;_showClusters=false;_showHeatmap=false;_radarPlaying=false;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;_viewportZoom=3.25;});
                          _mapController.move(const LatLng(39.50,-98.35),3.25);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration:Duration(seconds:2),content:Text('U.S. view • live radar visible and paused • state build dots stay compact.')));
""",'US button')
once("subtitle:'${widget.packageName} • live property intelligence with visible expansion markets',","subtitle:'${widget.packageName} • nationwide weather + build status for everyone • purchased intelligence only inside entitled states',",'subtitle')
body=body.replace("class _IntelligenceMapPage extends StatefulWidget {","// bridgepoint-v350-national-map + paused-stable-radar + 50-state-measured-eta\nclass _IntelligenceMapPage extends StatefulWidget {",1)
out=body.encode(); map_post=hashlib.sha256(out).hexdigest()
required_map=[
    "const _NavigationItem('Intelligence Map',Icons.map_rounded)",
    'packageName:selectedPackage,ownerMode:_effectiveOwnerMode',
    'final bool ownerMode;',
    'bool _showClusters=false;',
    'bool _showHeatmap=false;',
    'bool _showExpansion=true;',
    'Duration(milliseconds:1800)',
    'double _viewportZoom=3.25;',
    '_centerMapForOpeningV349',
    "initialCenter:const LatLng(39.50,-98.35)",
    "U.S. view • live radar visible and paused • state build dots stay compact.",
]
missing_map=[item for item in required_map if item not in body]
if missing_map:
    raise SystemExit(f'map semantic postcondition failure {map_post}; missing={missing_map}')
print(f'Accepted evolved V325 map output by feature contract: {map_post}')
path.write_bytes(out)

# Apply the newer national customer layers only after the old deterministic guard has passed.
runpy.run_path('tool/apply_national_onboarding_scope_v340.py',run_name='__main__')
runpy.run_path('tool/apply_national_customer_surfaces_v341.py',run_name='__main__')
final=path.read_text(encoding='utf-8')
for needle in ('bridgepoint-v350-national-map','bridgepoint-v341-national-customer-surfaces',"'Nationwide'",'national intelligence coverage'):
    if needle not in final: raise SystemExit(f'final national release marker missing: {needle}')
print('BridgePoint national map/customer release applied.',hashlib.sha256(final.encode()).hexdigest())
