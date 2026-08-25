from pathlib import Path
import re

p = Path('lib/main.dart')
text = p.read_text(encoding='utf-8')
original = text
start = text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
end = text.find('class _MapLegendDot extends StatelessWidget', start)
if start < 0 or end < 0:
    raise SystemExit('Intelligence map block missing')
block = text[start:end]

# v795: the official NOAA/NWS time-enabled MRMS service updates on a 5-minute
# cadence and the underlying composite is roughly 1 km resolution. Preserve
# that truth: animate time, but do not stretch raw reflectivity into fake
# roof-level precision when the user zooms deeply into a property.
if '_radarAnimationTimer' not in block:
    radar_line = re.search(r'(?m)^(\s*)bool\s+_showRadar\s*=\s*true;\s*$', block)
    if not radar_line:
        raise SystemExit('Radar state field missing')
    indent = radar_line.group(1)
    fields = f"""{radar_line.group(0)}
{indent}Timer? _radarAnimationTimer;
{indent}bool _radarPlaying = true;
{indent}int _radarFrameIndex = 48;
{indent}List<DateTime> get _radarFrames {{
{indent}  final now = DateTime.now().toUtc();
{indent}  final rounded = DateTime.utc(
{indent}      now.year, now.month, now.day, now.hour, (now.minute ~/ 5) * 5);
{indent}  return List.generate(
{indent}      49, (i) => rounded.subtract(Duration(minutes: (48 - i) * 5)));
{indent}}}
{indent}DateTime get _radarFrame =>
{indent}    _radarFrames[_radarFrameIndex.clamp(0, 48)];
{indent}String _radarClock(DateTime t) {{
{indent}  final l = t.toLocal();
{indent}  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
{indent}  final m = l.minute.toString().padLeft(2, '0');
{indent}  return '$h:$m ${{l.hour >= 12 ? 'PM' : 'AM'}}';
{indent}}}
{indent}void _startRadarLoop() {{
{indent}  _radarAnimationTimer?.cancel();
{indent}  _radarAnimationTimer =
{indent}      Timer.periodic(const Duration(milliseconds: 700), (_) {{
{indent}    if (!mounted || !_radarPlaying || !_showRadar) return;
{indent}    // At closer regional zoom skip alternate 5-minute frames to limit
{indent}    // unnecessary WMS tile churn while retaining the full scrub timeline.
{indent}    final step = _viewportZoom >= 8.5 ? 2 : 1;
{indent}    setState(() {{
{indent}      _radarFrameIndex =
{indent}          _radarFrameIndex + step > 48 ? 0 : _radarFrameIndex + step;
{indent}    }});
{indent}  }});
{indent}}}
{indent}void _toggleRadarPlayback() =>
{indent}    setState(() => _radarPlaying = !_radarPlaying);"""
    block = block[:radar_line.start()] + fields + block[radar_line.end():]

# Add playback startup to whatever initState shape earlier release layers leave.
if '_startRadarLoop();' not in block:
    init_at = block.find('void initState()')
    if init_at < 0:
        raise SystemExit('map initState missing')
    brace_at = block.find('{', init_at)
    depth = 0
    init_end = None
    for i in range(brace_at, len(block)):
        if block[i] == '{':
            depth += 1
        elif block[i] == '}':
            depth -= 1
            if depth == 0:
                init_end = i
                break
    if init_end is None:
        raise SystemExit('map initState end missing')
    block = block[:init_end] + '  _startRadarLoop();\n' + block[init_end:]

# v124 already owns a dispose hook in the generated release. Extend it instead
# of creating a competing lifecycle method.
if '_radarAnimationTimer?.cancel();' not in block[block.find('void dispose()') if 'void dispose()' in block else 0:]:
    dispose_at = block.find('void dispose()')
    if dispose_at >= 0:
        brace_at = block.find('{', dispose_at)
        block = block[:brace_at + 1] + '\n    _radarAnimationTimer?.cancel();' + block[brace_at + 1:]
    else:
        marker = '  @override\n  void didUpdateWidget'
        if marker not in block:
            raise SystemExit('didUpdateWidget anchor missing for radar cleanup')
        dispose = """  @override
  void dispose() {
    _radarAnimationTimer?.cancel();
    super.dispose();
  }

"""
        block = block.replace(marker, dispose + marker, 1)

old_services = [
    'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?',
    'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?',
]
new_url = 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?'
replaced = 0
for old in old_services:
    count = block.count(old)
    if count:
        block = block.replace(old, new_url)
        replaced += count
if new_url not in block:
    raise SystemExit('No NOAA radar service found in intelligence map')

# Isolate the WMS options attached to the time-enabled radar service.
url_at = block.find(new_url)
wms_at = block.rfind('WMSTileLayerOptions(', 0, url_at)
if wms_at < 0:
    raise SystemExit('NOAA WMS options missing')
depth = 0
wms_end = None
for i in range(wms_at, len(block)):
    if block[i] == '(':
        depth += 1
    elif block[i] == ')':
        depth -= 1
        if depth == 0:
            wms_end = i
            break
if wms_end is None:
    raise SystemExit('NOAA WMS options unterminated')
wms = block[wms_at:wms_end + 1]
wms = re.sub(r"layers\s*:\s*const\s*\[['\"]conus_bref_qcd['\"]\]", "layers: const ['0']", wms)
if "layers: const ['0']" not in wms and "layers:const ['0']" not in wms:
    raise SystemExit('Could not normalize NOAA WMS layer id')
