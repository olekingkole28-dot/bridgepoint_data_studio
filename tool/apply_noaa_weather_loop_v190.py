from pathlib import Path
import re

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
if start<0:
    start=text.find('class _IntelligenceMapPageState')
if start<0:
    raise SystemExit('v826 Intelligence Map state missing')
end=text.find('class _MapLegendDot',start)
if end<0:
    m=re.search(r'(?m)^class\s+_[A-Za-z0-9_]+',text[start+1:])
    end=len(text) if m is None else start+1+m.start()
if end<=start:
    raise SystemExit('v826 Intelligence Map boundary invalid')
block=text[start:end]

# Add the four-hour / five-minute playback state without changing unrelated map state.
if '_radarAnimationTimer' not in block:
    m=re.search(r'(?m)^(\s*)bool\s+_showRadar\s*=\s*true;\s*$',block)
    if m is None:
        raise SystemExit('v826 radar state field missing')
    i=m.group(1)
    fields=f"""{m.group(0)}
{i}Timer? _radarAnimationTimer;
{i}bool _radarPlaying = true;
{i}int _radarFrameIndex = 48;
{i}List<DateTime> get _radarFrames {{
{i}  final now=DateTime.now().toUtc();
{i}  final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/5)*5);
{i}  return List.generate(49,(index)=>rounded.subtract(Duration(minutes:(48-index)*5)));
{i}}}
{i}DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,48)];
{i}String _radarClock(DateTime t){{
{i}  final l=t.toLocal();final h=l.hour%12==0?12:l.hour%12;
{i}  return '$h:${{l.minute.toString().padLeft(2,'0')}} ${{l.hour>=12?'PM':'AM'}}';
{i}}}
{i}void _startRadarLoop(){{
{i}  _radarAnimationTimer?.cancel();
{i}  _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:700),(_){{
{i}    if(!mounted||!_radarPlaying||!_showRadar)return;
{i}    final step=_viewportZoom>=8.5?2:1;
{i}    setState(()=>_radarFrameIndex=_radarFrameIndex+step>48?0:_radarFrameIndex+step);
{i}  }});
{i}}}
{i}void _toggleRadarPlayback()=>setState(()=>_radarPlaying=!_radarPlaying);"""
    block=block[:m.start()]+fields+block[m.end():]

if '_startRadarLoop();' not in block:
    init=block.find('void initState()')
    if init<0:
        raise SystemExit('v826 map initState missing')
    brace=block.find('{',init);depth=0;close=None
    for x in range(brace,len(block)):
        if block[x]=='{': depth+=1
        elif block[x]=='}':
            depth-=1
            if depth==0:
                close=x;break
    if close is None:
        raise SystemExit('v826 map initState unterminated')
    block=block[:close]+'    _startRadarLoop();\n'+block[close:]

# Reuse the existing map dispose hook created by viewport v124.
dispose=block.find('void dispose()')
if dispose>=0:
    next_method=block.find('\n  @override',dispose+1)
    probe=block[dispose: next_method if next_method>dispose else len(block)]
    if '_radarAnimationTimer?.cancel();' not in probe:
        brace=block.find('{',dispose)
        block=block[:brace+1]+'\n    _radarAnimationTimer?.cancel();'+block[brace+1:]
else:
    marker='  @override\n  Widget build('
    if marker not in block:
        raise SystemExit('v826 map lifecycle insertion anchor missing')
    block=block.replace(marker,"""  @override
  void dispose(){
    _radarAnimationTimer?.cancel();
    super.dispose();
  }

"""+marker,1)

# Locate the actual main radar WMS controlled by _showRadar. This intentionally
# ignores the separate v177 preview/dialog WMS maps.
radar=re.search(r'if\s*\(\s*_showRadar(?:\s*&&[^)]*)?\s*\)\s*\n\s*TileLayer\(',block,re.S)
if radar is None:
    raise SystemExit('v826 main _showRadar TileLayer missing')
wms_at=block.find('WMSTileLayerOptions(',radar.end())
if wms_at<0 or wms_at-radar.end()>1400:
    raise SystemExit('v826 main radar WMS options missing')
depth=0;wms_end=None
for x in range(wms_at,len(block)):
    if block[x]=='(': depth+=1
    elif block[x]==')':
        depth-=1
        if depth==0:
            wms_end=x;break
if wms_end is None:
    raise SystemExit('v826 main radar WMS unterminated')
wms=block[wms_at:wms_end+1]

new_url='https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?'
base=re.compile(r"baseUrl\s*:\s*'[^']*'",re.S)
if base.search(wms) is None:
    raise SystemExit('v826 main radar baseUrl missing')
wms=base.sub(f"baseUrl: '{new_url}'",wms,count=1)
layers=re.compile(r"layers\s*:\s*const\s*\[[^\]]+\]",re.S)
if layers.search(wms) is None:
    raise SystemExit('v826 main radar layers missing')
