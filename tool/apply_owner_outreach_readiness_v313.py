from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-owner-outreach-readiness'
if marker in body:
    print('v313 owner outreach readiness already applied.')
    raise SystemExit(0)

old_flags="""  bool showInvestor=false;
  bool showSystems=false;
  bool showOperations=false;
"""
new_flags="""  bool showInvestor=false;
  bool showSystems=false;
  bool showOutreachReadiness=false;
  bool showOperations=false;
"""
if body.count(old_flags)!=1:
    raise SystemExit(f'v313 outreach flags anchor {body.count(old_flags)}')
body=body.replace(old_flags,new_flags,1)

old_buttons="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showSystems=!showSystems),
            icon:Icon(showSystems?Icons.expand_less_rounded:Icons.account_tree_outlined,size:17),
            label:Text(showSystems?'Hide system explorer':'System explorer'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOperations=!showOperations),
"""
new_buttons="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showSystems=!showSystems),
            icon:Icon(showSystems?Icons.expand_less_rounded:Icons.account_tree_outlined,size:17),
            label:Text(showSystems?'Hide system explorer':'System explorer'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOutreachReadiness=!showOutreachReadiness),
            icon:Icon(showOutreachReadiness?Icons.expand_less_rounded:Icons.campaign_rounded,size:17),
            label:Text(showOutreachReadiness?'Hide outreach readiness':'Outreach readiness'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOperations=!showOperations),
"""
if body.count(old_buttons)!=1:
    raise SystemExit(f'v313 outreach button anchor {body.count(old_buttons)}')
body=body.replace(old_buttons,new_buttons,1)

old_panels="""        if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],
        if(showSystems)...[const _OwnerSystemExplorerV286(),const SizedBox(height:18)],
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
new_panels="""        if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],
        if(showSystems)...[const _OwnerSystemExplorerV286(),const SizedBox(height:18)],
        if(showOutreachReadiness)...[const _OwnerOutreachReadinessV313(),const SizedBox(height:18)],
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
if body.count(old_panels)!=1:
    raise SystemExit(f'v313 outreach panel anchor {body.count(old_panels)}')
body=body.replace(old_panels,new_panels,1)

