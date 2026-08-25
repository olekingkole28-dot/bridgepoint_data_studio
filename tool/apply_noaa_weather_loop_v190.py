from pathlib import Path
import re

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
if start<0:
    start=text.find('class _IntelligenceMapPageState')
if start<0:
    raise SystemExit('v830 Intelligence Map state missing')

# Work from stable semantic positions instead of trying to parse the entire Dart
# class. Generated Dart contains nested string interpolation such as
# '${map['key']}', which makes simplistic quote/brace scanners unreliable.
show_radar=text.find('bool _showRadar = true;',start)
if show_radar<0:
    raise SystemExit('v830 radar state field missing')
main_radar_if=text.find('if (_showRadar)',show_radar)
if main_radar_if<0:
    raise SystemExit('v830 main radar condition missing')
main_tile=text.find('TileLayer(',main_radar_if)
main_wms=text.find('WMSTileLayerOptions(',main_tile)
marker_layer=text.find('MarkerLayer(markers: markers)',main_wms)
if min(main_tile,main_wms,marker_layer)<0 or not (main_radar_if<main_tile<main_wms<marker_layer):
    raise SystemExit('v830 main radar TileLayer/WMS sequence missing')
radar_probe=text[main_wms:marker_layer]
if not any(token in radar_probe.lower() for token in ('conus_bref_qcd','radar','reflectivity','ncep')):
    raise SystemExit('v830 main WMS did not validate as radar')

# Playback state immediately follows _showRadar.
if '_radarAnimationTimer' not in text[show_radar:main_radar_if]:
    field='bool _showRadar = true;'
    fields="""bool _showRadar = true;
  Timer? _radarAnimationTimer;
  bool _radarPlaying=true;
  int _radarFrameIndex=48;
  List<DateTime> get _radarFrames{
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/5)*5);
    return List.generate(49,(index)=>rounded.subtract(Duration(minutes:(48-index)*5)));
  }
  DateTime get _radarFrame=>_radarFrames[_radarFrameIndex.clamp(0,48)];
  String _radarClock(DateTime t){
    final l=t.toLocal();
    final h=l.hour%12==0?12:l.hour%12;
    return '$h:${l.minute.toString().padLeft(2,'0')} ${l.hour>=12?'PM':'AM'}';
  }
  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:700),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      final step=_viewportZoom>=8.5?2:1;
      setState(()=>_radarFrameIndex=_radarFrameIndex+step>48?0:_radarFrameIndex+step);
    });
  }
  void _toggleRadarPlayback()=>setState(()=>_radarPlaying=!_radarPlaying);"""
    text=text[:show_radar]+text[show_radar:].replace(field,fields,1)
    # Recompute positions after insertion.
    show_radar=text.find('bool _showRadar = true;',start)
    main_radar_if=text.find('if (_showRadar)',show_radar)
    main_tile=text.find('TileLayer(',main_radar_if)
    main_wms=text.find('WMSTileLayerOptions(',main_tile)
    marker_layer=text.find('MarkerLayer(markers: markers)',main_wms)

# Start playback in the first Intelligence Map initState. Insert immediately
# before the first dispose override rather than brace-parsing initState.
init=text.find('void initState()',start,main_radar_if)
first_dispose=text.find('void dispose()',init,main_radar_if)
if init<0 or first_dispose<0:
    raise SystemExit('v830 map init/dispose anchors missing')
if '_startRadarLoop();' not in text[init:first_dispose]:
    init_segment=text[init:first_dispose]
    close=init_segment.rfind('\n  }')
    if close<0:
        raise SystemExit('v830 initState closing boundary missing')
    init_segment=init_segment[:close]+'\n    _startRadarLoop();'+init_segment[close:]
    text=text[:init]+init_segment+text[first_dispose:]

# Consolidate duplicate generated dispose methods into one safe lifecycle hook.
# The current replay has one radar-refresh dispose and one viewport dispose.
first_dispose=text.find('void dispose()',init,main_radar_if)
did_update=text.find('void didUpdateWidget',first_dispose,main_radar_if)
if first_dispose<0 or did_update<0:
    raise SystemExit('v830 dispose/didUpdateWidget boundaries missing')
first_override=text.rfind('@override',init,first_dispose)
did_override=text.rfind('@override',first_dispose,did_update)
if first_override<0 or did_override<0:
    raise SystemExit('v830 lifecycle override boundaries missing')
lifecycle=text[first_override:did_override]
if lifecycle.count('void dispose()')>=1:
    merged="""@override
  void dispose(){
    _radarAnimationTimer?.cancel();
    _radarRefreshTimer?.cancel();
    _viewportRefreshTimer?.cancel();
    super.dispose();
  }

  """
    text=text[:first_override]+merged+text[did_override:]

# Recompute main WMS positions after lifecycle edits.
show_radar=text.find('bool _showRadar = true;',start)
main_radar_if=text.find('if (_showRadar)',show_radar)
main_tile=text.find('TileLayer(',main_radar_if)
main_wms=text.find('WMSTileLayerOptions(',main_tile)
marker_layer=text.find('MarkerLayer(markers: markers)',main_wms)
if min(main_radar_if,main_tile,main_wms,marker_layer)<0:
    raise SystemExit('v830 main radar anchors lost after lifecycle repair')

