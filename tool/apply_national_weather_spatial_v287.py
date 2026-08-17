from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v287-national-weather-spatial-background'
if marker in body:
    print('v287 already applied')
    raise SystemExit(0)

# Workspace scroll lock used by embedded 3D map while fingers are physically down.
anchor="const String _bridgePointLiveUrl = 'https://bridgepointintelligence.online/';\n"
if anchor not in body:
    m=re.search(r"const\s+_bridgePointLiveUrl\s*=\s*'https://bridgepointintelligence\.online/';\n",body)
    if not m: raise SystemExit('v287 live url anchor missing')
    anchor=m.group(0)
body=body.replace(anchor,anchor+"final ValueNotifier<bool> _bridgePointMapTouchLockV287=ValueNotifier<bool>(false);\n",1)

old_scroll="""                          child: SingleChildScrollView(
                            controller: _workspaceScrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              desktop ? 28 : 16,
                              8,
                              desktop ? 34 : 16,
                              52,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                KeyedSubtree(
                                  key: ValueKey(_liveRefreshTick),
                                  child: _buildSelectedPage(),
                                ),
                                const SizedBox(height: 30),
                                const _BridgePointLegalFooter(),
                              ],
                            ),
                          ),
"""
new_scroll="""                          child: ValueListenableBuilder<bool>(
                            valueListenable:_bridgePointMapTouchLockV287,
                            builder:(context,mapLocked,_)=>SingleChildScrollView(
                              controller: _workspaceScrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: mapLocked?const NeverScrollableScrollPhysics():const ClampingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                desktop ? 28 : 16,
                                8,
                                desktop ? 34 : 16,
                                52,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KeyedSubtree(
                                    key: ValueKey(_liveRefreshTick),
                                    child: _buildSelectedPage(),
                                  ),
                                  const SizedBox(height: 30),
                                  const _BridgePointLegalFooter(),
                                ],
                              ),
                            ),
                          ),
"""
if body.count(old_scroll)!=1: raise SystemExit(f'v287 workspace scroll anchor {body.count(old_scroll)}')
body=body.replace(old_scroll,new_scroll,1)

# Strong pointer capture plus national weather fields for Community 3D.
old_fields="""  int requestSerial=0;

  @override void initState(){super.initState();weatherMotion=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));_displayPreferences.addListener(_syncWeatherMotion);}
"""
new_fields="""  int requestSerial=0;
  int _activeMapPointersV287=0;
  Timer? _nationalWeatherTimerV287;
  List<DateTime> _nationalRadarFramesV287=<DateTime>[];
  List<DateTime> _nationalCloudFramesV287=<DateTime>[];
  int _nationalRadarIndexV287=0,_nationalCloudIndexV287=0,_nationalWeatherTickV287=0;
  final List<String> _nationalRadarLayersV287=<String>[];
  final List<String> _nationalCloudLayersV287=<String>[];

  @override void initState(){super.initState();weatherMotion=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));_displayPreferences.addListener(_syncWeatherMotion);}
"""
if body.count(old_fields)!=1: raise SystemExit(f'v287 3D fields anchor {body.count(old_fields)}')
body=body.replace(old_fields,new_fields,1)
old_dispose="@override void dispose(){debounce?.cancel();_displayPreferences.removeListener(_syncWeatherMotion);weatherMotion.dispose();super.dispose();}"
new_dispose="@override void dispose(){debounce?.cancel();_nationalWeatherTimerV287?.cancel();_bridgePointMapTouchLockV287.value=false;_displayPreferences.removeListener(_syncWeatherMotion);weatherMotion.dispose();super.dispose();}"
if body.count(old_dispose)!=1: raise SystemExit('v287 3D dispose anchor')
body=body.replace(old_dispose,new_dispose,1)

