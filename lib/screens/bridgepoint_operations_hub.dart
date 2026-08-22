import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/bridgepoint_operations_service.dart';

/// Modular Operations + Claims surface for BridgePoint's advanced property tools.
///
/// This screen is intentionally isolated from the legacy monolithic dashboard.
/// It can be inserted into navigation or opened contextually from a property or
/// claim without changing the backend contracts.
class BridgePointOperationsHub extends StatefulWidget {
  const BridgePointOperationsHub({
    super.key,
    this.propertyId,
    this.claimId,
  });

  final String? propertyId;
  final String? claimId;

  @override
  State<BridgePointOperationsHub> createState() =>
      _BridgePointOperationsHubState();
}

class _BridgePointOperationsHubState extends State<BridgePointOperationsHub> {
  final _operations = BridgePointOperationsService();
  late Future<Map<String, dynamic>> _readiness;
  bool _working = false;

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _readiness = _loadReadiness();
  }

  Future<Map<String, dynamic>> _loadReadiness() async {
    final dynamic result = await Supabase.instance.client
        .rpc('bridgepoint_capability_readiness_v522');
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('Unexpected capability response.');
  }

  void _refresh() => setState(() => _readiness = _loadReadiness());

  Color _statusColor(String status) {
    switch (status) {
      case 'LIVE':
      case 'VALIDATED_BASELINE':
        return _green;
      case 'BACKEND_READY':
      case 'ENTITLEMENT_READY':
      case 'ON_DEMAND':
        return _cyan;
      case 'PARTIAL':
      case 'SHADOW':
      case 'EVIDENCE_GATED':
      case 'PROFESSIONAL_REVIEW_REQUIRED':
        return _amber;
      case 'BLOCKED':
      case 'BLOCKED_EXTERNAL':
        return _red;
      default:
        return _muted;
    }
  }

  Future<void> _run(
    String title,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await action();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _panel,
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: SelectableText(
                _pretty(result),
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _pretty(dynamic value, [int depth = 0]) {
    if (value is Map) {
      return value.entries
          .map((e) => '${'  ' * depth}${e.key}: ${e.value is Map || e.value is List ? '\n${_pretty(e.value, depth + 1)}' : e.value}')
          .join('\n');
    }
    if (value is List) {
      return value.map((e) => '${'  ' * depth}• ${e is Map || e is List ? '\n${_pretty(e, depth + 1)}' : e}').join('\n');
    }
    return '${'  ' * depth}$value';
  }

  Widget _chip(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _statusColor(value).withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _statusColor(value).withOpacity(.35)),
        ),
        child: Text(
          value.replaceAll('_', ' '),
          style: TextStyle(
            color: _statusColor(value),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: _working ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: onTap == null ? _muted : _cyan),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: const TextStyle(
                      color: _muted, fontSize: 11, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _contextActions() {
    final propertyId = widget.propertyId;
    final claimId = widget.claimId;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _quickAction(
          icon: Icons.monitor_heart_outlined,
          title: 'Property Health',
          subtitle: propertyId == null
              ? 'Open this hub from a property to calculate its current health.'
              : 'Calculate the current evidence-backed component health score.',
          onTap: propertyId == null
              ? null
              : () => _run(
                    'Property Health',
                    () => _operations.propertyHealth(propertyId),
                  ),
        ),
        _quickAction(
          icon: Icons.view_in_ar_rounded,
          title: 'Digital Reconstruction',
          subtitle: propertyId == null
              ? 'Open from a property to start an accuracy-gated CAD/BIM job.'
              : 'Start a controlled DXF/IFC reconstruction intake.',
          onTap: propertyId == null
              ? null
              : () => _run(
                    'Reconstruction Intake',
                    () => _operations.createReconstruction(
                      propertyId: propertyId,
                    ),
                  ),
        ),
        _quickAction(
          icon: Icons.flight_takeoff_rounded,
          title: 'Dispatch Drone Pilot',
          subtitle: propertyId == null
              ? 'Open from a property to search qualified local pilots.'
              : 'Create a storm-damage capture request and run pilot matching.',
          onTap: propertyId == null
              ? null
              : () => _run(
                    'Drone Dispatch',
                    () => _operations.createDroneDispatch(
                      propertyId: propertyId,
                      jobType: 'STORM_DAMAGE',
                      urgency: 'SAME_DAY',
                    ),
                  ),
        ),
        _quickAction(
          icon: Icons.compare_arrows_rounded,
          title: 'Find Supplement Gaps',
          subtitle: claimId == null
              ? 'Open from a claim after the carrier estimate is parsed.'
              : 'Compare BridgePoint scope against the carrier estimate.',
          onTap: claimId == null
              ? null
              : () => _run(
                    'Supplement Gaps',
                    () => _operations.supplementGaps(claimId),
                  ),
        ),
        _quickAction(
          icon: Icons.cube_outlined,
          title: '3D Evidence Scene',
          subtitle: propertyId == null
              ? 'Open from a property/claim to build a source-linked scene.'
              : 'Create a 3D evidence reconstruction with explicit uncertainty.',
          onTap: propertyId == null
              ? null
              : () => _run(
                    '3D Evidence Scene',
                    () => _operations.createEvidenceScene(
                      propertyId: propertyId,
                      claimId: claimId,
                    ),
                  ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _readiness,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['capabilities'];
        final capabilities = raw is List
            ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations & Claims Intelligence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Storm, claims, digital twin, building condition, drone, IoT and procurement tools — with validation and compliance gates visible.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh readiness',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, color: _cyan),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _contextActions(),
            const SizedBox(height: 26),
            const Text('Capability readiness',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _red.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(snapshot.error.toString(),
                    style: const TextStyle(color: _red)),
              )
            else
              ...capabilities.map((capability) {
                final implementation =
                    capability['implementation_status']?.toString() ?? 'UNKNOWN';
                final validation =
                    capability['validation_status']?.toString() ?? 'UNKNOWN';
                final dependency =
                    capability['dependency_status']?.toString() ?? 'NONE';
                final entitled = capability['entitled'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panelSoft.withOpacity(.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.07)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (entitled ? _cyan : _muted).withOpacity(.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          entitled
                              ? Icons.auto_awesome_rounded
                              : Icons.lock_outline_rounded,
                          color: entitled ? _cyan : _muted,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capability['name']?.toString() ?? 'BridgePoint capability',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              capability['truthful_claim']?.toString() ?? '',
                              style: const TextStyle(
                                  color: _muted, fontSize: 11, height: 1.45),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _chip(implementation),
                                _chip(validation),
                                if (dependency != 'NONE') _chip(dependency),
                                _chip(entitled ? 'ENTITLED' : 'LOCKED'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (_working) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
          ],
        );
      },
    );
  }
}
