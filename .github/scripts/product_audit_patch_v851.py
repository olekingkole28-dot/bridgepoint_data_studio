from pathlib import Path
import re

ROOT = Path('.')


def read(path: str) -> str:
    return (ROOT / path).read_text()


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f'{label}: expected source block not found')


# ---------------------------------------------------------------------------
# Weather: drive the MRMS animation from NOAA's published idp_validtime values.
# If the catalog cannot be reached, omit TIME and let NOAA return latest image.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_map_weather_v2.dart'
s = read(path)
s = replace_once(
    s,
    "import 'dart:async';\n",
    "import 'dart:async';\nimport 'dart:convert';\n\nimport 'package:http/http.dart' as http;\n",
    'weather imports',
)
s = replace_once(
    s,
    """  int frame = 48;
  double _zoom = 4.0;
""",
    """  int frame = 0;
  double _zoom = 4.0;
  List<DateTime> _radarFrames = const <DateTime>[];
  bool _radarFramesLive = false;
""",
    'weather frame state',
)
old_frames = """  List<DateTime> get _frames {
    final now = DateTime.now().toUtc();
    final rounded = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 5) * 5,
    );
    return List.generate(
      49,
      (i) => rounded.subtract(Duration(minutes: (48 - i) * 5)),
    );
  }

  DateTime get _radarTime => _frames[frame.clamp(0, 48)];
"""
new_frames = """  DateTime get _radarTime {
    if (_radarFrames.isEmpty) return DateTime.now().toUtc();
    return _radarFrames[frame.clamp(0, _radarFrames.length - 1)];
  }

  Future<void> _loadRadarFrames() async {
    try {
      final uri = Uri.parse(
        'https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/'
        'radar_base_reflectivity_time/ImageServer/query',
      ).replace(queryParameters: const <String, String>{
        'where': '1=1',
        'outFields': 'idp_validtime',
        'returnGeometry': 'false',
        'orderByFields': 'idp_validtime ASC',
        'resultRecordCount': '500',
        'f': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final features = decoded['features'];
      if (features is! List) return;
      final unique = <int>{};
      for (final feature in features) {
        if (feature is! Map) continue;
        final attributes = feature['attributes'];
        if (attributes is! Map) continue;
        final raw = attributes['idp_validtime'];
        final epoch = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
        if (epoch != null && epoch > 0) unique.add(epoch);
      }
      final frames = unique
          .map(DateTime.fromMillisecondsSinceEpoch)
          .map((value) => value.toUtc())
          .toList()
        ..sort();
      if (frames.isEmpty || !mounted) return;
      setState(() {
        _radarFrames = frames;
        _radarFramesLive = true;
        frame = frames.length - 1;
      });
    } catch (_) {
      // No fabricated history: with no published catalog, WMS omits TIME and
      // NOAA serves the latest available image.
      if (mounted && _radarFrames.isEmpty) {
        setState(() => _radarFramesLive = false);
      }
    }
  }
"""
s = replace_once(s, old_frames, new_frames, 'weather frame generator')
s = replace_once(
    s,
    """    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _loadOverview(silent: true);
    });
""",
    """    _loadRadarFrames();
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (mounted && radar && playing && _radarFrames.length > 1) {
        setState(() =>
            frame = frame >= _radarFrames.length - 1 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _loadOverview(silent: true);
        _loadRadarFrames();
      }
    });
""",
    'weather timer',
)
s = replace_once(
    s,
    """    } catch (e) {
      return {'_error': '$e'};
    }
""",
    """    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
""",
    'weather safe rpc',
)
s = s.replace(
    "final hadError = mapPayload is Map && mapPayload['_error'] != null;",
    "final hadError = mapPayload is Map && mapPayload['available'] == false;",
)
s = replace_once(
    s,
    """    } catch (e) {
      if (mounted) setState(() => _locationMessage = '$e');
    } finally {
""",
    """    } catch (_) {
      if (mounted) {
        setState(() => _locationMessage =
            'BridgePoint could not read this device location. Check location services and permission, then try again.');
      }
    } finally {
""",
    'weather location error',
)
s = s.replace(
    "key: ValueKey('bp-radar-${_radarTime.millisecondsSinceEpoch}'),",
    "key: ValueKey(_radarFrames.isEmpty\n                            ? 'bp-radar-live'\n                            : 'bp-radar-${_radarTime.millisecondsSinceEpoch}'),",
)
s = s.replace(
    "otherParameters: {'TIME': _radarTime.toUtc().toIso8601String()},",
    "otherParameters: _radarFrames.isEmpty\n                              ? const <String, String>{}\n                              : {'TIME': _radarTime.toUtc().toIso8601String()},",
)
old_slider = """                            const Text('NOAA • 4H', style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Slider(
                                value: frame.toDouble(),
                                min: 0,
                                max: 48,
                                divisions: 48,
                                onChanged: (value) => setState(() {
                                  playing = false;
                                  frame = value.round();
                                }),
                              ),
                            ),
                            Text(_clock(_radarTime), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
"""
new_slider = """                            Text(
                              _radarFramesLive
                                  ? 'NOAA MRMS • ${_radarFrames.length} FRAMES'
                                  : 'NOAA MRMS • LIVE',
                              style: const TextStyle(color: _cyan, fontSize: 12.5, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: _radarFrames.length > 1
                                  ? Slider(
                                      value: frame.clamp(0, _radarFrames.length - 1).toDouble(),
                                      min: 0,
                                      max: (_radarFrames.length - 1).toDouble(),
                                      divisions: _radarFrames.length - 1,
                                      onChanged: (value) => setState(() {
                                        playing = false;
                                        frame = value.round();
                                      }),
                                    )
                                  : const Text(
                                      'Latest published reflectivity',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _muted, fontSize: 10.5),
                                    ),
                            ),
                            Text(
                              _radarFrames.isEmpty ? 'LATEST' : _clock(_radarTime),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                            ),
"""
s = replace_once(s, old_slider, new_slider, 'weather slider')
write(path, s)


