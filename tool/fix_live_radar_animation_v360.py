from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v360-live-radar-persistence'

required = [
    '_loadNoaaRadarFramesV271',
    '_radarIsLatestV271',
    '_radarPlaying',
    '_startRadarLoop',
    '_toggleRadarPlayback',
    'radar_base_reflectivity_time/ImageServer/WMSServer',
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f'v360 radar contract missing: {missing}')

# 1) Playback: make each verified frame perceptible, preserve pause/resume position,
# and hold on the newest verified NOW frame instead of instantly wrapping away.
old_loop = """  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:1800),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      setState((){final last=_radarFrames.length-1;_radarFrameIndex=_radarFrameIndex>=last?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});
    });
  }
  void _toggleRadarPlayback()=>setState(()=>_radarPlaying=!_radarPlaying);"""
new_loop = """  void _startRadarLoop(){
    _radarAnimationTimer?.cancel();
    _radarAnimationTimer=Timer.periodic(const Duration(milliseconds:2600),(_){
      if(!mounted||!_radarPlaying||!_showRadar)return;
      final last=_radarFrames.length-1;
      if(last<=0||_radarFrameIndex>=last){setState(()=>_radarPlaying=false);return;}
      setState((){
        _radarFrameIndex++;
        _radarRevision++;
        if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;
        if(_radarFrameIndex>=last)_radarPlaying=false;
      });
    });
  }
  void _toggleRadarPlayback(){
    if(_radarPlaying){setState(()=>_radarPlaying=false);return;}
    setState((){
      final last=_radarFrames.length-1;
      if(last<=0){_radarPlaying=false;return;}
      if(_radarFrameIndex>=last){_radarFrameIndex=0;_radarRevision++;}
      _radarPlaying=true;
    });
  }"""
if text.count(old_loop) != 1:
    raise SystemExit(f'v360 expected one evolved radar loop, found {text.count(old_loop)}')
text = text.replace(old_loop, new_loop, 1)

# 2) Frame refresh: a periodic metadata refresh must not snap a user who is
# paused/playing a historical frame back to NOW, and a transient frame-RPC error
# must never discard the last verified frame list. Initial fallback still renders
# useful current NOAA radar without a guessed TIME parameter.
old_refresh = """      setState((){
        _noaaRadarFramesV271=next.length>25?next.sublist(next.length-25):next;
        _radarFrameIndex=_noaaRadarFramesV271.length-1;
        _radarRevision++;
      });
    }catch(_){if(mounted)setState((){_weatherAllowedV318=true;_noaaRadarFramesV271=<DateTime>[];_radarFrameIndex=0;_radarRevision++;});}"""
new_refresh = """      final priorFrame=_radarFrame;
      final wasLatest=_radarIsLatestV271;
      final hadVerified=_noaaRadarFramesV271.length>=2;
      setState((){
        _noaaRadarFramesV271=next.length>25?next.sublist(next.length-25):next;
        final last=_noaaRadarFramesV271.length-1;
        if(!hadVerified||wasLatest){
          _radarFrameIndex=last;
        }else{
          final exact=_noaaRadarFramesV271.indexWhere((f)=>f.isAtSameMomentAs(priorFrame));
          _radarFrameIndex=exact>=0?exact:_radarFrameIndex.clamp(0,last);
        }
        _radarRevision++;
      });
    }catch(_){
      if(mounted&&_noaaRadarFramesV271.isEmpty)setState((){_weatherAllowedV318=true;_radarFrameIndex=0;_radarRevision++;});
    }"""
if text.count(old_refresh) != 1:
    raise SystemExit(f'v360 expected one evolved frame refresh block, found {text.count(old_refresh)}')
text = text.replace(old_refresh, new_refresh, 1)

# 3) Renderer persistence: V350/V321 used a per-frame ValueKey. That disposes the
# entire TileLayer on every frame and defeats flutter_map's tile reload/fade path,
# producing blank flashes on mobile/PWA/slow networks. Keep one stable stateful
# TileLayer while WMS TIME changes so already-visible tiles remain available until
# replacements load. Existing TileDisplay.fadeIn behavior can then do its job.
old_key = "key:ValueKey('noaa-radar-$_radarRevision-${_radarIsLatestV271?'live':_radarFrame.toIso8601String()}'),"
new_key = "key:const ValueKey('noaa-radar-timeline-v360'),"
if text.count(old_key) != 1:
    raise SystemExit(f'v360 expected one dynamic Intelligence Map radar key, found {text.count(old_key)}')
text = text.replace(old_key, new_key, 1)

# Ensure the active Intelligence Map radar still uses buffered/faded tiles. Do not
# change other map/weather renderers or increase database/API polling.
anchor = "if(_weatherAllowedV318&&_showRadar)Opacity(opacity:.88,child:TileLayer("
start = text.find(anchor)
if start < 0:
    raise SystemExit('v360 active Intelligence Map radar TileLayer not found')
end = text.find("if(_weatherAllowedV318&&_showRadar)Positioned(", start)
if end < 0:
    raise SystemExit('v360 could not bound Intelligence Map radar TileLayer')
radar_segment = text[start:end]
for needle in [
    "noaa-radar-timeline-v360",
    "radar_base_reflectivity_time/ImageServer/WMSServer",
    "otherParameters:_radarTimeParametersV271",
    "tileDisplay:const TileDisplay.fadeIn",
    "keepBuffer:",
]:
    if needle not in radar_segment:
        raise SystemExit(f'v360 radar persistence prerequisite missing: {needle}')

# Release assertions against regressions.
for forbidden in [
    "Timer.periodic(const Duration(milliseconds:1800)",
    "_radarFrameIndex=_radarFrameIndex>=last?0:_radarFrameIndex+1",
    "_noaaRadarFramesV271=<DateTime>[];_radarFrameIndex=0",
    old_key,
]:
    if forbidden in text:
        raise SystemExit(f'v360 radar regression remains: {forbidden}')
for required_after in [
    "Duration(milliseconds:2600)",
    "if(_radarFrameIndex>=last){_radarFrameIndex=0;_radarRevision++;}",
    "if(_radarFrameIndex>=last)_radarPlaying=false;",
    "final wasLatest=_radarIsLatestV271;",
    "if(mounted&&_noaaRadarFramesV271.isEmpty)",
    "noaa-radar-timeline-v360",
]:
    if required_after not in text:
        raise SystemExit(f'v360 output contract missing: {required_after}')

if marker not in text:
    text += "\nconst String _bridgePointLiveRadarV360='bridgepoint-v360-live-radar-persistence | stable tile layer | 2600ms dwell | pause-resume | hold NOW | preserve verified frames on refresh failure';\n"

path.write_text(text, encoding='utf-8')
print('BRIDGEPOINT LIVE RADAR V360 APPLIED')
print(' - stable Intelligence Map radar TileLayer preserves prior visible tiles during TIME reloads')
print(' - 2.6s verified-frame dwell; pause/resume keeps position')
print(' - playback stops and holds on newest verified NOW frame')
print(' - periodic frame refresh preserves historical selection; transient RPC failure keeps verified frames')
