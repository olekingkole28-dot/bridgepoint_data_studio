from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

anchor="""class _JsonIntelligenceList extends StatelessWidget {
"""
if anchor not in text: raise SystemExit('JSON intelligence widget missing')
if '_bridgePointCustomerSafeKey' not in text:
    helper=r'''bool _bridgePointCustomerSafeKey(String key){
  final k=key.toLowerCase();
  const blocked=[
    'formula','weight','coefficient','sql','query','secret','token','password','credential',
    'service_role','internal_config','raw_component','component_score','score_breakdown',
    'negative_breakdown','positive_breakdown','metadata','debug','payload','request_body',
    'response_body','rule_definition','model_definition','detector_definition','expression',
  ];
  return !blocked.any(k.contains);
}

'''
    text=text.replace(anchor,helper+anchor,1)
old="""        final visible = record.entries.where((entry) {
          final value = entry.value;
          return value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
        }).take(10).toList();
"""
new="""        final visible = record.entries.where((entry) {
          final value = entry.value;
          return _bridgePointCustomerSafeKey(entry.key) &&
              value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
        }).take(10).toList();
"""
if old not in text: raise SystemExit('generic intelligence renderer anchor missing')
text=text.replace(old,new,1)
for marker in ['_bridgePointCustomerSafeKey','score_breakdown','model_definition']:
    if marker not in text: raise SystemExit(f'missing v193 marker {marker}')
if text==original: raise SystemExit('No customer-safe JSON changes applied')
p.write_text(text,encoding='utf-8')
print('Applied customer-safe internal/formula filtering v193')
