from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v360-radar-playback-persistence'
if marker in body:
    print('v360 radar persistence already applied')
    raise SystemExit(0)


def once(old,new,label):
    global body
    c=body.count(old)
    if c!=1:
        raise SystemExit(f'v360 {label}: expected 1, found {c}')
    body=body.replace(old,new,1)

# Intelligence Map: retain loaded tiles, make motion perceivable, and dwell on NOW.
once("""  Timer? _radarAnimationTimer;
  bool _radarPlaying=false;
  int _radarFrameIndex=24;
""","""  Timer? _radarAnimationTimer;
  bool _radarPlaying=false;
  int _radarFrameIndex=24;
  int _radarNowHoldTicksV360=0;
""",'intelligence radar state')

once("""  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:1800),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      setState((){final last=_radarFrames.length-1;_radarFrameIndex=_radarFrameIndex>=last?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});
    });
  }
  void _toggleRadarPlayback()=>setState(()=>_radarPlaying=!_radarPlaying);
""","""  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:1600),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      final last=_radarFrames.length-1;
      if(last<=0)return;
      if(_radarFrameIndex>=last&&_radarNowHoldTicksV360<1){
        _radarNowHoldTicksV360++;
        return;
      }
      setState((){
        if(_radarFrameIndex>=last){
          _radarFrameIndex=0;
          _radarNowHoldTicksV360=0;
        }else{
          _radarFrameIndex++;
          if(_radarFrameIndex>=last)_radarNowHoldTicksV360=0;
        }
        if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;
      });
    });
  }
  void _toggleRadarPlayback()=>setState((){
    _radarPlaying=!_radarPlaying;
    if(_radarPlaying&&_radarIsLatestV271)_radarNowHoldTicksV360=1;
  });
""",'intelligence radar loop')

once("""        _noaaRadarFramesV271=next.length>25?next.sublist(next.length-25):next;
        _radarFrameIndex=_noaaRadarFramesV271.length-1;
        _radarRevision++;
""","""        _noaaRadarFramesV271=next.length>25?next.sublist(next.length-25):next;
        _radarFrameIndex=_noaaRadarFramesV271.length-1;
        _radarNowHoldTicksV360=0;
        _radarRevision++;
""",'frame refresh')

old_map_radar="""                        if(_weatherAllowedV318&&_showRadar)Opacity(opacity:.88,child:TileLayer(
                          key:ValueKey('noaa-radar-$_radarRevision-${_radarIsLatestV271?'live':_radarFrame.toIso8601String()}'),
                          wmsOptions:WMSTileLayerOptions(
                            baseUrl:_radarIsLatestV271?'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?_bp=$_radarRevision&':'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$_radarRevision&',
                            layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:_radarTimeParametersV271,
                          ),
                          maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:160),startOpacity:.90,reloadStartOpacity:.98),userAgentPackageName:'com.bridgepoint.data_studio',
                        )),
"""
new_map_radar="""                        if(_weatherAllowedV318&&_showRadar)Opacity(opacity:_radarIsLatestV271 ? .88 : .38,child:TileLayer(
                          key:const ValueKey('noaa-radar-live-underlay-v360'),
                          wmsOptions:WMSTileLayerOptions(
                            baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?',
                            layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',
                          ),
                          maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:420),startOpacity:.96,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',
                        )),
                        if(_weatherAllowedV318&&_showRadar&&!_radarIsLatestV271)Opacity(opacity:.88,child:TileLayer(
                          key:const ValueKey('noaa-radar-history-retained-v360'),
                          wmsOptions:WMSTileLayerOptions(
                            baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                            layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:_radarTimeParametersV271,
                          ),
                          maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.92,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',
                        )),
"""
once(old_map_radar,new_map_radar,'intelligence retained radar layers')

once("""                    if(loading&&data==null)Positioned.fill(child:Container(color:AppTheme.panel.withOpacity(.45),child:const Center(child:CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:2.5)))),
""","""                    if(loading&&data==null)Positioned(
                      left:14,top:72,
                      child:IgnorePointer(child:Container(
                        padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
                        decoration:BoxDecoration(color:const Color(0xE607111F),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.cyan.withOpacity(.20))),
                        child:const Row(mainAxisSize:MainAxisSize.min,children:[SizedBox(width:13,height:13,child:CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:1.8)),SizedBox(width:7),Text('Loading property intelligence • radar stays live',style:TextStyle(color:Colors.white,fontSize:7.8,fontWeight:FontWeight.w800))]),
                      )),
                    ),
""",'nonblocking map loader')

