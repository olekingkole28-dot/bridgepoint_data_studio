from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v360-live-radar-persistence'

# This patch runs late in the generated release graph, after the existing NOAA
# verified-frame/preload/resilience layers. Never silently fall back to an older
# renderer contract: print the evolved radar neighborhoods and fail closed.
required = ['_loadNoaaRadarFramesV271', '_radarIsLatestV271', '_radarPlaying']
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f'v360 radar control contract missing: {missing}')

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

# Hold the newest verified frame instead of immediately wrapping to the oldest.
pattern = r"setState\(\(\)\{\s*_radarFrameIndex=\(_radarFrameIndex\+1\)%_radarFrames\.length;\s*_radarFrame=_radarFrames\[_radarFrameIndex\];\s*_radarRevision\+\+;\s*\}\);"
replacement = "if(_radarFrameIndex>=_radarFrames.length-1){setState(()=>_radarPlaying=false);}else{setState((){_radarFrameIndex++;_radarFrame=_radarFrames[_radarFrameIndex];_radarRevision++;});}"
text, wrap_changed = re.subn(pattern, replacement, text, count=1)
if wrap_changed != 1:
    raise SystemExit(f'v360 expected one radar modulo-wrap callback, changed {wrap_changed}')

# V319/V321 may evolve the actual radar renderer independently from the V271
# frame-control API. Locate the shipping renderer by its permanent preload markers.
renderer_needles = ['bp-us-radar-preloaded', 'weather-center-radar-preloaded', 'iso-wms-preloaded-radar']
renderer_hits = [(needle, text.find(needle)) for needle in renderer_needles if text.find(needle) >= 0]
if not renderer_hits:
    raise SystemExit('v360 could not locate evolved preloaded radar renderer markers')

# Diagnostic until V360 is aligned to the evolved renderer. This is intentionally
# fail-closed and prints only source neighborhoods, never secrets or runtime data.
if marker not in text:
    for needle, idx in renderer_hits:
        lo = max(0, idx - 1800)
        hi = min(len(text), idx + 2200)
        print(f'V360_RENDERER_NEIGHBORHOOD_BEGIN {needle}')
        print(text[lo:hi])
        print(f'V360_RENDERER_NEIGHBORHOOD_END {needle}')
    # Also expose the current radar control/timer neighborhood.
    idx = text.find('_radarPlaying')
    if idx >= 0:
        print('V360_CONTROL_NEIGHBORHOOD_BEGIN')
        print(text[max(0, idx-1000):min(len(text), idx+3500)])
        print('V360_CONTROL_NEIGHBORHOOD_END')
    raise SystemExit('v360 renderer inspection required before persistence layer can be applied safely')

path.write_text(text, encoding='utf-8')
