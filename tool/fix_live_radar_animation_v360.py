from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v360-live-radar-persistence'

# This patch runs late in the generated release graph, after the existing NOAA
# frame verification/preload/resilience layers. It intentionally changes only
# radar playback/rendering behavior and leaves source truth / state access alone.
required = [
    '_loadNoaaRadarFramesV271',
    '_radarFrameParamV271',
    '_radarIsLatestV271',
    'conus_bref_qcd',
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f'v360 radar contract missing: {missing}')

# Keep animation slow enough for mobile/PWA/slow-network users to perceive each
# frame and for cached/preloaded tiles to settle before the next transition.
start_match = re.search(r'void\s+_startRadarAnimation\s*\(\s*\)\s*\{', text)
if not start_match:
    raise SystemExit('v360 could not locate radar animation timer')
start = start_match.start()
end_match = re.search(r'\n\s*void\s+_setRadarPlaying(?:V271)?\s*\(', text[start_match.end():])
if not end_match:
    raise SystemExit('v360 could not bound radar animation timer')
end = start_match.end() + end_match.start()
segment = text[start:end]
segment2, timer_changes = re.subn(
    r'Timer\.periodic\(const Duration\(milliseconds:\s*\d+\)',
    'Timer.periodic(const Duration(milliseconds:2600)',
    segment,
    count=1,
)
if timer_changes != 1:
    raise SystemExit('v360 expected exactly one radar timer period')
text = text[:start] + segment2 + text[end:]

# Play from the oldest verified frame only when the user presses Play while
# already parked on NOW. Pausing mid-loop therefore resumes from the same frame.
# The timer itself stops on the newest verified frame instead of immediately
# wrapping and making NOW disappear.
play_match = re.search(r'void\s+_setRadarPlayingV271\s*\(\s*bool\s+value\s*\)\s*\{', text)
if not play_match:
    raise SystemExit('v360 could not locate v271 radar play control')
play_start = play_match.start()
brace = play_match.end() - 1
depth = 0
quote = None
escaped = False
play_end = None
for i in range(brace, len(text)):
    ch = text[i]
    if quote:
        if escaped:
            escaped = False
        elif ch == '\\':
            escaped = True
        elif ch == quote:
            quote = None
        continue
    if ch in "'\"":
        quote = ch
        continue
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            play_end = i + 1
            break
if play_end is None:
    raise SystemExit('v360 could not parse radar play control')
old_play = text[play_start:play_end]
new_play = """void _setRadarPlayingV271(bool value){
    if(value && _radarFrames.length>1 && _radarFrameIndex>=_radarFrames.length-1){
      setState((){
        _radarFrameIndex=0;
        _radarFrame=_radarFrames.first;
        _radarRevision++;
        _radarPlaying=true;
      });
    }else{
      setState(()=>_radarPlaying=value);
    }
    _startRadarAnimation();
  }"""
text = text[:play_start] + new_play + text[play_end:]

# Replace the timer callback's unconditional modulo wrap with a hold-on-NOW
# contract. Support both compact and formatted generated-source variants.
wrap_patterns = [
    (r"setState\(\(\)\{\s*_radarFrameIndex=\(_radarFrameIndex\+1\)%_radarFrames\.length;\s*_radarFrame=_radarFrames\[_radarFrameIndex\];\s*_radarRevision\+\+;\s*\}\);",
     "if(_radarFrameIndex>=_radarFrames.length-1){setState(()=>_radarPlaying=false);}else{setState((){_radarFrameIndex++;_radarFrame=_radarFrames[_radarFrameIndex];_radarRevision++;});}"),
]
wrap_changed = 0
for pattern, replacement in wrap_patterns:
    text, n = re.subn(pattern, replacement, text, count=1)
    wrap_changed += n
if wrap_changed != 1:
    raise SystemExit(f'v360 expected one radar modulo-wrap callback, changed {wrap_changed}')

