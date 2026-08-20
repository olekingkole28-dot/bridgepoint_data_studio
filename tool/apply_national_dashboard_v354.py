from pathlib import Path

source_path=Path('tool/apply_national_dashboard_v352.py')
source=source_path.read_text(encoding='utf-8')

# Convert only the known brittle once() blocks in the isolated Daily Brief migration
# into structural generated-Flutter matchers. V352 runtime behavior is not changed.
def replace_once_block(script:str,label:str,replacement:str)->str:
    needle=repr(label)
    try:
        label_idx=script.index(needle)
    except ValueError:
        # Source uses single-quoted labels, while repr may choose the same. Fall back explicitly.
        label_idx=script.index("'"+label+"'")
    start=script.rfind('once(',0,label_idx)
    if start<0:
        raise SystemExit(f'v354 source block start missing: {label}')
    next_idx=script.find('\nonce(',label_idx)
    if next_idx<0:
        # Last once() before the next non-once section.
        end=script.find('\n\n# ',label_idx)
        if end<0:
            raise SystemExit(f'v354 source block end missing: {label}')
    else:
        end=next_idx+1
    return script[:start]+replacement+script[end:]

key_repair=r'''key_pattern=re.compile(r"key\s*:\s*ValueKey\(\s*'brief-[^']*'\s*\),")
key_replacement="key:ValueKey('brief-$_liveRefreshTick-$selectedPackage-$selectedDashboardStateCode'),"
text,key_count=key_pattern.subn(key_replacement,text,count=1)
if key_count!=1:
    raise SystemExit(f'v354 daily brief key: expected 1 structural anchor, found {key_count}')
'''
source=replace_once_block(source,'daily brief key',key_repair)

overview_call_repair=r'''overview_pattern=re.compile(r"selectedPackage\s*:\s*selectedPackage\s*,\s*dashboardRequest\s*:\s*dashboardRequest\s*,")
overview_replacement=("selectedPackage: selectedPackage,\n"
    "            selectedStateCode: selectedDashboardStateCode,\n"
    "            onStateChanged: _selectDashboardStateV352,\n"
    "            dashboardRequest: dashboardRequest,")
text,overview_count=overview_pattern.subn(overview_replacement,text,count=1)
if overview_count!=1:
    raise SystemExit(f'v354 overview state call: expected 1 structural anchor, found {overview_count}')
'''
source=replace_once_block(source,'overview state call',overview_call_repair)

ctor_repair=r'''overview_class_start=text.find('class _OverviewContent extends StatelessWidget')
overview_metric_start=text.find('class _MetricGrid extends StatelessWidget',overview_class_start)
if overview_class_start<0 or overview_metric_start<0:
    raise SystemExit('v354 overview class boundaries missing')
overview_segment=text[overview_class_start:overview_metric_start]
ctor_pattern=re.compile(r"required\s+this\.selectedPackage\s*,\s*required\s+this\.dashboardRequest\s*,")
ctor_replacement=("required this.selectedPackage,\n"
    "    required this.selectedStateCode,\n"
    "    required this.onStateChanged,\n"
    "    required this.dashboardRequest,")
overview_segment,ctor_count=ctor_pattern.subn(ctor_replacement,overview_segment,count=1)
if ctor_count!=1:
    raise SystemExit(f'v354 overview constructor: expected 1 structural anchor, found {ctor_count}')
text=text[:overview_class_start]+overview_segment+text[overview_metric_start:]
'''
source=replace_once_block(source,'overview constructor',ctor_repair)

fields_repair=r'''overview_class_start=text.find('class _OverviewContent extends StatelessWidget')
overview_metric_start=text.find('class _MetricGrid extends StatelessWidget',overview_class_start)
overview_segment=text[overview_class_start:overview_metric_start]
fields_pattern=re.compile(r"final\s+String\s+selectedPackage\s*;\s*final\s+Future<Map<String,\s*dynamic>>\s+dashboardRequest\s*;")
fields_replacement=("final String selectedPackage;\n"
    "  final String selectedStateCode;\n"
    "  final ValueChanged<String> onStateChanged;\n"
    "  final Future<Map<String, dynamic>> dashboardRequest;")
overview_segment,fields_count=fields_pattern.subn(fields_replacement,overview_segment,count=1)
if fields_count!=1:
    raise SystemExit(f'v354 overview fields: expected 1 structural anchor, found {fields_count}')
text=text[:overview_class_start]+overview_segment+text[overview_metric_start:]
'''
source=replace_once_block(source,'overview fields',fields_repair)

subtitle_repair=r'''subtitle_pattern=re.compile(r"['\"]\$selectedPackage\s*•\s*Connecticut statewide['\"]")
text,subtitle_count=subtitle_pattern.subn("'$selectedPackage • $selectedStateCode • national Daily Brief'",text,count=1)
if subtitle_count!=1:
    raise SystemExit(f'v354 overview subtitle: expected 1 structural anchor, found {subtitle_count}')
'''
source=replace_once_block(source,'overview subtitle',subtitle_repair)

placement_repair=r'''overview_class_start=text.find('class _OverviewContent extends StatelessWidget')
overview_metric_start=text.find('class _MetricGrid extends StatelessWidget',overview_class_start)
overview_segment=text[overview_class_start:overview_metric_start]
placement_pattern=re.compile(r"const\s+SizedBox\(height:\s*\d+\)\s*,\s*if\s*\(snapshot\.hasError\)")
placement_replacement=("const SizedBox(height: 14),\n"
    "            _DashboardStateSelectorV352(stateCode:selectedStateCode,onChanged:onStateChanged),\n"
    "            const SizedBox(height: 12),\n"
    "            if(data!=null)_StateTruthBannerV352(status:data),\n"
    "            const SizedBox(height: 18),\n"
    "            if (snapshot.hasError)")
overview_segment,placement_count=placement_pattern.subn(placement_replacement,overview_segment,count=1)
if placement_count!=1:
    raise SystemExit(f'v354 dashboard controls placement: expected 1 structural anchor, found {placement_count}')
text=text[:overview_class_start]+overview_segment+text[overview_metric_start:]
'''
source=replace_once_block(source,'dashboard state controls placement',placement_repair)

namespace={'__name__':'__main__','__file__':str(source_path)}
exec(compile(source,str(source_path),'exec'),namespace,namespace)
print('BRIDGEPOINT NATIONAL DASHBOARD V354 COMPATIBILITY PASSED')
print(' - Daily Brief migration anchors matched structurally; V352 low-I/O runtime behavior unchanged')
