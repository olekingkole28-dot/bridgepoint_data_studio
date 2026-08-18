from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-noaa-verified-frame-fallback'
if marker in body:
    print('v313 NOAA verified-frame fallback already applied.')
    raise SystemExit(0)

old_intel="""  List<DateTime> get _radarFrames{
    if(_noaaRadarFramesV271.length>=2)return _noaaRadarFramesV271;
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
"""
new_intel="""  List<DateTime> get _radarFrames{
    if(_noaaRadarFramesV271.length>=2)return _noaaRadarFramesV271;
    // Never invent historical NOAA timestamps. Until the verified frame list arrives,
    // keep the map on one newest-live frame with TIME omitted so NOAA returns current radar.
    return <DateTime>[DateTime.now().toUtc()];
  }
"""
if body.count(old_intel)!=1:
    raise SystemExit(f'v313 intelligence radar fallback anchor {body.count(old_intel)}')
body=body.replace(old_intel,new_intel,1)

old_weather="""  List<DateTime> get frames{
    if(noaaFramesV271.length>=2)return noaaFramesV271;
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
"""
new_weather="""  List<DateTime> get frames{
    if(noaaFramesV271.length>=2)return noaaFramesV271;
    // One live frame only until NOAA gives BridgePoint exact historical frame timestamps.
    return <DateTime>[DateTime.now().toUtc()];
  }
"""
if body.count(old_weather)!=1:
    raise SystemExit(f'v313 Weather Center radar fallback anchor {body.count(old_weather)}')
body=body.replace(old_weather,new_weather,1)

old_national="""  @override Widget build(BuildContext context){final r=radarFrame,c=cloudFrame;return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
    if(widget.clouds&&c!=null)Opacity(opacity:.20,child:TileLayer(key:ValueKey('bp-us-cloud-$cloudIndex-${c.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':c.toUtc().toIso8601String()}),maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:750),startOpacity:.15,reloadStartOpacity:.85),userAgentPackageName:'com.bridgepoint.data_studio')),
    if(widget.radar&&r!=null)Opacity(opacity:.66,child:TileLayer(key:ValueKey('bp-us-radar-$radarIndex-${r.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':'${r.toUtc().millisecondsSinceEpoch}'}),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.22,reloadStartOpacity:.90),userAgentPackageName:'com.bridgepoint.data_studio')),
  ]));}
"""
new_national="""  @override Widget build(BuildContext context){
    final r=radarFrame,c=cloudFrame;
    final latestRadar=r==null||radarFrames.isEmpty||radarIndex>=radarFrames.length-1;
    final radarParams=latestRadar?const <String,String>{}:<String,String>{'TIME':'${r.toUtc().millisecondsSinceEpoch}'};
    final radarKey=latestRadar?'latest-$tick':'$radarIndex-${r.millisecondsSinceEpoch}';
    return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
      if(widget.clouds&&c!=null)Opacity(opacity:.20,child:TileLayer(key:ValueKey('bp-us-cloud-$cloudIndex-${c.millisecondsSinceEpoch}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':c.toUtc().toIso8601String()}),maxNativeZoom:8,maxZoom:8.7,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:750),startOpacity:.15,reloadStartOpacity:.85),userAgentPackageName:'com.bridgepoint.data_studio')),
      if(widget.radar)Opacity(opacity:.66,child:TileLayer(key:ValueKey('bp-us-radar-$radarKey'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:radarParams),maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:520),startOpacity:.22,reloadStartOpacity:.90),userAgentPackageName:'com.bridgepoint.data_studio')),
    ]));
  }
"""
if body.count(old_national)!=1:
    raise SystemExit(f'v313 nationwide weather renderer anchor {body.count(old_national)}')
body=body.replace(old_national,new_national,1)

body += "\nconst String _bridgePointNoaaVerifiedFrameFallbackV313='bridgepoint-v313-noaa-verified-frame-fallback | newest NOAA radar always renders without TIME | no guessed historical timestamps | animation waits for verified frames';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 NOAA verified-frame fallback.')
