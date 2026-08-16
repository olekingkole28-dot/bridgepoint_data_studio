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

anchor="""  Future<void> publishConnected()async{
    setState(()=>busy=true);
    try{
      final response=await Supabase.instance.client.functions.invoke(
        'bridgepoint-social-publisher-v120',
        body:{'action':'publish','platforms':platforms.toList(),'limit':25},
      );
      final result=_edgeFunctionPayload(response.data);
      if(result['complete']!=true)throw Exception('${result['error']??'Social publisher failed.'}');
      final outcomes=result['results'] is List?List<dynamic>.from(result['results']):<dynamic>[];
      final published=outcomes.where((e)=>e is Map&&e['status']=='PUBLISHED').length;
      final needsConnection=outcomes.where((e)=>e is Map&&e['status']=='NEEDS_CONNECTION').length;
      final failed=outcomes.where((e)=>e is Map&&e['status']=='FAILED').length;
      if(mounted){
        await _showInfoDialog(context,'Social publishing finished',
          'Published: $published\\nNeeds connection: $needsConnection\\nFailed: $failed\\n\\nBridgePoint only marks a post published after the social platform returns a real provider response.');
        refresh();
      }
    }catch(e){if(mounted)_showInfoDialog(context,'Could not publish social posts',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
"""

addition=anchor+r'''

  Future<Map<String,dynamic>> _providerConfig(String platform)async{
    final result=await _callRpc('bridgepoint_social_provider_config_v122',const {});
    final list=result['providers'] is List?List<dynamic>.from(result['providers']):<dynamic>[];
    final found=list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>'${e['platform']}'==platform).toList();
    return found.isEmpty?<String,dynamic>{'platform':platform}:found.first;
  }

  Future<void> configureProvider(String platform)async{
    Map<String,dynamic> current;
    try{current=await _providerConfig(platform);}catch(e){if(mounted)_showInfoDialog(context,'Could not load provider setup',e.toString());return;}
    final clientId=TextEditingController(text:'${current['client_id']??''}');
    final secret=TextEditingController();
    bool applyMetaBoth=['FACEBOOK','INSTAGRAM'].contains(platform);
    bool showSecret=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      backgroundColor:AppTheme.panel,title:Text('Configure ${platform=='YOUTUBE_SHORTS'?'YouTube Shorts':platform} publishing'),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TextField(controller:clientId,decoration:const InputDecoration(labelText:'Provider Client ID / App ID / Client Key',border:OutlineInputBorder())),const SizedBox(height:10),
        TextField(controller:secret,obscureText:!showSecret,decoration:InputDecoration(labelText:current['client_secret_configured']==true?'Client Secret (leave blank to keep existing)':'Client Secret',border:const OutlineInputBorder(),suffixIcon:IconButton(onPressed:()=>setLocal(()=>showSecret=!showSecret),icon:Icon(showSecret?Icons.visibility_off_rounded:Icons.visibility_rounded)))),
        const SizedBox(height:10),Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(9)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('REGISTER THIS OAUTH REDIRECT URI',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),SelectableText('${current['redirect_uri']??'https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-social-connect-v122'}',style:const TextStyle(fontSize:9,color:Colors.white))])),
        if(['FACEBOOK','INSTAGRAM'].contains(platform))...[const SizedBox(height:8),CheckboxListTile(contentPadding:EdgeInsets.zero,value:applyMetaBoth,onChanged:(v)=>setLocal(()=>applyMetaBoth=v==true),title:const Text('Use this same Meta app for Facebook + Instagram',style:TextStyle(fontSize:10)),subtitle:const Text('Recommended when both accounts are managed through the same Meta developer app.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)))],
        const SizedBox(height:8),const Text('BridgePoint sends the Client Secret directly to a protected Supabase RPC, which stores it in Vault. The secret is never written into Flutter source and is never returned to this screen.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,{'client_id':clientId.text.trim(),'client_secret':secret.text,'meta_both':applyMetaBoth}),child:const Text('Save secure setup'))],
    )));
    clientId.dispose();secret.dispose();if(result==null)return;
    if('${result['client_id']??''}'.trim().isEmpty){if(mounted)_showInfoDialog(context,'Client ID required','Enter the Client ID/App ID/Client Key from the provider developer portal.');return;}
    setState(()=>busy=true);
    try{
      final targets=(result['meta_both']==true&&['FACEBOOK','INSTAGRAM'].contains(platform))?['FACEBOOK','INSTAGRAM']:[platform];
      for(final p in targets){await _callRpc('bridgepoint_social_save_provider_config_v122',{'p_platform':p,'p_client_id':result['client_id'],'p_client_secret':result['client_secret']});}
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${targets.map((p)=>p=='YOUTUBE_SHORTS'?'YouTube Shorts':p).join(' + ')} provider setup saved securely.')));refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not save provider setup',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> connectProvider(String platform)async{
    setState(()=>busy=true);
    try{
      final response=await Supabase.instance.client.functions.invoke('bridgepoint-social-connect-v122',body:{'action':'start','platform':platform,'return_url':_bridgePointLiveUrl});
      final result=_edgeFunctionPayload(response.data);
      if(result['setup_required']==true){if(mounted)await _showInfoDialog(context,'Provider setup required','${result['error']??'Configure this provider first.'}\n\nRedirect URI:\n${result['redirect_uri']??''}');return;}
      if(result['complete']!=true)throw Exception('${result['error']??'Could not start social connection.'}');
      final url='${result['connect_url']??''}';if(url.isEmpty)throw Exception('Provider did not return a connection URL.');
      final opened=await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
      if(!opened)throw Exception('Could not open the provider authorization page.');
      if(mounted)await _showInfoDialog(context,'Finish the connection','Complete the provider consent screen in the tab/window that just opened. BridgePoint stores the resulting account token in Vault. When you return, use Refresh connections if the status has not updated yet.');
    }catch(e){if(mounted)_showInfoDialog(context,'Could not connect $platform',e.toString());}
    finally{if(mounted){setState(()=>busy=false);refresh();}}
  }
'''
replace_once(anchor,addition,'social-connect-methods')