# Extract just the main WMS options using the known MarkerLayer boundary.
wms_segment=text[main_wms:marker_layer]
# Find the options call close by parenthesis depth. No Dart-string brace parsing is needed.
depth=0;wms_end_rel=None
for i,ch in enumerate(wms_segment):
    if ch=='(': depth+=1
    elif ch==')':
        depth-=1
        if depth==0:
            wms_end_rel=i+1
            break
if wms_end_rel is None:
    raise SystemExit('v830 radar WMS options unterminated')
wms=text[main_wms:main_wms+wms_end_rel]
new_url='https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?'
base_pat=re.compile(r"baseUrl\s*:\s*'[^']*'",re.S)
layer_pat=re.compile(r"layers\s*:\s*const\s*\[[^\]]+\]",re.S)
if not base_pat.search(wms) or not layer_pat.search(wms):
    raise SystemExit('v830 radar WMS base/layer fields missing')
wms=base_pat.sub(f"baseUrl:'{new_url}'",wms,count=1)
wms=layer_pat.sub("layers:const ['0']",wms,count=1)
if 'otherParameters:' not in wms:
    close=wms.rfind(')')
    wms=wms[:close]+"otherParameters:{'TIME':_radarFrame.toUtc().toIso8601String()},\n"+wms[close:]
text=text[:main_wms]+wms+text[main_wms+wms_end_rel:]

# Gate only the main raw-radar layer at deep property zoom.
main_radar_if=text.find('if (_showRadar)',show_radar)
main_tile=text.find('TileLayer(',main_radar_if)
if main_radar_if<0 or main_tile<0 or main_tile-main_radar_if>250:
    raise SystemExit('v830 main radar condition/tile adjacency missing')
text=text[:main_radar_if]+text[main_radar_if:main_tile].replace('if (_showRadar)','if (_showRadar && _viewportZoom <= 10.5)',1)+text[main_tile:]

# Add the timeline immediately before the existing top-right map controls.
controls=text.find('Positioned(',main_tile)
while controls>=0:
    probe=text[controls:controls+240]
    if re.search(r'top\s*:\s*14',probe) and re.search(r'right\s*:\s*14',probe):
        break
    controls=text.find('Positioned(',controls+1)
if controls<0:
    raise SystemExit('v830 map controls anchor missing')
if 'NOAA MRMS • ~1 KM SOURCE RESOLUTION' not in text[start:controls]:
    weather="""if (_showRadar && _viewportZoom <= 10.5)
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
                      """
    text=text[:controls]+weather+text[controls:]

# Formatting-tolerant radar control replacement. Restrict to the first control
# after the Intelligence Map build and before expansion control.
control_start=text.find('_MapControlButton(',controls)
replaced_toggle=False
while control_start>=0:
    next_control=text.find('_MapControlButton(',control_start+1)
    segment=text[control_start: next_control if next_control>0 else control_start+1800]
    if '_showRadar' in segment and 'Icons.radar_rounded' in segment:
        # Locate the call end by parenthesis depth; this is local and contains no problematic braces.
        depth=0;end_call=None
        for i,ch in enumerate(text[control_start:control_start+2200]):
            if ch=='(': depth+=1
            elif ch==')':
                depth-=1
                if depth==0:
                    end_call=control_start+i+1
                    break
        if end_call is None:
            raise SystemExit('v830 radar control call unterminated')
        replacement="""_MapControlButton(
                                icon:_showRadar?Icons.radar_rounded:Icons.hide_source_rounded,
                                tooltip:_showRadar?'Hide animated NOAA radar':'Show animated NOAA radar',
                                onTap:()=>setState((){_showRadar=!_showRadar;if(_showRadar){_radarFrameIndex=48;_radarPlaying=true;}}))"""
        text=text[:control_start]+replacement+text[end_call:]
        replaced_toggle=True
        break
    control_start=next_control
if not replaced_toggle:
    raise SystemExit('v830 radar toggle control missing')

text=text.replace('Live NOAA Radar','NOAA Weather Motion')
text=text.replace('LIVE NOAA RADAR • TAP TO ZOOM','NOAA WEATHER • TAP TO EXPAND')

required=[
    'NOAA MRMS • ~1 KM SOURCE RESOLUTION',
    'Pause weather motion',
    'radar_base_reflectivity_time/ImageServer/WMSServer',
    "'TIME':_radarFrame",
    '_viewportZoom <= 10.5',
    'stops over-zooming it here',
    'max:48',
    '_radarAnimationTimer?.cancel();',
    '_radarRefreshTimer?.cancel();',
    '_viewportRefreshTimer?.cancel();',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f'missing NOAA v830 marker {marker}')
# Ensure duplicate map dispose declarations were removed in the state prefix.
prefix_end=text.find('void didUpdateWidget',start)
if prefix_end<0 or text[start:prefix_end].count('void dispose()')!=1:
    raise SystemExit('v830 map dispose consolidation failed')
if text==original:
    raise SystemExit('No NOAA weather v830 changes applied')
p.write_text(text,encoding='utf-8')
print('Applied generated-shape NOAA weather timeline + consolidated map lifecycle v830')
