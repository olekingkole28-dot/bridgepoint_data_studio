from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v271-noaa-live-weather'
if marker in body:
    print('NOAA live weather v271 already applied.')
    raise SystemExit(0)

old_frames="""  bool _radarPlaying=true;
  int _radarFrameIndex=24;
  List<DateTime> get _radarFrames{
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,24)];
"""
new_frames="""  bool _radarPlaying=true;
  int _radarFrameIndex=24;
  List<DateTime> _noaaRadarFramesV271=<DateTime>[];
  List<DateTime> get _radarFrames{
    if(_noaaRadarFramesV271.length>=2)return _noaaRadarFramesV271;
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,_radarFrames.length-1)];
  bool get _radarIsLatestV271=>_radarFrameIndex>=_radarFrames.length-1;
  Map<String,String> get _radarTimeParametersV271=>_radarIsLatestV271
      ? const <String,String>{}
      : <String,String>{'TIME':'${_radarFrame.toUtc().millisecondsSinceEpoch}'};
"""
if body.count(old_frames)!=1:
    raise SystemExit(f'v271 intelligence radar frames anchor {body.count(old_frames)}')
body=body.replace(old_frames,new_frames,1)

old_loop="""      setState((){_radarFrameIndex=_radarFrameIndex>=24?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});
"""
new_loop="""      setState((){final last=_radarFrames.length-1;_radarFrameIndex=_radarFrameIndex>=last?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});
"""
if body.count(old_loop)!=1:
    raise SystemExit(f'v271 intelligence radar loop anchor {body.count(old_loop)}')
body=body.replace(old_loop,new_loop,1)

init_old="""    _startRadarLoop();
    unawaited(_checkNoaaHealth(silent:true));
"""
init_new="""    _startRadarLoop();
    unawaited(_loadNoaaRadarFramesV271());
    unawaited(_checkNoaaHealth(silent:true));
"""
if body.count(init_old)!=1:
    raise SystemExit(f'v271 intelligence init anchor {body.count(init_old)}')
body=body.replace(init_old,init_new,1)

method_anchor="""  Future<void> _checkNoaaHealth({bool silent=false})async{
"""
method_insert="""  Future<void> _loadNoaaRadarFramesV271()async{
    try{
      final r=await Supabase.instance.client.functions.invoke('bridgepoint-noaa-radar-frames-v271',body:const {});
      final p=_edgeFunctionPayload(r.data);
      if(r.status<200||r.status>=300||p['complete']!=true)return;
      final raw=p['frames_iso'];
      final next=raw is List?raw.map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];
      if(next.length<2||!mounted)return;
      setState((){
        _noaaRadarFramesV271=next.length>25?next.sublist(next.length-25):next;
        _radarFrameIndex=_noaaRadarFramesV271.length-1;
        _radarRevision++;
      });
    }catch(_){/* Latest NOAA radar still renders without a time filter. */}
  }

"""+method_anchor
if body.count(method_anchor)!=1:
    raise SystemExit(f'v271 intelligence frame loader anchor {body.count(method_anchor)}')
body=body.replace(method_anchor,method_insert,1)

old_main_time="""                              otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()},
"""
new_main_time="""                              otherParameters:_radarTimeParametersV271,
"""
if body.count(old_main_time)!=1:
    raise SystemExit(f'v271 main WMS time anchor {body.count(old_main_time)}')
body=body.replace(old_main_time,new_main_time,1)

old_preview="""                                    if(_showRadar)TileLayer(key:ValueKey('noaa-radar-preview-$_radarRevision-${_radarFrame.toIso8601String()}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$_radarRevision&',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()}),maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio'),
"""
new_preview="""                                    if(_showRadar)TileLayer(key:ValueKey('noaa-radar-preview-$_radarRevision-${_radarFrame.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$_radarRevision&',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:_radarTimeParametersV271),maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio'),
"""
if body.count(old_preview)!=1:
    raise SystemExit(f'v271 preview WMS anchor {body.count(old_preview)}')
body=body.replace(old_preview,new_preview,1)

old_slider="""                              const SizedBox(width:8),Expanded(child:Slider(value:_radarFrameIndex.toDouble(),min:0,max:24,divisions:24,onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();}))),
                              const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(8)),child:Text('${_radarClock(_radarFrame)}${_radarFrameIndex==24?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900))),
"""
new_slider="""                              const SizedBox(width:8),Expanded(child:Slider(value:_radarFrameIndex.clamp(0,_radarFrames.length-1).toDouble(),min:0,max:(_radarFrames.length-1).toDouble(),divisions:_radarFrames.length>1?_radarFrames.length-1:null,onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();_radarRevision++;}))),
                              const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(8)),child:Text('${_radarClock(_radarFrame)}${_radarIsLatestV271?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900))),
"""
if body.count(old_slider)!=1:
    raise SystemExit(f'v271 intelligence slider anchor {body.count(old_slider)}')
body=body.replace(old_slider,new_slider,1)

old_us_button="""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
"""
new_us_button="""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:(){
                              setState((){_showRadar=true;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;});
                              _mapController.move(const LatLng(39.50,-98.35),4.2);
                              unawaited(_loadNoaaRadarFramesV271());
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration:Duration(seconds:2),content:Text('United States live weather on • loading the latest NOAA precipitation radar…')));
                            }),
"""
if body.count(old_us_button)!=1:
    raise SystemExit(f'v271 US weather button anchor {body.count(old_us_button)}')
body=body.replace(old_us_button,new_us_button,1)

