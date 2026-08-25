from pathlib import Path
import re

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text


def _dart_block_end(source,start):
    """Return the matching closing brace for a Dart class, ignoring strings/comments."""
    opening=source.find('{',start)
    if opening<0:
        return -1
    depth=0
    i=opening
    mode='code'
    quote=None
    triple=False
    while i<len(source):
        if mode=='line_comment':
            if source[i]=='\n':
                mode='code'
            i+=1
            continue
        if mode=='block_comment':
            if source.startswith('*/',i):
                mode='code';i+=2
            else:
                i+=1
            continue
        if mode=='string':
            if triple:
                token=quote*3
                if source.startswith(token,i):
                    mode='code';quote=None;triple=False;i+=3
                else:
                    i+=1
                continue
            if source[i]=='\\':
                i+=2
                continue
            if source[i]==quote:
                mode='code';quote=None;i+=1
            else:
                i+=1
            continue
        if source.startswith('//',i):
            mode='line_comment';i+=2;continue
        if source.startswith('/*',i):
            mode='block_comment';i+=2;continue
        if source.startswith("'''",i):
            mode='string';quote="'";triple=True;i+=3;continue
        if source.startswith('"""',i):
            mode='string';quote='"';triple=True;i+=3;continue
        if source[i] in ("'",'"'):
            mode='string';quote=source[i];triple=False;i+=1;continue
        if source[i]=='{':
            depth+=1
        elif source[i]=='}':
            depth-=1
            if depth==0:
                return i+1
        i+=1
    return -1

start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
if start<0:start=text.find('class _IntelligenceMapPageState')
if start<0:raise SystemExit('v828 Intelligence Map state missing')
end=_dart_block_end(text,start)
if end<=start:raise SystemExit('v828 Intelligence Map brace boundary invalid')
block=text[start:end]

if '_radarAnimationTimer' not in block:
    m=re.search(r'(?m)^(\s*)bool\s+_showRadar\s*=\s*true;\s*$',block)
    if m is None:raise SystemExit('v828 radar state field missing')
    i=m.group(1)
    fields=f"""{m.group(0)}
{i}Timer? _radarAnimationTimer;
{i}bool _radarPlaying=true;
{i}int _radarFrameIndex=48;
{i}List<DateTime> get _radarFrames{{
{i}  final now=DateTime.now().toUtc();
{i}  final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/5)*5);
{i}  return List.generate(49,(index)=>rounded.subtract(Duration(minutes:(48-index)*5)));
{i}}}
{i}DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,48)];
{i}String _radarClock(DateTime t){{final l=t.toLocal();final h=l.hour%12==0?12:l.hour%12;return '$h:${{l.minute.toString().padLeft(2,'0')}} ${{l.hour>=12?'PM':'AM'}}';}}
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
    if init<0:raise SystemExit('v828 map initState missing')
    close=_dart_block_end(block,init)
    if close<0:raise SystemExit('v828 initState unterminated')
    block=block[:close-1]+'    _startRadarLoop();\n'+block[close-1:]

dispose=block.find('void dispose()')
if dispose>=0:
    dispose_end=_dart_block_end(block,dispose)
    if dispose_end<0:raise SystemExit('v828 dispose unterminated')
    probe=block[dispose:dispose_end]
    if '_radarAnimationTimer?.cancel();' not in probe:
        brace=block.find('{',dispose)
        block=block[:brace+1]+'\n    _radarAnimationTimer?.cancel();'+block[brace+1:]
else:
    marker='  @override\n  Widget build('
    if marker not in block:raise SystemExit('v828 lifecycle anchor missing')
    block=block.replace(marker,"""  @override
  void dispose(){_radarAnimationTimer?.cancel();super.dispose();}