if 'otherParameters:' not in wms:
    close = wms.rfind(')')
    wms = wms[:close] + "  otherParameters: {'TIME': _radarFrame.toUtc().toIso8601String()},\n" + wms[close:]
block = block[:wms_at] + wms + block[wms_end + 1:]

# Raw radar is a regional context layer. At deep property zoom hide it rather
# than scaling 1 km pixels into random-looking roof-sized color blocks.
condition_pattern = r'if\s*\(\s*_showRadar\s*\)\s*\n(\s*)TileLayer\('
if re.search(condition_pattern, block):
    block = re.sub(
        condition_pattern,
        lambda m: 'if (_showRadar && _viewportZoom <= 10.5)\n' + m.group(1) + 'TileLayer(',
        block,
        count=1,
    )
elif 'if (_showRadar && _viewportZoom <= 10.5)' not in block:
    raise SystemExit('Could not apply radar native-resolution zoom gate')

controls_anchor = """                      Positioned(
                        top: 14,
                        right: 14,
"""
if controls_anchor not in block:
    raise SystemExit('map controls anchor missing')
weather_controls = r'''                      if (_showRadar && _viewportZoom <= 10.5)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF071321).withOpacity(.94),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: AppTheme.cyan.withOpacity(.28)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(.35),
                                    blurRadius: 14)
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  IconButton.filledTonal(
                                    tooltip: _radarPlaying
                                        ? 'Pause weather motion'
                                        : 'Play weather motion',
                                    onPressed: _toggleRadarPlayback,
                                    icon: Icon(
                                        _radarPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 7),
                                  const _PulseDot(color: AppTheme.green),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'NOAA MRMS • ~1 KM SOURCE RESOLUTION',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .45),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Slider(
                                      value: _radarFrameIndex.toDouble(),
                                      min: 0,
                                      max: 48,
                                      divisions: 48,
                                      onChanged: (v) => setState(() {
                                        _radarPlaying = false;
                                        _radarFrameIndex = v.round();
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cyan.withOpacity(.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_radarClock(_radarFrame)}${_radarFrameIndex == 48 ? ' • NOW' : ''}',
                                      style: const TextStyle(
                                          color: AppTheme.cyan,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ]),
                                const Padding(
                                  padding: EdgeInsets.only(left: 44, right: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('-4h',
                                          style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 7)),
                                      Text('-3h',
                                          style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 7)),
                                      Text('-2h',
                                          style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 7)),
                                      Text('-1h',
                                          style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 7)),
                                      Text('Now',
                                          style: TextStyle(
                                              color: AppTheme.cyan,
                                              fontSize: 7,
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_showRadar && _viewportZoom > 10.5)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF071321).withOpacity(.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.amber.withOpacity(.35)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.zoom_out_map_rounded,
                                  color: AppTheme.amber, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Raw NOAA radar is ~1 km regional data, so BridgePoint stops over-zooming it here. Zoom out for reflectivity; property-level storm evidence stays separate from the raw radar pixels.',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 9,
                                      height: 1.4),
                                ),
                              ),
                            ]),
                          ),
                        ),
'''
block = block.replace(controls_anchor, weather_controls + controls_anchor, 1)

# Modern source formatting varies; replace the existing radar control structurally.
toggle_pattern = re.compile(
    r"_MapControlButton\(\s*icon:\s*_showRadar\s*\?\s*Icons\.radar_rounded\s*:\s*Icons\.hide_source_rounded,\s*"
    r"tooltip:\s*_showRadar\s*\?\s*'[^']*'\s*:\s*'[^']*',\s*"
    r"onTap:\s*\(\)\s*=>\s*setState\(\(\)\s*=>\s*_showRadar\s*=\s*!_showRadar\)\s*\)\s*\)",
    re.S,
)
replacement = """_MapControlButton(
                                icon: _showRadar
                                    ? Icons.radar_rounded
                                    : Icons.hide_source_rounded,
                                tooltip: _showRadar
                                    ? 'Hide animated NOAA radar'
                                    : 'Show animated NOAA radar',
                                onTap: () => setState(() {
                                  _showRadar = !_showRadar;
                                  if (_showRadar) {
                                    _radarFrameIndex = 48;
                                    _radarPlaying = true;
                                  }
                                }))"""
block, toggle_count = toggle_pattern.subn(replacement, block, count=1)
if toggle_count != 1:
    raise SystemExit(f'radar toggle anchor mismatch: {toggle_count}')

text = text[:start] + block + text[end:]
text = text.replace('Live NOAA Radar', 'NOAA Weather Motion')
text = text.replace('LIVE NOAA RADAR • TAP TO ZOOM',
                    'NOAA WEATHER • TAP TO EXPAND')
for marker in [
    'NOAA MRMS • ~1 KM SOURCE RESOLUTION',
    'Pause weather motion',
    'radar_base_reflectivity_time/ImageServer/WMSServer',
    "otherParameters: {'TIME'",
    '_viewportZoom <= 10.5',
    'stops over-zooming it here',
    'max: 48',
]:
    if marker not in text:
        raise SystemExit(f'missing weather v795 marker {marker}')
if text == original:
    raise SystemExit('No animated NOAA weather changes applied')
p.write_text(text, encoding='utf-8')
print(
    f'Applied NOAA time-enabled scale-aware weather v795; replaced {replaced} legacy radar URL(s)')
