from pathlib import Path

path=Path('lib/main.dart')
s=path.read_text(encoding='utf-8')
marker='bridgepoint-v225-transactional-email'
if marker in s:
    print('v225 transactional email UI already applied')
    raise SystemExit(0)

anchor="""                          if(widget.ownerMode) const Padding(
                            padding: EdgeInsets.only(top:4,bottom:8),
                            child: Text('Your login email and outbound business mailbox are shown separately so account access and customer outreach are never confused.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
                          ),
                          const Text('bridgepoint-v221-account-email',style:TextStyle(fontSize:0,color:Colors.transparent)),
"""
replacement="""                          if(widget.ownerMode) const Padding(
                            padding: EdgeInsets.only(top:4,bottom:8),
                            child: Text('Your login email and outbound business mailbox are shown separately so account access and customer outreach are never confused.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
                          ),
                          if(widget.ownerMode)...[
                            const SizedBox(height:10),
                            const _TransactionalMailSetupV225(),
                            const SizedBox(height:10),
                          ],
                          const Text('bridgepoint-v221-account-email',style:TextStyle(fontSize:0,color:Colors.transparent)),
                          const Text('bridgepoint-v225-transactional-email',style:TextStyle(fontSize:0,color:Colors.transparent)),
"""
if s.count(anchor)!=1:
    raise SystemExit(f'v225 settings anchor expected 1 match, found {s.count(anchor)}')
s=s.replace(anchor,replacement,1)