# Reset dwell state on direct user jumps/scrubs.
body=body.replace("_radarFrameIndex=_radarFrames.length-1;_radarPlaying=false;_radarRevision++;","_radarFrameIndex=_radarFrames.length-1;_radarPlaying=false;_radarNowHoldTicksV360=0;_radarRevision++;",2)
once("onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();_radarRevision++;})","onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();_radarNowHoldTicksV360=0;_radarRevision++;})",'intelligence scrub')

# Shared nationwide map helper: stable live underlay + retained historical layer and slower, intentional NOW dwell.
once("""  int radarIndex=0,cloudIndex=0,tick=0;
  Timer? timer,refresh;
""","""  int radarIndex=0,cloudIndex=0,tick=0;
  int radarNowHoldTicksV360=0;
  Timer? timer,refresh;
""",'nationwide helper state')
once("""  @override void initState(){super.initState();unawaited(load());timer=Timer.periodic(const Duration(milliseconds:950),(_){if(!mounted||!weatherAllowedV318||_displayPreferences.value.reducedMotion)return;setState((){tick++;if(radarFrames.length>1)radarIndex=(radarIndex+1)%radarFrames.length;if(tick.isEven&&cloudFrames.length>1)cloudIndex=(cloudIndex+1)%cloudFrames.length;});});refresh=Timer.periodic(const Duration(minutes:4),(_)=>unawaited(load()));}
""","""  @override void initState(){super.initState();unawaited(load());timer=Timer.periodic(const Duration(milliseconds:1500),(_){
    if(!mounted||!weatherAllowedV318||_displayPreferences.value.reducedMotion)return;
    final last=radarFrames.length-1;
    if(last>0&&radarIndex>=last&&radarNowHoldTicksV360<1){radarNowHoldTicksV360++;return;}
    setState((){
      tick++;
      if(last>0){if(radarIndex>=last){radarIndex=0;radarNowHoldTicksV360=0;}else{radarIndex++;if(radarIndex>=last)radarNowHoldTicksV360=0;}}
      if(tick.isEven&&cloudFrames.length>1)cloudIndex=(cloudIndex+1)%cloudFrames.length;
    });
  });refresh=Timer.periodic(const Duration(minutes:4),(_)=>unawaited(load()));}
""",'nationwide helper loop')
once("""      setState((){weatherAllowedV318=true;accessResolvedV318=true;radarFrames=r;cloudFrames=c;radarIndex=r.isEmpty?0:r.length-1;cloudIndex=c.isEmpty?0:c.length-1;});
""","""      setState((){weatherAllowedV318=true;accessResolvedV318=true;radarFrames=r;cloudFrames=c;radarIndex=r.isEmpty?0:r.length-1;radarNowHoldTicksV360=0;cloudIndex=c.isEmpty?0:c.length-1;});
""",'nationwide helper refresh')

old_helper_radar="""      if(widget.radar&&r!=null)Opacity(opacity:.90,child:TileLayer(key:ValueKey('bp-us-radar-$radarIndex-${r.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':r.toUtc().toIso8601String()}),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:180),startOpacity:.85,reloadStartOpacity:.95),userAgentPackageName:'com.bridgepoint.data_studio')),
"""
new_helper_radar="""      if(widget.radar)Opacity(opacity:r!=null&&radarIndex<radarFrames.length-1 ? .38 : .90,child:TileLayer(key:const ValueKey('bp-us-radar-live-underlay-v360'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0'),maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:420),startOpacity:.96,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar&&r!=null&&radarIndex<radarFrames.length-1)Opacity(opacity:.90,child:TileLayer(key:const ValueKey('bp-us-radar-history-retained-v360'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':r.toUtc().toIso8601String()}),maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.92,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio')),
"""
once(old_helper_radar,new_helper_radar,'nationwide retained radar')

