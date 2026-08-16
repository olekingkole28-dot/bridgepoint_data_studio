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
"""class _OwnerGrowthPanelState extends State<_OwnerGrowthPanel>{
  late Future<Map<String,dynamic>> request;
  bool busy=false;
""",
"""class _OwnerGrowthPanelState extends State<_OwnerGrowthPanel>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> todayRequest;
  bool busy=false;
""",
'growth-today-field')

replace_once(
"""  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_growth_center_v102',const {});
  void refresh()=>setState(()=>request=_load());
""",
"""  @override void initState(){super.initState();request=_load();todayRequest=_today();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_growth_center_v102',const {});
  String _todayIso(){final d=DateTime.now();return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';}
  Future<Map<String,dynamic>> _today()=>_callRpc('bridgepoint_growth_today_v132',{'p_day':_todayIso()});
  void refresh()=>setState((){request=_load();todayRequest=_today();});
""",
'growth-today-load')

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
if text.count(anchor)!=1:
    raise SystemExit(f'numbered publish anchor not found: {text.count(anchor)}')
addition=anchor+r'''

  Future<void> postDailySlot(int slot)async{
    setState(()=>busy=true);
    try{
      final response=await Supabase.instance.client.functions.invoke(
        'bridgepoint-social-publisher-v120',
        body:{'action':'publish','daily_slot':slot,'campaign_date':_todayIso(),'platforms':platforms.toList(),'limit':20},
      );
      final result=_edgeFunctionPayload(response.data);
      if(result['complete']!=true)throw Exception('${result['error']??'Could not publish today’s post.'}');
      final outcomes=result['results'] is List?List<dynamic>.from(result['results']):<dynamic>[];
      final published=outcomes.where((e)=>e is Map&&e['status']=='PUBLISHED').length;
      final needsConnection=outcomes.where((e)=>e is Map&&e['status']=='NEEDS_CONNECTION').length;
      final needsAsset=outcomes.where((e)=>e is Map&&e['status']=='NEEDS_ASSET').length;
      final failed=outcomes.where((e)=>e is Map&&e['status']=='FAILED').length;
      if(mounted){
        await _showInfoDialog(context,'Post #$slot finished',
          'Published to $published connected social${published==1?'':'s'}.\\nNeeds connection: $needsConnection\\nNeeds media: $needsAsset\\nFailed: $failed\\n\\nEach social receives its own platform-specific BridgePoint version.');
        refresh();
      }
    }catch(e){if(mounted)_showInfoDialog(context,'Could not post #$slot',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
'''
text=text.replace(anchor,addition,1)

explainer="""        const SizedBox(height:10),const _ExplainerBanner(icon:Icons.campaign_outlined,title:'One private button for your customer-acquisition posts',message:'BridgePoint keeps platform-specific founder posts ready for TikTok, Instagram, Facebook, LinkedIn, X and YouTube Shorts. Publish connected now sends the prepared variants through the approved account connections, records the real provider result, and keeps click → signup → trial → paid attribution tied back to the originating post.'),
"""
if text.count(explainer)!=1:
    raise SystemExit(f'growth explainer anchor not found: {text.count(explainer)}')
block=explainer+r'''
        const SizedBox(height:12),
        FutureBuilder<Map<String,dynamic>>(
          future:todayRequest,
          builder:(context,todaySnap){
            final posts=rows(todaySnap.data?['posts']);
            if(todaySnap.connectionState==ConnectionState.waiting&&!todaySnap.hasData)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);
            if(todaySnap.hasError)return _InlineError(message:todaySnap.error.toString());
            return Container(
              width:double.infinity,padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.035),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('TODAY’S SIX SALES POSTS',style:TextStyle(color:AppTheme.cyan,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.7)),SizedBox(height:3),Text('Each number has a different sales job. One tap sends that number’s platform-specific version to every connected social.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))])),OutlinedButton.icon(onPressed:busy?null:()=>setState(()=>todayRequest=_today()),icon:const Icon(Icons.refresh_rounded),label:const Text('Refresh'))]),
                const SizedBox(height:10),
                if(posts.isEmpty)const Text('BridgePoint is preparing today’s canonical six-post sales set.',style:TextStyle(color:AppTheme.textMuted))
                else LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1050?3:c.maxWidth>=700?2:1;const gap=9.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:posts.map((p){
                  final slot=(p['daily_slot'] as num?)?.toInt()??1;
                  final variants=rows(p['variants']);
                  final done=variants.where((v)=>v['status']=='PUBLISHED').length;
                  final ready=variants.where((v)=>['READY','APPROVED'].contains('${v['status']}')).length;
                  final first=variants.isEmpty?<String,dynamic>{}:variants.first;
                  return SizedBox(width:w,child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.66),borderRadius:BorderRadius.circular(12),border:Border.all(color:done==variants.length&&variants.isNotEmpty?AppTheme.green.withOpacity(.25):Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[CircleAvatar(radius:16,backgroundColor:AppTheme.cyan.withOpacity(.14),child:Text('$slot',style:const TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w900))),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['sales_objective']??'Sales post'}'.replaceAll('_',' '),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)),Text('${p['target_buyer']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.3))])),_OpportunityChip(label:done==variants.length&&variants.isNotEmpty?'POSTED':'$ready READY',color:done==variants.length&&variants.isNotEmpty?AppTheme.green:AppTheme.amber)]),
                    const SizedBox(height:8),Text('${p['core_promise']??''}',style:const TextStyle(fontSize:9,height:1.4)),
                    const SizedBox(height:8),Wrap(spacing:5,runSpacing:5,children:variants.map((v)=>_OpportunityChip(label:'${v['platform']}'.replaceAll('_',' '),color:v['status']=='PUBLISHED'?AppTheme.green:platformColor('${v['platform']}'))).toList()),
                    if('${first['caption']??''}'.isNotEmpty)...[const SizedBox(height:8),Text('${first['caption']}',maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35))],
                    const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy||done==variants.length&&variants.isNotEmpty?null:()=>postDailySlot(slot),icon:Icon(done==variants.length&&variants.isNotEmpty?Icons.check_circle_rounded:Icons.rocket_launch_rounded,size:17),label:Text(done==variants.length&&variants.isNotEmpty?'Post #$slot complete':'Post #$slot to ALL connected socials'))),
                  ])));
                }).toList());}),
                const SizedBox(height:8),const Text('Tomorrow’s six posts and the next two weeks generate automatically. BridgePoint keeps the sales objective consistent while adapting hook, length, proof style, hashtags and CTA for each social platform.',style:TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.4)),
              ]),
            );
          },
        ),
'''
text=text.replace(explainer,block,1)

if text==original:raise SystemExit('No numbered sales post changes applied')
path.write_text(text,encoding='utf-8')
print('Applied six numbered sales post UI v146')
