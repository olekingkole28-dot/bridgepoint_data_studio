from pathlib import Path
import re
import subprocess
import sys

# v212 is intentionally the final generated-source layer. Reconstruct it from the
# small source-controlled parts so older release patches cannot overwrite it.
parts=sorted(Path('tool/v212_parts').glob('part_*'))
if len(parts)!=8:
    raise SystemExit(f'Expected 8 v212 patch parts, found {len(parts)}')
patcher=Path('/tmp/apply_stability_ux_v212.py')
patcher.write_text(''.join(x.read_text(encoding='utf-8') for x in parts),encoding='utf-8')
subprocess.run([sys.executable,str(patcher),'lib/main.dart'],check=True)

body=Path('lib/main.dart').read_text(encoding='utf-8')
fail=[]

required=[
 'Save my info for next time','Your nickname','bridgepoint_property_browser_v188','All My States',
 'Current recorded owner','Open aerial • pinch / scroll to zoom','bridgepoint-property-street-media-v186',
 'World_Boundaries_and_Places','Center on my current location','NOAA WEATHER MOTION','Pause weather motion',
 'BUILDING NOW','_bridgePointPageAccent','_bridgePointCustomerSafeKey',
 'https://bridgepointintelligence.online/',
 # v212 production/UX contract
 'bridgepoint-v212-stability-connected-release','Pattern Intelligence','_PatternIntelligencePageV212',
 'bridgepoint_pattern_intelligence_v212','bridgepoint_expansion_progress_v212','MOST ACTIVE SIGNAL TYPES',
 'bridgepoint_top_signal_types_v212','MY PROPERTY TRACKERS','bridgepoint_my_property_trackers_v212',
 'Community Observation Map','BridgePoint Community Chat','bridgepoint_community_channels_v212',
 'Test NOAA live','bridgepoint-noaa-live-health-v212','_BrandContactProfileV212',
 'Show more plans','DRAG TO PAN • PINCH / SCROLL TO ZOOM',
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

# v212 routes by label so owner-only items can sit first without index drift.
for label in [
 'Daily Brief','Opportunities','Intelligence Map','Properties','My Home','My Work','Field Mode',
 'Weather Center','Signals','Community','Pattern Intelligence','Packages','About BridgePoint','Sources',
 'Permit Context','Coverage','Models','Settings','Owner Center','Owner Demo','Founder Command'
]:
    if f"case '{label}':" not in body: fail.append(f'navigation label has no page route: {label}')

# Guard customer-facing generic JSON renderer from proprietary internals.
safe=body[body.find('bool _bridgePointCustomerSafeKey'):body.find('class _JsonIntelligenceList')]
for token in ['formula','weight','score_breakdown','model_definition','metadata']:
    if token not in safe:
        fail.append(f'customer-safe JSON filter does not block {token}')

if fail:
    print('STRICT RELEASE AUDIT FAILED')
    for item in fail: print(' -',item)
    raise SystemExit(1)
print('Strict v212 release audit passed: stability, owner isolation, multistate search, NOAA health, expansion progress, trackers, community, pattern intelligence, packages, media, walkthrough and customer-safe details are present.')
