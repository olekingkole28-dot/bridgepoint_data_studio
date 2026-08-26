import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointDisplaySettingsV2 extends StatefulWidget {
  const BridgePointDisplaySettingsV2({super.key});

  @override
  State<BridgePointDisplaySettingsV2> createState() =>
      _BridgePointDisplaySettingsV2State();
}

class _BridgePointDisplaySettingsV2State
    extends State<BridgePointDisplaySettingsV2> {
  bool _busy = true;
  String? _message;
  bool _largeText = false;
  bool _highContrast = false;
  bool _reducedMotion = false;
  bool _simplified = false;
  String _mapStyle = 'satellite';

  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_display_preferences_v80');
      final prefs = _map(raw);
      if (!mounted) return;
      setState(() {
        _largeText = prefs['large_text'] == true;
        _highContrast = prefs['high_contrast'] == true;
        _reducedMotion = prefs['reduced_motion'] == true;
        _simplified = prefs['simplified_views'] == true;
        final style = '${prefs['map_base_style'] ?? 'satellite'}';
        _mapStyle = const ['satellite', 'street', 'standard'].contains(style)
            ? style
            : 'satellite';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Display preferences unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_update_display_preferences_v98',
        params: {
          'p_large_text': _largeText,
          'p_high_contrast': _highContrast,
          'p_reduced_motion': _reducedMotion,
          'p_simplified_views': _simplified,
          'p_map_base_style': _mapStyle,
        },
      );
      if (mounted) setState(() => _message = 'Display preferences saved.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save display preferences: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Display & Accessibility',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text(
          'Keep BridgePoint readable and usable across phones, tablets and desktops without removing the underlying intelligence.',
          style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: _cyan)),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  value: _largeText,
                  onChanged: _busy ? null : (v) => setState(() => _largeText = v),
                  title: const Text('Larger text'),
                ),
                SwitchListTile(
                  value: _highContrast,
                  onChanged: _busy ? null : (v) => setState(() => _highContrast = v),
                  title: const Text('Higher contrast'),
                ),
                SwitchListTile(
                  value: _reducedMotion,
                  onChanged: _busy ? null : (v) => setState(() => _reducedMotion = v),
                  title: const Text('Reduced motion'),
                  subtitle: const Text('Reduce nonessential animation while preserving live-data state changes.'),
                ),
                SwitchListTile(
                  value: _simplified,
                  onChanged: _busy ? null : (v) => setState(() => _simplified = v),
                  title: const Text('Simplified views'),
                  subtitle: const Text('Prioritize the most important facts and next action first.'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _mapStyle,
                  items: const [
                    DropdownMenuItem(
                      value: 'satellite',
                      child: Text('Satellite / aerial-first'),
                    ),
                    DropdownMenuItem(value: 'street', child: Text('Street map')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _mapStyle = value ?? 'satellite'),
                  decoration: const InputDecoration(labelText: 'Default map style'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save display preferences'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
