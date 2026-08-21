from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v422-owner-funnel-truth'
if marker in text:
    print('Owner Funnel Truth V422 already applied')
    raise SystemExit(0)
if 'bridgepoint-v420-owner-cross-filters' not in text:
    raise SystemExit('V422 requires V420 Owner Everything filters')

old_rpc="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v417',{'p_since':_since().toUtc().toIso8601String()});"
new_rpc="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v422',{'p_since':_since().toUtc().toIso8601String()});"
if text.count(old_rpc)!=1:
    raise SystemExit(f'V422 owner RPC anchor count {text.count(old_rpc)}')
text=text.replace(old_rpc,new_rpc,1)

old_head="""    if(key=='funnel')return '${funnel['unique_visitors_24h']??0} visitors/24h • ${funnel['active_trials']??0} server-side trials • ${funnel['tracking_status']??'tracking status unavailable'}';
"""
new_head="""    if(key=='funnel'){
      final health=metricValue(funnel['health']),conversion=metricValue(funnel['conversion']),browser=map(conversion['browser']),drop=map(conversion['largest_dropoff']);
      final browserEvents=browser['browser_events']??0,tracking=health['tracking_status']??'tracking status unavailable',trials=health['active_trials']??0;
      final dropText=drop['window']=='UNAVAILABLE'?'largest drop-off unavailable':'largest drop: ${drop['prior_count']??0} → ${drop['current_count']??0} into ${drop['into_stage']??'next stage'}';
      return '$browserEvents browser events • $trials server-side trials • $tracking • $dropText';
    }
"""
if text.count(old_head)!=1:
    raise SystemExit(f'V422 funnel headline anchor count {text.count(old_head)}')
text=text.replace(old_head,new_head,1)

text += '\n// bridgepoint-v422-owner-funnel-truth\n'
path.write_text(text,encoding='utf-8')
print('Applied Owner Funnel Truth V422')
