from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v431-owner-essentials'
if marker in text:
    print('Owner Essentials V431 already applied')
    raise SystemExit(0)
if 'bridgepoint-v422-owner-funnel-truth' not in text:
    raise SystemExit('V431 requires V422 Owner Everything')

old_rpc="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v422',{'p_since':_since().toUtc().toIso8601String()});"
new_rpc="Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v431',{'p_since':_since().toUtc().toIso8601String()});"
if text.count(old_rpc)!=1:
    raise SystemExit(f'V431 owner RPC anchor count {text.count(old_rpc)}')
text=text.replace(old_rpc,new_rpc,1)

field_anchor="  String workerFilter='ALL';\n"
if text.count(field_anchor)!=1:
    raise SystemExit(f'V431 field anchor count {text.count(field_anchor)}')
text=text.replace(field_anchor,field_anchor+"  bool detailsExpanded=false;\n",1)

method_anchor='  Future<void> showDetails(Map<String,dynamic> section,Map<String,dynamic> live)async{'
if text.count(method_anchor)!=1:
    raise SystemExit(f'V431 method anchor count {text.count(method_anchor)}')
method=r'''  Widget _ownerEssentialsV431(Map<String,dynamic> data,Map<String,dynamic> live){
    final e=map(data['owner_essentials']),geo=map(data['visitor_geography']);
    final systems=map(live['systems']),national=map(live['national']),billing=map(live['billing']),social=map(live['social']),snapshot=map(live['snapshot']);
    Map<String,dynamic> metricValue(dynamic metric)=>map(map(metric)['value']);
    final cron=metricValue(systems['cron']),nationalSummary=metricValue(national['summary']),sourceTasks=metricValue(national['source_tasks']);
    final oauth=metricValue(social['oauth']),intel=metricValue(snapshot['intelligence']),billingReadiness=map(billing['readiness']);
    final geoRows=rows(geo['locations']);
    final browserInstrumentation='${e['browser_signup_instrumentation']??'UNAVAILABLE'}';
    String number(dynamic v)=>v==null?'—':'$v';
    String money(dynamic v){final n=v is num?v.toDouble():double.tryParse('$v');return n==null?'—':'\$${n.toStringAsFixed(n.truncateToDouble()==n?0:2)}';}
    String measured(dynamic v,String instrumentation)=>instrumentation=='AVAILABLE'?number(v):'Unavailable';
    Widget tile(String label,String value,{String? note,Color color=AppTheme.cyan,IconData icon=Icons.insights_outlined})=>Container(
      width:156,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withOpacity(.14))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:16),const SizedBox(height:6),Text(value,style:TextStyle(color:color,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(label,style:const TextStyle(color:Colors.white,fontSize:8.3,fontWeight:FontWeight.w900,height:1.25)),if(note!=null)...[const SizedBox(height:3),Text(note,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.2,height:1.3))]]));
    final actions=<String>[];
    final replies=(e['replies_needing_approval'] as num?)?.toInt()??0;
    final deliverability=(e['outreach_deliverability_warnings'] as num?)?.toInt()??0;
    final failedSource=(sourceTasks['failed'] as num?)?.toInt()??0;
    final oauthBlocked=(oauth['blocked'] as num?)?.toInt()??0;
    final futurePatterns=(intel['future_dated_patterns'] as num?)?.toInt()??0;
    if(replies>0)actions.add('$replies inbound repl${replies==1?'y needs':'ies need'} your exact approval before any response.');
    if(deliverability>0)actions.add('$deliverability outreach/deliverability warning${deliverability==1?'':'s'} need review; nothing here sends email.');
    if(oauthBlocked>0)actions.add('$oauthBlocked social provider connection${oauthBlocked==1?'':'s'} still need OAuth/provider approval.');
    if(futurePatterns>0)actions.add('$futurePatterns future-dated intelligence pattern${futurePatterns==1?'':'s'} still need source-date review.');
    if(actions.isEmpty)actions.add('No owner-only action is proven by the current essentials snapshot.');
    Widget actionBox()=>Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.05),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.amber.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.priority_high_rounded,color:AppTheme.amber,size:16),SizedBox(width:6),Text('NEEDS YOUR ATTENTION',style:TextStyle(color:AppTheme.amber,fontSize:8.8,fontWeight:FontWeight.w900,letterSpacing:.5))]),const SizedBox(height:6),...actions.map((x)=>Padding(padding:const EdgeInsets.only(bottom:4),child:Text('• $x',style:const TextStyle(color:Colors.white70,fontSize:8.2,height:1.35))))]));
    Widget geoBox()=>Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Colors.white.withOpacity(.025),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.public_rounded,color:AppTheme.cyan,size:16),SizedBox(width:6),Text('VISITOR GEOGRAPHY • 24H',style:TextStyle(color:Colors.white,fontSize:8.8,fontWeight:FontWeight.w900))]),const SizedBox(height:4),Text('${geo['privacy']??'Coarse geography only; exact IP is not shown.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.4,height:1.3)),const SizedBox(height:7),if(geoRows.isEmpty)Text('${geo['visitors_unknown_geo_24h']??0} visitor${geo['visitors_unknown_geo_24h']==1?'':'s'} • geography UNKNOWN',style:const TextStyle(color:Colors.white70,fontSize:8.2)) else Wrap(spacing:6,runSpacing:6,children:geoRows.take(8).map((g){final city='${g['city']??''}'.trim(),region='${g['region_code']??''}'.trim(),country='${g['country_code']??'UNKNOWN'}';final place=[if(city.isNotEmpty)city,if(region.isNotEmpty)region,country].join(', ');return _OpportunityChip(label:'$place • ${g['visitors']??0}',color:AppTheme.cyan);}).toList()),if((geo['visitors_unknown_geo_24h'] as num?)?.toInt()!=null&&(geo['visitors_unknown_geo_24h'] as num).toInt()>0)...[const SizedBox(height:6),Text('${geo['visitors_unknown_geo_24h']} visitor geography UNKNOWN',style:const TextStyle(color:AppTheme.amber,fontSize:7.8,fontWeight:FontWeight.w800))]]));
    return Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.07),Colors.transparent]),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.home_work_outlined,color:AppTheme.cyan,size:18),SizedBox(width:7),Expanded(child:Text('OWNER ESSENTIALS',style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.5))),_OpportunityChip(label:'V431',color:AppTheme.cyan)]),
      const SizedBox(height:4),const Text('The business view first. Deep database, worker, source and engineering detail stays collapsed below.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.1,height:1.35)),const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        tile('Tracked visitors today',number(e['tracked_visitors_today']),icon:Icons.today_rounded),tile('Tracked visitors • 24h',number(e['tracked_visitors_24h']),icon:Icons.visibility_outlined),tile('Homepage visitors',number(e['homepage_visitors_24h']),icon:Icons.home_outlined),tile('App visitors',number(e['app_visitors_24h']),icon:Icons.apps_rounded),tile('Territory visitors',number(e['territory_visitors_24h']),icon:Icons.map_outlined),tile('Sample visitors',number(e['sample_visitors_24h']),icon:Icons.science_outlined),
        tile('Package viewers',number(e['package_viewers_24h']),icon:Icons.inventory_2_outlined),tile('Signup viewers',measured(e['signup_viewers_24h'],browserInstrumentation),note:browserInstrumentation=='AVAILABLE'?null:'V424 browser instrumentation not yet observed',icon:Icons.person_add_alt_1),tile('Form starters',measured(e['signup_form_starters_24h'],browserInstrumentation),note:browserInstrumentation=='AVAILABLE'?null:'Unavailable is not zero',icon:Icons.edit_note_rounded),tile('Signup submits',measured(e['signup_submits_24h'],browserInstrumentation),note:browserInstrumentation=='AVAILABLE'?null:'Unavailable is not zero',icon:Icons.send_rounded),tile('Signup success',number(e['signup_success_24h']),icon:Icons.verified_user_outlined),tile('Checkout starters',number(e['checkout_starters_24h']),icon:Icons.shopping_cart_checkout_rounded),tile('Paid • 24h',number(e['paid_24h']),color:AppTheme.green,icon:Icons.payments_outlined),
        tile('Active trials',number(e['active_trials']),color:AppTheme.blue,icon:Icons.timer_outlined),tile('Active customers',number(e['active_customers']),color:AppTheme.green,icon:Icons.groups_2_outlined),tile('MRR',money(e['active_mrr']),color:AppTheme.green,icon:Icons.attach_money_rounded),tile('Replies needing approval',number(replies),color:replies>0?AppTheme.amber:AppTheme.green,icon:Icons.mark_email_unread_outlined),tile('Expansion states',number(nationalSummary['states']),note:'${sourceTasks['failed']??0} failed source tasks',icon:Icons.public_rounded),tile('Worker health','${cron['failed']??e['failed_runs_15m']??0} failed',note:'${cron['succeeded']??e['successful_runs_15m']??0} recent successes',color:((cron['failed'] as num?)?.toInt()??0)>0?AppTheme.red:AppTheme.green,icon:Icons.health_and_safety_outlined),tile('Billing','${billingReadiness['readiness']??(e['billing_connected']==true?'CONNECTED':'UNAVAILABLE')}',color:e['billing_connected']==true?AppTheme.green:AppTheme.amber,icon:Icons.credit_card_rounded),
      ]),
      const SizedBox(height:10),actionBox(),const SizedBox(height:8),geoBox(),
      if(failedSource>0)...[const SizedBox(height:7),Text('$failedSource national source task${failedSource==1?' is':'s are'} failed and remain in worker/source recovery; see More details for exact source truth.',style:const TextStyle(color:AppTheme.amber,fontSize:7.7,height:1.35))],
      const SizedBox(height:5),Text('${data['owner_essentials_truth_rule']??'Unavailable instrumentation stays unavailable; no exact IP is exposed.'}',style:const TextStyle(color:Colors.white38,fontSize:7.2,height:1.3)),
      const Text('bridgepoint-v431-owner-essentials',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ]));
  }

'''
text=text.replace(method_anchor,method+method_anchor,1)

