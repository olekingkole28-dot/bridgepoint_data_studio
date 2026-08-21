from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v418-owner-truth-gaps'
if marker in text:
    print('Owner Truth Gaps V418 already applied')
    raise SystemExit(0)
if 'bridgepoint-v417-owner-running-release-truth' not in text:
    raise SystemExit('V418 requires V417 owner release truth')

attention_data_old="    final systems=map(live['systems']),national=map(live['national']),snapshot=map(live['snapshot']),social=map(live['social']),podcast=map(live['podcast']),lifecycle=map(live['lifecycle']);"
attention_data_new=attention_data_old+"\n    final metrics=map(live['metrics']);"
if text.count(attention_data_old)!=1:
    raise SystemExit(f'V418 attention data anchor count {text.count(attention_data_old)}')
text=text.replace(attention_data_old,attention_data_new,1)

arrays_anchor="    final moving=<String>[];"
if text.count(arrays_anchor)!=1:
    raise SystemExit(f'V418 attention arrays anchor count {text.count(arrays_anchor)}')
arrays_insert=arrays_anchor+r'''
    final truthGaps=<String>[];
    int unavailableMetrics=0,contradictedMetrics=0,warningMetrics=0;
    for(final entry in metrics.entries){
      final m=map(entry.value);
      final observed='${m['observed_state']??''}'.toUpperCase();
      final health='${m['health_status']??''}'.toUpperCase();
      if(observed=='UNAVAILABLE')unavailableMetrics++;
      if(observed=='CONTRADICTED')contradictedMetrics++;
      if(health=='WARNING')warningMetrics++;
    }'''
text=text.replace(arrays_anchor,arrays_insert,1)

auto_anchor="    if(reviewPending>0)automatic.add('$reviewPending record${reviewPending==1?'':'s'} are waiting for match review instead of being force-matched.');"
if text.count(auto_anchor)!=1:
    raise SystemExit(f'V418 automatic anchor count {text.count(auto_anchor)}')
auto_insert=auto_anchor+r'''
    final funnelMetric=map(metrics['funnel.health']);
    final deploymentMetric=map(metrics['deployment.pwa']);
    final securityMetric=map(metrics['security.rls_posture']);
    if('${funnelMetric['observed_state']??''}'.toUpperCase()=='CONTRADICTED')truthGaps.add('Acquisition funnel tracking is contradicted: server-side trials exist while the browser conversion path is missing. Treat browser funnel conversion as incomplete until instrumentation is repaired.');
    if('${deploymentMetric['observed_state']??''}'.toUpperCase()=='UNAVAILABLE')truthGaps.add('Deployment/PWA verification is not yet materialized into the owner backend. This running build now exposes its embedded release SHA, but installability/publication proof remains a separate release check.');
    if('${securityMetric['health_status']??''}'.toUpperCase()=='WARNING')truthGaps.add('Database RLS posture has a warning. BridgePoint must review affected tables deliberately instead of mass-enabling RLS and risking worker breakage.');
    if(unavailableMetrics>0)automatic.add('$unavailableMetrics owner metric${unavailableMetrics==1?' is':'s are'} explicitly unavailable rather than being shown as fake zeroes.');
    if(contradictedMetrics>0)automatic.add('$contradictedMetrics metric${contradictedMetrics==1?' has':'s have'} conflicting source truth and need instrumentation/reconciliation repair.');'''
text=text.replace(auto_anchor,auto_insert,1)

moving_anchor="    moving.add('${oauth['publish_ready']??0} of ${oauth['configured']??oauth['providers']??6} social targets are publish-ready.');"
if text.count(moving_anchor)!=1:
    raise SystemExit(f'V418 moving anchor count {text.count(moving_anchor)}')
moving_insert=moving_anchor+r'''
    moving.add('${metrics.length} reconciled owner metrics are being tracked • $unavailableMetrics unavailable • $contradictedMetrics contradicted • $warningMetrics warnings.');'''
text=text.replace(moving_anchor,moving_insert,1)

fallback_anchor="    if(automatic.isEmpty)automatic.add('No automatically handled blocker is currently reported by the reconciled owner snapshot.');"
if text.count(fallback_anchor)!=1:
    raise SystemExit(f'V418 fallback anchor count {text.count(fallback_anchor)}')
fallback_replace=fallback_anchor+r'''
    if(truthGaps.isEmpty)truthGaps.add('No reconciled truth gap is currently elevated. BridgePoint will still keep unavailable instrumentation labeled explicitly in Details.');'''
text=text.replace(fallback_anchor,fallback_replace,1)

layout_anchor="        SizedBox(width:width,child:listCard('TOP SYSTEMS MOVING',Icons.trending_up_rounded,AppTheme.cyan,moving)),"
# V416 currently builds the desktop row inline with Expanded listCard widgets, so insert the truth-gap card after the whole responsive block instead.
responsive_anchor="      LayoutBuilder(builder:(context,c){if(c.maxWidth<760){return Column(children:[Row(children:[listCard('REQUIRES OWNER ACTION',Icons.pan_tool_alt_outlined,AppTheme.red,ownerActions)]),const SizedBox(height:8),Row(children:[listCard('HANDLED AUTOMATICALLY',Icons.autorenew_rounded,AppTheme.green,automatic)]),const SizedBox(height:8),Row(children:[listCard('TOP SYSTEMS MOVING',Icons.trending_up_rounded,AppTheme.cyan,moving)])]);}return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[listCard('REQUIRES OWNER ACTION',Icons.pan_tool_alt_outlined,AppTheme.red,ownerActions),const SizedBox(width:8),listCard('HANDLED AUTOMATICALLY',Icons.autorenew_rounded,AppTheme.green,automatic),const SizedBox(width:8),listCard('TOP SYSTEMS MOVING',Icons.trending_up_rounded,AppTheme.cyan,moving)]);}),"
if text.count(responsive_anchor)!=1:
    raise SystemExit(f'V418 responsive attention anchor count {text.count(responsive_anchor)}')
responsive_replace=responsive_anchor+r'''
      const SizedBox(height:8),
      Row(children:[listCard('TRUTH GAPS • NOT ZEROES',Icons.fact_check_outlined,AppTheme.amber,truthGaps)]),'''
text=text.replace(responsive_anchor,responsive_replace,1)

footer_anchor="      const Text('bridgepoint-v417-owner-running-release-truth',style:TextStyle(fontSize:0,color:Colors.transparent)),"
if text.count(footer_anchor)!=1:
    raise SystemExit(f'V418 footer anchor count {text.count(footer_anchor)}')
text=text.replace(footer_anchor,footer_anchor+"\n      const Text('bridgepoint-v418-owner-truth-gaps',style:TextStyle(fontSize:0,color:Colors.transparent)),",1)

path.write_text(text,encoding='utf-8')
print('Applied Owner Truth Gaps V418')