"""+marker,1)

# Select the first WMS options block inside the exact Intelligence Map class
# that proves itself to be radar. Preview/dialog WMS helpers live outside this class.
search_at=0;wms_at=None;wms_end=None;wms=None
while True:
    candidate=block.find('WMSTileLayerOptions(',search_at)
    if candidate<0:break
    depth=0;candidate_end=None
    for x in range(candidate,len(block)):
        if block[x]=='(':depth+=1
        elif block[x]==')':
            depth-=1
            if depth==0:candidate_end=x;break
    if candidate_end is None:raise SystemExit('v828 WMS options unterminated')
    candidate_text=block[candidate:candidate_end+1]
    lower=candidate_text.lower()
    if any(token in lower for token in ('radar','ncep','bref','reflectivity')):
        wms_at,wms_end,wms=candidate,candidate_end,candidate_text
        break
    search_at=candidate_end+1
if wms_at is None or wms is None:
    raise SystemExit(f'v828 radar WMS options not found; class_len={len(block)} wms_count={block.count("WMSTileLayerOptions(")}')

new_url='https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?'
base=re.compile(r"baseUrl\s*:\s*'[^']*'",re.S)
if base.search(wms) is None:raise SystemExit('v828 radar baseUrl missing')
wms=base.sub(f"baseUrl:'{new_url}'",wms,count=1)
layers=re.compile(r"layers\s*:\s*const\s*\[[^\]]+\]",re.S)
if layers.search(wms) is None:raise SystemExit('v828 radar layers missing')
wms=layers.sub("layers:const ['0']",wms,count=1)
if 'otherParameters:' not in wms:
    close=wms.rfind(')')
    wms=wms[:close]+"otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()},\n"+wms[close:]
block=block[:wms_at]+wms+block[wms_end+1:]

conditions=list(re.finditer(r'if\s*\(\s*_showRadar\s*\)',block))
gated=False
for c in conditions:
    tail=block[c.end():c.end()+1400]
    tile=tail.find('TileLayer(');positioned=tail.find('Positioned(')
    if tile>=0 and (positioned<0 or tile<positioned):
        block=block[:c.start()]+'if (_showRadar && _viewportZoom <= 10.5)'+block[c.end():]
        gated=True;break
if not gated and 'if (_showRadar && _viewportZoom <= 10.5)' not in block:
    raise SystemExit('v828 radar zoom-gate anchor missing')

control=re.search(r'(?m)^\s*Positioned\(\s*\n\s*top:\s*14,\s*\n\s*right:\s*14,',block)
if control is None:raise SystemExit('v828 map controls anchor missing')
weather=r'''                      if (_showRadar && _viewportZoom <= 10.5)
                        Positioned(left:14,right:14,bottom:14,child:Container(
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
                            const Padding(padding:EdgeInsets.only(left:44,right:8),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('-4h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-3h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-2h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-1h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('Now',style:TextStyle(color:AppTheme.cyan,fontSize:7,fontWeight:FontWeight.w900))])),
                          ]),
                        )),
                      if (_showRadar && _viewportZoom > 10.5)
                        Positioned(left:14,right:14,bottom:14,child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFF071321).withOpacity(.95),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.amber.withOpacity(.35))),child:const Row(children:[Icon(Icons.zoom_out_map_rounded,color:AppTheme.amber,size:18),SizedBox(width:8),Expanded(child:Text('Raw NOAA radar is ~1 km regional data, so BridgePoint stops over-zooming it here. Zoom out for reflectivity; property-level storm evidence stays separate from the raw radar pixels.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)))]))),
'''
block=block[:control.start()]+weather+block[control.start():]

toggle=re.compile(r"_MapControlButton\(\s*icon:\s*_showRadar\s*\?\s*Icons\.radar_rounded\s*:\s*Icons\.hide_source_rounded,\s*tooltip:\s*_showRadar\s*\?\s*'[^']*'\s*:\s*'[^']*',\s*onTap:\s*\(\)\s*=>\s*setState\(\(\)\s*=>\s*_showRadar\s*=\s*!_showRadar\)\s*\)\s*\)",re.S)
replacement="""_MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide animated NOAA radar':'Show animated NOAA radar',onTap:()=>setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=48;_radarPlaying=true;}}))"""
block,toggle_count=toggle.subn(replacement,block,count=1)
if toggle_count!=1:raise SystemExit(f'v828 radar toggle anchor mismatch: {toggle_count}')

text=text[:start]+block+text[end:]
text=text.replace('Live NOAA Radar','NOAA Weather Motion').replace('LIVE NOAA RADAR • TAP TO ZOOM','NOAA WEATHER • TAP TO EXPAND')
for marker in ['NOAA MRMS • ~1 KM SOURCE RESOLUTION','Pause weather motion','radar_base_reflectivity_time/ImageServer/WMSServer',"'TIME':_radarFrame",'_viewportZoom <= 10.5','stops over-zooming it here','max:48']:
    if marker not in text:raise SystemExit(f'missing NOAA v828 marker {marker}')
if text==original:raise SystemExit('No NOAA weather v828 changes applied')
p.write_text(text,encoding='utf-8')
print('Applied brace-safe NOAA time-enabled scale-aware weather timeline v828')
