from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v304-customer-plain-language'
if marker in body:
    print('v304 already applied')
    raise SystemExit(0)

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

body += "\nconst String _bridgePointCustomerPlainLanguageV304='bridgepoint-v304-customer-plain-language | customer screens avoid internal version/backend vocabulary | owner technical detail preserved';\n"
path.write_text(body,encoding='utf-8')
print('Applied v304 customer plain-language polish.')