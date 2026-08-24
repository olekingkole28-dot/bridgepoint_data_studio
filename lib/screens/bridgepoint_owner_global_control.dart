import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner-only global expansion, portability and localization control plane.
///
/// Server RPCs enforce owner/admin access. This screen never changes customer
/// entitlements or marks unfinished jurisdictions live; it only queues work and
/// exposes verified status.
class BridgePointOwnerGlobalControl extends StatefulWidget {
  const BridgePointOwnerGlobalControl({super.key});

  @override
  State<BridgePointOwnerGlobalControl> createState() =>
      _BridgePointOwnerGlobalControlState();
}

class _BridgePointOwnerGlobalControlState
    extends State<BridgePointOwnerGlobalControl> {
  late Future<Map<String, dynamic>> _status;
  final _country = TextEditingController();
  final _region = TextEditingController();
  final _name = TextEditingController();
  final _state = TextEditingController(text: 'CT');
  bool _working = false;
  String? _result;

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  @override
  void dispose() {
    _country.dispose();
    _region.dispose();
    _name.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    final dynamic result =
        await Supabase.instance.client.rpc(name, params: params);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('Unexpected BridgePoint owner response.');
  }

  Future<Map<String, dynamic>> _load() => _rpc(
        'bridgepoint_owner_global_command_v675',
        const <String, dynamic>{
          'p_action': 'STATUS',
          'p_country_code': null,
          'p_region_code': null,
          'p_jurisdiction_name': null,
          'p_countries': <dynamic>[],
        },
      );

  void _refresh() => setState(() => _status = _load());

  String _pretty(dynamic value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Future<void> _run(
    String action, {
    String? country,
    String? region,
    String? jurisdictionName,
  }) async {
    if (_working) return;
    setState(() {
      _working = true;
      _result = 'Working…';
    });
    try {
      final result = await _rpc(
        'bridgepoint_owner_global_command_v675',
        <String, dynamic>{
          'p_action': action,
          'p_country_code': country,
          'p_region_code': region,
          'p_jurisdiction_name': jurisdictionName,
          'p_countries': <dynamic>[],
        },
      );
      if (!mounted) return;
      setState(() {
        _result = _pretty(result);
        _status = _load();
      });
    } catch (error) {
      if (mounted) setState(() => _result = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stateManifest() async {
    if (_working) return;
    final state = _state.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(state)) {
      setState(() => _result = 'Enter a valid two-letter state code.');
      return;
    }
    setState(() {
      _working = true;
      _result = 'Reading $state export manifest…';
    });
    try {
      final result = await _rpc(
        'bridgepoint_owner_state_export_manifest_v675',
        <String, dynamic>{'p_state_code': state},
      );
      if (mounted) setState(() => _result = _pretty(result));
    } catch (error) {
      if (mounted) setState(() => _result = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that resource.')),
      );
    }
  }

  Widget _metric(String label, dynamic value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _button(IconData icon, String label, VoidCallback? onPressed,
          {bool primary = false}) =>
      FilledButton.icon(
        onPressed: _working ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: primary ? _cyan : _panelSoft,
          foregroundColor: primary ? const Color(0xFF00151C) : Colors.white,
          side: BorderSide(color: primary ? _cyan : Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _status,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final jurisdictions = data['jurisdictions'] is Map
            ? Map<String, dynamic>.from(data['jurisdictions'] as Map)
            : const <String, dynamic>{};
        final mode = data['mode'] is Map
            ? Map<String, dynamic>.from(data['mode'] as Map)
            : const <String, dynamic>{};
        final languages = data['languages'] is List
            ? (data['languages'] as List)
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList(growable: false)
            : const <Map<String, dynamic>>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Global / Export Control',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text(
                          'Start one state, one country, the full U.S., or worldwide discovery. Readiness gates stay enforced.',
                          style: TextStyle(color: _muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, color: _cyan),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(color: _cyan)
              else if (snapshot.hasError)
                Text(snapshot.error.toString(),
                    style: const TextStyle(color: _amber))
              else ...[
                LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth < 720
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 30) / 4;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                          width: width,
                          child: _metric('Jurisdictions',
                              jurisdictions['total'] ?? '—')),
                      SizedBox(
                          width: width,
                          child: _metric(
                              'Countries', jurisdictions['countries'] ?? '—')),
                      SizedBox(
                          width: width,
                          child: _metric('U.S. jurisdictions',
                              jurisdictions['us_subdivisions'] ?? '—')),
                      SizedBox(
                          width: width,
                          child: _metric('CT parity checks',
                              data['parity_requirements'] ?? '—')),
                    ],
                  );
                }),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expansion controls',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      const SizedBox(height: 5),
                      const Text(
                        'These actions queue discovery/build work. They never bypass validation or customer-readiness gates.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _button(Icons.map_rounded, 'Reinforce full U.S.',
                              () => _run('START_US_ALL'),
                              primary: true),
                          _button(
                            Icons.public_rounded,
                            'Start worldwide discovery',
                            () => showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: _panel,
                                title: const Text('Start worldwide discovery?'),
                                content: const Text(
                                    'This queues discovery across the registered country catalog. It does not mark unfinished countries live.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Queue worldwide')),
                                ],
                              ),
                            ).then((ok) {
                              if (ok == true) _run('START_WORLD_DISCOVERY');
                            }),
                            primary: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 780;
                        final fields = [
                          Expanded(
                            child: TextField(
                              controller: _country,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 2,
                              decoration: const InputDecoration(
                                  labelText: 'Country code',
                                  hintText: 'US',
                                  counterText: '',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _region,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 12,
                              decoration: const InputDecoration(
                                  labelText: 'Region / state',
                                  hintText: 'OH',
                                  counterText: '',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                  labelText: 'Jurisdiction name',
                                  hintText: 'Ohio',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (narrow)
                              ...fields.expand((w) => [w, const SizedBox(height: 8)])
                            else
                              Row(children: [
                                fields[0],
                                const SizedBox(width: 8),
                                fields[1],
                                const SizedBox(width: 8),
                                fields[2],
                              ]),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _button(
                                Icons.rocket_launch_rounded,
                                'Start jurisdiction',
                                () => _run(
                                  'START_JURISDICTION',
                                  country: _country.text.trim().toUpperCase(),
                                  region: _region.text.trim().isEmpty
                                      ? null
                                      : _region.text.trim().toUpperCase(),
                                  jurisdictionName: _name.text.trim().isEmpty
                                      ? null
                                      : _name.text.trim(),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cost & continuity mode',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      const SizedBox(height: 5),
                      Text('Current: ${mode['mode'] ?? '—'}',
                          style: const TextStyle(color: _green)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _button(Icons.speed_rounded, 'Full speed',
                              () => _run('SET_MODE', country: 'FULL_SPEED')),
                          _button(Icons.savings_outlined, 'Lean survival',
                              () => _run('SET_MODE', country: 'LEAN_SURVIVAL')),
                          _button(Icons.computer_rounded, 'Local first',
                              () => _run('SET_MODE', country: 'LOCAL_FIRST')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Portable state export',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      const SizedBox(height: 5),
                      const Text(
                        'State bundles are the portable unit: CSV/Parquet-style files + optional DuckDB, with Google Sheets used as the lightweight roll-up layer.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _state,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 2,
                              decoration: const InputDecoration(
                                  labelText: 'State',
                                  counterText: '',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _button(Icons.fact_check_outlined,
                                    'Check export manifest', _stateManifest),
                                _button(
                                  Icons.download_rounded,
                                  'State export wizard',
                                  () => _open(Uri.parse(
                                      'https://bridgepointintelligence.online/downloads/backup/BridgePoint_State_Export_Wizard.bat')),
                                ),
                                _button(
                                  Icons.backup_rounded,
                                  'Full backup wizard',
                                  () => _open(Uri.parse(
                                      'https://bridgepointintelligence.online/downloads/backup/BridgePoint_Backup_Wizard.bat')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Languages',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: languages
                            .map((language) => Chip(
                                  backgroundColor: _panelSoft,
                                  side: BorderSide(
                                      color: Colors.white.withOpacity(.08)),
                                  label: Text(
                                    '${language['native_name'] ?? language['name']} · ${language['status'] ?? 'FOUNDATION'}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: SelectableText(_result!,
                      style: const TextStyle(
                          color: _muted,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          height: 1.45)),
                ),
              ],
              if (_working) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(color: _cyan),
              ],
            ],
          ),
        );
      },
    );
  }
}