style_anchor="""      await c.addCircleLayer('bp-community-clusters','bp-community-clusters-glow',
        const ml.CircleLayerProperties(
          circleRadius:['interpolate',['linear'],['get','strength'],0,10,100,27],
          circleColor:['match',['get','state'],'PEAK','#FF6677','EMERGING','#FFC857','RECOVERY','#4F7CFF','HISTORICAL','#718096','#38D49A'],
          circleOpacity:.22,circleBlur:.55,circleStrokeWidth:2,
          circleStrokeColor:['match',['get','state'],'PEAK','#FF6677','EMERGING','#FFC857','RECOVERY','#4F7CFF','HISTORICAL','#718096','#38D49A'],
          circleStrokeOpacity:.88,
        ),minzoom:5);
      if(mounted)setState(()=>styleReady=true);
"""
if body.count(style_anchor)!=1: raise SystemExit('v287 3D style anchor')
body=body.replace(style_anchor,style_anchor.replace("      if(mounted)setState(()=>styleReady=true);\n","      if(mounted)setState(()=>styleReady=true);\n      unawaited(_installNationalWeatherV287());\n"),1)

refresh_anchor="  Future<void> _refreshWeatherForCamera({bool force=false})async{\n"
methods=r'''  String _radarWmsTileV287(DateTime frame){
    final time=frame.toUtc().millisecondsSinceEpoch;
    return 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=0&STYLES=&FORMAT=image/png&TRANSPARENT=true&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&BBOX={bbox-epsg-3857}&TIME=$time';
  }
  String _cloudWmsTileV287(DateTime frame){
    final time=Uri.encodeComponent(frame.toUtc().toIso8601String());
    return 'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=global_visible_imagery_mosaic&STYLES=&FORMAT=image/png&TRANSPARENT=true&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&BBOX={bbox-epsg-3857}&TIME=$time';
  }
  Future<void> _installNationalWeatherV287()async{
    final c=controller;if(c==null||!styleReady)return;
    try{
      final result=await Future.wait([
        Supabase.instance.client.functions.invoke('bridgepoint-noaa-radar-frames-v271',body:const {}),
        Supabase.instance.client.functions.invoke('bridgepoint-noaa-cloud-frames-v215',body:const {}),
      ]);
      final radarPayload=_edgeFunctionPayload(result[0].data),cloudPayload=_edgeFunctionPayload(result[1].data);
      final radarRaw=radarPayload['frames_iso'];final cloudRaw=cloudPayload['frames'];
      var radar=radarRaw is List?radarRaw.map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];
      var cloud=cloudRaw is List?cloudRaw.map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];
      if(radar.length>4)radar=radar.sublist(radar.length-4);
      if(cloud.length>2)cloud=cloud.sublist(cloud.length-2);
      _nationalRadarFramesV287=radar;_nationalCloudFramesV287=cloud;
      for(var i=0;i<cloud.length;i++){
        final source='bp-us-cloud-src-v287-$i',layer='bp-us-cloud-v287-$i';
        await c.addSource(source,ml.RasterSourceProperties(tiles:[_cloudWmsTileV287(cloud[i])],tileSize:256,minzoom:2,maxzoom:8,attribution:'NOAA nowCOAST satellite'));
        await c.addRasterLayer(source,layer,ml.RasterLayerProperties(rasterOpacity:i==cloud.length-1 ? .20 : 0,rasterFadeDuration:900,rasterResampling:'linear'),minzoom:2,maxzoom:8.7);
        _nationalCloudLayersV287.add(layer);
      }
      for(var i=0;i<radar.length;i++){
        final source='bp-us-radar-src-v287-$i',layer='bp-us-radar-v287-$i';
        await c.addSource(source,ml.RasterSourceProperties(tiles:[_radarWmsTileV287(radar[i])],tileSize:256,minzoom:2,maxzoom:12,attribution:'NOAA/NWS radar'));
        await c.addRasterLayer(source,layer,ml.RasterLayerProperties(rasterOpacity:i==radar.length-1 ? .62 : 0,rasterFadeDuration:650,rasterResampling:'linear'),minzoom:2,maxzoom:20);
        _nationalRadarLayersV287.add(layer);
      }
      _nationalRadarIndexV287=radar.isEmpty?0:radar.length-1;_nationalCloudIndexV287=cloud.isEmpty?0:cloud.length-1;
      _nationalWeatherTimerV287?.cancel();
      _nationalWeatherTimerV287=Timer.periodic(const Duration(milliseconds:1550),(_)=>unawaited(_advanceNationalWeatherV287()));
    }catch(_){/* Real weather is additive; the 3D property map always stays usable. */}
  }
  Future<void> _advanceNationalWeatherV287()async{
    final c=controller;if(c==null||!styleReady)return;
    _nationalWeatherTickV287++;
    if(_nationalRadarLayersV287.isNotEmpty){
      _nationalRadarIndexV287=(_nationalRadarIndexV287+1)%_nationalRadarLayersV287.length;
      for(var i=0;i<_nationalRadarLayersV287.length;i++){try{await c.setLayerVisibility(_nationalRadarLayersV287[i],i==_nationalRadarIndexV287);}catch(_){}}
    }
    if(_nationalWeatherTickV287.isEven&&_nationalCloudLayersV287.isNotEmpty){
      _nationalCloudIndexV287=(_nationalCloudIndexV287+1)%_nationalCloudLayersV287.length;
      for(var i=0;i<_nationalCloudLayersV287.length;i++){try{await c.setLayerVisibility(_nationalCloudLayersV287[i],i==_nationalCloudIndexV287);}catch(_){}}
    }
  }
  void _mapPointerDownV287(PointerDownEvent _){_activeMapPointersV287++;_bridgePointMapTouchLockV287.value=true;}
  void _mapPointerUpV287(PointerEvent _){_activeMapPointersV287=(_activeMapPointersV287-1).clamp(0,10).toInt();if(_activeMapPointersV287==0)_bridgePointMapTouchLockV287.value=false;}

'''
if body.count(refresh_anchor)!=1: raise SystemExit('v287 weather method anchor')
body=body.replace(refresh_anchor,methods+refresh_anchor,1)