attention_anchor="      const SizedBox(height:13),\n      _ownerAttentionV416(live),"
if text.count(attention_anchor)!=1:
    raise SystemExit(f'V431 attention placement anchor count {text.count(attention_anchor)}')
attention_replace="      const SizedBox(height:13),\n      _ownerEssentialsV431(data,live),\n      const SizedBox(height:8),\n      Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()=>setState(()=>detailsExpanded=!detailsExpanded),icon:Icon(detailsExpanded?Icons.expand_less_rounded:Icons.tune_rounded),label:Text(detailsExpanded?'Hide technical details':'More details'))),\n      if(detailsExpanded)...[\n      const SizedBox(height:13),\n      _ownerAttentionV416(live),"
text=text.replace(attention_anchor,attention_replace,1)

footer_anchor="      const SizedBox(height:10),Text('Live owner snapshot • ${_bpDateTime(data['generated_at'])} • V${data['version']??410}',style:const TextStyle(color:Colors.white38,fontSize:7.6)),"
if text.count(footer_anchor)!=1:
    raise SystemExit(f'V431 details close anchor count {text.count(footer_anchor)}')
text=text.replace(footer_anchor,"      ],\n"+footer_anchor,1)

text += '\n// bridgepoint-v431-owner-essentials-release\n'
path.write_text(text,encoding='utf-8')
print('Applied Owner Essentials V431 simple default command view')