classes=r'''
class _TransactionalMailSetupV225 extends StatefulWidget{
  const _TransactionalMailSetupV225();
  @override State<_TransactionalMailSetupV225> createState()=>_TransactionalMailSetupV225State();
}

class _TransactionalMailSetupV225State extends State<_TransactionalMailSetupV225>{
  Map<String,dynamic> state=<String,dynamic>{};
  bool loading=true;
  String? error;

  @override void initState(){super.initState();unawaited(_refresh());}

  Future<Map<String,dynamic>> _invoke(String action,{String? apiKey})async{
    final body=<String,dynamic>{'action':action};
    if(apiKey!=null)body['api_key']=apiKey;
    final response=await Supabase.instance.client.functions.invoke('bridgepoint-mail-admin-v225',body:body);
    final raw=response.data;
    final data=raw is Map?Map<String,dynamic>.from(raw as Map):<String,dynamic>{'complete':false,'error':'Unexpected BridgePoint mail response'};
    if(response.status>=400||data['complete']==false)throw Exception('${data['error']??'Transactional email request failed'}');
    return data;
  }

  Future<void> _refresh()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final remote=await _invoke('status');
      Map<String,dynamic> counts=<String,dynamic>{};
      try{counts=await _callRpc('bridgepoint_mail_provider_status_v225',const {});}catch(_){}
      if(mounted)setState((){state=<String,dynamic>{...counts,...remote};loading=false;});
    }catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }

  Future<void> _verify()async{
    setState((){loading=true;error=null;});
    try{final data=await _invoke('verify');if(mounted)setState((){state=<String,dynamic>{...state,...data};loading=false;});await _refresh();}
    catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }

  Future<void> _test()async{
    setState((){loading=true;error=null;});
    try{
      final data=await _invoke('send_test');
      if(mounted){setState((){state=<String,dynamic>{...state,...data};loading=false;});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Test email sent to ${data['test_recipient']??'your account email'}')));}
      await _refresh();
    }catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }

  Future<void> _connect()async{
    final controller=TextEditingController();
    var saving=false;
    final key=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      backgroundColor:AppTheme.panel,
      title:const Row(children:[Icon(Icons.mark_email_read_outlined,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Text('Connect Resend'))]),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('BridgePoint uses Resend for automatic purchase welcome and transactional emails. Create a Resend account, then create one Full access API key for setup. Paste it below. BridgePoint sends it directly to the secured Supabase Edge Function, stores it encrypted in Vault, and never displays it again.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5)),
        const SizedBox(height:12),
        TextField(controller:controller,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'Resend API key',hintText:'re_••••••••••••••••')),
        const SizedBox(height:10),
        const Text('After the key is connected, BridgePoint automatically creates the sending domain bridgepointintelligence.online and shows the exact SPF/DKIM DNS records. No key is stored in the app or GitHub.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
      ]))),
      actions:[
        TextButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
        FilledButton.icon(onPressed:saving?null:(){final value=controller.text.trim();if(!value.startsWith('re_')){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Paste the Resend key beginning with re_.')));return;}setLocal(()=>saving=true);Navigator.pop(dialogContext,value);},icon:saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.lock_rounded),label:const Text('Securely connect')),
      ],
    )));
    controller.dispose();
    if(key==null||key.isEmpty)return;
    setState((){loading=true;error=null;});
    try{
      final data=await _invoke('configure',apiKey:key);
      if(mounted){setState((){state=<String,dynamic>{...state,...data};loading=false;});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Resend connected securely. Add the DNS records shown below, then verify the domain.')));}
    }catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }

  Widget _dnsRecords(){
    final records=state['dns_records'];
    if(records is! List||records.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:10),const Text('DNS RECORDS TO ADD',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8,color:AppTheme.cyan)),const SizedBox(height:6),
      ...records.map((raw){
        final r=raw is Map?Map<String,dynamic>.from(raw as Map):<String,dynamic>{};
        final type='${r['type']??''}';final name='${r['name']??''}';final value='${r['value']??''}';final priority='${r['priority']??''}';final status='${r['status']??''}';
        return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.55),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('${r['record']??'DNS'} • $type',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text(status.toUpperCase(),style:TextStyle(fontSize:8,fontWeight:FontWeight.w900,color:status.toLowerCase().contains('verified')?AppTheme.green:AppTheme.amber))]),
          const SizedBox(height:5),SelectableText('Name: $name',style:const TextStyle(fontSize:9,color:AppTheme.textMuted)),
          if(priority.isNotEmpty)SelectableText('Priority: $priority',style:const TextStyle(fontSize:9,color:AppTheme.textMuted)),
          SelectableText('Value: $value',style:const TextStyle(fontSize:9,color:AppTheme.textMuted,height:1.35)),
        ]));
      }),
    ]);
  }

  @override Widget build(BuildContext context){
    final configured=state['configured']==true;
    final ready=state['ready']==true;
    final status='${state['domain_status']??(configured?'CHECKING':'NOT CONFIGURED')}'.replaceAll('_',' ');
    final statusColor=ready?AppTheme.green:configured?AppTheme.amber:AppTheme.textMuted;
    return Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.42),borderRadius:BorderRadius.circular(12),border:Border.all(color:(ready?AppTheme.green:AppTheme.cyan).withOpacity(.22))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(ready?Icons.mark_email_read_rounded:Icons.outgoing_mail,color:ready?AppTheme.green:AppTheme.cyan),const SizedBox(width:9),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Transactional purchase email',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Automatic customer thank-you and purchase delivery email through Resend.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.35))])),if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))]),
      const SizedBox(height:9),
      _SettingsStatusRow(label:'Provider',value:'Resend',color:AppTheme.cyan),
      _SettingsStatusRow(label:'Sending domain',value:'${state['domain']??'bridgepointintelligence.online'}',color:AppTheme.blue),
      _SettingsStatusRow(label:'Domain status',value:status,color:statusColor),
      _SettingsStatusRow(label:'From',value:'${state['from_email']??'notifications@bridgepointintelligence.online'}',color:AppTheme.cyan),
      _SettingsStatusRow(label:'Replies go to',value:'${state['reply_to_email']??_bridgePointOutreachEmail}',color:AppTheme.blue),
      if(state.containsKey('pending_count'))_SettingsStatusRow(label:'Queued / sent / failed',value:'${state['pending_count']??0} / ${state['sent_count']??0} / ${state['failed_count']??0}',color:AppTheme.textMuted),
      if(error!=null)Padding(padding:const EdgeInsets.only(top:7),child:Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:9,height:1.4))),
      _dnsRecords(),
      const SizedBox(height:8),
      Wrap(spacing:8,runSpacing:8,children:[
        if(!configured)FilledButton.icon(onPressed:loading?null:_connect,icon:const Icon(Icons.add_link_rounded),label:const Text('Connect Resend')),
        if(configured&&!ready)FilledButton.icon(onPressed:loading?null:_verify,icon:const Icon(Icons.verified_user_outlined),label:const Text('Verify domain')),
        if(configured)OutlinedButton.icon(onPressed:loading?null:_refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Refresh status')),
        if(ready)FilledButton.tonalIcon(onPressed:loading?null:_test,icon:const Icon(Icons.send_rounded),label:const Text('Send test email')),
      ]),
      if(!configured)const Padding(padding:EdgeInsets.only(top:8),child:Text('One external account step is required: create the Resend account/API key. Everything after that is handled here in BridgePoint.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.8,height:1.4))),
      if(configured&&!ready)const Padding(padding:EdgeInsets.only(top:8),child:Text('Add every DNS record shown above at the domain provider. DNS values are safe to copy; your Resend API key is not shown or stored in this app.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.8,height:1.4))),
    ]));
  }
}

'''
# Insert before the purchase center class added by v224 so related owner/billing tools stay together.
class_anchor='class _PurchaseCenterV224 extends StatefulWidget{'
idx=s.find(class_anchor)
if idx<0:
    raise SystemExit('v225 class insertion anchor missing')
s=s[:idx]+classes+s[idx:]
path.write_text(s,encoding='utf-8')
print('Applied secure Resend transactional email setup v225.')
