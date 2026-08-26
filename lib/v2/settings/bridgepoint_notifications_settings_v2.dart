import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointNotificationsSettingsV2 extends StatefulWidget {
  const BridgePointNotificationsSettingsV2({super.key});

  @override
  State<BridgePointNotificationsSettingsV2> createState() =>
      _BridgePointNotificationsSettingsV2State();
}

class _BridgePointNotificationsSettingsV2State
    extends State<BridgePointNotificationsSettingsV2> {
  bool _busy = true;
  String? _message;
  bool _inApp = true;
  bool _push = true;
  bool _critical = true;
  bool _followUps = true;
  bool _sourceHealth = true;
  bool _dailyBrief = true;

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
      final raw = await Supabase.instance.client
          .rpc('bridgepoint_notification_preferences_v834');
      final prefs = _map(raw);
      if (!mounted) return;
      setState(() {
        _inApp = prefs['in_app_enabled'] != false;
        _push = prefs['device_push_enabled'] != false;
        _critical = prefs['critical_opportunities'] != false;
        _followUps = prefs['saved_follow_ups'] != false;
        _sourceHealth = prefs['source_health'] != false;
        _dailyBrief = prefs['daily_brief'] != false;
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Notification preferences unavailable: $e');
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
        'bridgepoint_update_notification_preferences_v74',
        params: {
          'p_in_app_enabled': _inApp,
          'p_device_push_enabled': _push,
          'p_critical_opportunities': _critical,
          'p_saved_follow_ups': _followUps,
          'p_source_health': _sourceHealth,
          'p_daily_brief': _dailyBrief,
        },
      );
      if (mounted) setState(() => _message = 'Notification preferences saved.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save notifications: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text(
          'Control operational alerts without hiding critical account or security messages that BridgePoint must still surface.',
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
                  value: _inApp,
                  onChanged: _busy ? null : (v) => setState(() => _inApp = v),
                  title: const Text('In-app notifications'),
                  subtitle: const Text('Unread/read alerts inside BridgePoint.'),
                ),
                SwitchListTile(
                  value: _push,
                  onChanged: _busy ? null : (v) => setState(() => _push = v),
                  title: const Text('Device push notifications'),
                  subtitle: const Text('Phone/computer notifications when supported by the installed app/browser.'),
                ),
                SwitchListTile(
                  value: _critical,
                  onChanged: _busy ? null : (v) => setState(() => _critical = v),
                  title: const Text('Critical / high-priority opportunities'),
                ),
                SwitchListTile(
                  value: _followUps,
                  onChanged: _busy ? null : (v) => setState(() => _followUps = v),
                  title: const Text('Saved follow-ups / next actions'),
                ),
                SwitchListTile(
                  value: _sourceHealth,
                  onChanged: _busy ? null : (v) => setState(() => _sourceHealth = v),
                  title: const Text('Source health / freshness alerts'),
                ),
                SwitchListTile(
                  value: _dailyBrief,
                  onChanged: _busy ? null : (v) => setState(() => _dailyBrief = v),
                  title: const Text('Daily intelligence brief'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save notifications'),
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