wms=layers.sub("layers: const ['0']",wms,count=1)
if 'otherParameters:' not in wms:
    close=wms.rfind(')')
    wms=wms[:close]+"  otherParameters: {'TIME': _radarFrame.toUtc().toIso8601String()},\n"+wms[close:]
block=block[:wms_at]+wms+block[wms_end+1:]

# Raw reflectivity is regional context; don't fake property-level pixel precision.
condition=r'if\s*\(\s*_showRadar\s*\)\s*\n(\s*)TileLayer\('
block,count=re.subn(condition,lambda m:'if (_showRadar && _viewportZoom <= 10.5)\n'+m.group(1)+'TileLayer(',block,count=1)
if count!=1 and 'if (_showRadar && _viewportZoom <= 10.5)' not in block:
    raise SystemExit('v826 radar zoom-gate anchor missing')

# Timeline controls sit above the existing top-right map controls.
control=re.search(r'(?m)^\s*Positioned\(\s*\n\s*top:\s*14,\s*\n\s*right:\s*14,',block)
if control is None:
    raise SystemExit('v826 map controls anchor missing')
weather=r'''                      if (_showRadar && _viewportZoom <= 10.5)
                        Positioned(
                          left:14,right:14,bottom:14,
                          child:Container(
                            padding:const EdgeInsets.fromLTRB(10,8,10,7),
                            decoration:BoxDecoration(color:const Color(0xFF071321).withOpacity(.94),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.28)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.35),blurRadius:14)]),
                            child:Column(mainAxisSize:MainAxisSize.min,children:[
                              Row(children:[
                                IconButton.filledTonal(tooltip:_radarPlaying?'Pause weather motion':'Play weather motion',onPressed:_toggleRadarPlayback,icon:Icon(_radarPlaying?Icons.pause_rounded:Icons.play_arrow_rounded,size:20)),
                                const SizedBox(width:7),const _PulseDot(color:AppTheme.green),const SizedBox(width:6),
                                const Text('NOAA MRMS • ~1 KM SOURCE RESOLUTION',style:TextStyle(color:Colors.white,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.45)),
                                const SizedBox(width:8),
                                Expanded(child:Slider(value:_radarFrameIndex.toDouble(),min:0,max:48,divisions:48,onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();}))),
                                const SizedBox(width:6),
                                Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(8)),child:Text('${_radarClock(_radarFrame)}${_radarFrameIndex==48?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900))),
                              ]),
                              const Padding(padding:EdgeInsets.only(left:44,right:8),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                                Text('-4h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-3h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-2h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-1h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('Now',style:TextStyle(color:AppTheme.cyan,fontSize:7,fontWeight:FontWeight.w900)),
                              ])),
                            ]),
                          ),
                        ),
                      if (_showRadar && _viewportZoom > 10.5)
                        Positioned(left:14,right:14,bottom:14,child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFF071321).withOpacity(.95),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.amber.withOpacity(.35))),child:const Row(children:[
                          Icon(Icons.zoom_out_map_rounded,color:AppTheme.amber,size:18),SizedBox(width:8),Expanded(child:Text('Raw NOAA radar is ~1 km regional data, so BridgePoint stops over-zooming it here. Zoom out for reflectivity; property-level storm evidence stays separate from the raw radar pixels.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))),
                        ]))),
'''
block=block[:control.start()]+weather+block[control.start():]

# Upgrade the existing radar toggle in place.
toggle=re.compile(r"_MapControlButton\(\s*icon:\s*_showRadar\s*\?\s*Icons\.radar_rounded\s*:\s*Icons\.hide_source_rounded,\s*tooltip:\s*_showRadar\s*\?\s*'[^']*'\s*:\s*'[^']*',\s*onTap:\s*\(\)\s*=>\s*setState\(\(\)\s*=>\s*_showRadar\s*=\s*!_showRadar\)\s*\)\s*\)",re.S)
replacement="""_MapControlButton(
                                icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,
                                tooltip:_showRadar?'Hide animated NOAA radar':'Show animated NOAA radar',
                                onTap:()=>setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=48;_radarPlaying=true;}}))"""
block,toggle_count=toggle.subn(replacement,block,count=1)
if toggle_count!=1:
    raise SystemExit(f'v826 radar toggle anchor mismatch: {toggle_count}')

text=text[:start]+block+text[end:]
text=text.replace('Live NOAA Radar','NOAA Weather Motion')
text=text.replace('LIVE NOAA RADAR • TAP TO ZOOM','NOAA WEATHER • TAP TO EXPAND')
for marker in ['NOAA MRMS • ~1 KM SOURCE RESOLUTION','Pause weather motion','radar_base_reflectivity_time/ImageServer/WMSServer',"otherParameters: {'TIME'",'_viewportZoom <= 10.5','stops over-zooming it here','max:48']:
    if marker not in text:
        raise SystemExit(f'missing NOAA weather v826 marker {marker}')
if text==original:
    raise SystemExit('No NOAA weather v826 changes applied')
p.write_text(text,encoding='utf-8')
print('Applied structural NOAA time-enabled scale-aware weather timeline v826')
