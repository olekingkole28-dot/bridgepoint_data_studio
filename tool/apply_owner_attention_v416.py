from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v416-owner-attention'
if marker in text:
    print('Owner Attention V416 already applied')
    raise SystemExit(0)
if 'bridgepoint-v415-owner-truth' not in text:
    raise SystemExit('V416 requires V415 owner truth')

method_anchor="  Future<void> showDetails(Map<String,dynamic> section,Map<String,dynamic> live)async{"
if text.count(method_anchor)!=1:
    raise SystemExit(f'V416 method anchor count {text.count(method_anchor)}')

method=r'''  Widget _ownerAttentionV416(Map<String,dynamic> live){
    Map<String,dynamic> metricValue(dynamic metric)=>map(map(metric)['value']);
    final systems=map(live['systems']),national=map(live['national']),snapshot=map(live['snapshot']),social=map(live['social']);
    final cron=metricValue(systems['cron']),tasks=metricValue(national['source_tasks']),intel=metricValue(snapshot['intelligence']),matching=metricValue(snapshot['matching']),oauth=metricValue(social['oauth']);
    final verified=map(intel['verified_opportunities']);
    final ownerActions=<String>[];
    final automatic=<String>[];
    final moving=<String>[];

    final sourceFailed=(tasks['failed'] as num?)?.toInt()??0;
    final futurePatterns=(intel['future_dated_patterns'] as num?)?.toInt()??0;
    final oauthBlocked=(oauth['blocked'] as num?)?.toInt()??0;
    final cronFailed=(cron['failed'] as num?)?.toInt()??0;
    final reviewPending=(matching['match_review_pending'] as num?)?.toInt()??0;
    final signal24=(matching['signal_created_24h'] as num?)?.toInt()??0;
    final verifiedTotal=(verified['total'] as num?)?.toInt()??0;

    if(oauthBlocked>0)ownerActions.add('$oauthBlocked social provider connection${oauthBlocked==1?'':'s'} still need OAuth/provider approval before automatic publishing can work.');
    if(futurePatterns>0)ownerActions.add('$futurePatterns future-dated pattern${futurePatterns==1?'':'s'} need source-date semantics reviewed before they should influence freshness reporting.');
    if(sourceFailed>0)automatic.add('$sourceFailed source task${sourceFailed==1?'':'s'} failed; ingestion workers are retrying/replacing those sources without discarding good rows.');
    if(cronFailed>0)automatic.add('$cronFailed current cron job${cronFailed==1?'':'s'} failed; worker health should be inspected automatically before adding concurrency.');
    if(reviewPending>0)automatic.add('$reviewPending record${reviewPending==1?'':'s'} are waiting for match review instead of being force-matched.');
    if(ownerActions.isEmpty)ownerActions.add('No new owner-only action is proven by the current snapshot. BridgePoint can keep advancing automatically.');
    if(automatic.isEmpty)automatic.add('No automatically handled blocker is currently reported by the reconciled owner snapshot.');

    moving.add('$signal24 signals created in the last 24 hours.');
    moving.add('$verifiedTotal VERIFIED opportunities currently meet the strict evidence contract.');
    moving.add('${tasks['queued']??0} source tasks queued and ${tasks['running']??0} running across national ingestion.');
    moving.add('${cron['succeeded']??0} recent cron runs succeeded with ${cronFailed} current failures.');
    moving.add('${oauth['publish_ready']??0} of ${oauth['configured']??oauth['providers']??6} social targets are publish-ready.');

    Widget listCard(String title,IconData icon,Color color,List<String> items)=>Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.045),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.14))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:color,size:17),const SizedBox(width:7),Expanded(child:Text(title,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.35)))]),const SizedBox(height:8),...items.take(5).map((x)=>Padding(padding:const EdgeInsets.only(bottom:6),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('• ',style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w900)),Expanded(child:Text(x,style:const TextStyle(color:Colors.white70,fontSize:8.2,height:1.35)))]))) ])));

    return Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF07111F).withOpacity(.72),borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white.withOpacity(.07))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.bolt_rounded,color:AppTheme.amber,size:19),const SizedBox(width:7),const Expanded(child:Text('TODAY • OWNER ATTENTION',style:TextStyle(color:Colors.white,fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:.45))),Text('V416',style:TextStyle(color:AppTheme.textMuted.withOpacity(.8),fontSize:7.5,fontWeight:FontWeight.w800))]),
      const SizedBox(height:4),const Text('The short version: what needs you, what BridgePoint is handling by itself, and the biggest systems moving now.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.4)),
      const SizedBox(height:10),
      LayoutBuilder(builder:(context,c){if(c.maxWidth<760){return Column(children:[Row(children:[listCard('REQUIRES OWNER ACTION',Icons.pan_tool_alt_outlined,AppTheme.red,ownerActions)]),const SizedBox(height:8),Row(children:[listCard('HANDLED AUTOMATICALLY',Icons.autorenew_rounded,AppTheme.green,automatic)]),const SizedBox(height:8),Row(children:[listCard('TOP SYSTEMS MOVING',Icons.trending_up_rounded,AppTheme.cyan,moving)])]);}return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[listCard('REQUIRES OWNER ACTION',Icons.pan_tool_alt_outlined,AppTheme.red,ownerActions),const SizedBox(width:8),listCard('HANDLED AUTOMATICALLY',Icons.autorenew_rounded,AppTheme.green,automatic),const SizedBox(width:8),listCard('TOP SYSTEMS MOVING',Icons.trending_up_rounded,AppTheme.cyan,moving)]);}),
      const SizedBox(height:5),const Text('Only reconciled owner metrics appear here. Missing instrumentation stays unavailable instead of becoming a fake zero.',style:TextStyle(color:Colors.white38,fontSize:7.3,height:1.3)),
      const Text('bridgepoint-v416-owner-attention',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ]));
  }

'''
text=text.replace(method_anchor,method+method_anchor,1)

chips_anchor="      const SizedBox(height:13),\n      LayoutBuilder(builder:(context,c){final compact=c.maxWidth<720;return Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:["
if text.count(chips_anchor)!=1:
    raise SystemExit(f'V416 placement anchor count {text.count(chips_anchor)}')
replacement="      const SizedBox(height:13),\n      _ownerAttentionV416(live),\n      const SizedBox(height:13),\n      LayoutBuilder(builder:(context,c){final compact=c.maxWidth<720;return Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:["
text=text.replace(chips_anchor,replacement,1)

path.write_text(text,encoding='utf-8')
print('Applied Owner Attention V416')