# Weather Center: same persistence rules so opening the dedicated radar does not regress the map fix.
once("""  int index=0;
  int revision=0;
""","""  int index=0;
  int revision=0;
  int radarNowHoldTicksV360=0;
""",'weather center state')
once("""    timer=Timer.periodic(const Duration(milliseconds:900),(_){if(!mounted||!playing||!weatherAllowedV318)return;setState((){final last=frames.length-1;index=index>=last?0:index+1;});});
""","""    timer=Timer.periodic(const Duration(milliseconds:1500),(_){
      if(!mounted||!playing||!weatherAllowedV318)return;
      final last=frames.length-1;
      if(last<=0)return;
      if(index>=last&&radarNowHoldTicksV360<1){radarNowHoldTicksV360++;return;}
      setState((){if(index>=last){index=0;radarNowHoldTicksV360=0;}else{index++;if(index>=last)radarNowHoldTicksV360=0;}});
    });
""",'weather center loop')
once("""        index=noaaFramesV271.isEmpty?0:noaaFramesV271.length-1;
        revision++;
""","""        index=noaaFramesV271.isEmpty?0:noaaFramesV271.length-1;
        radarNowHoldTicksV360=0;
        revision++;
""",'weather center refresh')

old_wc_layer="""            TileLayer(
              key:ValueKey('weather-center-radar-$revision-${frame.millisecondsSinceEpoch}'),
              wmsOptions:WMSTileLayerOptions(
                baseUrl:isLatestV271?'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?':'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',
                otherParameters:isLatestV271?const <String,String>{}:<String,String>{'TIME':frame.toUtc().toIso8601String()},
              ),
              maxNativeZoom:12,panBuffer:0,keepBuffer:2,userAgentPackageName:'com.bridgepoint.data_studio',
            ),
"""
new_wc_layer="""            Opacity(opacity:isLatestV271 ? .90 : .38,child:TileLayer(
              key:const ValueKey('weather-center-radar-live-underlay-v360'),
              wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0'),
              maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:420),startOpacity:.96,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',
            )),
            if(!isLatestV271)Opacity(opacity:.90,child:TileLayer(
              key:const ValueKey('weather-center-radar-history-retained-v360'),
              wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:<String,String>{'TIME':frame.toUtc().toIso8601String()}),
              maxNativeZoom:12,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.92,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',
            )),
"""
once(old_wc_layer,new_wc_layer,'weather center retained radar')
once("onChanged:(v)=>setState((){playing=false;index=v.round();revision++;})","onChanged:(v)=>setState((){playing=false;index=v.round();radarNowHoldTicksV360=0;revision++;})",'weather center scrub')
once("onPressed:(){setState((){index=frames.length-1;playing=true;revision++;});unawaited(_loadFramesV271());}","onPressed:(){setState((){index=frames.length-1;playing=true;radarNowHoldTicksV360=1;revision++;});unawaited(_loadFramesV271());}",'weather center jump')

body += "\nconst String _bridgePointRadarPlaybackPersistenceV360='bridgepoint-v360-radar-playback-persistence | stable retained tile keys | live underlay | perceivable 1.5s+ frames | NOW dwell | nonblocking initial radar';\n"

required=[
    marker,
    'noaa-radar-live-underlay-v360',
    'noaa-radar-history-retained-v360',
    'bp-us-radar-live-underlay-v360',
    'weather-center-radar-live-underlay-v360',
    'Loading property intelligence • radar stays live',
    'reloadStartOpacity:1',
    '_radarNowHoldTicksV360',
]
for needle in required:
    if needle not in body:
        raise SystemExit(f'v360 missing required marker {needle}')
for forbidden in [
    "ValueKey('noaa-radar-$_radarRevision-${_radarIsLatestV271?'live':_radarFrame.toIso8601String()}')",
    "ValueKey('weather-center-radar-$revision-${frame.millisecondsSinceEpoch}')",
    "ValueKey('bp-us-radar-$radarIndex-${r.millisecondsSinceEpoch}')",
]:
    if forbidden in body:
        raise SystemExit(f'v360 destructive radar key remains: {forbidden}')

path.write_text(body,encoding='utf-8')
print('Applied V360 persistent NOAA radar playback repair.')