# ---------------------------------------------------------------------------
# Operations: these are customer workflows; failures should not expose database
# exceptions or function names. Keep actions intact and provide usable messages.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_operations_workspace_v2.dart'
s = read(path)
s = replace_once(
    s,
    """  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try { return await Supabase.instance.client.rpc(name, params: params); }
    catch (e) { return {'available': false, 'rpc': name, 'error': '$e'}; }
  }
""",
    """  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }
""",
    'operations safe rpc',
)
replacements = {
    "_message = 'Could not save: $e'": "_message = 'Could not save this opportunity right now. Please try again.'",
    "_message = 'Feedback unavailable: $e'": "_message = 'Could not record feedback right now. Please try again.'",
    "_message = 'Route build unavailable: $e'": "_message = 'Could not build this field route right now. Please try again.'",
    "_message = 'Offline preparation unavailable: $e'": "_message = 'Could not prepare this route for offline use right now.'",
    "_message = 'Route stop update unavailable: $e'": "_message = 'Could not record this route-stop update right now.'",
    "_message = 'Could not mark read: $e'": "_message = 'Could not update this notification right now.'",
    "_message = 'Invite unavailable: $e'": "_message = 'Could not create this team invite right now. Check the email and try again.'",
}
for old, new in replacements.items():
    s = s.replace(old, new)
write(path, s)


# ---------------------------------------------------------------------------
# Calendar: replace typed ISO timestamp UX with native date/time pickers.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_calendar_v2.dart'
s = read(path)
helper_marker = "  Future<void> _createEvent() async {"
if 'Future<DateTime?> _pickDateTime' not in s:
    helper = r'''  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final base = initial ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _pickerLabel(DateTime? value, String fallback) =>
      value == null ? fallback : _when(value.toIso8601String());

'''
    s = s.replace(helper_marker, helper + helper_marker, 1)

