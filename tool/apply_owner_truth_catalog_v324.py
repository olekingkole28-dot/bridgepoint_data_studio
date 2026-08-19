from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v324-owner-truth-customer-safe-catalog'
if marker in body:
    print('BridgePoint v324 already applied')
    raise SystemExit(0)
if 'bridgepoint-v323-owner-moderation-ui' not in body:
    raise SystemExit('v324 requires verified v323 generated source')

widget=r'''
class _OwnerTruthPanelV324 extends StatefulWidget{
  const _OwnerTruthPanelV324({this.contextLabel='OWNER CENTER'});
  final String contextLabel;
  @override State<_OwnerTruthPanelV324> createState()=>_OwnerTruthPanelV324State();
}
class _OwnerTruthPanelV324State extends State<_OwnerTruthPanelV324>{
  late Future<Map<String,dynamic>> request;
  Timer? timer;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_owner_truth_v322',const {});timer=Timer.periodic(const Duration(seconds:30),(_){if(mounted)setState(()=>request=_callRpc('bridgepoint_owner_truth_v322',const {}));});}
  @override void dispose(){timer?.cancel();super.dispose();}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_owner_truth_v322',const {}));
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  Widget stat(String label,String value,String detail,Color color)=>Container(width:190,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,fontWeight:FontWeight.w900,letterSpacing:.5)),const SizedBox(height:4),Text(value,style:TextStyle(color:color,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(detail,style:const TextStyle(color:Colors.white54,fontSize:7.5,height:1.35))]));
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,s){
    if(s.connectionState==ConnectionState.waiting&&!s.hasData)return Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:AppTheme.cyan)),const SizedBox(width:10),Text('Loading canonical owner truth…',style:TextStyle(color:AppTheme.textMuted,fontSize:9))])));
    if(s.hasError)return _DashboardError(title:'Canonical owner truth could not load',message:s.error.toString(),onRetry:refresh);
    final d=s.data??const <String,dynamic>{};
    final cb=map(d['customers_and_billing']),billing=map(cb['production_readiness']),automation=map(d['automation']),load=map(automation['expansion_load']);
    final permits=map(d['permits']),municipal=map(permits['connecticut_municipal_sources']),permitRows=map(permits['permit_records']);
    final expansion=map(d['expansion']),markets=rows(expansion['markets']);
    final live=markets.where((m)=>'${m['data_status']}'.toUpperCase()=='LIVE').length;
    final building=markets.where((m)=>'${m['data_status']}'.toUpperCase()=='BUILDING'||'${map(m['build_eta'])['status']}'.toUpperCase()=='RUNNING').length;
    final queued=markets.where((m)=>'${map(m['build_eta'])['eta_status']}'.toUpperCase()=='QUEUED').length;
    final dbSize=load['database_size_gb'];
    final pending=load['property_queue_pending'];
    final billingReady='${billing['readiness']??'CHECK PENDING'}'.replaceAll('_',' ');
    final billingColor=billing['payments_enabled']==true?AppTheme.green:AppTheme.amber;
    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[AppTheme.green.withOpacity(.07),AppTheme.cyan.withOpacity(.035),Colors.transparent]),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:AppTheme.green.withOpacity(.11),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.fact_check_outlined,color:AppTheme.green,size:20)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('CANONICAL OWNER TRUTH • ${widget.contextLabel}',style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:2),const Text('One owner-only snapshot for customers, billing, automation, permits and expansion. Customer metrics exclude private platform accounts.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4))])),IconButton(tooltip:'Refresh canonical truth',onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan,size:19))]),
      const SizedBox(height:11),Wrap(spacing:8,runSpacing:8,children:[
        stat('CUSTOMER ACCOUNTS','${cb['customer_accounts']??0}','Founder/co-owner accounts excluded',AppTheme.cyan),
        stat('TRIALS / PAID','${cb['customer_trials']??0} / ${cb['customer_active_paid']??0}','Customer subscriptions only',AppTheme.green),
        stat('PRODUCTION BILLING',billingReady,'${billing['requirements_due']??'—'} Stripe requirement(s) due',billingColor),
        stat('AUTOMATION','${automation['active_jobs']??0} jobs','${automation['failed_15m']??0} failed in last 15 min',((automation['failed_15m'] as num?)??0)>0?AppTheme.red:AppTheme.green),
        stat('CT PERMIT SOURCES','${municipal['ready_sources']??0} ready','${municipal['discovery_pending']??0} discovery pending',AppTheme.amber),
        stat('PERMITS MATCHED','${permitRows['property_matched']??0}','${permitRows['unmatched']??0} unmatched',AppTheme.blue),
        stat('GEOGRAPHIES','$live live • $building building','$queued queued by load governor',AppTheme.cyan),
        stat('DB / QUEUE',dbSize==null?'—':'${dbSize} GB',pending==null?'Queue status unavailable':'$pending downstream jobs pending',AppTheme.blue),
      ]),
      const SizedBox(height:8),Text('Truth v${d['truth_version']??'—'} • ${_bpDateTime(d['generated_at'])} • refreshes every 30 seconds',style:const TextStyle(color:Colors.white38,fontSize:7.5)),
    ])));
  });
}

'''
anchor='class _OwnerCenterPageState extends State<_OwnerCenterPage>{'
if anchor not in body: raise SystemExit('Owner Center anchor missing')
body=body.replace(anchor,widget+anchor,1)

