from pathlib import Path

path=Path('lib/screens/bridgepoint_owner_command_center.dart')
text=path.read_text(encoding='utf-8')
original=text


def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

import_anchor="import 'bridgepoint_owner_global_control.dart';\n"
new_import="import 'bridgepoint_owner_surface_audit_v792.dart';\n"
if new_import not in text:
    if text.count(import_anchor)!=1:
        raise SystemExit('surface-import-anchor missing/duplicated')
    text=text.replace(import_anchor,import_anchor+new_import,1)

segment_anchor="""                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.build_circle_outlined),
                  label: Text('Operations'),
                ),
"""
segment_new=segment_anchor+"""                ButtonSegment(
                  value: 4,
                  icon: Icon(Icons.visibility_outlined),
                  label: Text('Surfaces'),
                ),
"""
if "label: Text('Surfaces')" not in text:
    replace_once(segment_anchor,segment_new,'surface-tab-segment')

old_switch="""            2 => const BridgePointOwnerGlobalControl(),
            _ => const BridgePointOperationsHub(),
"""
new_switch="""            2 => const BridgePointOwnerGlobalControl(),
            3 => const BridgePointOperationsHub(),
            _ => const BridgePointOwnerSurfaceAudit(),
"""
if 'const BridgePointOwnerSurfaceAudit()' not in text:
    replace_once(old_switch,new_switch,'surface-tab-switch')

# The ledger is intentionally future-safe. It must not truncate as the durable
# requirement set grows beyond the original 216 cross-chat recovery list.
text=text.replace("'p_limit': 216,","'p_limit': 1000,",1)
text=text.replace("DropdownMenuItem(value: 'ALL', child: Text('All 216'))","DropdownMenuItem(value: 'ALL', child: Text('All requirements'))",1)

if text==original:
    print('Owner surface audit wiring already applied v792')
else:
    path.write_text(text,encoding='utf-8')
    print('Applied owner surface audit and future-safe completion limit v792')