old_map="""        SizedBox(height:compact?390:510,child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
          gestureRecognizers:<Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(()=>EagerGestureRecognizer()),
          },
"""
new_map="""        SizedBox(height:compact?390:510,child:Listener(
          behavior:HitTestBehavior.opaque,
          onPointerDown:_mapPointerDownV287,onPointerUp:_mapPointerUpV287,onPointerCancel:_mapPointerUpV287,
          child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
          gestureRecognizers:<Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(()=>EagerGestureRecognizer()),
          },
"""
if body.count(old_map)!=1: raise SystemExit('v287 3D map opening anchor')
body=body.replace(old_map,new_map,1)
old_close="""          onCameraIdle:_queueRefresh,
        ))),
        if(weatherEffect!='CLEAR')"""
new_close="""          onCameraIdle:_queueRefresh,
        )))),
        if(weatherEffect!='CLEAR')"""
if body.count(old_close)!=1: raise SystemExit('v287 3D map closing anchor')
body=body.replace(old_close,new_close,1)

# Re-enable real national cloud motion on Intelligence Map and make it default.
body=body.replace("bool _showClouds=false;","bool _showClouds=true;",1)
body=body.replace("_visibleLayer='opportunities';_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;","_visibleLayer='opportunities';_showRadar=true;_showClouds=true;_showExpansion=false;_radarPlaying=true;",1)
init_anchor="""    _startRadarLoop();
    unawaited(_loadNoaaRadarFramesV271());
    unawaited(_checkNoaaHealth(silent:true));
"""
init_new="""    _startRadarLoop();
    unawaited(_loadNoaaRadarFramesV271());
    unawaited(_loadCloudFrames());
    unawaited(_checkNoaaHealth(silent:true));
"""
if body.count(init_anchor)!=1: raise SystemExit('v287 intelligence init anchor')
body=body.replace(init_anchor,init_new,1)
radar_layer="""                          if(_showRadar)TileLayer(
                            key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}'),
                            wmsOptions:WMSTileLayerOptions(
                              baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$_radarRevision&',
                              layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',
                              otherParameters:_radarTimeParametersV271,
                            ),
                            maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
"""
cloud_then_radar="""                          if(_showClouds&&_cloudFrame!=null)Opacity(opacity:.20,child:TileLayer(
                            key:ValueKey('noaa-cloud-v287-${_cloudFrame!.millisecondsSinceEpoch}'),
                            wmsOptions:WMSTileLayerOptions(
                              baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',
                              layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',
                              otherParameters:{'TIME':_cloudFrame!.toUtc().toIso8601String()},
                            ),
                            maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,
                            tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:700),startOpacity:.20,reloadStartOpacity:.82),
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          )),
"""+radar_layer
if body.count(radar_layer)!=1: raise SystemExit(f'v287 intelligence radar anchor {body.count(radar_layer)}')
body=body.replace(radar_layer,cloud_then_radar,1)

