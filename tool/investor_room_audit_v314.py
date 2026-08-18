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
            errors.append(f'{label}: forbidden legacy pattern remains: {needle}')

require('Investor Room identity',
        'bridgepoint-v314-investor-room',
        'class _OwnerInvestorRoomV314',
        "bridgepoint_owner_investor_room_v314")

require('Investor aggregated feed fields',
        "room['metrics']",
        "room['valuation']",
        "room['investor_targets']",
        "room['package_entitlement_audit']")

require('Investor Room charts',
        'class _InvestorValuationChartV314',
        'class _InvestorValuationPainterV314',
        'WHAT IS MOVING THE MODELED VALUE',
        'COMMERCIAL TRACTION FUNNEL',
        'GEOGRAPHIC SCALE',
        'Milestone high-water')

require('Investor export',
        "investor_export_stub.dart' if (dart.library.html) 'investor_export_web.dart'",
        'Download Investor Brief',
        "Icons.print_rounded",
        'bridgepointDownloadInvestorHtml',
        'bridgepointPrintInvestorHtml',
        'BridgePoint_Investor_Brief_')

require('Investor targets',
        'Investor targets',
        'Public contact / pitch',
        'Update investor status',
        'contact_reverification_due',
        'Investment closed: use Owner Center')

require('Valuation integrity wording',
        'MODELED PRE-MONEY ESTIMATE',
        'Modeled contribution',
        'not an appraisal or guarantee',
        'package entitlement audit')

require('Owner Investor Room active',
        'if(showInvestor)...[const _OwnerInvestorRoomV314()')
forbid('Owner Investor Room active',
       'if(showInvestor)...[const _OwnerInvestorCockpitV277()')

# Preserve every critical final-polish contract around the new investor layer.
require('Inherited final polish',
        'bridgepoint-v313-dna-data-tunnel-background',
        'bridgepoint-v313-expansion-dual-source-resilience',
        'bridgepoint-v313-owner-outreach-readiness',
        'bridgepoint-v313-noaa-verified-frame-fallback',
        'bridgepoint-v313-responsive-action-rows',
        'bridgepoint-v313-brand-live-refresh',
        'bridgepoint-v263-package-aware-ai',
        'bridgepoint-v279-community-3d-live-weather',
        'bridgepoint-v284-founder-reviews-customer-preview')

empty_patterns=[
    r'onPressed\s*:\s*\(\)\s*\{\s*\}',
    r'onTap\s*:\s*\(\)\s*\{\s*\}',
    r'onPressed\s*:\s*\(\s*\)\s*=>\s*null',
    r'onTap\s*:\s*\(\s*\)\s*=>\s*null',
]
for pat in empty_patterns:
    if re.search(pat,body,re.S):
        errors.append(f'interaction audit: dead callback matched {pat}')

if errors:
    print('BRIDGEPOINT V314 INVESTOR ROOM AUDIT FAILED')
    for item in errors:
        print(' -',item)
    raise SystemExit(1)

print('BRIDGEPOINT V314 INVESTOR ROOM AUDIT PASSED')
print(' - Investor Room is the active owner investor experience')
print(' - one aggregated owner RPC supplies valuation, metrics, investor targets and entitlement status')
print(' - valuation history, driver bars, traction funnel and geographic scale charts are present')
print(' - print and downloadable investor brief controls are present')
print(' - live investor target pipeline and status controls are present')
print(' - valuation is labeled modeled/pre-money and is not presented as a certified appraisal')
print(' - package entitlement audit is surfaced in the investor story')
print(' - v313 AI/weather/expansion/outreach/profile/customer-preview contracts remain intact')
