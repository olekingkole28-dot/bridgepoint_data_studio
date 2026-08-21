from pathlib import Path
import runpy

# Apply only after the verified v380 generated release exists.
text=Path('lib/main.dart').read_text(encoding='utf-8')
if 'bridgepoint-v380-owner-national-cockpit' not in text:
    raise SystemExit('v381 requires generated v380 owner cockpit baseline')

runpy.run_path('tool/apply_customer_preview_mobile_v381.py',run_name='__main__')
runpy.run_path('tool/apply_map_modes_radar_v381.py',run_name='__main__')
runpy.run_path('tool/apply_owner_visual_national_v381.py',run_name='__main__')

text=Path('lib/main.dart').read_text(encoding='utf-8')
required=[
    'bridgepoint-v381a-customer-preview-mobile',
    'bridgepoint-v381b-clean-map-radar',
    'bridgepoint-v381c-owner-visual-national',
    'bridgepoint_owner_preview_contract_v381',
    'bridgepoint_owner_permit_coverage_v381',
    "_mapModeV381='INTELLIGENCE'",
    'radar-prev-v381',
    'NATIONAL EXPANSION COMMAND',
]
missing=[x for x in required if x not in text]
if missing:
    raise SystemExit(f'v381 final contract missing: {missing}')
for forbidden in ['Raw live backend details','owner-only navigation is hidden; your real backend owner permissions are unchanged.']:
    if forbidden in text:
        raise SystemExit(f'v381 legacy UI still present: {forbidden}')
html=Path('web/index.html').read_text(encoding='utf-8')
if 'bp-expansion-launcher' in html or '>Expansion Engine<' in html:
    raise SystemExit('v381 web duplicate expansion launcher survived v380 cleanup')
print('BRIDGEPOINT V381 OWNER/CUSTOMER/MAP EXPERIENCE AUDIT PASSED')