insert_anchor="""

class _OwnerSystemExplorerV286 extends StatefulWidget{
"""
widget=r'''

class _OwnerOutreachReadinessV313 extends StatefulWidget{
  const _OwnerOutreachReadinessV313();
  @override State<_OwnerOutreachReadinessV313> createState()=>_OwnerOutreachReadinessV313State();
}
class _OwnerOutreachReadinessV313State extends State<_OwnerOutreachReadinessV313>{
  late Future<Map<String,dynamic>> request;
  Timer? timer;
  @override void initState(){
    super.initState();
    request=_callRpc('bridgepoint_owner_outreach_readiness_v313',const {});
    timer=Timer.periodic(const Duration(seconds:20),(_){if(mounted)setState(()=>request=_callRpc('bridgepoint_owner_outreach_readiness_v313',const {}));});
  }
  @override void dispose(){timer?.cancel();super.dispose();}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_owner_outreach_readiness_v313',const {}));
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  int n(dynamic v)=>v is num?v.toInt():int.tryParse('$v')??0;
  Color scoreColor(int score)=>score>=90?AppTheme.green:score>=75?AppTheme.cyan:score>=60?AppTheme.blue:AppTheme.amber;
  String friendlyAction(dynamic value){
    final s='${value??''}';
    if(s=='FOLLOW_UP_NOW')return 'FOLLOW UP NOW';
    if(s=='FIX_DELIVERY_FIRST')return 'FIX DELIVERY';
    if(s=='SUPPRESS')return 'SUPPRESSED';
    return 'VERIFY + ENROLL';
  }

  Widget metric(String label,dynamic value,String detail,IconData icon,Color color){
    return LayoutBuilder(builder:(context,c)=>Container(
      width:c.maxWidth,
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.16))),
      child:Row(children:[
        Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20)),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.5)),
          const SizedBox(height:2),Text('$value',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:2),Text(detail,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
        ])),
      ]),
    ));
  }

  Widget candidate(Map<String,dynamic> item){
    final score=n(item['readiness_score']);final color=scoreColor(score);
    final company='${item['company_name']??item['email']??'Prospect'}';
    final person=['${item['first_name']??''}','${item['last_name']??''}'].where((x)=>x.trim().isNotEmpty).join(' ');
    final title='${item['title']??item['segment']??'Customer prospect'}';
    final place=['${item['city']??''}','${item['state_code']??''}'].where((x)=>x.trim().isNotEmpty).join(', ');
    final email='${item['email']??''}';
    return Container(
      margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.58),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.14))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(11)),child:Text('$score',style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:13))),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(company,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)),
            if(person.isNotEmpty)Text(person,style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w800)),
            const SizedBox(height:2),Text('$title${place.isEmpty?'':' • $place'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
            if(email.isNotEmpty)Text(email,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
          ])),
          const SizedBox(width:8),_OpportunityChip(label:friendlyAction(item['recommended_action']),color:color),
        ]),
        const SizedBox(height:8),Text('${item['why_next']??'Review this customer-lane prospect before the next outreach action.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
      ]),
    );
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,s){
      if(s.hasError)return _DashboardError(title:'Outreach readiness could not load',message:s.error.toString(),onRetry:refresh);
      final d=s.data??const <String,dynamic>{};final candidates=rows(d['candidates']);final segments=rows(d['segments']);
      final loading=s.connectionState==ConnectionState.waiting&&!s.hasData;
      return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Expanded(child:_PanelHeader(title:'Outreach Readiness',subtitle:'Automatic customer prospect ranking • Apollo-safe next actions',action:'Owner only')),
          IconButton(onPressed:loading?null:refresh,tooltip:'Refresh outreach readiness',icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height:10),
        const _ExplainerBanner(icon:Icons.auto_awesome_rounded,title:'BridgePoint prepares the next outreach move automatically',message:'The system ranks customer-lane prospects and separates customer acquisition from multipliers and strategic targets. Real Apollo enrollment or sending still uses an approved sender/sequence confirmation, so an automation mistake cannot blast your mailbox.'),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=900?4:c.maxWidth>=520?2:1;const gap=10.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          SizedBox(width:w,child:metric('CUSTOMER INVENTORY','${d['customer_inventory']??0} / ${d['customer_target']??500}','${d['customer_remaining']??0} prospects remain to the customer-only target',Icons.groups_2_rounded,AppTheme.cyan)),
          SizedBox(width:w,child:metric('KNOWN SEQUENCE MEMBERS',d['known_sequence_membership_estimate']??0,'Current scheduled + terminal sequence statuses without double-counting delivered contacts',Icons.mark_email_read_outlined,AppTheme.blue)),
          SizedBox(width:w,child:metric('ESTIMATED READY POOL',d['estimated_ready_pool']??0,'Candidates outside the known sequence membership estimate',Icons.rocket_launch_outlined,AppTheme.green)),
          SizedBox(width:w,child:metric('HIGH-PRIORITY PROSPECTS',d['high_priority_customer_prospects']??0,'Customer-lane prospects BridgePoint ranks ahead of normal priority',Icons.priority_high_rounded,AppTheme.amber)),
        ]);}),
        const SizedBox(height:14),
        Wrap(spacing:7,runSpacing:7,children:segments.map((seg)=>_OpportunityChip(label:'${seg['segment']??'CUSTOMER'} • ${seg['contacts']??0}',color:(seg['high_priority'] as num? ?? 0)>0?AppTheme.cyan:AppTheme.blue)).toList()),
        const SizedBox(height:14),
        Row(children:[const Expanded(child:Text('BEST NEXT CUSTOMER PROSPECTS',style:TextStyle(fontWeight:FontWeight.w900,fontSize:10,letterSpacing:.7))),Text(d['latest_sync_at']==null?'Waiting for first sync':'Synced ${_bpDateTime(d['latest_sync_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))]),
        const SizedBox(height:8),
        if(candidates.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:18),child:Text('No customer candidates are waiting for review right now.',style:TextStyle(color:AppTheme.textMuted)))
        else ...candidates.take(16).map(candidate),
        const SizedBox(height:6),
        Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.055),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.14))),child:Text('${d['estimate_note']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.45))),
        const SizedBox(height:4),const Text('bridgepoint-v313-owner-outreach-readiness',style:TextStyle(fontSize:0,color:Colors.transparent)),
      ])));
    },
  );
}
'''
if body.count(insert_anchor)!=1:
    raise SystemExit(f'v313 outreach class anchor {body.count(insert_anchor)}')
body=body.replace(insert_anchor,widget+insert_anchor,1)
body += "\nconst String _bridgePointOwnerOutreachReadinessV313='bridgepoint-v313-owner-outreach-readiness | ranked customer prospects | estimated ready pool | separate lanes | Apollo enrollment verification guardrail';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 owner outreach readiness UI.')
