from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v314-investor-room'
if marker in body:
    print('v314 Investor Room already applied.')
    raise SystemExit(0)

import_anchor="import 'dart:ui' as ui;\n"
import_line="import 'investor_export_stub.dart' if (dart.library.html) 'investor_export_web.dart' as investor_export;\n"
if import_line not in body:
    if body.count(import_anchor)!=1:
        raise SystemExit(f'v314 import anchor {body.count(import_anchor)}')
    body=body.replace(import_anchor,import_anchor+import_line,1)

old_panel="if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],"
new_panel="if(showInvestor)...[const _OwnerInvestorRoomV314(),const SizedBox(height:18)],"
if body.count(old_panel)!=1:
    raise SystemExit(f'v314 investor panel anchor {body.count(old_panel)}')
body=body.replace(old_panel,new_panel,1)

class_anchor="\n\nclass _OwnerSystemExplorerV286 extends StatefulWidget{"
widget=r'''

class _OwnerInvestorRoomV314 extends StatefulWidget{
  const _OwnerInvestorRoomV314();
  @override State<_OwnerInvestorRoomV314> createState()=>_OwnerInvestorRoomV314State();
}

class _OwnerInvestorRoomV314State extends State<_OwnerInvestorRoomV314>{
  late Future<Map<String,dynamic>> request;
  Timer? timer;
  @override void initState(){
    super.initState();
    request=_callRpc('bridgepoint_owner_investor_room_v314',const {});
    timer=Timer.periodic(const Duration(seconds:30),(_){if(mounted)setState(()=>request=_callRpc('bridgepoint_owner_investor_room_v314',const {}));});
  }
  @override void dispose(){timer?.cancel();super.dispose();}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_owner_investor_room_v314',const {}));
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  List<dynamic> list(dynamic v)=>v is List?v:<dynamic>[];
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse('$v')??0;
  String money(dynamic v){final x=n(v).round();if(x>=1000000)return '\$${(x/1000000).toStringAsFixed(x%1000000==0?0:2)}M';if(x>=1000)return '\$${(x/1000).toStringAsFixed(x%1000==0?0:1)}K';return '\$${_formatInteger(x)}';}
  String esc(dynamic value)=>const HtmlEscape(HtmlEscapeMode.element).convert('${value??''}');

  String investorHtml(Map<String,dynamic> room){
    final metrics=map(room['metrics']),valuation=map(room['valuation']),targets=map(room['investor_targets']),audit=map(room['package_entitlement_audit']);
    final h=map(metrics['headline']),g=map(metrics['geographic_scale']),c=map(metrics['commercialization']),o=map(metrics['operating_system']),p=map(metrics['presentation']);
    final drivers=rows(valuation['drivers']),investors=rows(targets['targets']);
    final generated=_bpDateTime(room['generated_at']);
    final driverRows=drivers.map((d)=>'<tr><td>${esc(d['label'])}</td><td>${money(d['value_usd'])}</td><td>${esc(d['why']??'')}</td></tr>').join();
    final investorRows=investors.map((i)=>'<tr><td><b>${esc(i['firm_name'])}</b><br><small>Fit ${esc(i['fit_score'])}/100 • ${esc(i['priority'])}</small></td><td>${esc(i['focus_summary'])}</td><td>${esc(i['why_bridgepoint_fit'])}</td><td>${esc(i['public_email']??'')}<br>${esc(i['public_phone']??'')}<br>${esc(i['public_contact_url']??'')}</td><td>${esc(i['outreach_status'])}</td></tr>').join();
    final openItems=list(o['needs_attention']).map((x){final m=map(x);return '<li><b>${esc(m['title']??m['kind'])}</b> — ${esc(m['detail'])}</li>';}).join();
    return '''<!doctype html><html><head><meta charset="utf-8"><title>BridgePoint Investor Brief</title><style>
      @page{margin:0.55in}body{font-family:Arial,Helvetica,sans-serif;color:#0a1625;margin:0;background:#fff}h1{font-size:28px;margin:0 0 4px;color:#0668e8}h2{font-size:17px;color:#0b4fa7;border-bottom:2px solid #dcecff;padding-bottom:5px;margin-top:24px}.sub{color:#516170;font-size:12px}.hero{border:1px solid #b9d9ff;background:linear-gradient(135deg,#eef7ff,#fff);padding:18px;border-radius:14px;margin:14px 0}.value{font-size:34px;font-weight:900;color:#075fd1}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}.kpi{border:1px solid #d7e3ef;border-radius:9px;padding:9px}.kpi b{display:block;font-size:17px;color:#0b4fa7}.kpi span{font-size:9px;color:#667788;text-transform:uppercase}table{border-collapse:collapse;width:100%;font-size:10px}th,td{border:1px solid #dce4ec;padding:7px;text-align:left;vertical-align:top}th{background:#eef6ff;color:#174b86}.note{background:#f7f9fb;border-left:4px solid #168cff;padding:10px;font-size:10px}.warn{background:#fff9e8;border-left-color:#e9a216}.good{color:#168a54;font-weight:800}.footer{margin-top:24px;color:#708090;font-size:8px}.noprint{margin:12px 0}@media print{.noprint{display:none}.pagebreak{break-before:page}}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}}
    </style></head><body>
    <h1>BridgePoint Intelligence</h1><div class="sub">Investor Operating Brief • Updated ${esc(generated)} • Live production metrics</div>
    <div class="hero"><div class="sub">MODELED PRE-MONEY ESTIMATE</div><div class="value">${money(valuation['modeled_pre_money_usd'])}</div><div>Range ${money(valuation['low_usd'])} – ${money(valuation['high_usd'])} • Confidence ${esc(valuation['confidence_score'])}/100 • Milestone high-water ${money(valuation['milestone_high_water_usd'])}</div><p class="sub">${esc(valuation['disclaimer'])}</p></div>
    <div class="grid"><div class="kpi"><span>Canonical properties</span><b>${_formatInteger(h['canonical_properties']??0)}</b></div><div class="kpi"><span>Property scores</span><b>${_formatInteger(h['property_scores']??0)}</b></div><div class="kpi"><span>Detected patterns</span><b>${_formatInteger(h['detected_patterns']??0)}</b></div><div class="kpi"><span>Verified opportunities</span><b>${_formatInteger(h['verified_opportunities']??0)}</b></div><div class="kpi"><span>Automation jobs</span><b>${_formatInteger(h['active_automation_jobs']??0)}</b></div><div class="kpi"><span>Latest failures</span><b>${_formatInteger(h['failed_latest_runs_15m']??0)}</b></div><div class="kpi"><span>Customer prospects</span><b>${_formatInteger(c['customer_prospects']??0)}</b></div><div class="kpi"><span>Active trials / paid</span><b>${_formatInteger(c['active_trials']??0)} / ${_formatInteger(c['active_paid']??0)}</b></div></div>
    <h2>Valuation Drivers</h2><table><tr><th>Driver</th><th>Modeled contribution</th><th>Why it moves the estimate</th></tr>$driverRows</table>
    <h2>Expansion & Commercialization</h2><div class="grid"><div class="kpi"><span>CT properties • LIVE</span><b>${_formatInteger(g['ct_properties']??0)}</b></div><div class="kpi"><span>NY properties • BUILDING</span><b>${_formatInteger(g['ny_properties']??0)}</b></div><div class="kpi"><span>Scheduled customer outreach</span><b>${_formatInteger(c['customer_scheduled']??0)}</b></div><div class="kpi"><span>Estimated ready outreach pool</span><b>${_formatInteger(c['customer_ready_pool']??0)}</b></div><div class="kpi"><span>Booked MRR</span><b>${money(c['active_mrr'])}</b></div><div class="kpi"><span>Trial pipeline MRR</span><b>${money(c['trial_pipeline_mrr'])}</b></div><div class="kpi"><span>Requirements verified</span><b>${_formatInteger(o['requirements_verified']??0)} / ${_formatInteger(o['requirements_total']??0)}</b></div><div class="kpi"><span>Entitlement audit</span><b class="good">${esc(audit['status'])}</b></div></div>
    <h2>How to Present BridgePoint</h2><div class="note"><b>Opening:</b> ${esc(p['opening'])}<br><br><b>Scale:</b> ${esc(p['scale_script'])}<br><br><b>Intelligence:</b> ${esc(p['intelligence_script'])}<br><br><b>Automation:</b> ${esc(p['automation_script'])}<br><br><b>Commercialization:</b> ${esc(p['commercialization_script'])}<br><br><b>Readiness:</b> ${esc(p['readiness_script'])}<br><br><b>Close:</b> ${esc(p['close'])}</div>
    <h2>Open / External Items</h2><div class="note warn"><ul>$openItems</ul></div>
    <div class="pagebreak"></div><h2>Investor Target Pipeline</h2><table><tr><th>Investor</th><th>What they focus on</th><th>Why BridgePoint fits</th><th>Public contact</th><th>Status</th></tr>$investorRows</table>
    <div class="footer">BridgePoint Intelligence • Internal fundraising brief. Valuation is a modeled estimate, not an appraisal or guarantee. Investor contact information is limited to publicly verifiable routes and should be re-verified before outreach.</div>
    </body></html>''';
  }

  Future<void> exportRoom(Map<String,dynamic> room,{required bool print})async{
    final html=investorHtml(room);
    final ok=print?await investor_export.bridgepointPrintInvestorHtml(html):await investor_export.bridgepointDownloadInvestorHtml('BridgePoint_Investor_Brief_${DateTime.now().toIso8601String().substring(0,10)}.html',html);
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?(print?'Investor print view opened.':'Investor brief downloaded.'):'This device cannot open the requested export.')));
  }

  Future<void> updateInvestor(String key,String status)async{
    await _callRpc('bridgepoint_owner_update_investor_target_v314',{'p_investor_key':key,'p_status':status,'p_notes':null});
    refresh();
  }

  Widget kpi(String label,dynamic value,String meaning,Color color,IconData icon)=>InkWell(
    onTap:()=>_showInfoDialog(context,label,meaning),borderRadius:BorderRadius.circular(12),child:Container(width:220,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.16))),child:Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:19)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.45)),const SizedBox(height:3),Text('$value',style:TextStyle(color:color,fontSize:17,fontWeight:FontWeight.w900)),const Text('Tap for meaning',style:TextStyle(color:Colors.white38,fontSize:7.2))]))])));

  Widget driverBars(List<Map<String,dynamic>> drivers){
    final maxValue=drivers.fold<double>(1,(m,d)=>n(d['value_usd'])>m?n(d['value_usd']):m);
    return Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.50),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('WHAT IS MOVING THE MODELED VALUE',style:TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w900,fontSize:9,letterSpacing:.6)),const SizedBox(height:10),...drivers.where((d)=>n(d['value_usd'])>0).map((d){final v=n(d['value_usd']);return Padding(padding:const EdgeInsets.only(bottom:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${d['label']}',style:const TextStyle(fontSize:8.8,fontWeight:FontWeight.w800))),Text(money(v),style:const TextStyle(color:AppTheme.cyan,fontSize:8.8,fontWeight:FontWeight.w900))]),const SizedBox(height:4),LinearProgressIndicator(value:(v/maxValue).clamp(0,1),minHeight:7,color:AppTheme.cyan,backgroundColor:Colors.white10,borderRadius:BorderRadius.circular(8))]));})]));
  }

  Widget traction(Map<String,dynamic> c){
    final vals=<MapEntry<String,double>>[MapEntry('Customer prospects',n(c['customer_prospects'])),MapEntry('Known sequence members',n(c['customer_known_sequence_members'])),MapEntry('Active trials',n(c['active_trials'])),MapEntry('Active paid',n(c['active_paid']))];
    final maxV=vals.fold<double>(1,(m,e)=>e.value>m?e.value:m);
    return Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.50),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('COMMERCIAL TRACTION FUNNEL',style:TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900,fontSize:9,letterSpacing:.6)),const SizedBox(height:10),...vals.map((e)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(e.key,style:const TextStyle(fontSize:8.8,fontWeight:FontWeight.w800))),Text(_formatInteger(e.value.round()),style:const TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900,fontSize:9))]),const SizedBox(height:4),FractionallySizedBox(widthFactor:(e.value/maxV).clamp(.025,1),child:Container(height:10,decoration:BoxDecoration(color:AppTheme.green.withOpacity(.72),borderRadius:BorderRadius.circular(8))))])))]));
  }

  Widget investorCard(Map<String,dynamic> i){
    final color=n(i['fit_score'])>=90?AppTheme.green:n(i['fit_score'])>=84?AppTheme.cyan:AppTheme.blue;
    final email='${i['public_email']??''}',phone='${i['public_phone']??''}',url='${i['public_contact_url']??''}',status='${i['outreach_status']??'NOT_CONTACTED'}';
    return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.56),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.15))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:46,height:46,alignment:Alignment.center,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(11)),child:Text('${i['fit_score']??0}',style:TextStyle(color:color,fontSize:13,fontWeight:FontWeight.w900))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${i['firm_name']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),Text('${i['firm_type']??''} • ${i['stage_summary']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),const SizedBox(height:3),Text('${i['check_size_summary']??''}',style:const TextStyle(color:AppTheme.cyan,fontSize:8.3,fontWeight:FontWeight.w800))])),_OpportunityChip(label:status.replaceAll('_',' '),color:color)]),
      const SizedBox(height:8),Text('${i['why_bridgepoint_fit']??''}',style:const TextStyle(color:Colors.white70,fontSize:9,height:1.45)),const SizedBox(height:8),Wrap(spacing:7,runSpacing:7,children:[if(email.isNotEmpty)OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('mailto:$email?subject=BridgePoint%20Intelligence%20-%20investment%20conversation')),icon:const Icon(Icons.email_outlined,size:15),label:Text(email)),if(phone.isNotEmpty)OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'),'')}')),icon:const Icon(Icons.phone_outlined,size:15),label:Text(phone)),if(url.isNotEmpty)OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),icon:const Icon(Icons.open_in_new_rounded,size:15),label:const Text('Public contact / pitch')),PopupMenuButton<String>(tooltip:'Update investor status',onSelected:(v)=>updateInvestor('${i['investor_key']}',v),itemBuilder:(_)=>['READY','CONTACTED','REPLIED','MEETING','DILIGENCE','PASSED','INVESTED'].map((v)=>PopupMenuItem(value:v,child:Text(v.replaceAll('_',' ')))).toList(),child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),decoration:BoxDecoration(border:Border.all(color:Colors.white24),borderRadius:BorderRadius.circular(10)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.edit_note_rounded,size:15),SizedBox(width:5),Text('Update status')])))]),
      if(status=='INVESTED')const Padding(padding:EdgeInsets.only(top:8),child:Text('Investment closed: use Owner Center → Advanced admin → Owner Team to invite the investor as an owner only after legal/governance terms are finalized.',style:TextStyle(color:AppTheme.amber,fontSize:8.5,height:1.4,fontWeight:FontWeight.w700))),
      if(i['contact_reverification_due']==true)const Padding(padding:EdgeInsets.only(top:6),child:Text('Contact data is older than 30 days — re-verify before outreach.',style:TextStyle(color:AppTheme.amber,fontSize:8.3,fontWeight:FontWeight.w800))),
    ]));
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,s){
    if(s.connectionState==ConnectionState.waiting&&!s.hasData)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Building live Investor Room…',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:10),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:3)])));
    if(s.hasError)return _DashboardError(title:'Investor Room could not load',message:s.error.toString(),onRetry:refresh);
    final room=s.data??const <String,dynamic>{};final metrics=map(room['metrics']),valuation=map(room['valuation']),targets=map(room['investor_targets']),audit=map(room['package_entitlement_audit']);
    final h=map(metrics['headline']),g=map(metrics['geographic_scale']),c=map(metrics['commercialization']),o=map(metrics['operating_system']),p=map(metrics['presentation']);final drivers=rows(valuation['drivers']),history=rows(valuation['history']),investors=rows(targets['targets']);
    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[AppTheme.cyan.withOpacity(.11),AppTheme.blue.withOpacity(.045),Colors.transparent]),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.start,runSpacing:8,children:[const SizedBox(width:560,child:_PanelHeader(title:'Investor Room',subtitle:'Live system story • modeled valuation • charts • investor targets • presentation brief',action:'Owner only')),Wrap(spacing:6,runSpacing:6,children:[OutlinedButton.icon(onPressed:()=>exportRoom(room,print:true),icon:const Icon(Icons.print_rounded,size:16),label:const Text('Print')),FilledButton.tonalIcon(onPressed:()=>exportRoom(room,print:false),icon:const Icon(Icons.download_rounded,size:16),label:const Text('Download Investor Brief')),IconButton(onPressed:refresh,tooltip:'Refresh Investor Room',icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))])]),
      const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.06),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),child:LayoutBuilder(builder:(context,b){final compact=b.maxWidth<720;final left=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('MODELED PRE-MONEY ESTIMATE',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:3),Text(money(valuation['modeled_pre_money_usd']),style:const TextStyle(color:AppTheme.cyan,fontSize:34,fontWeight:FontWeight.w900)),Text('${money(valuation['low_usd'])} low • ${money(valuation['high_usd'])} high • ${valuation['confidence_score']??0}/100 confidence',style:const TextStyle(color:Colors.white70,fontSize:9.5,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text('Milestone high-water ${money(valuation['milestone_high_water_usd'])}',style:const TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text('${valuation['disclaimer']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4))]);final right=Container(height:150,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.black.withOpacity(.12),borderRadius:BorderRadius.circular(12)),child:_InvestorValuationChartV314(history:history));return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[left,const SizedBox(height:12),right]):Row(crossAxisAlignment:CrossAxisAlignment.center,children:[Expanded(child:left),const SizedBox(width:14),Expanded(child:right)]); })),
      const SizedBox(height:12),Wrap(spacing:9,runSpacing:9,children:[kpi('CANONICAL PROPERTIES',_formatInteger(h['canonical_properties']??0),'Operating property-data scale across live and building markets.',AppTheme.cyan,Icons.home_work_outlined),kpi('PROPERTY SCORES',_formatInteger(h['property_scores']??0),'Modeled property outputs created from BridgePoint evidence.',AppTheme.blue,Icons.speed_rounded),kpi('DETECTED PATTERNS',_formatInteger(h['detected_patterns']??0),'Reusable evidence/signal relationships detected by BridgePoint.',AppTheme.green,Icons.hub_outlined),kpi('VERIFIED OPPORTUNITIES',_formatInteger(h['verified_opportunities']??0),'Direct-evidence opportunities after dedupe and verification.',AppTheme.amber,Icons.bolt_rounded),kpi('AUTOMATION JOBS',_formatInteger(h['active_automation_jobs']??0),'Production jobs keeping ingestion, expansion, health and learning moving.',const Color(0xFF9B7BFF),Icons.autorenew_rounded),kpi('ENTITLEMENT AUDIT','${audit['status']??'—'}','Proves customers receive their valid purchased package access and no extra package leakage was found.',audit['status']=='PASS'?AppTheme.green:AppTheme.red,Icons.verified_user_outlined)]),
      const SizedBox(height:14),LayoutBuilder(builder:(context,b){final compact=b.maxWidth<780;final a=driverBars(drivers),d=traction(c);return compact?Column(children:[a,const SizedBox(height:10),d]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:a),const SizedBox(width:10),Expanded(child:d)]);}),
      const SizedBox(height:14),Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.50),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('GEOGRAPHIC SCALE',style:TextStyle(color:AppTheme.blue,fontWeight:FontWeight.w900,fontSize:9,letterSpacing:.6)),const SizedBox(height:8),_InvestorDualBarV314(labelA:'Connecticut • LIVE',valueA:n(g['ct_properties']),labelB:'New York • BUILDING',valueB:n(g['ny_properties'])),const SizedBox(height:8),Text('${g['live_states']??0} live state • ${g['building_states']??0} building state • expansion UI follows backend market records automatically',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),
      const SizedBox(height:10),ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,title:const Text('Investor talking points',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11)),subtitle:const Text('Exactly how to walk through the system in a meeting',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),children:[for(final item in [MapEntry('1 • OPENING',p['opening']),MapEntry('2 • SCALE',p['scale_script']),MapEntry('3 • INTELLIGENCE',p['intelligence_script']),MapEntry('4 • AUTOMATION',p['automation_script']),MapEntry('5 • COMMERCIALIZATION',p['commercialization_script']),MapEntry('6 • READINESS',p['readiness_script']),MapEntry('7 • CLOSE',p['close'])])if(item.value!=null)Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.035),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.10))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.key,style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900)),const SizedBox(height:5),SelectableText('${item.value}',style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.5))]))]),
      ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,initiallyExpanded:false,title:Text('Investor targets • ${investors.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),subtitle:Text('${investors.where((i)=>i['priority']=='HIGH').length} high-priority current targets • public contact data only',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),children:[...investors.map(investorCard)]),
      ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,title:Text('Readiness & open items • ${o['requirements_open']??0} open total',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:10)),subtitle:Text('${o['requirements_verified']??0}/${o['requirements_total']??0} requirements verified • package entitlement audit ${audit['status']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),children:[...list(o['needs_attention']).map((x){final m=map(x);return ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.info_outline_rounded,color:AppTheme.amber,size:18),title:Text('${m['title']??m['kind']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:9.5)),subtitle:Text('${m['detail']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35));})]),
      const SizedBox(height:4),Text('Investor Room updated ${room['generated_at']==null?'now':_bpDateTime(room['generated_at'])} • valuation refreshes hourly and the room refreshes while open',style:const TextStyle(color:Colors.white30,fontSize:7.5)),const Text('bridgepoint-v314-investor-room',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ])));
  });
}

class _InvestorValuationChartV314 extends StatelessWidget{
  const _InvestorValuationChartV314({required this.history});final List<Map<String,dynamic>> history;
  @override Widget build(BuildContext context)=>CustomPaint(painter:_InvestorValuationPainterV314(history),child:const SizedBox.expand());
}
class _InvestorValuationPainterV314 extends CustomPainter{
  _InvestorValuationPainterV314(this.history);final List<Map<String,dynamic>> history;
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse('$v')??0;
  @override void paint(Canvas canvas,Size size){
    final data=history.isEmpty?<Map<String,dynamic>>[{'modeled_pre_money_usd':0,'low_usd':0,'high_usd':0}]:history;
    final vals=data.expand((x)=>[n(x['low_usd']),n(x['modeled_pre_money_usd']),n(x['high_usd'])]).toList();final minV=vals.reduce(min),maxV=vals.reduce(max);final span=max(1.0,maxV-minV);final left=6.0,top=8.0,right=size.width-6,bottom=size.height-18;
    canvas.drawLine(Offset(left,bottom),Offset(right,bottom),Paint()..color=Colors.white.withOpacity(.12)..strokeWidth=1);
    canvas.drawLine(Offset(left,top),Offset(left,bottom),Paint()..color=Colors.white.withOpacity(.12)..strokeWidth=1);
    Offset p(int i,double v)=>Offset(left+(right-left)*(data.length<=1?1:i/(data.length-1)),bottom-(bottom-top)*((v-minV)/span));
    void line(String key,Color color,double width){final path=ui.Path();for(var i=0;i<data.length;i++){final pt=p(i,n(data[i][key]));if(i==0)path.moveTo(pt.dx,pt.dy);else path.lineTo(pt.dx,pt.dy);}canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=width..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..color=color);}
    line('low_usd',AppTheme.blue.withOpacity(.45),1.4);line('high_usd',AppTheme.green.withOpacity(.45),1.4);line('modeled_pre_money_usd',AppTheme.cyan,2.6);
    final tp=TextPainter(textDirection:TextDirection.ltr,text:TextSpan(text:'VALUATION HISTORY • MODEL / LOW / HIGH',style:TextStyle(color:Colors.white.withOpacity(.55),fontSize:7,fontWeight:FontWeight.w800)));tp.layout();tp.paint(canvas,Offset(10,1));
  }
  @override bool shouldRepaint(covariant _InvestorValuationPainterV314 old)=>old.history!=history;
}
class _InvestorDualBarV314 extends StatelessWidget{
  const _InvestorDualBarV314({required this.labelA,required this.valueA,required this.labelB,required this.valueB});final String labelA,labelB;final double valueA,valueB;
  @override Widget build(BuildContext context){final maxV=max(1.0,max(valueA,valueB));Widget row(String label,double value,Color color)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:8.8,fontWeight:FontWeight.w800))),Text(_formatInteger(value.round()),style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:9))]),const SizedBox(height:4),LinearProgressIndicator(value:(value/maxV).clamp(0,1),minHeight:9,color:color,backgroundColor:Colors.white10,borderRadius:BorderRadius.circular(8))]));return Column(children:[row(labelA,valueA,AppTheme.green),row(labelB,valueB,AppTheme.amber)]);}
}
'''
if body.count(class_anchor)!=1:
    raise SystemExit(f'v314 class anchor {body.count(class_anchor)}')
body=body.replace(class_anchor,widget+class_anchor,1)
body += "\nconst String _bridgePointInvestorRoomV314='bridgepoint-v314-investor-room | valuation history chart | valuation drivers | traction funnel | investor target pipeline | package entitlement audit | print | download investor brief';\n"
path.write_text(body,encoding='utf-8')
print('Applied v314 Investor Room.')