old="""            ...connections.where((c)=>['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN','X','YOUTUBE_SHORTS'].contains('${c['platform']}')).map((c){final p='${c['platform']}';final live=connected.contains(p);final label=p=='YOUTUBE_SHORTS'?'YOUTUBE SHORTS':p;return _OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION',live?AppTheme.green:AppTheme.amber);}),
            const SizedBox(height:8),const Text('BridgePoint will never claim a post was published when the platform is not actually connected. TikTok/Meta/LinkedIn need approved publishing OAuth/API connections before true unattended posting can be enabled.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
"""
new="""            ...connections.where((c)=>['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN','X','YOUTUBE_SHORTS'].contains('${c['platform']}')).map((c){final p='${c['platform']}';final live=connected.contains(p);final label=p=='YOUTUBE_SHORTS'?'YOUTUBE SHORTS':p;return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:_OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION',live?AppTheme.green:AppTheme.amber)),const SizedBox(width:6),TextButton.icon(onPressed:busy?null:()=>configureProvider(p),icon:const Icon(Icons.settings_outlined,size:15),label:const Text('Configure')),const SizedBox(width:4),FilledButton.tonalIcon(onPressed:busy?null:()=>connectProvider(p),icon:Icon(live?Icons.sync_rounded:Icons.link_rounded,size:15),label:Text(live?'Reconnect':'Connect'))]));}),
            const SizedBox(height:6),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:busy?null:refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Refresh connections')),const _OpportunityChip(label:'TOKENS STORED IN VAULT',color:AppTheme.green)]),
            const SizedBox(height:8),const Text('Configure stores provider developer credentials securely. Connect opens the provider’s real OAuth consent screen. BridgePoint never claims a post was published when the platform is not actually connected and approved for the required publishing scope.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
"""
replace_once(old,new,'connection-controls')

if text==original:raise SystemExit('No social connection changes applied')
path.write_text(text,encoding='utf-8')
print('Applied owner social configure/connect UI v123')
