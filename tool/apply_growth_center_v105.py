from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""        const SizedBox(height:18),const _EmergencyAdminPanel(),
""",
"""        const SizedBox(height:18),const _OwnerGrowthPanel(),
        const SizedBox(height:18),const _EmergencyAdminPanel(),
""",
'owner-growth-insert')

marker="class _EmergencyAdminPanel extends StatefulWidget{"
if text.count(marker)!=1:
    raise SystemExit('growth class marker not found exactly once')

owner_growth=r'''
class _OwnerGrowthPanel extends StatefulWidget{
  const _OwnerGrowthPanel();
  @override State<_OwnerGrowthPanel> createState()=>_OwnerGrowthPanelState();
}
class _OwnerGrowthPanelState extends State<_OwnerGrowthPanel>{
  late Future<Map<String,dynamic>> request;
  bool busy=false;
  int dailyPosts=6;
  String approvalMode='AUTO_WHEN_CONNECTED';
  final Set<String> platforms={'TIKTOK','FACEBOOK','INSTAGRAM'};

  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_growth_center_v102',const {});
  void refresh()=>setState(()=>request=_load());
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};

  Future<void> saveSettings()async{
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_growth_settings_v102',{
        'p_daily_post_target':dailyPosts,
        'p_platforms':platforms.toList(),
        'p_approval_mode':approvalMode,
        'p_active':true,
      });
      if(mounted)setState(()=>request=Future.value(result));
    }catch(e){if(mounted)_showInfoDialog(context,'Could not update Growth Engine',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> generateWeek()async{
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_growth_generate_queue_v102',{'p_days':7});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Growth queue refreshed • ${result['inserted']??0} new post slots added.')));refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not generate posts',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> mark(Map<String,dynamic> item,String status)async{
    try{await _callRpc('bridgepoint_growth_mark_content_v102',{'p_content_id':item['content_id'],'p_status':status,'p_error':null});if(mounted)refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not update post',e.toString());}
  }

  Future<void> sharePost(Map<String,dynamic> item)async{
    final caption='${item['caption']??''}'.trim();if(caption.isEmpty)return;
    try{await SharePlus.instance.share(ShareParams(title:'BridgePoint ${item['platform']} post',subject:'BridgePoint outreach',text:caption));}
    catch(e){if(mounted)_showInfoDialog(context,'Share unavailable',e.toString());}
  }

  Future<void> copyPost(Map<String,dynamic> item)async{
    final caption='${item['caption']??''}'.trim();if(caption.isEmpty)return;
    await Clipboard.setData(ClipboardData(text:caption));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Post copied.')));
  }

  Future<void> createReferral()async{
    final controller=TextEditingController(text:'Founder outreach');
    final label=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      backgroundColor:AppTheme.panel,title:const Text('Create tracked referral link'),
      content:TextField(controller:controller,decoration:const InputDecoration(labelText:'Label',hintText:'Example: Middletown roofer outreach',border:OutlineInputBorder())),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text.trim()),child:const Text('Create link'))],
    ));
    controller.dispose();if(label==null||label.isEmpty)return;
    try{
      final result=await _callRpc('bridgepoint_growth_create_referral_v102',{'p_label':label});
      final url='${result['url']??''}';if(url.isNotEmpty)await Clipboard.setData(ClipboardData(text:url));
      if(mounted){await _showInfoDialog(context,'Referral link ready',url.isEmpty?'BridgePoint created the referral record.':'$url\n\nThe link has been copied.');refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not create referral link',e.toString());}
  }

  Future<void> addProspect()async{
    final company=TextEditingController(),name=TextEditingController(),email=TextEditingController(),phone=TextEditingController(),website=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      backgroundColor:AppTheme.panel,title:const Text('Add a sales prospect'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:company,decoration:const InputDecoration(labelText:'Company',border:OutlineInputBorder())),const SizedBox(height:9),
        TextField(controller:name,decoration:const InputDecoration(labelText:'Contact name (optional)',border:OutlineInputBorder())),const SizedBox(height:9),
        TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email (optional)',border:OutlineInputBorder())),const SizedBox(height:9),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone (optional)',border:OutlineInputBorder())),const SizedBox(height:9),
        TextField(controller:website,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'Website (optional)',border:OutlineInputBorder())),
        const SizedBox(height:10),const Text('BridgePoint tracks the prospect and next action. It does not send unsolicited bulk email automatically. Direct outbound sending should use a lawful/approved provider and honor opt-outs.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Add prospect'))],
    ));
    if(ok==true){
      try{await _callRpc('bridgepoint_growth_add_prospect_v102',{'p_company_name':company.text.trim(),'p_contact_name':name.text.trim(),'p_email':email.text.trim(),'p_phone':phone.text.trim(),'p_website':website.text.trim(),'p_source':'OWNER_OUTREACH'});if(mounted)refresh();}
      catch(e){if(mounted)_showInfoDialog(context,'Could not add prospect',e.toString());}
    }
    company.dispose();name.dispose();email.dispose();phone.dispose();website.dispose();
  }

  String whenText(Object? value){
    final dt=DateTime.tryParse('$value')?.toLocal();if(dt==null)return '$value';
    final h=dt.hour%12==0?12:dt.hour%12;final m=dt.minute.toString().padLeft(2,'0');final ap=dt.hour>=12?'PM':'AM';
    return '${dt.month}/${dt.day} • $h:$m $ap';
  }

  Color platformColor(String p)=>switch(p){'TIKTOK'=>const Color(0xFFE6E6E6),'FACEBOOK'=>AppTheme.blue,'INSTAGRAM'=>const Color(0xFFFF78C6),'LINKEDIN'=>AppTheme.cyan,_=>AppTheme.green};

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final campaign=map(data['campaign']),summary=map(data['summary']);
      final connections=rows(data['connections']),queue=rows(data['queue']),prospects=rows(data['prospects']),referrals=rows(data['referrals']);
      if(snapshot.hasData){
        dailyPosts=(campaign['daily_post_target'] as num?)?.toInt()??dailyPosts;
        approvalMode='${campaign['approval_mode']??approvalMode}';
        final ps=(campaign['platforms'] as List? ?? const []).map((e)=>'$e').toSet();if(ps.isNotEmpty){platforms..clear()..addAll(ps);}
      }
      final connected=connections.where((c)=>c['can_publish']==true&&c['connection_status']=='CONNECTED').map((c)=>'${c['platform']}').toSet();
      final next=queue.where((q)=>['READY','APPROVED'].contains('${q['status']}')).take(12).toList();
      return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _PanelHeader(title:'Growth & Outreach Engine',subtitle:'Private founder growth center • content queue • referrals • prospects • conversion tracking',action:'Owner only'),
        const SizedBox(height:10),const _ExplainerBanner(icon:Icons.campaign_outlined,title:'Six posts a day without six manual writing sessions',message:'BridgePoint keeps a rolling week of varied founder/customer-acquisition posts. Copy or Share works now. When an approved social publishing connector is connected, AUTO WHEN CONNECTED can publish the same scheduled queue without rebuilding your workflow.'),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=900?4:c.maxWidth>=560?2:1;const gap=10.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:w,label:'READY POSTS',value:_formatInteger(summary['ready']??queue.length),detail:'Rolling scheduled queue',icon:Icons.schedule_send_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'PROSPECTS',value:_formatInteger(summary['prospects']??prospects.length),detail:'Founder sales pipeline',icon:Icons.groups_rounded,accent:AppTheme.blue),
          _MetricCard(width:w,label:'DEMO / TRIAL',value:_formatInteger(summary['demos']??0),detail:'Qualified growth outcomes',icon:Icons.rocket_launch_outlined,accent:AppTheme.amber),
          _MetricCard(width:w,label:'PAID',value:_formatInteger(summary['paid']??0),detail:'Attributed prospects',icon:Icons.payments_outlined,accent:AppTheme.green),
        ]);}),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=900;final w=wide?(c.maxWidth-12)/2:c.maxWidth;return Wrap(spacing:12,runSpacing:12,children:[
          SizedBox(width:w,child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('AUTOMATION SETTINGS',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:10),
            DropdownButtonFormField<int>(value:dailyPosts,dropdownColor:AppTheme.panel,decoration:const InputDecoration(labelText:'Posts per day / platform',border:OutlineInputBorder()),items:[1,2,3,4,5,6,8,10,12].map((v)=>DropdownMenuItem(value:v,child:Text('$v per day'))).toList(),onChanged:busy?null:(v)=>setState(()=>dailyPosts=v??6)),
            const SizedBox(height:9),DropdownButtonFormField<String>(value:approvalMode,dropdownColor:AppTheme.panel,decoration:const InputDecoration(labelText:'Publishing mode',border:OutlineInputBorder()),items:const [
              DropdownMenuItem(value:'AUTO_WHEN_CONNECTED',child:Text('Auto-publish when connected')),
              DropdownMenuItem(value:'REVIEW_EACH',child:Text('Review every post')),
              DropdownMenuItem(value:'QUEUE_ONLY',child:Text('Queue only')),
            ],onChanged:busy?null:(v)=>setState(()=>approvalMode=v??approvalMode)),
            const SizedBox(height:9),Wrap(spacing:7,runSpacing:7,children:['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN'].map((p)=>FilterChip(selected:platforms.contains(p),label:Text(p),onSelected:busy?null:(v)=>setState((){if(v){platforms.add(p);}else if(platforms.length>1){platforms.remove(p);}}))).toList()),
            const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:busy?null:saveSettings,icon:const Icon(Icons.save_outlined),label:Text(busy?'Saving…':'Save automation')),OutlinedButton.icon(onPressed:busy?null:generateWeek,icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Fill next 7 days'))]),
          ]))),
          SizedBox(width:w,child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('PUBLISHING CONNECTIONS',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:8),
            ...connections.where((c)=>['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN'].contains('${c['platform']}')).map((c){final p='${c['platform']}';final live=connected.contains(p);return _OwnerStatusRow(p,live?'CONNECTED':'QUEUE / SHARE',live?AppTheme.green:AppTheme.amber);}),
            const SizedBox(height:8),const Text('BridgePoint will never claim a post was published when the platform is not actually connected. TikTok/Meta/LinkedIn need approved publishing OAuth/API connections before true unattended posting can be enabled.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
            const Divider(height:24),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:createReferral,icon:const Icon(Icons.link_rounded),label:const Text('New referral link')),OutlinedButton.icon(onPressed:addProspect,icon:const Icon(Icons.person_add_alt_rounded),label:const Text('Add prospect'))]),
            if(referrals.isNotEmpty)...[const SizedBox(height:9),Text('${referrals.length} active tracked referral link${referrals.length==1?'':'s'}',style:const TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w800))],
          ]))),
        ]);}),
        const SizedBox(height:14),
        const Text('NEXT SCHEDULED POSTS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:8),
        if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)
        else if(snapshot.hasError)_InlineError(message:snapshot.error.toString())
        else if(next.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('No posts are queued. Choose “Fill next 7 days.”',style:TextStyle(color:AppTheme.textMuted)))
        else ...next.map((item)=>Container(
          width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.48),borderRadius:BorderRadius.circular(11),border:Border.all(color:platformColor('${item['platform']}').withOpacity(.14))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[_OpportunityChip(label:'${item['platform']}',color:platformColor('${item['platform']}')),const SizedBox(width:7),_OpportunityChip(label:'${item['status']}',color:AppTheme.cyan),const Spacer(),Text(whenText(item['scheduled_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w800))]),
            const SizedBox(height:7),Text('${item['caption']??''}',maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10,height:1.45)),
            const SizedBox(height:7),Wrap(spacing:6,runSpacing:6,children:[
              TextButton.icon(onPressed:()=>copyPost(item),icon:const Icon(Icons.copy_rounded,size:16),label:const Text('Copy')),
              TextButton.icon(onPressed:()=>sharePost(item),icon:const Icon(Icons.ios_share_rounded,size:16),label:const Text('Share now')),
              TextButton.icon(onPressed:()=>mark(item,'PUBLISHED'),icon:const Icon(Icons.check_circle_outline_rounded,size:16),label:const Text('Mark posted')),
              TextButton.icon(onPressed:()=>mark(item,'SKIPPED'),icon:const Icon(Icons.skip_next_rounded,size:16),label:const Text('Skip')),
            ]),
          ]),
        )),
      ])));
    },
  );
}

'''
text=text.replace(marker,owner_growth+marker,1)

if text==original:
    raise SystemExit('No growth center changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint owner Growth Center patch v105')
