from pathlib import Path
import re

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')


def matching_brace(text: str, open_index: int) -> int:
    """Return the closing brace for a Dart block while ignoring strings/comments."""
    depth=0
    i=open_index
    quote=None
    triple=False
    escaped=False
    line_comment=False
    block_comment=False
    while i<len(text):
        ch=text[i]
        nxt=text[i+1] if i+1<len(text) else ''

        if line_comment:
            if ch=='\n': line_comment=False
            i+=1
            continue
        if block_comment:
            if ch=='*' and nxt=='/':
                block_comment=False
                i+=2
            else:
                i+=1
            continue
        if quote is not None:
            if triple:
                if text.startswith(quote*3,i):
                    quote=None
                    triple=False
                    i+=3
                    continue
                i+=1
                continue
            if escaped:
                escaped=False
                i+=1
                continue
            if ch=='\\':
                escaped=True
                i+=1
                continue
            if ch==quote:
                quote=None
            i+=1
            continue

        if ch=='/' and nxt=='/':
            line_comment=True
            i+=2
            continue
        if ch=='/' and nxt=='*':
            block_comment=True
            i+=2
            continue
        if ch in ("'",'"'):
            if text.startswith(ch*3,i):
                quote=ch
                triple=True
                i+=3
            else:
                quote=ch
                triple=False
                i+=1
            continue
        if ch=='{':
            depth+=1
        elif ch=='}':
            depth-=1
            if depth==0:
                return i
        i+=1
    raise SystemExit('v319 responsive repair: unbalanced Dart method block')


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

# Scope the shared nationwide weather class for timer/load/build changes.
state_start=body.find('class _BridgePointNationwideWeatherV287State extends State<_BridgePointNationwideWeatherV287>')
if state_start<0:
    raise SystemExit('v319 responsive repair: nationwide weather state missing')
state_end=body.find('\nclass ',state_start+10)
if state_end<0:
    state_end=len(body)
block=body[state_start:state_end]

# Hunk 12: quicker verified-frame playback.
block=block.replace('Timer.periodic(const Duration(milliseconds:1500)', 'Timer.periodic(const Duration(milliseconds:950)',1)
# Hunk 13 load-window tuning. Be whitespace tolerant because earlier release
# layers have changed formatting more than once.
block=re.sub(
    r"if\s*\(r\.length\s*>\s*10\)\s*r\s*=\s*r\.sublist\(r\.length\s*-\s*10\)\s*;\s*if\s*\(c\.length\s*>\s*6\)\s*c\s*=\s*c\.sublist\(c\.length\s*-\s*6\)\s*;",
    "if(r.length>6)r=r.sublist(r.length-6);if(c.length>2)c=c.sublist(c.length-2);",
    block,
    count=1,
)

# Hunk 13 renderer: locate the actual Dart build method and replace the method
# structurally. This is intentionally independent of the previous renderer's
# whitespace, latest-frame variables, or responsive formatting.
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
  }"""

if 'bp-us-radar-preloaded-' not in block:
    sig=block.find('Widget build(BuildContext context)')
    if sig<0:
        raise SystemExit('v319 responsive repair: nationwide weather build signature missing')
    method_start=block.rfind('@override',0,sig)
    if method_start<0 or sig-method_start>80:
        method_start=sig
    open_brace=block.find('{',sig)
    if open_brace<0:
        raise SystemExit('v319 responsive repair: nationwide weather build opening brace missing')
    close_brace=matching_brace(block,open_brace)
    block=block[:method_start]+new_build+block[close_brace+1:]

body=body[:state_start]+block+body[state_end:]

# Hunk 14: replace the Weather Center getter by its stable identifier rather
# than by the old expression. The semicolon terminates this expression-bodied
# getter, so this remains a narrow one-getter edit even if formatting evolves.
new_time="Map<String,String> get timeParametersV271=><String,String>{'TIME':frame.toUtc().toIso8601String()};"
if new_time not in body:
    marker='Map<String,String> get timeParametersV271'
    getter_start=body.find(marker)
    if getter_start<0:
        # tolerate whitespace between the generic type and get keyword
        m=re.search(r'Map<String,String>\s+get\s+timeParametersV271',body)
        getter_start=-1 if m is None else m.start()
    if getter_start>=0:
        getter_end=body.find(';',getter_start)
        if getter_end<0 or getter_end-getter_start>500:
            raise SystemExit('v319 responsive repair: Weather Center time getter terminator missing')
        body=body[:getter_start]+new_time+body[getter_end+1:]
    elif 'weather-center-radar-preloaded' not in body or "frames[i].toUtc().toIso8601String()" not in body:
        raise SystemExit('v319 responsive repair: neither legacy Weather Center getter nor direct-ISO preloaded renderer is present')
    else:
        print('v319 Weather Center already uses direct ISO timestamps in the preloaded renderer; legacy getter not required')

# Hunk 15: retain only the eight verified frames animated by Weather Center.
if 'noaaFramesV271=next.length>8?next.sublist(next.length-8):next' not in body:
    marker='noaaFramesV271=next.length'
    assign_start=body.find(marker)
    if assign_start<0:
        m=re.search(r'noaaFramesV271\s*=\s*next\.length',body)
        assign_start=-1 if m is None else m.start()
    if assign_start>=0:
        # This assignment sits inside setState and ends before the next semicolon.
        assign_end=body.find(';',assign_start)
        if assign_end<0 or assign_end-assign_start>500:
            raise SystemExit('v319 responsive repair: Weather Center frame assignment terminator missing')
        assignment=body[assign_start:assign_end]
        if 'next.sublist' in assignment:
            body=body[:assign_start]+'noaaFramesV271=next.length>8?next.sublist(next.length-8):next'+body[assign_end:]
    elif 'weather-center-radar-preloaded' not in body:
        raise SystemExit('v319 responsive repair: Weather Center frame source and preloaded renderer both missing')

required=[
    '_BridgePointNationwideWeatherV287(radar:true,clouds:false)',
    'Duration(milliseconds:950)',
    'bp-us-radar-preloaded-',
    'weather-center-radar-preloaded',
    "frames[i].toUtc().toIso8601String()",
]
missing=[x for x in required if x not in body]
if missing:
    raise SystemExit(f'v319 responsive repair incomplete: {missing}')

path.write_text(body,encoding='utf-8')
print('Repaired the five v319 hunks structurally on the responsive/mobile release.')
