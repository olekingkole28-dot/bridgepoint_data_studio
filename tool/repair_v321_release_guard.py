from pathlib import Path

path=Path('tool/apply_resilience_expansion_radar_v321.py')
body=path.read_text(encoding='utf-8')
replacements={
    '    "bridgepoint_user_market_context_v320",\n':'    "bridgepoint_public_expansion_status_v321",\n',
    '    "Queued • position",\n':'    "bridgepoint_public_expansion_status_v321",\n',
}
changed=0
for old,new in replacements.items():
    if old in body:
        body=body.replace(old,new,1)
        changed+=1
if changed:
    path.write_text(body,encoding='utf-8')
    print(f'Repaired {changed} v321 marker audit expectation(s) to validate active backend contracts instead of dynamic UI text.')
elif 'bridgepoint_public_expansion_status_v321' in body:
    print('v321 marker audit already repaired.')
else:
    raise SystemExit('v321 guard repair anchors missing')
