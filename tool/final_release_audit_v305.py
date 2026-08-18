from pathlib import Path
import re

body=Path('lib/main.dart').read_text(encoding='utf-8')
errors=[]

def require(label,*needles):
    for needle in needles:
        if needle not in body:
            errors.append(f'{label}: missing {needle}')

def forbid(label,*needles):
    for needle in needles:
        if needle in body:
            errors.append(f'{label}: forbidden legacy/customer text still present: {needle}')

require('release identity',
        'https://bridgepointintelligence.online/',
        'bridgepoint-v290-semantic-immersive-backgrounds',
        'bridgepoint-v304-customer-plain-language')

require('immersive rendering',
        '_BridgePointSemanticScenePainterV290',
        '_bridgePointPageAccentV290',
        'scene:spec.scene',
        'panel.withOpacity(.90)',
        'disableAnimations')

for label in [
    'Daily Brief','Opportunities','Intelligence Map','Properties','My Home','My Work','Field Mode',
    'Weather Center','Signals','Community','Pattern Intelligence','Packages','About BridgePoint','Sources',
    'Permit Context','Coverage','Models','Settings','Owner Center','Founder Command','Owner Demo'
]:
    if f"'{label}'" not in body:
        errors.append(f'immersive page map: missing page label {label}')

require('customer/owner boundary',
        '_effectiveOwnerMode',
        'CUSTOMER PREVIEW',
        'DEMO • NO CHARGE',
        'This preview never opens a payment session.',
        "configuration['checkout_ready']==true&&configuration['available_for_self_checkout']==true")

require('accessibility',
        'Larger text',
        'Stronger contrast',
        'Reduce motion and scanning effects',
        'Simplified views (hide optional map layers)')

require('legal and privacy',
        'BridgePoint Legal & Trust Summary',
        'not professional advice or proof of damage, coverage, a permit, customer intent, or a guaranteed outcome',
        'privacy')

require('launch-critical customer workflows',
        'Send to CRM','Customize Dashboard','Save my info for next time','Your nickname',
        'Center on my current location','Property Image History','Add / update front photo',
        'BridgePoint Community Chat','Show more plans','Sign out')

forbid('plain-language customer polish',
       'BridgePoint V81 uses negative scoring',
       'V36 compound property intelligence',
       'Search BridgePoint’s canonical property inventory.',
       'Automatically rendered from Supabase — no hard-coded source cards')

empty_patterns=[
    r'onPressed\s*:\s*\(\)\s*\{\s*\}',
    r'onTap\s*:\s*\(\)\s*\{\s*\}',
    r'onPressed\s*:\s*\(\s*\)\s*=>\s*null',
    r'onTap\s*:\s*\(\s*\)\s*=>\s*null',
]
for pat in empty_patterns:
    if re.search(pat,body,re.S):
        errors.append(f'interaction audit: empty/dead callback matched {pat}')

# Prevent raw formulas/internal implementation details from re-entering customer evidence cards.
require('customer-safe evidence', '_bridgePointCustomerSafeKey')

if errors:
    print('BRIDGEPOINT FINAL RELEASE AUDIT FAILED')
    for item in errors:
        print(' -',item)
    raise SystemExit(1)

print('BRIDGEPOINT FINAL RELEASE AUDIT PASSED')
print(' - page-specific immersive background contract present')
print(' - customer preview/no-charge and checkout gates present')
print(' - customer-facing technical-version wording removed')
print(' - accessibility/legal/privacy/customer-safe evidence contracts present')
print(' - no empty click handlers detected')
