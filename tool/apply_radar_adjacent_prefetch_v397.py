from pathlib import Path

p=Path('lib/main.dart')
t=p.read_text(encoding='utf-8')
marker='bridgepoint-v397-radar-adjacent-prefetch'
if marker in t:
    print('v397 already applied')
    raise SystemExit(0)

for required in [
    'bridgepoint-v395-radar-layer-identity',
    "key:const ValueKey('noaa-radar-current-v395')",
    "key:const ValueKey('noaa-radar-prev-v395')",
    'Timer.periodic(const Duration(milliseconds:3400)',
]:
    if required not in t:
        raise SystemExit(f'v397 prerequisite missing: {required}')

# V395 preserves the currently visible and prior frame. V397 adds a deliberately
# almost-transparent NEXT-frame TileLayer so browser/flutter_map tile caches warm
# the exact WMS URLs before playback advances. This prevents a slow historical
# request from making the next frame appear only at the end of its dwell interval.
current_anchor="""                        if(_weatherAllowedV318&&_showRadar)Opacity(opacity:.88,child:TileLayer(
                          key:const ValueKey('noaa-radar-current-v395'),
"""
if t.count(current_anchor)!=1:
    raise SystemExit('v397 current radar anchor drift')

prefetch="""                        if(_weatherAllowedV318&&_showRadar&&_radarFrames.length>1&&_radarFrameIndex<_radarFrames.length-1)IgnorePointer(child:Opacity(opacity:.001,child:TileLayer(
                          key:const ValueKey('noaa-radar-next-v397'),
                          wmsOptions:WMSTileLayerOptions(
                            baseUrl:_radarFrameIndex+1>=_radarFrames.length-1?'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?_bp=$_radarRevision&':'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                            layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',
                            otherParameters:_radarFrameIndex+1>=_radarFrames.length-1?const <String,String>{}:<String,String>{'TIME':_radarFrames[_radarFrameIndex+1].toUtc().toIso8601String()},
                          ),
                          maxNativeZoom:12,panBuffer:0,keepBuffer:2,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:120),startOpacity:1,reloadStartOpacity:1),userAgentPackageName:'com.bridgepoint.data_studio',
                        ))),
"""
t=t.replace(current_anchor,prefetch+current_anchor,1)

# Keep NOW fresh while retaining a stable stateful TileLayer. The query revision
# changes the tile URL without changing the widget key, so the old visible tiles
# remain until the new current tiles arrive. The hidden prefetch uses the same
# revision when its next frame is NOW, allowing an immediate cache hit on advance.
old_latest="baseUrl:_radarIsLatestV271?'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?':'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',"
new_latest="baseUrl:_radarIsLatestV271?'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?_bp=$_radarRevision&':'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',"
if t.count(old_latest)!=1:
    raise SystemExit(f'v397 expected one current latest base URL, found {t.count(old_latest)}')
t=t.replace(old_latest,new_latest,1)

# Do not discard a last-good current radar frame while the next one is being warmed.
# V395 already gives the current layer reloadStartOpacity=1 and a perceptible prior
# layer; assert both contracts remain so prefetch cannot regress continuity.
for expected in [
    "key:const ValueKey('noaa-radar-next-v397')",
    "opacity:.001",
    "_radarFrames[_radarFrameIndex+1].toUtc().toIso8601String()",
    "MapServer/WMSServer?_bp=$_radarRevision&",
    "key:const ValueKey('noaa-radar-current-v395')",
    "key:const ValueKey('noaa-radar-prev-v395')",
    'reloadStartOpacity:1',
    'Duration(milliseconds:3400)',
]:
    if expected not in t:
        raise SystemExit(f'v397 output contract missing: {expected}')

for forbidden in [
    "key:ValueKey('noaa-radar-current-v391-",
    "key:ValueKey('noaa-radar-prev-v391-",
    'Timer.periodic(const Duration(milliseconds:1800)',
    'Timer.periodic(const Duration(milliseconds:2600)',
]:
    if forbidden in t:
        raise SystemExit(f'v397 radar regression remains: {forbidden}')

t += "\nconst String _bridgePointRadarAdjacentPrefetchV397='bridgepoint-v397-radar-adjacent-prefetch | next-frame WMS cache warm | fresh NOW revision | preserved current+prior frames | 3400ms dwell';\n"
p.write_text(t,encoding='utf-8')
print('BRIDGEPOINT RADAR V397 APPLIED')
print(' - hidden adjacent next-frame WMS prefetch warms browser/flutter_map cache')
print(' - NOW gets a cache-busting revision without changing current TileLayer identity')
print(' - current/prior visible frames remain preserved during slow or failed next-frame loads')
