import 'package:flutter/material.dart';

import '../services/bridgepoint_operations_service.dart';

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
  bool _running = false;
  String? _lastAction;
  Object? _lastResult;

  String? get propertyId {
    final value = widget.propertyId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get claimId {
    final value = widget.claimId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _run(String label, Future<Object?> Function() action) async {
    if (_running) return;
    setState(() {
      _running = true;
      _lastAction = label;
      _lastResult = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label completed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _lastResult = error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null && !_running;
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 11, height: 1.35)),
                  ],
                ),
              ),
              if (!enabled)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 8),
                  child: Icon(Icons.lock_outline_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations Hub',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'BridgePoint execution workflows tied to real property/claim context.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_running) const LinearProgressIndicator(),
          if (_lastAction != null) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lastAction!,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _lastResult?.toString() ??
                          (_running ? 'Working…' : 'No result yet.'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _quickAction(
            icon: Icons.route_rounded,
            title: 'Optimize Route',
            subtitle: propertyId == null
                ? 'Open from a property to create an evidence-aware field route.'
                : 'Build a route around this property and nearby priorities.',
            onTap: propertyId == null
                ? null
                : () => _run(
                      'Route Optimization',
                      () => _operations.optimizeRoute(propertyId!),
                    ),
          ),
          _quickAction(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Build Evidence Packet',
            subtitle: propertyId == null
                ? 'Open from a property to build a shareable evidence packet.'
                : 'Assemble source-linked evidence for this property.',
            onTap: propertyId == null
                ? null
                : () => _run(
                      'Evidence Packet',
                      () => _operations.buildEvidencePacket(propertyId!),
                    ),
          ),
          _quickAction(
            icon: Icons.flight_takeoff_rounded,
            title: 'Drone Dispatch',
            subtitle: propertyId == null
                ? 'Open from a property to prepare a drone/inspection dispatch.'
                : 'Prepare a same-day storm-damage inspection dispatch.',
            onTap: propertyId == null
                ? null
                : () => _run(
                      'Drone Dispatch',
                      () => _operations.createDroneDispatch(
                        propertyId: propertyId!,
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
                      () => _operations.supplementGaps(claimId!),
                    ),
          ),
          _quickAction(
            icon: Icons.view_in_ar_rounded,
            title: '3D Evidence Scene',
            subtitle: propertyId == null
                ? 'Open from a property/claim to build a source-linked scene.'
                : 'Create a 3D evidence reconstruction with explicit uncertainty.',
            onTap: propertyId == null
                ? null
                : () => _run(
                      '3D Evidence Scene',
                      () => _operations.createEvidenceScene(
                        propertyId: propertyId!,
                        claimId: claimId,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
