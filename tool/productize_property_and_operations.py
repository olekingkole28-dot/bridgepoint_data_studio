from pathlib import Path
import re

# Properties -> visual dossier
p = Path('lib/v2/bridgepoint_properties_v2.dart')
s = p.read_text()
if "import 'bridgepoint_property_dossier_v2.dart';" not in s:
    s = s.replace("import 'package:supabase_flutter/supabase_flutter.dart';\n", "import 'package:supabase_flutter/supabase_flutter.dart';\n\nimport 'bridgepoint_property_dossier_v2.dart';\n")
s = s.replace("builder: (context) => _PropertyDetailSheet(property: property),", "builder: (context) => BridgePointPropertyDossierV2(propertyId: id, seed: property),")
p.write_text(s)

# Investor -> same dossier, no raw row dump
p = Path('lib/v2/bridgepoint_investor_v2.dart')
s = p.read_text()
if "import 'bridgepoint_property_dossier_v2.dart';" not in s:
    s = s.replace("import 'package:supabase_flutter/supabase_flutter.dart';\n", "import 'package:supabase_flutter/supabase_flutter.dart';\n\nimport 'bridgepoint_property_dossier_v2.dart';\n")
new_open = '''void _open(BuildContext context) {
    final propertyId = '${row['property_id'] ?? ''}'.trim();
    if (propertyId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BridgePointPropertyDossierV2(
        propertyId: propertyId,
        seed: row,
      ),
    );
  }

  @override'''
s2, n = re.subn(r"void _open\(BuildContext context\) \{.*?\n  \}\n\n  @override", new_open, s, count=1, flags=re.S)
if n != 1:
    raise SystemExit('Investor open contract changed')
p.write_text(s2)

# Operations -> curated product cards instead of arbitrary payload serialization
p = Path('lib/v2/bridgepoint_operations_workspace_v2.dart')
s = p.read_text()
start = s.find('class _CompactMap extends StatelessWidget')
if start < 0:
    raise SystemExit('Operations compact map contract missing')
replacement = r'''class _CompactMap extends StatelessWidget {
  const _CompactMap(this.value);
  final Map<String, dynamic> value;

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  String _clean(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text.replaceAll('_', ' ');
  }

  String _title() {
    for (final key in const ['title','signal_name','model_name','display_name','route_name','name','source_name','provider']) {
      final v = _clean(value[key]);
      if (v.isNotEmpty) return v;
    }
    return 'BridgePoint intelligence';
  }

  String _subtitle() {
    for (final key in const ['description','customer_outcome','best_for','full_address','privacy','note','message']) {
      final v = _clean(value[key]);
      if (v.isNotEmpty) return v;
    }
    return 'Live BridgePoint workspace data';
  }

  List<MapEntry<String, dynamic>> _details() {
    const preferred = [
      'status','state_code','municipality','county','severity','strength','confidence',
      'source_count','evidence_count','signal_family','model_category','target_entity_type',
      'strict_queue_status','strict_qualified_count','member_role','active','joined_at',
      'stop_count','route_status','scheduled_for','health_status','freshness_status',
      'total_records_ingested','last_successful_import_at','your_pending_count'
    ];
    final out = <MapEntry<String,dynamic>>[];
    for (final key in preferred) {
      final v = value[key];
      if (v == null || _clean(v).isEmpty || v is Map || v is List) continue;
      out.add(MapEntry(key,v));
    }
    return out.take(8).toList();
  }

  String _label(String key) => key
      .replaceAll('_',' ')
      .split(' ')
      .where((x) => x.isNotEmpty)
      .map((x) => '${x[0].toUpperCase()}${x.substring(1)}')
      .join(' ');

  Color _accent() {
    final status = _clean(value['status'] ?? value['health_status'] ?? value['strict_queue_status']).toLowerCase();
    if (status.contains('fail') || status.contains('error') || status.contains('critical')) return _amber;
    if (status.contains('live') || status.contains('healthy') || status.contains('active')) return _green;
    if (value['severity'] is num && (value['severity'] as num) >= 70) return _amber;
    return _cyan;
  }

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value['available'] == false) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: const Row(children: [
          Icon(Icons.hourglass_empty_rounded, color: _cyan),
          SizedBox(width: 11),
          Expanded(child: Text('This workspace section is still building or has no customer-facing results yet.', style: TextStyle(color: _muted, fontWeight: FontWeight.w600))),
        ]),
      );
    }
    final accent = _accent();
    final details = _details();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withValues(alpha: .10), const Color(0xFF0E2035)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .22)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0,6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.insights_rounded, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_subtitle(), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, height: 1.4, fontWeight: FontWeight.w600)),
          ])),
        ]),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in details)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF081625), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .08))),
                child: Text('${_label(e.key)}: ${_clean(e.value)}', style: TextStyle(color: e.key.contains('status') ? accent : _muted, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
          ]),
        ],
      ]),
    );
  }
}
'''
s = s[:start] + replacement
# remaining tiny opportunity labels
s = s.replace("fontSize: 10)),", "fontSize: 12.5, fontWeight: FontWeight.w600)),")
s = s.replace("fontSize: 9)),", "fontSize: 12.5, fontWeight: FontWeight.w600)),")
p.write_text(s)

print('Productized Properties, Investor and Operations')
