from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
original=body

# Hunk 10: the small Intelligence Map preview should use the shared, preloaded
# national radar renderer and keep clouds off. This is deliberately structural
# so phone layout changes do not matter.
body=body.replace(
    'const _BridgePointNationwideWeatherV287(radar:false),',
    'const _BridgePointNationwideWeatherV287(radar:false,clouds:false),'
)
preview_start="if(_weatherAllowedV318&&_showRadar)TileLayer(key:ValueKey('noaa-radar-preview-"
while preview_start in body:
    start=body.index(preview_start)
    end_marker="userAgentPackageName:'com.bridgepoint.data_studio'),"
    end=body.find(end_marker,start)
    if end<0:
        raise SystemExit('v319 responsive repair: radar preview TileLayer end not found')
    end+=len(end_marker)
    body=body[:start]+"if(_weatherAllowedV318&&_showRadar)const _BridgePointNationwideWeatherV287(radar:true,clouds:false),"+body[end:]

# Scope the shared nationwide weather class for its timer/build changes.
state_start=body.find('class _BridgePointNationwideWeatherV287State extends State<_BridgePointNationwideWeatherV287>')
if state_start<0:
    raise SystemExit('v319 responsive repair: nationwide weather state missing')
state_end=body.find('\nclass ',state_start+10)
if state_end<0:
    state_end=len(body)
block=body[state_start:state_end]

# Hunk 12: quicker verified-frame playback.
block=block.replace('Timer.periodic(const Duration(milliseconds:1500)', 'Timer.periodic(const Duration(milliseconds:950)',1)
# Hunk 13 load-window tuning.
block=block.replace('if(r.length>10)r=r.sublist(r.length-10);if(c.length>6)c=c.sublist(c.length-6);','if(r.length>6)r=r.sublist(r.length-6);if(c.length>2)c=c.sublist(c.length-2);',1)

# Replace the v313 latest-frame renderer with v319 preloaded verified frames.
old_build="""  @override Widget build(BuildContext context){
    if(!weatherAllowedV318)return const SizedBox.shrink();
    final r=radarFrame,c=cloudFrame;
    final latestRadar=r==null||radarFrames.isEmpty||radarIndex>=radarFrames.length-1;
    final radarParams=latestRadar?const <String,String>{}:<String,String>{'TIME':'${r.toUtc().millisecondsSinceEpoch}'};
    final radarKey=latestRadar?'latest-$tick':'$radarIndex-${r.millisecondsSinceEpoch}';
    return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
      if(widget.clouds&&c!=null)Opacity(opacity:.20,child:TileLayer(key:ValueKey('bp-us-cloud-$cloudIndex-${c.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':c.toUtc().toIso8601String()}),maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:750),startOpacity:.15,reloadStartOpacity:.85),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar&&r!=null)Opacity(opacity:.66,child:TileLayer(key:ValueKey('bp-us-radar-$radarKey'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:radarParams),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.22,reloadStartOpacity:.90),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar&&r!=null)const Positioned(left:6,bottom:6,child:_RadarIntensityLegendV318(compact:true,overlay:true)),
    ]));
  }
"""
new_build="""  @override Widget build(BuildContext context){
    if(!weatherAllowedV318)return const SizedBox.shrink();
    final r=radarFrame,c=cloudFrame;
    return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
      if(widget.clouds&&c!=null)Opacity(opacity:.12,child:TileLayer(key:ValueKey('bp-us-cloud-$cloudIndex-${c.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':c.toUtc().toIso8601String()}),maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:350),startOpacity:.6,reloadStartOpacity:.9),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar)
        for(var i=0;i<radarFrames.length;i++)
          Opacity(opacity:i==radarIndex ? .78 : 0,child:TileLayer(key:ValueKey('bp-us-radar-preloaded-$i-${radarFrames[i].millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':radarFrames[i].toUtc().toIso8601String()}),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:180),startOpacity:.85,reloadStartOpacity:.95),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar&&r!=null)Positioned(left:6,bottom:6,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _RadarIntensityLegendV318(compact:true,overlay:true),
        const SizedBox(height:3),
        Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:const Color(0xE607111F),borderRadius:BorderRadius.circular(7)),child:Text('${r.toLocal().hour%12==0?12:r.toLocal().hour%12}:${r.toLocal().minute.toString().padLeft(2,'0')} ${r.toLocal().hour>=12?'PM':'AM'} • ${radarIndex>=radarFrames.length-1?'NOW':'RADAR HISTORY'}',style:const TextStyle(color:Colors.white,fontSize:7.5,fontWeight:FontWeight.w900))),
      ])),
    ]));
  }
"""
if old_build in block:
    block=block.replace(old_build,new_build,1)
elif 'bp-us-radar-preloaded-' not in block:
    raise SystemExit('v319 responsive repair: nationwide weather build anchor missing')

body=body[:state_start]+block+body[state_end:]

# Hunk 14: Weather Center must use exact ISO timestamps for verified frames.
old_time="Map<String,String> get timeParametersV271=>isLatestV271?const <String,String>{}:<String,String>{'TIME':'${frame.toUtc().millisecondsSinceEpoch}'};"
new_time="Map<String,String> get timeParametersV271=><String,String>{'TIME':frame.toUtc().toIso8601String()};"
if old_time in body:
    body=body.replace(old_time,new_time,1)
elif new_time not in body:
    raise SystemExit('v319 responsive repair: Weather Center time parameter anchor missing')

# Hunk 15: retain only the eight verified frames actually animated by Weather Center.
old_frames="noaaFramesV271=next.length>25?next.sublist(next.length-25):next"
new_frames="noaaFramesV271=next.length>8?next.sublist(next.length-8):next"
if old_frames in body:
    body=body.replace(old_frames,new_frames,1)
elif new_frames not in body:
    raise SystemExit('v319 responsive repair: Weather Center frame window anchor missing')

required=[
    '_BridgePointNationwideWeatherV287(radar:true,clouds:false)',
    'Duration(milliseconds:950)',
    'bp-us-radar-preloaded-',
    "timeParametersV271=><String,String>{'TIME':frame.toUtc().toIso8601String()}",
    'noaaFramesV271=next.length>8?next.sublist(next.length-8):next',
]
missing=[x for x in required if x not in body]
if missing:
    raise SystemExit(f'v319 responsive repair incomplete: {missing}')

path.write_text(body,encoding='utf-8')
print('Repaired the five v319 hunks that collide with the responsive/mobile release.')
