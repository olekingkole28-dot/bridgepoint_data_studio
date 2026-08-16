from pathlib import Path
import re

body=Path('lib/main.dart').read_text(encoding='utf-8')
fail=[]

required=[
 'Save my info for next time','Your nickname','bridgepoint_property_browser_v188','All My States',
 'Current recorded owner','Open aerial • pinch / scroll to zoom','bridgepoint-property-street-media-v186',
 'World_Boundaries_and_Places','Center on my current location','NOAA WEATHER MOTION','Pause weather motion',
 'BUILDING NOW','bridgepoint_expansion_eta_v188','_bridgePointPageAccent','_bridgePointCustomerSafeKey',
 'https://bridgepointintelligence.online/',
]
for x in required:
    if x not in body: fail.append(f'missing required UI/release marker: {x}')

for pattern,label in [
 (r'onPressed\s*:\s*\(\)\s*\{\s*\}', 'empty onPressed handler'),
 (r'onTap\s*:\s*\(\)\s*\{\s*\}', 'empty onTap handler'),
 (r'tooltip\s*:\s*[\'\"]Reset Connecticut', 'legacy Connecticut reset control'),
 (r'bridgepoint_flutter_property_suggestions_v77[\s\S]{0,180}p_state_code[\s\S]{0,40}CT', 'Connecticut-only global search'),
 (r'https://olekingkole28-dot\.github\.io/bridgepoint-live', 'legacy public GitHub Pages URL'),
]:
    if re.search(pattern,body,re.I): fail.append(label)

# Every visible navigation index in the current workspace must resolve to a real page case.
for idx in range(14):
    if f'case {idx}:' not in body: fail.append(f'visible navigation index {idx} has no page case')

# Guard customer-facing generic JSON renderer from proprietary internals.
for token in ['formula','weight','score_breakdown','model_definition','metadata']:
    if token not in body[body.find('bool _bridgePointCustomerSafeKey'):body.find('class _JsonIntelligenceList')]:
        fail.append(f'customer-safe JSON filter does not block {token}')

if fail:
    print('STRICT RELEASE AUDIT FAILED')
    for item in fail: print(' -',item)
    raise SystemExit(1)
print('Strict release contract audit passed: routes, click handlers, multistate search, customer-safe details, location, weather, domain, expansion UI, and media markers are present.')
