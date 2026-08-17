from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v282-founder-story-reviews'
if marker in body:
    print('Founder story and reviews v282 already applied.')
    raise SystemExit(0)

old="""          _BrandContactProfileV215(ownerMode:ownerMode),
          const SizedBox(height:18),
"""
new="""          _FounderStoryReviewsV282(ownerMode:ownerMode),
          const SizedBox(height:18),
          _BrandContactProfileV215(ownerMode:ownerMode),
          const SizedBox(height:18),
"""
if body.count(old)!=1:
    raise SystemExit(f'v282 About insertion anchor {body.count(old)}')
body=body.replace(old,new,1)

anchor="""IconData _trainingIcon(String key) {
"""
widget=r'''class _FounderStoryReviewsV282 extends StatefulWidget{
  const _FounderStoryReviewsV282({required this.ownerMode});
  final bool ownerMode;
  @override State<_FounderStoryReviewsV282> createState()=>_FounderStoryReviewsV282State();
}

class _FounderStoryReviewsV282State extends State<_FounderStoryReviewsV282>{
  late Future<Map<String,dynamic>> request;
  Timer? timer;
  final reviewController=TextEditingController();
  int reviewRating=5;
  bool reviewSeeded=false;
  bool submitting=false;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_brand_profile_v212',const {});timer=Timer.periodic(const Duration(seconds:20),(_){if(mounted&&!submitting)setState(()=>request=_callRpc('bridgepoint_brand_profile_v212',const {}));});}
  @override void dispose(){timer?.cancel();reviewController.dispose();super.dispose();}
  Map<String,dynamic> m(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_brand_profile_v212',const {}));
  String imageUrl(Map<String,dynamic> d,String key){final p='${d[key]??''}'.trim();final base='${d['brand_media_base_url']??''}'.trim();return p.isEmpty||base.isEmpty?'':'$base$p';}
  String mime(XFile f){final n=f.name.toLowerCase();if(n.endsWith('.png'))return 'image/png';if(n.endsWith('.webp'))return 'image/webp';return 'image/jpeg';}
  String ext(XFile f){final n=f.name.toLowerCase();if(n.endsWith('.png'))return '.png';if(n.endsWith('.webp'))return '.webp';return '.jpg';}
  Future<String> upload(XFile f,String kind)async{
    final bytes=await f.readAsBytes();if(bytes.isEmpty)throw Exception('That image could not be read.');if(bytes.length>15728640)throw Exception('Please choose an image smaller than 15 MB.');
    final user=Supabase.instance.client.auth.currentUser;if(user==null)throw Exception('Your session expired. Sign in again.');
    final p='$kind/${user.id}/${DateTime.now().microsecondsSinceEpoch}${ext(f)}';
    await Supabase.instance.client.storage.from('bridgepoint-brand-media').uploadBinary(p,bytes,fileOptions:FileOptions(contentType:mime(f),upsert:false,cacheControl:'3600'));
    return p;
  }
  Future<void> editProfile(Map<String,dynamic> d)async{
    final name=TextEditingController(text:'${d['founder_name']??''}'),title=TextEditingController(text:'${d['founder_title']??''}'),bio=TextEditingController(text:'${d['founder_bio']??''}'),backstory=TextEditingController(text:'${d['founder_backstory']??''}'),message=TextEditingController(text:'${d['founder_message']??''}'),mollyName=TextEditingController(text:'${d['molly_name']??'Molly'}'),mollyStory=TextEditingController(text:'${d['molly_story']??''}');
    XFile? founderFile,mollyFile;final picker=ImagePicker();
    final ok=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      backgroundColor:AppTheme.panel,title:const Text('Meet the Owner • live profile'),
      content:SizedBox(width:720,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Owner / founder name',border:OutlineInputBorder())),const SizedBox(height:8),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Title',hintText:'Founder & Owner',border:OutlineInputBorder())),const SizedBox(height:8),
        TextField(controller:bio,maxLines:3,decoration:const InputDecoration(labelText:'Short bio',border:OutlineInputBorder())),const SizedBox(height:8),
        TextField(controller:backstory,maxLines:6,decoration:const InputDecoration(labelText:'Backstory • why you built BridgePoint',border:OutlineInputBorder())),const SizedBox(height:8),
        TextField(controller:message,maxLines:4,decoration:const InputDecoration(labelText:'Message from the founder',border:OutlineInputBorder())),const SizedBox(height:10),
        Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickImage(source:ImageSource.gallery,imageQuality:90,maxWidth:2000);if(f!=null)setLocal(()=>founderFile=f);},icon:const Icon(Icons.account_circle_outlined),label:Text(founderFile==null?'Choose founder photo':founderFile!.name,overflow:TextOverflow.ellipsis))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()async{final f=await picker.pickImage(source:ImageSource.gallery,imageQuality:90,maxWidth:2000);if(f!=null)setLocal(()=>mollyFile=f);},icon:const Icon(Icons.pets_outlined),label:Text(mollyFile==null?'Choose Molly photo':mollyFile!.name,overflow:TextOverflow.ellipsis)))]),const SizedBox(height:10),
        TextField(controller:mollyName,decoration:const InputDecoration(labelText:'Molly feature name',border:OutlineInputBorder())),const SizedBox(height:8),
        TextField(controller:mollyStory,maxLines:5,decoration:const InputDecoration(labelText:'Molly story / role in BridgePoint',border:OutlineInputBorder())),const SizedBox(height:8),
        const Text('Saving updates the live BridgePoint brand profile. Other signed-in members receive the latest version automatically while this page is open.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(dialogContext,true),icon:const Icon(Icons.publish_rounded),label:const Text('Publish changes'))]
    )));
    if(ok==true){
      try{
        setState(()=>submitting=true);final payload=Map<String,dynamic>.from(d);
        payload['founder_name']=name.text.trim();payload['founder_title']=title.text.trim();payload['founder_bio']=bio.text.trim();payload['founder_backstory']=backstory.text.trim();payload['founder_message']=message.text.trim();payload['molly_name']=mollyName.text.trim();payload['molly_story']=mollyStory.text.trim();
        if(founderFile!=null)payload['founder_image_path']=await upload(founderFile!,'founder');
        if(mollyFile!=null)payload['molly_image_path']=await upload(mollyFile!,'molly');
        await _callRpc('bridgepoint_owner_update_founder_profile_v281',{'p_profile':payload});refresh();
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Meet the Owner profile published live.')));
      }catch(e){if(mounted)_showInfoDialog(context,'Could not publish profile','$e');}finally{if(mounted)setState(()=>submitting=false);}
    }
    for(final c in [name,title,bio,backstory,message,mollyName,mollyStory]){c.dispose();}
  }
  Future<void> submitReview()async{
    final text=reviewController.text.trim();if(text.length<2){_showInfoDialog(context,'Add a review','Write at least a few words about your BridgePoint experience.');return;}
    try{setState(()=>submitting=true);final r=await _callRpc('bridgepoint_submit_review_v281',{'p_rating':reviewRating,'p_review':text});refresh();if(mounted)_showInfoDialog(context,'Review received','${r['message']??'Your review was submitted.'}');}catch(e){if(mounted)_showInfoDialog(context,'Could not submit review','$e');}finally{if(mounted)setState(()=>submitting=false);}
  }
  Future<void> ownerReviewQueue()async{
    try{
      final data=await _callRpc('bridgepoint_owner_reviews_v281',{'p_status':null});final all=rows(data['reviews']);if(!mounted)return;
      await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(backgroundColor:AppTheme.panel,title:Text('Review moderation • ${all.length} total'),content:SizedBox(width:760,height:520,child:all.isEmpty?const Center(child:Text('No reviews have been submitted yet.',style:TextStyle(color:AppTheme.textMuted))):ListView.separated(itemCount:all.length,separatorBuilder:(_,__)=>const Divider(height:18),itemBuilder:(context,i){final r=all[i];return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${r['reviewer_name']??'Member'} • ${r['rating']} ★',style:const TextStyle(fontWeight:FontWeight.w900))),_OpportunityChip(label:'${r['moderation_status']}',color:r['moderation_status']=='APPROVED'?AppTheme.green:r['moderation_status']=='REJECTED'?AppTheme.red:AppTheme.amber)]),const SizedBox(height:5),Text('${r['review_text']}',style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.4)),const SizedBox(height:7),Wrap(spacing:6,runSpacing:6,children:[FilledButton.tonal(onPressed:()async{await _callRpc('bridgepoint_owner_review_action_v281',{'p_review_id':r['review_id'],'p_action':'APPROVE','p_owner_response':null});if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();},child:const Text('Approve')),OutlinedButton(onPressed:()async{await _callRpc('bridgepoint_owner_review_action_v281',{'p_review_id':r['review_id'],'p_action':'FEATURE','p_owner_response':null});if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();},child:const Text('Feature')),TextButton(onPressed:()async{await _callRpc('bridgepoint_owner_review_action_v281',{'p_review_id':r['review_id'],'p_action':'REJECT','p_owner_response':null});if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();},child:const Text('Reject'))])]);})),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close'))]));
    }catch(e){if(mounted)_showInfoDialog(context,'Review moderation could not load','$e');}
  }
  Widget portrait(String url,IconData fallback,Color accent){return Container(width:112,height:112,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:accent.withOpacity(.35),width:2),boxShadow:[BoxShadow(color:accent.withOpacity(.10),blurRadius:20)]),child:url.isEmpty?Icon(fallback,size:54,color:accent):Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Icon(fallback,size:54,color:accent)));}
  Widget stars(int rating,{double size=18,ValueChanged<int>? onTap})=>Wrap(spacing:1,children:List.generate(5,(i)=>InkWell(onTap:onTap==null?null:()=>onTap(i+1),child:Icon(i<rating?Icons.star_rounded:Icons.star_border_rounded,color:AppTheme.amber,size:size))));
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,s){
    if(s.connectionState==ConnectionState.waiting&&!s.hasData)return const Card(child:Padding(padding:EdgeInsets.all(18),child:LinearProgressIndicator(color:AppTheme.cyan,minHeight:3)));
    if(s.hasError)return _DashboardError(title:'Meet the Owner could not load',message:s.error.toString(),onRetry:refresh);
    final d=s.data??const <String,dynamic>{};final summary=m(d['review_summary']);final reviews=rows(d['reviews']);final mine=m(d['my_review']);
    if(!reviewSeeded&&mine.isNotEmpty){reviewSeeded=true;reviewRating=(mine['rating'] as num?)?.toInt()??5;reviewController.text='${mine['review_text']??''}';}
    final founder=imageUrl(d,'founder_image_path'),molly=imageUrl(d,'molly_image_path');final founderName='${d['founder_name']??''}'.trim();final mollyName='${d['molly_name']??'Molly'}'.trim();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:_PanelHeader(title:'Meet the Owner',subtitle:'The person, story and mission behind BridgePoint',action:'Founder story')),if(widget.ownerMode)FilledButton.tonalIcon(onPressed:submitting?null:()=>editProfile(d),icon:const Icon(Icons.edit_rounded,size:17),label:const Text('Edit live profile'))]),const SizedBox(height:10),
      Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.09),AppTheme.blue.withOpacity(.04),Colors.transparent]),borderRadius:BorderRadius.circular(14)),child:LayoutBuilder(builder:(context,c){final compact=c.maxWidth<680;final text=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(founderName.isEmpty?'BridgePoint Founder':founderName,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),if('${d['founder_title']??''}'.trim().isNotEmpty)...[const SizedBox(height:3),Text('${d['founder_title']}',style:const TextStyle(color:AppTheme.cyan,fontSize:10,fontWeight:FontWeight.w900))],if('${d['founder_bio']??''}'.trim().isNotEmpty)...[const SizedBox(height:9),Text('${d['founder_bio']}',style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.55))],if('${d['founder_backstory']??''}'.trim().isNotEmpty)ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('My backstory • why I built BridgePoint',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),children:[Align(alignment:Alignment.centerLeft,child:Text('${d['founder_backstory']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.6)))]),if('${d['founder_message']??''}'.trim().isNotEmpty)Container(width:double.infinity,margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.05),borderRadius:BorderRadius.circular(10)),child:Text('“${d['founder_message']}”',style:const TextStyle(color:Color(0xFFDDECF8),fontSize:10,fontStyle:FontStyle.italic,height:1.5)))]);return compact?Column(children:[portrait(founder,Icons.person_rounded,AppTheme.cyan),const SizedBox(height:12),text]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[portrait(founder,Icons.person_rounded,AppTheme.cyan),const SizedBox(width:18),Expanded(child:text)]);}))),
      const SizedBox(height:10),Card(child:Padding(padding:const EdgeInsets.all(16),child:LayoutBuilder(builder:(context,c){final compact=c.maxWidth<620;final text=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(mollyName.isEmpty?'Molly':mollyName,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:3),const Text('BRIDGEPOINT COMPANION',style:TextStyle(color:Color(0xFFE8B77F),fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.7)),if('${d['molly_story']??''}'.trim().isNotEmpty)...[const SizedBox(height:7),Text('${d['molly_story']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55))]else...[const SizedBox(height:7),const Text('You already see Molly throughout BridgePoint tips and walkthroughs. The founder can add her full story here anytime.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.55))]]);return compact?Column(children:[portrait(molly,Icons.pets_rounded,const Color(0xFFE8B77F)),const SizedBox(height:10),text]):Row(children:[portrait(molly,Icons.pets_rounded,const Color(0xFFE8B77F)),const SizedBox(width:16),Expanded(child:text)]);}))),
      const SizedBox(height:16),Row(children:[const Expanded(child:_PanelHeader(title:'BridgePoint Reviews',subtitle:'Verified signed-in members • 1–5 stars • moderated public feedback',action:'Customer voice')),if(widget.ownerMode)OutlinedButton.icon(onPressed:ownerReviewQueue,icon:const Icon(Icons.rate_review_outlined,size:17),label:Text('Moderate ${summary['pending_count']??0}'))]),const SizedBox(height:9),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[stars(((summary['average_rating'] as num?)?.round()??0),size:22),const SizedBox(width:8),Text('${summary['average_rating']??0} / 5',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900)),const Spacer(),Text('${summary['approved_count']??0} published',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))]),if(reviews.isEmpty)...[const SizedBox(height:8),const Text('No public reviews yet. Customer feedback will appear here after moderation.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5))]else...[const SizedBox(height:10),...reviews.take(8).map((r)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${r['reviewer_name']??'BridgePoint member'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:9.5))),stars((r['rating'] as num?)?.toInt()??0,size:15)]),const SizedBox(height:5),Text('${r['review_text']}',style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.45)),if('${r['owner_response']??''}'.trim().isNotEmpty)...[const SizedBox(height:7),Text('BridgePoint: ${r['owner_response']}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,height:1.4))],const SizedBox(height:4),Text(_bpDateTime(r['updated_at']??r['submitted_at']),style:const TextStyle(color:Colors.white38,fontSize:7.5))]))]]))),
      const SizedBox(height:9),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(mine.isEmpty?'Share your BridgePoint experience':'Edit your review',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:6),stars(reviewRating,size:25,onTap:(v)=>setState(()=>reviewRating=v)),const SizedBox(height:8),TextField(controller:reviewController,maxLines:4,maxLength:2000,decoration:const InputDecoration(labelText:'Your review',hintText:'What has been useful? What should others know?',border:OutlineInputBorder())),const SizedBox(height:7),Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[FilledButton.icon(onPressed:submitting?null:submitReview,icon:const Icon(Icons.star_rounded),label:Text(submitting?'Submitting…':'Submit review')),if(mine.isNotEmpty)_OpportunityChip(label:'YOUR REVIEW • ${mine['moderation_status']??'PENDING'}',color:mine['moderation_status']=='APPROVED'?AppTheme.green:AppTheme.amber)]),const SizedBox(height:5),const Text('Reviews are tied to a verified BridgePoint account. New or edited reviews go through moderation before becoming public.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4))]))),
      const SizedBox(height:3),Text('Profile refreshed • ${_bpDateTime(d['updated_at'])}',style:const TextStyle(color:Colors.white38,fontSize:7.5)),const Text('bridgepoint-v282-founder-story-reviews',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ]);
  });
}

'''
if body.count(anchor)!=1:
    raise SystemExit(f'v282 class anchor {body.count(anchor)}')
body=body.replace(anchor,widget+anchor,1)
body += "\nconst String _bridgePointFounderStoryReviewsV282='bridgepoint-v282-founder-story-reviews | live founder profile | Molly feature | owner photo upload | verified reviews | moderation';\n"
path.write_text(body,encoding='utf-8')
print('Applied live Meet the Owner, Molly and reviews UI v282.')
