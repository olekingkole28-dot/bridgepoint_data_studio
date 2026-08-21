from pathlib import Path

p = Path('lib/main.dart')
t = p.read_text(encoding='utf-8')
marker = 'bridgepoint-v395-radar-layer-identity'
if marker in t:
    print('v395 already applied')
    raise SystemExit(0)

for required in [
    'bridgepoint-v360-live-radar-persistence',
    'bridgepoint-v391-map-clean-radar',
    "noaa-radar-current-v391-${_radarFrameIndex.clamp(0,_radarFrames.length-1)}-${_radarIsLatestV271?_radarRevision:0}",
    "noaa-radar-prev-v391-${_radarPreviousFrameIndexV391.clamp(0,_radarFrames.length-1)}",
]:
    if required not in t:
        raise SystemExit(f'v395 prerequisite missing: {required}')

# V391 reintroduced per-frame ValueKeys after V360 had intentionally stabilized the
# radar TileLayer. A changing key disposes the TileLayer at every animation tick, so
# slow NOAA WMS tiles can leave the map blank until a new frame finally arrives.
# Keep both timeline layers stateful while their WMS TIME parameters change so
# flutter_map can retain already-visible tiles during reload/crossfade.
t = t.replace(
    "key:ValueKey('noaa-radar-prev-v391-${_radarPreviousFrameIndexV391.clamp(0,_radarFrames.length-1)}'),",
    "key:const ValueKey('noaa-radar-prev-v395'),",
    1,
)
t = t.replace(
    "key:ValueKey('noaa-radar-current-v391-${_radarFrameIndex.clamp(0,_radarFrames.length-1)}-${_radarIsLatestV271?_radarRevision:0}'),",
    "key:const ValueKey('noaa-radar-current-v395'),",
    1,
)

# Make the retained prior frame strong enough to remain perceptible while a slower
# current frame is loading, without overpowering the active frame once it arrives.
t = t.replace(
    "if(_weatherAllowedV318&&_showRadar&&_radarPlaying&&_radarFrames.length>1)Opacity(opacity:.22,child:TileLayer(",
    "if(_weatherAllowedV318&&_showRadar&&_radarPlaying&&_radarFrames.length>1)Opacity(opacity:.36,child:TileLayer(",
    1,
)

# Ensure both layers retain a useful tile buffer for mobile/PWA pan/zoom and slow
# network reloads. The current layer already fades in; preserving its identity makes
# reloadStartOpacity meaningful instead of recreating the subtree.
t = t.replace(
    "maxNativeZoom:12,panBuffer:0,keepBuffer:2,userAgentPackageName:'com.bridgepoint.data_studio',",
    "maxNativeZoom:12,panBuffer:1,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:700),startOpacity:.55,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',",
    1,
)

for forbidden in [
    "key:ValueKey('noaa-radar-current-v391-",
    "key:ValueKey('noaa-radar-prev-v391-",
]:
    if forbidden in t:
        raise SystemExit(f'v395 dynamic radar key remains: {forbidden}')

for expected in [
    "key:const ValueKey('noaa-radar-current-v395')",
    "key:const ValueKey('noaa-radar-prev-v395')",
    'Timer.periodic(const Duration(milliseconds:3400)',
    'reloadStartOpacity:1',
]:
    if expected not in t:
        raise SystemExit(f'v395 output contract missing: {expected}')

t += "\nconst String _bridgePointRadarLayerIdentityV395='bridgepoint-v395-radar-layer-identity | stable current+prior tile layers | retained visible frame during NOAA WMS reload | 3400ms dwell';\n"
p.write_text(t, encoding='utf-8')
print('BRIDGEPOINT RADAR V395 APPLIED')
print(' - stable current and prior radar TileLayer identities')
print(' - prior frame remains perceptible while slow tiles load')
print(' - buffered fade/reload preserves visible radar across playback')
