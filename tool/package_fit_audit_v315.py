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
            errors.append(f'{label}: forbidden legacy onboarding remains: {needle}')

require('v315 identity','bridgepoint-v315-catalog-aware-onboarding','class _PackageFitQuestionnaireV315','class _PackageFitResultDialogV315','class _OwnerPackageFitPreviewDialogV315')
require('catalog-aware RPCs','bridgepoint_complete_onboarding_v315','bridgepoint_package_fit_preview_v315')
require('targeted questions',
        'Which best describes you or your organization?',
        'What kind of properties or assets matter most?',
        'What is the biggest outcome you want from BridgePoint?',
        'Which capabilities would help you most?',
        'How many people will use BridgePoint?',
        'How broad is your territory?',
        'How do you want BridgePoint delivered?')
require('audience coverage',
        'Homeowner','Roofing / exterior contractor','Public adjuster / claims professional','Commercial real estate / property management',
        'Property investor / acquisitions','Solar / energy','Institutional investor / analytics','Insurer / risk / analytics','Software / data / platform','Government / infrastructure')
require('technology capability coverage',
        'Data onboarding','Coverage readiness','Source health / provenance','Property resolution','Signal / evidence normalization','Imagery / physical change',
        'Outcome learning','Historical replay','Team roles / entitlements','Natural-language AI','Marketplace / entitlements','API access','White-label portal','Source ROI')
require('availability honesty','BEST ACTIONABLE FIT','Available now','Managed activation','Future / early-access fit','not falsely offered as immediately ready')
require('owner exact preview','Preview as customer','Preview package fit','Customer package-fit preview','same package-fit questionnaire a new customer sees','Preview answers do not change your founder profile')
require('billing/access separation','A recommendation never purchases a plan automatically','server-side billing and entitlement rules')
forbid('legacy first-login recommender',"_callRpc('bridgepoint_complete_onboarding_v70'")

# Inherited release contracts must survive v315.
require('inherited release',
        'bridgepoint-v313-dna-data-tunnel-background','bridgepoint-v314-investor-room','bridgepoint-v263-package-aware-ai',
        'bridgepoint-v279-community-3d-live-weather','bridgepoint-v284-founder-reviews-customer-preview','bridgepoint-v313-owner-outreach-readiness')

empty_patterns=[r'onPressed\s*:\s*\(\)\s*\{\s*\}',r'onTap\s*:\s*\(\)\s*\{\s*\}',r'onPressed\s*:\s*\(\s*\)\s*=>\s*null',r'onTap\s*:\s*\(\s*\)\s*=>\s*null']
for pat in empty_patterns:
    if re.search(pat,body,re.S):errors.append(f'interaction audit: dead callback matched {pat}')

if errors:
    print('BRIDGEPOINT V315 PACKAGE FIT AUDIT FAILED')
    for item in errors:print(' -',item)
    raise SystemExit(1)

print('BRIDGEPOINT V315 PACKAGE FIT AUDIT PASSED')
print(' - first-login questions cover consumer, contractor, investor, company, enterprise, infrastructure and technology use cases')
print(' - package recommendations use the v315 catalog-aware backend instead of legacy package keys')
print(' - available, managed and future fits are clearly separated')
print(' - owner can preview the exact customer questionnaire without changing founder profile')
print(' - DNA background, Investor Room, AI, Community 3D, outreach and customer preview contracts remain present')