old_toggle="""                            _MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide precipitation radar':'Show precipitation radar',onTap:()=>setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=24;_radarPlaying=true;}})),
"""
new_toggle="""                            _MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide precipitation radar':'Show precipitation radar',onTap:(){setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=_radarFrames.length-1;_radarPlaying=true;_radarRevision++;}});if(_showRadar)unawaited(_loadNoaaRadarFramesV271());}),
"""
if body.count(old_toggle)!=1:
    raise SystemExit(f'v271 radar toggle anchor {body.count(old_toggle)}')
body=body.replace(old_toggle,new_toggle,1)

# Weather Center: use the same exact NOAA frames and no TIME filter for the latest image.
old_wc="""  Map<String,dynamic>? health;
  List<DateTime> get frames{
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get frame=>frames[index.clamp(0,24)];
  @override void initState(){
    super.initState();
    timer=Timer.periodic(const Duration(milliseconds:900),(_){if(!mounted||!playing)return;setState(()=>index=index>=24?0:index+1);});
    refreshTimer=Timer.periodic(const Duration(seconds:60),(_){if(!mounted)return;setState(()=>revision++);});
  }
"""
new_wc="""  Map<String,dynamic>? health;
  List<DateTime> noaaFramesV271=<DateTime>[];
  List<DateTime> get frames{
    if(noaaFramesV271.length>=2)return noaaFramesV271;
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get frame=>frames[index.clamp(0,frames.length-1)];
  bool get isLatestV271=>index>=frames.length-1;
  Map<String,String> get timeParametersV271=>isLatestV271?const <String,String>{}:<String,String>{'TIME':'${frame.toUtc().millisecondsSinceEpoch}'};
  Future<void> _loadFramesV271()async{
    try{
      final r=await Supabase.instance.client.functions.invoke('bridgepoint-noaa-radar-frames-v271',body:const {});
      final p=_edgeFunctionPayload(r.data);
      if(r.status<200||r.status>=300||p['complete']!=true)return;
      final raw=p['frames_iso'];
      final next=raw is List?raw.map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList():<DateTime>[];
      if(next.length<2||!mounted)return;
      setState((){noaaFramesV271=next.length>25?next.sublist(next.length-25):next;index=noaaFramesV271.length-1;revision++;});
    }catch(_){/* Latest NOAA image remains available without TIME. */}
  }
  @override void initState(){
    super.initState();
    unawaited(_loadFramesV271());
    timer=Timer.periodic(const Duration(milliseconds:900),(_){if(!mounted||!playing)return;setState((){final last=frames.length-1;index=index>=last?0:index+1;});});
    refreshTimer=Timer.periodic(const Duration(seconds:60),(_){if(!mounted)return;setState(()=>revision++);});
  }
"""
if body.count(old_wc)!=1:
    raise SystemExit(f'v271 weather center frame anchor {body.count(old_wc)}')
body=body.replace(old_wc,new_wc,1)

old_wc_wms="""            TileLayer(key:ValueKey('weather-center-radar-$revision-${frame.toIso8601String()}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$revision&',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':frame.toUtc().toIso8601String()}),maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio'),
"""
new_wc_wms="""            TileLayer(key:ValueKey('weather-center-radar-$revision-${frame.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$revision&',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:timeParametersV271),maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio'),
"""
if body.count(old_wc_wms)!=1:
    raise SystemExit(f'v271 weather center WMS anchor {body.count(old_wc_wms)}')
body=body.replace(old_wc_wms,new_wc_wms,1)

old_wc_slider="""          const SizedBox(width:7),Expanded(child:Slider(value:index.toDouble(),min:0,max:24,divisions:24,onChanged:(v)=>setState((){playing=false;index=v.round();}))),
          const SizedBox(width:8),Text('${_clock(frame)}${index==24?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),
"""
new_wc_slider="""          const SizedBox(width:7),Expanded(child:Slider(value:index.clamp(0,frames.length-1).toDouble(),min:0,max:(frames.length-1).toDouble(),divisions:frames.length>1?frames.length-1:null,onChanged:(v)=>setState((){playing=false;index=v.round();revision++;}))),
          const SizedBox(width:8),Text('${_clock(frame)}${isLatestV271?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),
"""
if body.count(old_wc_slider)!=1:
    raise SystemExit(f'v271 weather center slider anchor {body.count(old_wc_slider)}')
body=body.replace(old_wc_slider,new_wc_slider,1)

old_jump="""          FilledButton.tonalIcon(onPressed:()=>setState((){index=24;playing=true;revision++;}),icon:const Icon(Icons.water_drop_outlined,size:16),label:const Text('Jump to current rain')),
"""
new_jump="""          FilledButton.tonalIcon(onPressed:(){setState((){index=frames.length-1;playing=true;revision++;});unawaited(_loadFramesV271());},icon:const Icon(Icons.water_drop_outlined,size:16),label:const Text('Jump to current rain')),
"""
if body.count(old_jump)!=1:
    raise SystemExit(f'v271 weather center jump anchor {body.count(old_jump)}')
body=body.replace(old_jump,new_jump,1)

body += "\nconst String _bridgePointNoaaLiveWeatherV271='bridgepoint-v271-noaa-live-weather | bridgepoint-noaa-radar-frames-v271 | United States live weather on | latest NOAA precipitation radar';\n"
path.write_text(body,encoding='utf-8')
print('Fixed NOAA live weather rendering, exact frames, and U.S. weather button v271.')