# Shared nationwide live weather layer for every simpler FlutterMap.
helper_anchor="class _MapLegendDot extends StatelessWidget {\n"
helper=r'''class _BridgePointNationwideWeatherV287 extends StatefulWidget{
  const _BridgePointNationwideWeatherV287({this.clouds=true,this.radar=true});
  final bool clouds,radar;
  @override State<_BridgePointNationwideWeatherV287> createState()=>_BridgePointNationwideWeatherV287State();
}
class _BridgePointNationwideWeatherV287State extends State<_BridgePointNationwideWeatherV287>{
  List<DateTime> radarFrames=<DateTime>[],cloudFrames=<DateTime>[];
  int radarIndex=0,cloudIndex=0,tick=0;Timer? timer,refresh;
  DateTime? get radarFrame=>radarFrames.isEmpty?null:radarFrames[radarIndex.clamp(0,radarFrames.length-1)];
  DateTime? get cloudFrame=>cloudFrames.isEmpty?null:cloudFrames[cloudIndex.clamp(0,cloudFrames.length-1)];
  @override void initState(){super.initState();unawaited(load());timer=Timer.periodic(const Duration(milliseconds:1500),(_){if(!mounted||_displayPreferences.value.reducedMotion)return;setState((){tick++;if(radarFrames.length>1)radarIndex=(radarIndex+1)%radarFrames.length;if(tick.isEven&&cloudFrames.length>1)cloudIndex=(cloudIndex+1)%cloudFrames.length;});});refresh=Timer.periodic(const Duration(minutes:4),(_)=>unawaited(load()));}
  @override void dispose(){timer?.cancel();refresh?.cancel();super.dispose();}
  Future<void> load()async{try{final result=await Future.wait([Supabase.instance.client.functions.invoke('bridgepoint-noaa-radar-frames-v271',body:const {}),Supabase.instance.client.functions.invoke('bridgepoint-noaa-cloud-frames-v215',body:const {})]);final rp=_edgeFunctionPayload(result[0].data),cp=_edgeFunctionPayload(result[1].data);var r=rp['frames_iso'] is List?(rp['frames_iso'] as List).map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];var c=cp['frames'] is List?(cp['frames'] as List).map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];if(r.length>10)r=r.sublist(r.length-10);if(c.length>6)c=c.sublist(c.length-6);if(mounted)setState((){radarFrames=r;cloudFrames=c;radarIndex=r.isEmpty?0:r.length-1;cloudIndex=c.isEmpty?0:c.length-1;});}catch(_){}}
  @override Widget build(BuildContext context){final r=radarFrame,c=cloudFrame;return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
    if(widget.clouds&&c!=null)Opacity(opacity:.20,child:TileLayer(key:ValueKey('bp-us-cloud-$cloudIndex-${c.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':c.toUtc().toIso8601String()}),maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:750),startOpacity:.15,reloadStartOpacity:.85),userAgentPackageName:'com.bridgepoint.data_studio')),
    if(widget.radar&&r!=null)Opacity(opacity:.66,child:TileLayer(key:ValueKey('bp-us-radar-$radarIndex-${r.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':'${r.toUtc().millisecondsSinceEpoch}'}),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.22,reloadStartOpacity:.90),userAgentPackageName:'com.bridgepoint.data_studio')),
  ]));}
}

'''
if body.count(helper_anchor)!=1: raise SystemExit('v287 helper anchor')
body=body.replace(helper_anchor,helper+helper_anchor,1)

