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
"""  Future<void> generateWeek()async{
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_growth_generate_queue_v102',{'p_days':7});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Growth queue refreshed • ${result['inserted']??0} new post slots added.')));refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not generate posts',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
""",
"""  Future<void> generateWeek()async{
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_growth_generate_queue_v102',{'p_days':7});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Growth queue refreshed • ${result['inserted']??0} new post slots added.')));refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not generate posts',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> publishConnected()async{
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
""",
'publish-connected-method')

replace_once(
"""            ],onChanged:busy?null:(v)=>setState(()=>approvalMode=v??approvalMode)),
            const SizedBox(height:9),Wrap(spacing:7,runSpacing:7,children:['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN'].map((p)=>FilterChip(selected:platforms.contains(p),label:Text(p),onSelected:busy?null:(v)=>setState((){if(v){platforms.add(p);}else if(platforms.length>1){platforms.remove(p);}}))).toList()),
            const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:busy?null:saveSettings,icon:const Icon(Icons.save_outlined),label:Text(busy?'Saving…':'Save automation')),OutlinedButton.icon(onPressed:busy?null:generateWeek,icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Fill next 7 days'))]),
""",
"""            ],onChanged:busy?null:(v)=>setState(()=>approvalMode=v??approvalMode)),
            const SizedBox(height:9),Wrap(spacing:7,runSpacing:7,children:['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN','X','YOUTUBE_SHORTS'].map((p)=>FilterChip(selected:platforms.contains(p),label:Text(p=='YOUTUBE_SHORTS'?'YOUTUBE SHORTS':p),onSelected:busy?null:(v)=>setState((){if(v){platforms.add(p);}else if(platforms.length>1){platforms.remove(p);}}))).toList()),
            const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[
              FilledButton.icon(onPressed:busy?null:publishConnected,icon:const Icon(Icons.rocket_launch_rounded),label:Text(busy?'Working…':'Publish connected now')),
              OutlinedButton.icon(onPressed:busy?null:saveSettings,icon:const Icon(Icons.save_outlined),label:const Text('Save automation')),
              OutlinedButton.icon(onPressed:busy?null:generateWeek,icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Fill next 7 days')),
            ]),
            const SizedBox(height:8),const Text('One click publishes the platform-specific BridgePoint variants only to accounts that are truly connected. Every attempt, provider post ID, error and tracked campaign URL is recorded for attribution.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
""",
'platforms-and-publish-button')

replace_once(
"""            ...connections.where((c)=>['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN'].contains('${c['platform']}')).map((c){final p='${c['platform']}';final live=connected.contains(p);return _OwnerStatusRow(p,live?'CONNECTED':'QUEUE / SHARE',live?AppTheme.green:AppTheme.amber);}),
""",
"""            ...connections.where((c)=>['TIKTOK','FACEBOOK','INSTAGRAM','LINKEDIN','X','YOUTUBE_SHORTS'].contains('${c['platform']}')).map((c){final p='${c['platform']}';final live=connected.contains(p);final label=p=='YOUTUBE_SHORTS'?'YOUTUBE SHORTS':p;return _OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION',live?AppTheme.green:AppTheme.amber);}),
""",
'connection-platforms')

replace_once(
"""        const SizedBox(height:10),const _ExplainerBanner(icon:Icons.campaign_outlined,title:'Six posts a day without six manual writing sessions',message:'BridgePoint keeps a rolling week of varied founder/customer-acquisition posts. Copy or Share works now. When an approved social publishing connector is connected, AUTO WHEN CONNECTED can publish the same scheduled queue without rebuilding your workflow.'),
""",
"""        const SizedBox(height:10),const _ExplainerBanner(icon:Icons.campaign_outlined,title:'One private button for your customer-acquisition posts',message:'BridgePoint keeps platform-specific founder posts ready for TikTok, Instagram, Facebook, LinkedIn, X and YouTube Shorts. Publish connected now sends the prepared variants through the approved account connections, records the real provider result, and keeps click → signup → trial → paid attribution tied back to the originating post.'),
""",
'growth-explainer')

if text==original:
    raise SystemExit('No social publishing changes were applied')
path.write_text(text,encoding='utf-8')
print('Applied owner-only social publishing UI v120')