start = s.index('  Future<void> _createEvent() async {')
end = s.index('  Future<void> _deleteCustom(', start)
create_method = r'''  Future<void> _createEvent() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    String type = 'FOLLOW_UP';
    DateTime? startsAt;
    DateTime? endsAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add calendar item'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'APPOINTMENT', child: Text('Appointment')),
                    DropdownMenuItem(value: 'INSPECTION', child: Text('Inspection')),
                    DropdownMenuItem(value: 'FIELD_VISIT', child: Text('Field visit')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, color: _cyan),
                  title: const Text('Start'),
                  subtitle: Text(_pickerLabel(startsAt, 'Choose date and time')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await _pickDateTime(initial: startsAt);
                    if (picked != null) setLocal(() => startsAt = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_rounded, color: _cyan),
                  title: const Text('End (optional)'),
                  subtitle: Text(_pickerLabel(endsAt, 'No end time')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (endsAt != null)
                      IconButton(
                        tooltip: 'Clear end time',
                        onPressed: () => setLocal(() => endsAt = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                  onTap: () async {
                    final picked = await _pickDateTime(
                      initial: endsAt ?? startsAt?.add(const Duration(hours: 1)),
                    );
                    if (picked != null) setLocal(() => endsAt = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: title.text.trim().isEmpty || startsAt == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || startsAt == null) {
      title.dispose();
      notes.dispose();
      return;
    }
    if (endsAt != null && endsAt!.isBefore(startsAt!)) {
      if (mounted) setState(() => _message = 'End time must be after the start time.');
      title.dispose();
      notes.dispose();
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.rpc('bridgepoint_calendar_event_upsert_v835', params: {
        'p_calendar_event_id': null,
        'p_title': title.text.trim(),
        'p_event_type': type,
        'p_starts_at': startsAt!.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_property_id': null,
        'p_opportunity_id': null,
        'p_claim_id': null,
        'p_route_plan_id': null,
        'p_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        'p_status': 'SCHEDULED',
      });
      if (mounted) setState(() { _message = 'Calendar item added.'; _request = _load(); });
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not add this calendar item right now. Please try again.');
    } finally {
      title.dispose();
      notes.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

'''
s = s[:start] + create_method + s[end:]

start = s.index('  Future<void> _scheduleRoute(')
end = s.index('  Widget _eventCard(', start)
schedule_method = r'''  Future<void> _scheduleRoute(Map<String, dynamic> route) async {
    final picked = await _pickDateTime();
    if (picked == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Schedule ${route['route_name'] ?? 'route'}'),
        content: Text('Schedule this route for ${_when(picked.toIso8601String())}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Schedule')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.rpc('bridgepoint_schedule_route_v835', params: {
        'p_route_plan_id': route['route_plan_id'],
        'p_scheduled_for': picked.toUtc().toIso8601String(),
      });
      if (mounted) setState(() { _message = 'Route scheduled.'; _request = _load(); });
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not schedule this route right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
s = s[:start] + schedule_method + s[end:]
write(path, s)


# ---------------------------------------------------------------------------
# Remove dead recursive developer payload presenters from customer code paths.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_global_search_v2.dart'
s = read(path)
marker = '\nclass _PayloadPanel extends StatelessWidget {'
if marker in s:
    s = s[:s.index(marker)].rstrip() + '\n'
write(path, s)

path = 'lib/v2/bridgepoint_buildings_v2.dart'
s = read(path)
marker = '\nclass _Payload extends StatelessWidget {'
if marker in s:
    s = s[:s.index(marker)].rstrip() + '\n'
write(path, s)

path = 'lib/v2/bridgepoint_property_presentation_v2.dart'
s = read(path)
start_marker = 'class _AllFields extends StatelessWidget {'
end_marker = 'Widget _responsiveHeading('
if start_marker in s and end_marker in s:
    a = s.index(start_marker)
    b = s.index(end_marker, a)
    s = s[:a] + s[b:]
write(path, s)


# Required markers before committing.
checks = {
    'lib/v2/bridgepoint_map_weather_v2.dart': [
        '_loadRadarFrames',
        'idp_validtime',
        'NOAA MRMS',
        "'bp-radar-live'",
    ],
    'lib/v2/bridgepoint_operations_workspace_v2.dart': [
        'Could not build this field route right now',
        "return const <String, dynamic>{'available': false};",
    ],
    'lib/v2/bridgepoint_calendar_v2.dart': [
        'Future<DateTime?> _pickDateTime',
        'showDatePicker',
        'showTimePicker',
    ],
}
for file, markers in checks.items():
    text = read(file)
    for marker in markers:
        if marker not in text:
            raise SystemExit(f'{file}: missing marker {marker}')

if 'class _PayloadPanel extends StatelessWidget' in read('lib/v2/bridgepoint_global_search_v2.dart'):
    raise SystemExit('Global Search debug payload presenter still present')
if 'class _Payload extends StatelessWidget' in read('lib/v2/bridgepoint_buildings_v2.dart'):
    raise SystemExit('Buildings debug payload presenter still present')
if 'class _AllFields extends StatelessWidget' in read('lib/v2/bridgepoint_property_presentation_v2.dart'):
    raise SystemExit('Property presentation audit payload presenter still present')

print('V851 weather/operations/calendar hardening complete')
