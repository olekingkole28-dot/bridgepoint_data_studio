from pathlib import Path
import re

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text
start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
end=text.find('class _MapLegendDot extends StatelessWidget',start)
if start<0 or end<0: raise SystemExit('Intelligence map block missing')
block=text[start:end]

field_anchor="""  bool _showRadar=true;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
"""
fields="""  bool _showRadar=true;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
  Timer? _radarAnimationTimer;
  bool _radarPlaying=true;
  int _radarFrameIndex=24;
  List<DateTime> get _radarFrames{
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,24)];
  String _radarClock(DateTime t){final l=t.toLocal();final h=l.hour%12==0?12:l.hour%12;final m=l.minute.toString().padLeft(2,'0');return '$h:$m ${l.hour>=12?'PM':'AM'}';}
  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:850),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      setState(()=>_radarFrameIndex=_radarFrameIndex>=24?0:_radarFrameIndex+1);
    });
  }
  void _toggleRadarPlayback()=>setState(()=>_radarPlaying=!_radarPlaying);
"""
if field_anchor not in block: raise SystemExit('Radar state fields anchor missing')
block=block.replace(field_anchor,fields,1)

init_marker='  @override\n  void initState() {'
init_start=block.find(init_marker)
if init_start<0: raise SystemExit('map initState missing')
init_end=block.find('\n  }',init_start)
if init_end<0: raise SystemExit('map initState end missing')
if '_startRadarLoop();' not in block[init_start:init_end]: block=block[:init_end]+"\n    _startRadarLoop();"+block[init_end:]
if 'void dispose(){_radarAnimationTimer?.cancel();super.dispose();}' not in block:
    marker='  @override\n  void didUpdateWidget'
    if marker not in block: raise SystemExit('didUpdateWidget anchor missing')
    block=block.replace(marker,"  @override\n  void dispose(){_radarAnimationTimer?.cancel();super.dispose();}\n\n"+marker,1)

# Only replace the georeferenced current layer inside the intelligence map. Match URL-level text rather than the entire formatted widget.
old_url="https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?"
new_url="https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?"
count=block.count(old_url)
if count<1:
    # Accept generated variants with harmless query suffixes.
    block,n=re.subn(r"https://opengeo\.ncep\.noaa\.gov/geoserver/conus/conus_bref_qcd/ows\?[^']*",new_url,block)
    count=n
else:
    block=block.replace(old_url,new_url)
if count<1: raise SystemExit('No static NOAA radar service URL found in intelligence map')

block=block.replace("layers:const ['conus_bref_qcd']","layers:const ['0']")
# Add the WMS TIME dimension anywhere the time-enabled service is configured.
time_line="layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',"
if time_line in block:
    block=block.replace(time_line,time_line+"\n                              otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()},")
else:
    # Whitespace-tolerant fallback.
    block,n=re.subn(r"(layers\s*:\s*const\s*\['0'\]\s*,\s*format\s*:\s*'image/png'\s*,\s*transparent\s*:\s*true\s*,\s*version\s*:\s*'1\.3\.0'\s*,)",r"\1\n                              otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()},",block)
    if n<1: raise SystemExit('Could not attach TIME dimension to NOAA radar layer')

controls_anchor="""                      Positioned(
                        top: 14,
                        right: 14,
"""
weather_controls="""                      if(_showRadar)Positioned(
                        left:14,right:14,bottom:14,
                        child:Container(
                          padding:const EdgeInsets.fromLTRB(10,8,10,7),
                          decoration:BoxDecoration(color:const Color(0xFF071321).withOpacity(.94),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.28)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.35),blurRadius:14)]),
                          child:Column(mainAxisSize:MainAxisSize.min,children:[
                            Row(children:[
                              IconButton.filledTonal(tooltip:_radarPlaying?'Pause weather motion':'Play weather motion',onPressed:_toggleRadarPlayback,icon:Icon(_radarPlaying?Icons.pause_rounded:Icons.play_arrow_rounded,size:20)),
                              const SizedBox(width:7),const _PulseDot(color:AppTheme.green),const SizedBox(width:6),
                              const Text('NOAA WEATHER MOTION',style:TextStyle(color:Colors.white,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.6)),
                              const SizedBox(width:8),Expanded(child:Slider(value:_radarFrameIndex.toDouble(),min:0,max:24,divisions:24,onChanged:(v)=>setState((){_radarPlaying=false;_radarFrameIndex=v.round();}))),
                              const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(8)),child:Text('${_radarClock(_radarFrame)}${_radarFrameIndex==24?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900))),
                            ]),
                            const Padding(padding:EdgeInsets.only(left:44,right:8),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                              Text('-4h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-3½h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-3h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-2½h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-2h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-1½h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-1h',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('-30m',style:TextStyle(color:AppTheme.textMuted,fontSize:7)),Text('Now',style:TextStyle(color:AppTheme.cyan,fontSize:7,fontWeight:FontWeight.w900)),
                            ])),
                          ]),
                        ),
                      ),
"""
if controls_anchor not in block: raise SystemExit('map controls anchor missing')
block=block.replace(controls_anchor,weather_controls+controls_anchor,1)

old_toggle="_MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide live NOAA radar':'Show live NOAA radar',onTap:()=>setState(()=>_showRadar=!_showRadar)),"
new_toggle="_MapControlButton(icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,tooltip:_showRadar?'Hide animated NOAA weather':'Show animated NOAA weather',onTap:()=>setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=24;_radarPlaying=true;}})),"
if old_toggle not in block: raise SystemExit('radar toggle anchor missing')
block=block.replace(old_toggle,new_toggle,1)
block=block.replace('left:14,bottom:14,\n                          child:GestureDetector(', 'left:14,top:14,\n                          child:GestureDetector(',1)

text=text[:start]+block+text[end:]
text=text.replace('Live NOAA Radar','NOAA Weather Motion')
text=text.replace('LIVE NOAA RADAR • TAP TO ZOOM','NOAA WEATHER • TAP TO EXPAND')
for marker in ['NOAA WEATHER MOTION','Pause weather motion','radar_base_reflectivity_time/ImageServer/WMSServer',"otherParameters:{'TIME'",'-30m']:
    if marker not in text: raise SystemExit(f'missing weather v190 marker {marker}')
if text==original: raise SystemExit('No animated NOAA weather changes applied')
p.write_text(text,encoding='utf-8')
print(f'Applied NOAA time-enabled animated weather loop with play/pause and timeline v190; replaced {count} radar service URL(s)')
