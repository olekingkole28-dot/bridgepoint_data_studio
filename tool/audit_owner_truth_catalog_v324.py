from pathlib import Path

body=Path('lib/main.dart').read_text(encoding='utf-8')
errors=[]

def require(label,*needles):
    for needle in needles:
        if needle not in body:
            errors.append(f'{label}: missing {needle}')

def forbid(label,*needles):
    for needle in needles:
        if needle in body:
            errors.append(f'{label}: forbidden {needle}')

require('v324 identity','bridgepoint-v324-owner-truth-customer-safe-catalog')
require('canonical owner truth','class _OwnerTruthPanelV324','bridgepoint_owner_truth_v322','CANONICAL OWNER TRUTH','CUSTOMER ACCOUNTS','PRODUCTION BILLING','CT PERMIT SOURCES','PERMITS MATCHED','DB / QUEUE')
require('owner/investor placement',"const _OwnerTruthPanelV324()","const _OwnerTruthPanelV324(contextLabel:'INVESTOR ROOM')")
require('owner catalog proof',"catalog_scope","OWNER CATALOG","owner priority ${model['priority_threshold']}")
forbid('customer package threshold leakage'," • priority ${model['priority_threshold']")

if body.count('_OwnerTruthPanelV324(')<3:
    errors.append('canonical owner truth: expected class constructor plus Owner Center and Investor Room placements')

if errors:
    print('BRIDGEPOINT V324 RELEASE AUDIT FAILED')
    for e in errors:
        print(' -',e)
    raise SystemExit(1)

print('BRIDGEPOINT V324 RELEASE AUDIT PASSED')
print(' - canonical owner truth is visible in Owner Center and Investor Room')
print(' - customer package detail no longer exposes scoring thresholds')
print(' - owner package view retains owner-only threshold detail')
