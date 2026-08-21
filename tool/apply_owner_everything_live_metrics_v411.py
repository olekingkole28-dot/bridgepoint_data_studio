from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v415-owner-truth'

if marker in text:
    print('Owner Everything V415 truth already applied')
    raise SystemExit(0)
if 'bridgepoint-v410-owner-everything-command-center' not in text:
    raise SystemExit('V415 requires Owner Everything V410')

old="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v410',{'p_since':_since().toUtc().toIso8601String()});"
new="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v415',{'p_since':_since().toUtc().toIso8601String()});"
if text.count(old)!=1:
    raise SystemExit(f'V415 owner RPC anchor count {text.count(old)}')
text=text.replace(old,new,1)

old_head=r'''  String _headline(String key,Map<String,dynamic> live){
    final systems=map(live['systems']),national=map(live['national']),funnel=map(live['funnel']),outreach=map(live['outreach']),social=map(live['social']);
    if(key=='overview')return '${systems['overall_status']??'Status loading'} • ${rows(systems['systems']).length} monitored systems';
    if(key=='coverage')return '${national['average_verified_progress_pct']??'—'}% average verified progress • ${rows(national['states']).length} states';
    if(key=='funnel')return '${funnel['unique_visitors']??0} unique visitors • ${funnel['known_users']??0} known users in selected window';
    if(key=='outreach')return '${outreach['emails_sent']??0} sent • ${outreach['replies']??0} replies • ${outreach['paid_customers']??0} paid';
    if(key=='social')return '${rows(social['connections']).length} provider targets • ${_socialCount(social,'PUBLISHED')} published attempts recorded';
    if(key=='registry')return '${rows(live['features']).length} major workstreams registered';
    if(key=='glossary')return '${rows(live['glossary']).length} owner terms explained';
    return 'Open Details for current source-of-truth status';
  }
'''
new_head=r'''  String _headline(String key,Map<String,dynamic> live){
    final systems=map(live['systems']),national=map(live['national']),funnel=map(live['funnel']),outreach=map(live['outreach']),social=map(live['social']);
    final metrics=map(live['metrics']),snapshot=map(live['snapshot']),access=map(live['access']);
    Map<String,dynamic> metricValue(dynamic metric)=>map(map(metric)['value']);
    if(key=='overview'){
      final cron=metricValue(systems['cron']);
      return '${systems['overall_status']??'Status loading'} • ${rows(systems['workers']).length} ChatGPT workers • ${cron['failed']??0} current cron failures';
    }
    if(key=='coverage'){
      final summary=metricValue(national['summary']),tasks=metricValue(national['source_tasks']);
      return '${summary['states']??0} states • ${summary['canonical_properties']??0} canonical properties • ${tasks['failed']??0} failed source tasks';
    }
    if(key=='matching'){
      final m=metricValue(snapshot['matching']);
      return '~${m['evidence_estimated_total']??'—'} evidence • ~${m['signal_estimated_total']??'—'} signals • ${m['signal_created_24h']??0} signals/24h • ${m['match_review_pending']??0} review';
    }
    if(key=='scoring'){
      final i=metricValue(snapshot['intelligence']),v=map(i['verified_opportunities']);
      return '${v['total']??0} VERIFIED • ~${i['score_estimated_total']??'—'} scores • ${i['patterns_recent_24h']??0} recent patterns • ${i['future_dated_patterns']??0} timing warnings';
    }
    if(key=='readiness'){
      final r=metricValue(access['national_contract']);
      return '${r['states_with_scores']??0} states with scores • ${r['states_with_opportunities']??0} with strict opportunities • ${r['health_status']??'contract status unavailable'}';
    }
    if(key=='billing'){
      final b=map(live['billing']),s=map(b['subscriptions']),t=map(b['trial_scope']),r=map(b['readiness']);
      return '${s['ordinary_customer_active_trials']??s['active_trials']??0} customer trials • ${s['paid_customers']??0} paid • ${t['platform_override_active_trials']??0} owner/test trials • ${r['readiness']??'billing status unavailable'}';
    }
    if(key=='funnel')return '${funnel['unique_visitors_24h']??0} visitors/24h • ${funnel['active_trials']??0} server-side trials • ${funnel['tracking_status']??'tracking status unavailable'}';
    if(key=='outreach')return '${outreach['sent_24h']??0} sent/24h • ${outreach['replies']??0} replies • ${outreach['sample_requests']??0} samples • ${outreach['paid']??0} paid';
    if(key=='referrals'){final r=map(map(live['referrals'])['summary']);return '${r['active']??0} tracked links • ${r['clicks']??0} clicks • ${r['signups']??0} signups • ${r['paid']??0} paid';}
    if(key=='newsroom'){final n=map(map(live['newsroom'])['owned_media']);return '${n['published']??0} published • ${n['stories_total']??0} generated/draft items • ${n['audio_files']??0} audio files';}
    if(key=='social'){
      final oauth=metricValue(social['oauth']),attempts=metricValue(social['attempts']);
      return '${oauth['publish_ready']??0} publish-ready • ${oauth['blocked']??0} OAuth blocked • ${attempts['published']??0} published attempts';
    }
    if(key=='earned'){final e=map(live['earned']);return '${e['sent_or_submitted']??0} sent/submitted • ${e['accepted']??0} accepted • ${e['published']??0} published • ${e['backlinks']??0} backlinks';}
    if(key=='experiments'){final e=map(live['experiments']);return '${e['active']??0} active experiments • ${e['experiments']??0} registered';}
    if(key=='security'){final r=metricValue(map(live['security'])['rls']);return '${r['rls_disabled_non_system_tables']??0} tables need RLS review • backup proof stays explicit until verified';}
    if(key=='activity'){final a=map(live['activity']);return '${rows(a['feed']).length} meaningful recent events • cross-system feed live';}
    if(key=='registry')return '${rows(live['features']).length} major workstreams registered';
    if(key=='glossary')return '${rows(live['glossary']).length} owner terms explained';
    final metric=map(metrics['$key.summary']);
    if(metric.isNotEmpty)return '${metric['observed_state']??'UNAVAILABLE'} • ${metric['limitation']??'Open Details for current source-of-truth status'}';
    return 'Open Details for current source-of-truth status';
  }
'''
if text.count(old_head)!=1:
    raise SystemExit(f'V415 headline anchor count {text.count(old_head)}')
text=text.replace(old_head,new_head,1)

insert='\n// bridgepoint-v415-owner-truth\n'
text=text+insert
path.write_text(text,encoding='utf-8')
print('Applied Owner Everything V415 reconciled owner truth')
