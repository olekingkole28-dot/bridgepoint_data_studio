from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v417-owner-running-release-truth'
if marker in text:
    print('Owner running release truth V417 already applied')
    raise SystemExit(0)
if 'bridgepoint-v416-owner-attention' not in text:
    raise SystemExit('V417 requires V416 Owner Attention')

rpc_old="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v415',{'p_since':_since().toUtc().toIso8601String()});"
rpc_new="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v417',{'p_since':_since().toUtc().toIso8601String()});"
if text.count(rpc_old)!=1:
    raise SystemExit(f'V417 owner RPC anchor count {text.count(rpc_old)}')
text=text.replace(rpc_old,rpc_new,1)

headline_anchor="    if(key=='social'){"
if text.count(headline_anchor)!=1:
    raise SystemExit(f'V417 headline placement anchor count {text.count(headline_anchor)}')
headline_insert=r'''    if(key=='podcast'){
      final p=metricValue(map(live['podcast'])['feed_directory']);
      return '${p['approved_scripts']??0} approved scripts • ${p['audio_files_present']??0} audio files • ${p['published_audio_episodes']??0} published episodes • RSS ${p['rss_feed_observable']==true?'observable':'not yet observable'}';
    }
    if(key=='lifecycle'){
      final l=metricValue(map(live['lifecycle'])['newsletter']);
      return '${l['approved_newsletter_derivatives']??0} approved newsletter items • ${l['published_newsletter_derivatives']??0} published • send ledger ${l['send_ledger_observable']==true?'observable':'not yet observable'}';
    }
'''
text=text.replace(headline_anchor,headline_insert+headline_anchor,1)

attention_anchor="    final systems=map(live['systems']),national=map(live['national']),snapshot=map(live['snapshot']),social=map(live['social']);"
if text.count(attention_anchor)!=1:
    raise SystemExit(f'V417 attention data anchor count {text.count(attention_anchor)}')
attention_replace="    final systems=map(live['systems']),national=map(live['national']),snapshot=map(live['snapshot']),social=map(live['social']),podcast=map(live['podcast']),lifecycle=map(live['lifecycle']);"
text=text.replace(attention_anchor,attention_replace,1)

metric_anchor="    final cron=metricValue(systems['cron']),tasks=metricValue(national['source_tasks']),intel=metricValue(snapshot['intelligence']),matching=metricValue(snapshot['matching']),oauth=metricValue(social['oauth']);"
if text.count(metric_anchor)!=1:
    raise SystemExit(f'V417 attention metric anchor count {text.count(metric_anchor)}')
metric_replace=metric_anchor+"\n    final podcastTruth=metricValue(podcast['feed_directory']),lifecycleTruth=metricValue(lifecycle['newsletter']);"
text=text.replace(metric_anchor,metric_replace,1)

auto_anchor="    if(reviewPending>0)automatic.add('$reviewPending record${reviewPending==1?'':'s'} are waiting for match review instead of being force-matched.');"
if text.count(auto_anchor)!=1:
    raise SystemExit(f'V417 automatic truth anchor count {text.count(auto_anchor)}')
auto_insert=auto_anchor+r'''
    if((podcastTruth['approved_scripts'] as num?)?.toInt()??0>0 && ((podcastTruth['published_audio_episodes'] as num?)?.toInt()??0)==0)automatic.add('${podcastTruth['approved_scripts']} approved podcast script is prepared; audio/MP3/RSS publication is not yet proven.');
    if((lifecycleTruth['approved_newsletter_derivatives'] as num?)?.toInt()??0>0 && lifecycleTruth['send_ledger_observable']!=true)automatic.add('${lifecycleTruth['approved_newsletter_derivatives']} approved newsletter item is prepared; subscriber/send lifecycle telemetry is not yet proven.');'''
text=text.replace(auto_anchor,auto_insert,1)

anchor="    moving.add('${oauth['publish_ready']??0} of ${oauth['configured']??oauth['providers']??6} social targets are publish-ready.');"
if text.count(anchor)!=1:
    raise SystemExit(f'V417 release placement anchor count {text.count(anchor)}')
replacement=anchor+r'''
    const runningRelease=String.fromEnvironment('BRIDGEPOINT_RELEASE',defaultValue:'');
    if(runningRelease.isEmpty){
      automatic.add('This build does not contain an embedded production release SHA, so treat it as local/preview until a verified production build is loaded.');
    }else{
      final shortRelease=runningRelease.length>12?runningRelease.substring(0,12):runningRelease;
      moving.add('Running app release $shortRelease is embedded in this exact web/PWA build.');
    }
'''
text=text.replace(anchor,replacement,1)

footer_anchor="      const Text('bridgepoint-v416-owner-attention',style:TextStyle(fontSize:0,color:Colors.transparent)),"
if text.count(footer_anchor)!=1:
    raise SystemExit(f'V417 footer anchor count {text.count(footer_anchor)}')
footer=footer_anchor+r'''
      const Text('bridgepoint-v417-owner-running-release-truth',style:TextStyle(fontSize:0,color:Colors.transparent)),'''
text=text.replace(footer_anchor,footer,1)

path.write_text(text,encoding='utf-8')
print('Applied Owner V417 release + podcast + lifecycle truth')
