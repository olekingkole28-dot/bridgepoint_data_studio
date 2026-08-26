from pathlib import Path

p = Path('lib/v2/bridgepoint_intelligence_surfaces_v2.dart')
s = p.read_text(encoding='utf-8')
start = s.index('class _DataRowCard extends StatelessWidget {')
replacement = r'''class _DataRowCard extends StatelessWidget {
  const _DataRowCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Map<String, dynamic> payload;

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  List<MapEntry<String, dynamic>> _customerEntries() {
    const preferred = <String>[
      'description',
      'provider',
      'state_code',
      'geographic_scope',
      'source_category',
      'health_status',
      'status',
      'signal_family',
      'severity',
      'confidence_percent',
      'evidence_at',
      'last_checked_at',
      'last_successful_import_at',
      'total_records_ingested',
      'last_run_records_found',
      'model_category',
      'target_entity_type',
      'package_count',
      'active',
    ];
    final entries = <MapEntry<String, dynamic>>[];
    for (final key in preferred) {
      final value = payload[key];
      if (value == null || '$value'.trim().isEmpty) continue;
      entries.add(MapEntry(key, value));
    }
    return entries.take(12).toList();
  }

  void _open(BuildContext context) {
    final entries = _customerEntries();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: .55)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: .18),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: _bpMuted,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (entries.isEmpty)
                  const _EmptyBox(
                    'BridgePoint has the summary for this item. No additional customer-facing detail is available yet.',
                  )
                else ...[
                  const Text(
                    'INTELLIGENCE DETAILS',
                    style: TextStyle(
                      color: _bpCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _bpSoft.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: accent.withValues(alpha: .12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(entry.key).toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .55,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: .10),
                _bpPanel,
                _bpPanel,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: .24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: .20)),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _bpMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _bpRed.withValues(alpha: .14),
              _bpPanel,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bpRed.withValues(alpha: .30)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_problem_rounded, color: _bpRed, size: 25),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BridgePoint could not refresh this view',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The live data request did not complete. Refresh the view to try again; your underlying intelligence is not removed by a display error.',
                    style: TextStyle(
                      color: _bpMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_bpSoft, _bpPanel],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bpCyan.withValues(alpha: .12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _bpCyan.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                color: _bpCyan,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nothing matched this view',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _bpMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
'''
s = s[:start] + replacement + '\n'
p.write_text(s, encoding='utf-8')
print('Shared intelligence cards, details, errors, and empty states polished.')