owner_heading="""        _PageHeading(title:'Owner Center',subtitle:'Today’s decisions first • deeper controls only when you need them',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:10),_ExplainerBanner("""
owner_replace="""        _PageHeading(title:'Owner Center',subtitle:'Today’s decisions first • deeper controls only when you need them',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:10),const _OwnerTruthPanelV324(),
        const SizedBox(height:10),_ExplainerBanner("""
if owner_heading not in body: raise SystemExit('Owner Center insertion anchor missing')
body=body.replace(owner_heading,owner_replace,1)

investor="if(showInvestor)...[const _OwnerInvestorRoomV314(),const SizedBox(height:18)],"
investor_new="if(showInvestor)...[const _OwnerTruthPanelV324(contextLabel:'INVESTOR ROOM'),const SizedBox(height:12),const _OwnerInvestorRoomV314(),const SizedBox(height:18)],"
if investor not in body: raise SystemExit('Investor Room insertion anchor missing')
body=body.replace(investor,investor_new,1)

old="""                            '${model['model_category'] ?? 'intelligence'} • ${model['target_entity_type'] ?? 'entity'} • priority ${model['priority_threshold'] ?? '—'}',"""
new="""                            '${model['model_category'] ?? 'intelligence'} • ${model['target_entity_type'] ?? 'entity'}${ownerMode && model['priority_threshold'] != null ? ' • owner priority ${model['priority_threshold']}' : ''}',"""
if old not in body: raise SystemExit('Package threshold display anchor missing')
body=body.replace(old,new,1)

package_load="final data=snapshot.data;final packages=_bpRows(data?['packages']);final loading=snapshot.connectionState==ConnectionState.waiting;"
package_load_new="final data=snapshot.data;final packages=_bpRows(data?['packages']);final loading=snapshot.connectionState==ConnectionState.waiting;final catalogScope='${data?['catalog_scope']??''}';"
if package_load not in body: raise SystemExit('Package catalog scope anchor missing')
body=body.replace(package_load,package_load_new,1)
owner_demo="""        FilledButton.tonalIcon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _SalesDemoDialogV224()),icon:const Icon(Icons.play_circle_outline_rounded),label:const Text('Demo checkout')),
      ])),"""
owner_demo_new="""        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[FilledButton.tonalIcon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _SalesDemoDialogV224()),icon:const Icon(Icons.play_circle_outline_rounded),label:const Text('Demo checkout')),const SizedBox(height:4),Text(catalogScope.isEmpty?'OWNER CATALOG':catalogScope.replaceAll('_',' '),style:const TextStyle(color:AppTheme.amber,fontSize:7,fontWeight:FontWeight.w900))]),
      ])),"""
if owner_demo not in body: raise SystemExit('Owner package catalog badge anchor missing')
body=body.replace(owner_demo,owner_demo_new,1)

body+='\n// bridgepoint-v324-owner-truth-customer-safe-catalog\n'
path.write_text(body,encoding='utf-8')
print('Applied BridgePoint v324 Owner Truth + customer-safe package UI.')
