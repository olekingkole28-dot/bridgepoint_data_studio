from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v315-catalog-aware-onboarding'
if marker in body:
    print('v315 catalog-aware onboarding already applied.')
    raise SystemExit(0)

start=body.find('class _OnboardingScreen extends StatefulWidget {')
end=body.find('class _AuthScreen extends StatefulWidget {',start)
if start<0 or end<0:
    raise SystemExit(f'v315 onboarding block anchors start={start} end={end}')

replacement=r'''class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen({required this.onComplete});
  final VoidCallback onComplete;
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Card(child:Container(
    width:820,padding:const EdgeInsets.all(28),child:_PackageFitQuestionnaireV315(saveAnswers:true,onFinished:onComplete),
  ))))));
}

class _PackageFitQuestionnaireV315 extends StatefulWidget{
  const _PackageFitQuestionnaireV315({required this.saveAnswers,this.onFinished,this.ownerPreview=false});
  final bool saveAnswers;final VoidCallback? onFinished;final bool ownerPreview;
  @override State<_PackageFitQuestionnaireV315> createState()=>_PackageFitQuestionnaireV315State();
}
class _PackageFitQuestionnaireV315State extends State<_PackageFitQuestionnaireV315>{
  String audience='Roofing / exterior contractor';
  String propertyFocus='Residential homes';
  String goal='Find & prioritize opportunities';
  String teamScale='2-5 people';
  String territory='Statewide';
  String integration='BridgePoint app';
  final Set<String> capabilities={'Opportunity scoring','Weather impact','Field routes'};
  bool loading=false;String? error;

  static const audiences=<String>[
    'Homeowner','Roofing / exterior contractor','Restoration / mitigation','Home services contractor','Public adjuster / claims professional',
    'Commercial real estate / property management','Property investor / acquisitions','Developer / builder','Solar / energy',
    'Institutional investor / analytics','Insurer / risk / analytics','Software / data / platform','Government / infrastructure','Other'
  ];
  static const properties=<String>['One home','Residential homes','Commercial properties','Mixed residential + commercial','Development sites','Large portfolios','Public infrastructure'];
  static const goals=<String>[
    'Understand my property','Find & prioritize opportunities','Monitor changes','Plan field work','Acquire / invest','Find development / redevelopment','Organize evidence',
    'Build custom intelligence','Analyze patterns at scale','Understand risk','Manage a team workflow','Track infrastructure / public projects','Integrate / build technology',
    'Expand geographic data coverage','Clean / resolve property data','Prove data quality','Prove ROI / learn from outcomes','Ask natural-language property questions'
  ];
  static const capabilityOptions=<String>[
    'Opportunity scoring','Weather impact','Monitoring','Field routes','Property timeline','Portfolio relationships','Custom models','Pattern intelligence','Data onboarding',
    'Coverage readiness','Source health / provenance','Property resolution','Signal / evidence normalization','Imagery / physical change','Outcome learning','Historical replay',
    'Next-best action','Team roles / entitlements','Natural-language AI','Marketplace / entitlements','Evidence reports','API access','White-label portal','Source ROI'
  ];
  static const scales=<String>['One person','2-5 people','6-25 people','26+ people','Enterprise / institutional'];
  static const territories=<String>['One property','Local','Statewide','Multi-state','National'];
  static const integrations=<String>['BridgePoint app','Managed implementation','API / embed','White-label portal'];

  Map<String,dynamic> get answers=>{
    'audience':audience,'property_focus':propertyFocus,'goal':goal,'capabilities':capabilities.toList()..sort(),
    'team_scale':teamScale,'territory':territory,'integration':integration,
  };

  Widget drop(String label,String helper,String value,List<String> options,ValueChanged<String?> change)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    DropdownButtonFormField<String>(value:value,isExpanded:true,dropdownColor:AppTheme.panel,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:loading?null:change),
    const SizedBox(height:4),Text(helper,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
  ]);

  Future<void> submit()async{
    if(capabilities.isEmpty){setState(()=>error='Choose at least one capability that matters to you.');return;}
    setState((){loading=true;error=null;});
    try{
      final result=await _callRpc(widget.saveAnswers?'bridgepoint_complete_onboarding_v315':'bridgepoint_package_fit_preview_v315',{'p_answers':answers});
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(context)=>_PackageFitResultDialogV315(result:result,ownerPreview:widget.ownerPreview));
      if(widget.saveAnswers&&mounted)widget.onFinished?.call();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Center(child:_BridgePointMark(size:56)),const SizedBox(height:12),
    Text(widget.ownerPreview?'Customer package-fit preview':'Let’s find the BridgePoint package that actually fits you',textAlign:TextAlign.center,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),
    Text(widget.ownerPreview?'This is the same package-fit questionnaire a new customer sees. Preview answers do not change your founder profile.':'These questions are matched against BridgePoint’s live package catalog. We’ll show your best available fit, other strong matches, managed options, and future/early-access fits without pretending unfinished products are ready.',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted,height:1.5,fontSize:10)),
    const SizedBox(height:22),
    drop('1 • Which best describes you or your organization?','This separates homeowner, contractor, investor, commercial, institutional, technology and government use cases.',audience,audiences,(v)=>setState(()=>audience=v??audience)),
    const SizedBox(height:12),
    drop('2 • What kind of properties or assets matter most?','Property focus helps BridgePoint distinguish residential, commercial, development, portfolio and infrastructure products.',propertyFocus,properties,(v)=>setState(()=>propertyFocus=v??propertyFocus)),
    const SizedBox(height:12),
    drop('3 • What is the biggest outcome you want from BridgePoint?','Your primary outcome carries more weight than generic company size or job title.',goal,goals,(v)=>setState(()=>goal=v??goal)),
    const SizedBox(height:13),
    const Text('4 • Which capabilities would help you most?  •  choose up to 4',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),
    const SizedBox(height:4),const Text('This is where BridgePoint can recognize specialized fits such as storm impact, custom models, APIs, public-data onboarding, evidence reports, routes, monitoring or source-quality technology.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),const SizedBox(height:9),
    Wrap(spacing:7,runSpacing:7,children:capabilityOptions.map((v)=>FilterChip(label:Text(v,style:const TextStyle(fontSize:8.5)),selected:capabilities.contains(v),onSelected:loading?null:(selected)=>setState((){if(selected){if(capabilities.length<4){capabilities.add(v);}else{ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Choose up to four capabilities. Remove one to select another.')));}}else{capabilities.remove(v);}}))).toList()),
    const SizedBox(height:14),
    LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=620;final left=drop('5 • How many people will use BridgePoint?','Team size helps identify individual, Company and enterprise delivery.',teamScale,scales,(v)=>setState(()=>teamScale=v??teamScale));final right=drop('6 • How broad is your territory?','This helps distinguish one-property/local use from multi-state or national infrastructure.',territory,territories,(v)=>setState(()=>territory=v??territory));return wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:left),const SizedBox(width:12),Expanded(child:right)]):Column(children:[left,const SizedBox(height:12),right]);}),
    const SizedBox(height:12),
    drop('7 • How do you want BridgePoint delivered?','Choose the app for normal use, or tell us when you need managed implementation, API/embed delivery, or a white-label portal.',integration,integrations,(v)=>setState(()=>integration=v??integration)),
    if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:9))],
    const SizedBox(height:19),FilledButton.icon(onPressed:loading?null:submit,icon:const Icon(Icons.auto_awesome_rounded),label:Text(loading?'Matching the live catalog…':widget.ownerPreview?'Preview package matches':'Show my package matches')),
    const SizedBox(height:7),const Text('A recommendation never purchases a plan automatically. Checkout, trials, discounts and access are still enforced by BridgePoint’s server-side billing and entitlement rules.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white38,fontSize:7.8,height:1.35)),
  ]);
}

class _PackageFitResultDialogV315 extends StatelessWidget{
  const _PackageFitResultDialogV315({required this.result,this.ownerPreview=false});
  final Map<String,dynamic> result;final bool ownerPreview;
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  Color statusColor(String bucket)=>switch(bucket){'AVAILABLE_NOW'=>AppTheme.green,'MANAGED_FIT'=>AppTheme.cyan,_=>AppTheme.amber};
  String price(Map<String,dynamic> p){final v=p['monthly_price'];if(v==null)return '';final d=v is num?v.toDouble():double.tryParse('$v')??0;return d<=0?'':' • \$${d.toStringAsFixed(d.truncateToDouble()==d?0:2)}/mo';}
  Widget fitCard(Map<String,dynamic> p,{bool primary=false}){final bucket='${p['availability_bucket']??''}';final color=statusColor(bucket);final dims=(p['matched_dimensions'] is List)?List<dynamic>.from(p['matched_dimensions']).join(' • '):'';return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:EdgeInsets.all(primary?14:11),decoration:BoxDecoration(color:color.withOpacity(primary?.10:.05),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(primary?.34:.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text('${p['package_name']??'BridgePoint package'}',style:TextStyle(fontSize:primary?13:10.5,fontWeight:FontWeight.w900))),_OpportunityChip(label:'${p['action_label']??bucket.replaceAll('_',' ')}',color:color)]),const SizedBox(height:5),Text('${p['description']??''}',style:const TextStyle(color:Colors.white70,fontSize:8.8,height:1.4)),if(dims.isNotEmpty)...[const SizedBox(height:5),Text('Matched: $dims',style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w800))],if('${p['fit_note']??''}'.isNotEmpty)...[const SizedBox(height:4),Text('${p['fit_note']}${price(p)}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.35))]]));}
  Widget section(String title,String subtitle,List<Map<String,dynamic>> list){if(list.isEmpty)return const SizedBox.shrink();return ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:10.5)),subtitle:Text(subtitle,style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),children:list.take(5).map((p)=>fitCard(p)).toList());}
  @override Widget build(BuildContext context){final primary=map(result['best_actionable']);final overall=map(result['best_overall']);final primaryKey='${primary['package_key']??''}',overallKey='${overall['package_key']??''}';final available=rows(result['available_now']);final managed=rows(result['managed_fits']);final future=rows(result['future_fits']);return AlertDialog(title:Row(children:[const Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),const SizedBox(width:9),Expanded(child:Text(ownerPreview?'Customer package-fit preview':'Your BridgePoint package matches',style:const TextStyle(fontWeight:FontWeight.w900)))]),content:SizedBox(width:760,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(primary.isNotEmpty)...[const Text('BEST ACTIONABLE FIT',style:TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.7)),const SizedBox(height:7),fitCard(primary,primary:true)],
    if(overall.isNotEmpty&&overallKey!=primaryKey)...[const SizedBox(height:6),Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.06),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.14))),child:Text('BridgePoint also identified ${overall['package_name']} as your strongest overall fit. Its current status is ${overall['action_label']}, so it is being shown as a fit—not falsely offered as immediately ready.',style:const TextStyle(color:Colors.white70,fontSize:8.8,height:1.45)))],
    section('Available now','Ready products that strongly match your answers.',available),section('Managed fits','Strong matches that require managed activation or a pilot-style implementation.',managed),section('Future / early-access fits','BridgePoint recognized the need, but these are not represented as immediately ready.',future),
    const SizedBox(height:7),Text('${result['explanation']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.4)),const SizedBox(height:5),Text('Catalog coverage: ${result['rules_covered_count']??'—'} / ${result['catalog_package_count']??'—'} active packages evaluated.',style:const TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w800)),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(ownerPreview?'Close preview':'Open my workspace'))]);}
}

class _OwnerPackageFitPreviewDialogV315 extends StatelessWidget{
  const _OwnerPackageFitPreviewDialogV315();
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(16),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:900),child:Card(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:const _PackageFitQuestionnaireV315(saveAnswers:false,ownerPreview:true)))));
}

'''
body=body[:start]+replacement+body[end:]

founder_old="OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))])"
founder_new="OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _OwnerPackageFitPreviewDialogV315()),icon:const Icon(Icons.quiz_outlined),label:const Text('Preview package fit'))])"
if body.count(founder_old)!=1:
    raise SystemExit(f'v315 founder package-fit preview anchor {body.count(founder_old)}')
body=body.replace(founder_old,founder_new,1)

body += "\nconst String _bridgePointCatalogAwareOnboardingV315='bridgepoint-v315-catalog-aware-onboarding | 33-package live catalog fit | specific-fit routing | available now | managed fit | future early-access fit | owner exact questionnaire preview';\n"
path.write_text(body,encoding='utf-8')
print('Applied catalog-aware package fit onboarding v315.')