community_base="TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),if(_displayPreferences.value.mapBaseStyle=='satellite')"
if body.count(community_base)!=1: raise SystemExit(f'v287 community map base {body.count(community_base)}')
body=body.replace(community_base,"TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),const _BridgePointNationwideWeatherV287(),if(_displayPreferences.value.mapBaseStyle=='satellite')",1)
field_base="""            TileLayer(urlTemplate:_bridgePointBaseMapUrl(),userAgentPackageName:'com.bridgepointintelligence.app'),
                          if(_displayPreferences.value.mapBaseStyle=='satellite')
"""
field_new="""            TileLayer(urlTemplate:_bridgePointBaseMapUrl(),userAgentPackageName:'com.bridgepointintelligence.app'),
            const _BridgePointNationwideWeatherV287(),
                          if(_displayPreferences.value.mapBaseStyle=='satellite')
"""
if body.count(field_base)!=1: raise SystemExit(f'v287 field map base {body.count(field_base)}')
body=body.replace(field_base,field_new,1)

preview_base="""                                    TileLayer(
                                      urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:'com.bridgepoint.data_studio',
                                    ),
                                    if(_showRadar)TileLayer("""
preview_new="""                                    TileLayer(
                                      urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:'com.bridgepoint.data_studio',
                                    ),
                                    const _BridgePointNationwideWeatherV287(radar:false),
                                    if(_showRadar)TileLayer("""
if body.count(preview_base)!=1: raise SystemExit(f'v287 preview map {body.count(preview_base)}')
body=body.replace(preview_base,preview_new,1)

dialog_base="""              TileLayer(
                urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:'com.bridgepoint.data_studio',
              ),
              TileLayer(
                key:ValueKey('noaa-radar-dialog-$revision'),"""
dialog_new="""              TileLayer(
                urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:'com.bridgepoint.data_studio',
              ),
              const _BridgePointNationwideWeatherV287(radar:false),
              TileLayer(
                key:ValueKey('noaa-radar-dialog-$revision'),"""
if body.count(dialog_base)!=1: raise SystemExit(f'v287 dialog map {body.count(dialog_base)}')
body=body.replace(dialog_base,dialog_new,1)

weather_base="""            TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),
            TileLayer(key:ValueKey('weather-center-radar-$revision-${frame.millisecondsSinceEpoch}')"""
weather_new="""            TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),
            const _BridgePointNationwideWeatherV287(radar:false),
            TileLayer(key:ValueKey('weather-center-radar-$revision-${frame.millisecondsSinceEpoch}')"""
if body.count(weather_base)!=1: raise SystemExit(f'v287 Weather Center map {body.count(weather_base)}')
body=body.replace(weather_base,weather_new,1)

# Replace the v278 floating-line screensaver look with a deep geospatial intelligence environment.
old_ref="CustomPaint(painter:_BridgePointAtmospherePainterV278(t:controller.value,accent:widget.accent))"
new_ref="CustomPaint(painter:_BridgePointSpatialAtmospherePainterV287(t:controller.value,accent:widget.accent))"
if body.count(old_ref)!=1: raise SystemExit('v287 background painter ref')
body=body.replace(old_ref,new_ref,1)
body=body.replace("imageOpacity:daily ? .24 : map ? .22 : .16","imageOpacity:daily ? .12 : map ? .10 : .08",1)

