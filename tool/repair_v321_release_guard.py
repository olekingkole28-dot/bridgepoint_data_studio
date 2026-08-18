from pathlib import Path

path=Path('tool/apply_resilience_expansion_radar_v321.py')
body=path.read_text(encoding='utf-8')
old='    "bridgepoint_user_market_context_v320",\n'
new='    "bridgepoint_public_expansion_status_v321",\n'
if old in body:
    body=body.replace(old,new,1)
    path.write_text(body,encoding='utf-8')
    print('Repaired v321 marker audit to validate the active expansion-status contract.')
elif new in body:
    print('v321 marker audit already repaired.')
else:
    raise SystemExit('v321 guard repair anchor missing')
