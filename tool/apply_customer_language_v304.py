from pathlib import Path
import re
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v304-customer-plain-language'
if marker in body:
    print('v304 already applied')
    raise SystemExit(0)

# v309 compile repair runs here because v304 is the first guaranteed release layer
# immediately after v290 in the production workflow.
immersive_old="i%4==0?.08:.035"
immersive_new="i%4==0 ? 0.08 : 0.035"
immersive_count=body.count(immersive_old)
if immersive_count!=1:
    raise SystemExit(f'v309 Signals ternary anchor count {immersive_count}')
body=body.replace(immersive_old,immersive_new,1)
semantic_start=body.find('class _BridgePointSemanticScenePainterV290')
semantic_end=body.find('class _BridgePointSpatialAtmospherePainterV287',semantic_start)
if semantic_start<0 or semantic_end<0:
    raise SystemExit('v309 semantic painter bounds unavailable')
if re.findall(r'\d\?\.\d',body[semantic_start:semantic_end]):
    raise SystemExit('v309 ambiguous conditional decimal remains in semantic painter')

replacements={
    "Yes. BridgePoint V81 uses negative scoring. Missing direct matches, missing corroboration, weak source diversity, older evidence, and lower confidence subtract visible points.":
    "Yes. BridgePoint scoring can subtract points when direct matches or corroboration are missing, evidence is older, source diversity is weak, or confidence is lower.",
    "detail: 'V36 compound property intelligence',":"detail: 'Compound property intelligence',",
    "Search BridgePoint’s canonical property inventory.":"Search BridgePoint’s live property inventory.",
    "The canonical home, building, parcel or place that all other observations connect back to.":"The home, building, parcel or place that BridgePoint connects evidence and observations back to.",
    "title: 'Source Registry',":"title: 'Live Data Sources',",
    "Automatically rendered from Supabase — no hard-coded source cards":"Automatically refreshed from BridgePoint’s live source registry",
}
for old,new in replacements.items():
    count=body.count(old)
    if count!=1:
        raise SystemExit(f'v304 anchor count {count}: {old[:80]}')
    body=body.replace(old,new,1)

body += "\nconst String _bridgePointSemanticImmersiveCompileV309='bridgepoint-v309-semantic-immersive-compile | Signals ternary numeric syntax repaired';\n"
body += "\nconst String _bridgePointCustomerPlainLanguageV304='bridgepoint-v304-customer-plain-language | customer screens avoid internal version/backend vocabulary | owner technical detail preserved';\n"
path.write_text(body,encoding='utf-8')
print('Applied v309 immersive compile repair + v304 customer plain-language polish.')

# v312 replaces the old diagram/grid animation with the cinematic parallax environment
# on every release that passes through v304.
runpy.run_path('tool/apply_cinematic_immersive_v312.py',run_name='__main__')