# Find the active NOAA WMS radar widget in the final generated FlutterMap child
# list. We retain it as the animated foreground, but crossfade old/new frame
# layers for 1.6s. A stable current-reflectivity safety TileLayer sits behind
# historical playback only; if a historical tile is late/missing, a valid NOAA
# image remains instead of the map flashing blank. At NOW the safety layer is
# removed so the newest frame is not double-rendered.
radar_anchor = "_radarFrameParamV271"
param_idx = text.find(radar_anchor)
if param_idx < 0:
    raise SystemExit('v360 active radar parameters not found')
widget_start = text.rfind('if(_showRadar)', 0, param_idx)
if widget_start < 0:
    raise SystemExit('v360 active radar widget start not found')

# Generated map radar widgets are compact, but parse balanced delimiters rather
# than relying on indentation/line numbers so future responsive edits survive.
pos = text.find('(', widget_start)
if pos < 0 or pos > param_idx:
    raise SystemExit('v360 radar widget opening parenthesis not found')
depth = 0
quote = None
escaped = False
widget_close = None
for i in range(pos, len(text)):
    ch = text[i]
    if quote:
        if escaped:
            escaped = False
        elif ch == '\\':
            escaped = True
        elif ch == quote:
            quote = None
        continue
    if ch in "'\"":
        quote = ch
        continue
    if ch == '(':
        depth += 1
    elif ch == ')':
        depth -= 1
        if depth == 0:
            widget_close = i + 1
            break
if widget_close is None:
    raise SystemExit('v360 could not parse active radar widget')
if widget_close < len(text) and text[widget_close] == ',':
    widget_close += 1
animated = text[widget_start:widget_close]
if 'TileLayer' not in animated or 'conus_bref_qcd' not in animated:
    raise SystemExit('v360 active radar widget is not expected NOAA TileLayer')

# Turn the original conditional TileLayer into a child expression for the
# AnimatedSwitcher without touching its verified TIME semantics / tile provider.
animated_child = animated
animated_child = re.sub(r'^if\(_showRadar\)', '', animated_child, count=1)
animated_child = animated_child.rstrip(',')

safety = """if(_showRadar && !_radarIsLatestV271)Opacity(
              opacity:.34,
              child:TileLayer(
                key:const ValueKey('noaa-radar-safety-v360-live'),
                wmsOptions:WMSTileLayerOptions(
                  baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows',
                  layers:const ['conus_bref_qcd'],
                  format:'image/png',
                  transparent:true,
                ),
                userAgentPackageName:'com.bridgepoint.intelligence',
                maxZoom:9,
                panBuffer:3,
                keepBuffer:3,
                tileProvider:NetworkTileProvider(),
              ),
            ),
            if(_showRadar)AnimatedSwitcher(
              duration:const Duration(milliseconds:1600),
              switchInCurve:Curves.easeOut,
              switchOutCurve:Curves.easeIn,
              layoutBuilder:(current,previous)=>Stack(
                fit:StackFit.expand,
                children:[...previous,if(current!=null)current],
              ),
              child:""" + animated_child + """,
            ),"""
text = text[:widget_start] + safety + text[widget_close:]

# Release-time assertions: useful initial current radar, no fast loop, explicit
# slow-network persistence layer, crossfade, and hold-on-NOW behavior.
assertions = [
    "milliseconds:2600",
    "noaa-radar-safety-v360-live",
    "Duration(milliseconds:1600)",
    "_radarFrameIndex>=_radarFrames.length-1",
    "setState(()=>_radarPlaying=false)",
    "_showRadar=true",
    "_radarPlaying=false",
]
missing_after = [needle for needle in assertions if needle not in text]
if missing_after:
    raise SystemExit(f'v360 output contract missing: {missing_after}')
if 'milliseconds:850' in text:
    raise SystemExit('v360 fast 850ms radar playback remains')

if marker not in text:
    text += "\nconst String _bridgePointLiveRadarV360='bridgepoint-v360-live-radar-persistence | hold-now | 2600ms-dwell | 1600ms-crossfade | latest-safety-layer';\n"

path.write_text(text, encoding='utf-8')
print('BridgePoint v360 live radar persistence/playback contract applied')
