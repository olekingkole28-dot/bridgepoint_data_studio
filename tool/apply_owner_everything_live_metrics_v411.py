from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v411-owner-live-metrics'

if marker in text:
    print('Owner Everything V411 live metrics already applied')
    raise SystemExit(0)
if 'bridgepoint-v410-owner-everything-command-center' not in text:
    raise SystemExit('V411 requires Owner Everything V410')

old="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v410',{'p_since':_since().toUtc().toIso8601String()});"
new="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v411',{'p_since':_since().toUtc().toIso8601String()});"
if text.count(old)!=1:
    raise SystemExit(f'V411 owner RPC anchor count {text.count(old)}')
text=text.replace(old,new,1)

old_head="""    if(key=='social')return '${rows(social['connections']).length} provider targets • ${_socialCount(social,'PUBLISHED')} published attempts recorded';
    if(key=='registry')return '${rows(live['features']).length} major workstreams registered';
"""
new_head="""    if(key=='social')return '${rows(social['connections']).length} provider targets • ${_socialCount(social,'PUBLISHED')} published attempts recorded';
    if(key=='billing'){final b=map(live['billing']),s=map(b['subscriptions']),r=map(b['readiness']);return '${s['customer_active_trials']??0} customer trials • ${s['customer_active_paid']??0} paid customers • ${s['owner_admin_trial_rows']??0} owner/test trial rows • ${r['readiness']??'billing status unavailable'}';}
    if(key=='referrals'){final r=map(live['referrals']),s=map(r['summary']);return '${s['active_links']??0} tracked links • ${s['clicks']??0} clicks • ${s['signups']??0} signups • ${s['paid']??0} paid';}
    if(key=='activity'){final a=map(live['activity']);return '${rows(a['feed']).length} meaningful events in selected window • cross-system feed expanding';}
    if(key=='registry')return '${rows(live['features']).length} major workstreams registered';
"""
if text.count(old_head)!=1:
    raise SystemExit(f'V411 headline anchor count {text.count(old_head)}')
text=text.replace(old_head,new_head,1)

insert='\n// bridgepoint-v411-owner-live-metrics\n'
text=text+insert
path.write_text(text,encoding='utf-8')
print('Applied Owner Everything V411 live billing/referral/activity metrics')