painter_anchor="class _BridgePointAtmospherePainterV278 extends CustomPainter{\n"
new_painter=r'''class _BridgePointSpatialAtmospherePainterV287 extends CustomPainter{
  const _BridgePointSpatialAtmospherePainterV287({required this.t,required this.accent});
  final double t;final Color accent;
  @override void paint(Canvas canvas,Size size){
    if(size.isEmpty)return;
    final horizon=size.height*.36;
    final topGlow=Paint()..shader=ui.Gradient.radial(Offset(size.width*(.72+.035*sin(t*pi*2)),size.height*.16),size.width*.62,[accent.withOpacity(.13),const Color(0xFF0A2340).withOpacity(.05),Colors.transparent],[0,.46,1]);
    canvas.drawRect(Offset.zero&size,topGlow);
    final ground=Paint()..shader=ui.Gradient.linear(Offset(0,horizon),Offset(0,size.height),[const Color(0x00102136),const Color(0xB0081727),const Color(0xFA050D17)],[0,.42,1]);
    canvas.drawRect(Rect.fromLTRB(0,horizon,size.width,size.height),ground);
    final vanishing=Offset(size.width*(.50+.018*sin(t*pi*2)),horizon);
    final grid=Paint()..style=PaintingStyle.stroke..strokeWidth=.72..color=accent.withOpacity(.095);
    final gridBright=Paint()..style=PaintingStyle.stroke..strokeWidth=1.15..color=accent.withOpacity(.16);
    for(var i=-10;i<=10;i++){final bottomX=size.width*.5+i*(size.width/11.5);canvas.drawLine(vanishing,Offset(bottomX,size.height*1.05),i%5==0?gridBright:grid);}
    for(var i=0;i<18;i++){final q=i/18.0;final curve=q*q;final y=horizon+(size.height-horizon)*curve;canvas.drawLine(Offset(0,y),Offset(size.width,y),i%4==0?gridBright:grid);}
    for(var k=0;k<7;k++){final phase=(t*.18+k*.13)%1.0;final cx=size.width*(.18+(k%3)*.31)+sin((t+k)*pi*2)*8;final cy=size.height*(.55+(k%2)*.16);final r=size.width*(.055+.13*phase);final contour=Paint()..style=PaintingStyle.stroke..strokeWidth=.7..color=(k.isEven?accent:const Color(0xFF7EA6C9)).withOpacity(.045+.035*(1-phase));canvas.drawOval(Rect.fromCenter(center:Offset(cx,cy),width:r*2.2,height:r*.72),contour);}
    final nodes=<Offset>[];for(var i=0;i<13;i++){final x=((i*83.0+31)%997)/997*size.width;final y=horizon+((i*149.0+73)%991)/991*(size.height-horizon);nodes.add(Offset(x,y));}
    final link=Paint()..strokeWidth=.65..color=accent.withOpacity(.075);for(var i=1;i<nodes.length;i++)canvas.drawLine(nodes[i-1],nodes[i],link);
    for(var i=0;i<nodes.length;i++){final pulse=.45+.55*((sin(t*pi*2+i*.77)+1)/2);canvas.drawCircle(nodes[i],2.0+(i%3)*.35,Paint()..color=accent.withOpacity(.18+.18*pulse));canvas.drawCircle(nodes[i],8+(i%4)*2,Paint()..color=accent.withOpacity(.018+.022*pulse));}
    final sweepX=((t*1.05)%1.0)*size.width;final sweep=Paint()..shader=ui.Gradient.linear(Offset(sweepX-120,0),Offset(sweepX+120,0),[Colors.transparent,accent.withOpacity(.035),Colors.transparent]);canvas.drawRect(Rect.fromLTWH(sweepX-120,0,240,size.height),sweep);
    final vignette=Paint()..shader=ui.Gradient.radial(size.center(Offset.zero),size.longestSide*.62,[Colors.transparent,const Color(0xCC020812)],[.52,1]);canvas.drawRect(Offset.zero&size,vignette);
  }
  @override bool shouldRepaint(covariant _BridgePointSpatialAtmospherePainterV287 old)=>old.t!=t||old.accent!=accent;
}

'''
if body.count(painter_anchor)!=1: raise SystemExit('v287 painter class anchor')
body=body.replace(painter_anchor,new_painter+painter_anchor,1)

body += "\nconst String _bridgePointNationalWeatherSpatialBackgroundV287='bridgepoint-v287-national-weather-spatial-background | real NOAA national radar motion | NOAA nowCOAST cloud motion | Community 3D parent scroll lock | spatial geospatial horizon background';\n"
path.write_text(body,encoding='utf-8')
print('Applied v287 national live weather, 3D gesture lock and spatial background.')
