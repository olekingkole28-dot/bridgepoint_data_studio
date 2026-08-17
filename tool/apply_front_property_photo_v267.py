from pathlib import Path

main=Path('lib/main.dart')
pubspec=Path('pubspec.yaml')
body=main.read_text(encoding='utf-8')
yaml=pubspec.read_text(encoding='utf-8')
marker='bridgepoint-v267-front-property-photo'
if marker in body:
    print('Front property photo contribution v267 already applied.')
    raise SystemExit(0)

if '  image_picker:' not in yaml:
    anchor='  http: ^1.5.0\n'
    if yaml.count(anchor)!=1:
        raise SystemExit(f'v267 image_picker dependency anchor {yaml.count(anchor)}')
    yaml=yaml.replace(anchor,anchor+'  image_picker: ^1.1.2\n',1)
    pubspec.write_text(yaml,encoding='utf-8')

if "import 'dart:typed_data';" not in body:
    anchor="import 'dart:math';\n"
    if body.count(anchor)!=1:
        raise SystemExit(f'v267 typed_data import anchor {body.count(anchor)}')
    body=body.replace(anchor,anchor+"import 'dart:typed_data';\n",1)

if "import 'package:image_picker/image_picker.dart';" not in body:
    anchor="import 'package:http/http.dart' as http;\n"
    if body.count(anchor)!=1:
        raise SystemExit(f'v267 image_picker import anchor {body.count(anchor)}')
    body=body.replace(anchor,anchor+"import 'package:image_picker/image_picker.dart';\n",1)

start=body.find('class _PropertyMediaThumb extends StatefulWidget{')
end=body.find('class _PropertyMediaMissing extends StatelessWidget {',start)
if start<0 or end<0:
    raise SystemExit(f'v267 property media anchors {start} {end}')

replacement=r'''
Future<Map<String,dynamic>> _bridgePointResolvePrivateMediaItemV267(dynamic raw)async{
  final item=Map<String,dynamic>.from(_bpMap(raw));
  if(item.isEmpty)return item;
  final direct='${item['media_url']??''}'.trim();
  if(direct.isNotEmpty)return item;
  final bucket='${item['media_bucket']??''}'.trim();
  final path='${item['media_path']??''}'.trim();
  if(bucket.isEmpty||path.isEmpty)return item;
  try{
    final signed=await Supabase.instance.client.storage.from(bucket).createSignedUrl(path,3600);
    if(signed.trim().isNotEmpty){
      item['media_url']=signed;
      item['thumbnail_url']=signed;
      item['_signed_storage']=true;
    }
  }catch(_){ }
  return item;
}

Future<Map<String,dynamic>> _bridgePointResolvePrivateMediaBundleV267(Map<String,dynamic> raw)async{
  final bundle=Map<String,dynamic>.from(raw);
  for(final key in const ['primary','front','aerial_current']){
    final value=_bpMap(bundle[key]);
    if(value.isNotEmpty)bundle[key]=await _bridgePointResolvePrivateMediaItemV267(value);
  }
  final items=_bpRows(bundle['items']);
  if(items.isNotEmpty)bundle['items']=await Future.wait(items.map(_bridgePointResolvePrivateMediaItemV267));
  return bundle;
}

class _FrontPropertyPhotoDialogV267 extends StatefulWidget{
  const _FrontPropertyPhotoDialogV267({required this.propertyId});
  final String propertyId;
  @override State<_FrontPropertyPhotoDialogV267> createState()=>_FrontPropertyPhotoDialogV267State();
}

class _FrontPropertyPhotoDialogV267State extends State<_FrontPropertyPhotoDialogV267>{
  final picker=ImagePicker();
  final noteController=TextEditingController();
  XFile? selected;
  Uint8List? bytes;
  bool rights=false;
  bool privacy=false;
  bool uploading=false;
  String? error;

  @override void dispose(){noteController.dispose();super.dispose();}

  String _mime(XFile f){
    final n=f.name.toLowerCase();
    if(n.endsWith('.png'))return 'image/png';
    if(n.endsWith('.webp'))return 'image/webp';
    return 'image/jpeg';
  }
  String _extension(XFile f){
    final n=f.name.toLowerCase();
    if(n.endsWith('.png'))return '.png';
    if(n.endsWith('.webp'))return '.webp';
    return '.jpg';
  }

  Future<void> _pick(ImageSource source)async{
    if(uploading)return;
    try{
      final file=await picker.pickImage(source:source,imageQuality:88,maxWidth:2400);
      if(file==null)return;
      final data=await file.readAsBytes();
      if(data.isEmpty)throw Exception('That image could not be read.');
      if(data.length>15728640)throw Exception('Please choose a photo smaller than 15 MB.');
      if(!mounted)return;
      setState((){selected=file;bytes=data;error=null;});
    }catch(e){if(mounted)setState(()=>error='${e}'.replaceFirst('Exception: ',''));}
  }

  Future<void> _submit()async{
    final file=selected;final data=bytes;
    if(file==null||data==null||uploading)return;
    if(!rights||!privacy){setState(()=>error='Confirm both photo contribution rules before submitting.');return;}
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null){setState(()=>error='Your BridgePoint session expired. Sign in again before uploading.');return;}
    setState((){uploading=true;error=null;});
    String? uploadedPath;
    try{
      final path='property-contributions/${user.id}/${widget.propertyId}/${DateTime.now().microsecondsSinceEpoch}${_extension(file)}';
      uploadedPath=path;
      await Supabase.instance.client.storage.from('bridgepoint-community-media').uploadBinary(
        path,data,fileOptions:FileOptions(contentType:_mime(file),upsert:false,cacheControl:'3600'),
      );
      final result=await _callRpc('bridgepoint_submit_property_photo_v266',{
        'p_property_id':widget.propertyId,
        'p_media_path':path,
        'p_captured_at':DateTime.now().toUtc().toIso8601String(),
        'p_note':noteController.text.trim().isEmpty?null:noteController.text.trim(),
        'p_visibility':'PUBLIC',
        'p_rights_attested':true,
      });
      if(result['complete']!=true)throw Exception('${result['message']??'BridgePoint could not submit this photo.'}');
      if(!mounted)return;
      Navigator.pop(context,true);
    }catch(e){
      if(uploadedPath!=null){try{await Supabase.instance.client.storage.from('bridgepoint-community-media').remove([uploadedPath]);}catch(_){}}
      if(mounted)setState(()=>error='${e}'.replaceFirst('Exception: ',''));
    }finally{if(mounted)setState(()=>uploading=false);}
  }

  @override Widget build(BuildContext context)=>Dialog(
    backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(14),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:680,maxHeight:860),child:Padding(
      padding:const EdgeInsets.all(18),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.add_a_photo_rounded,color:Colors.white)),
          const SizedBox(width:10),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Add / update front photo',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
            SizedBox(height:2),Text('Help BridgePoint keep the property visually current.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)),
          ])),
          IconButton(onPressed:uploading?null:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height:14),
        Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.06),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(Icons.camera_alt_outlined,color:AppTheme.cyan,size:17),SizedBox(width:7),Text('Best photo',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900))]),
          SizedBox(height:5),
          Text('Take a clear front/exterior photo from a public or permitted location. Try to show the structure, not people or vehicles. This becomes a visual reference — not proof of damage or a claim.',style:TextStyle(color:Colors.white70,fontSize:9,height:1.45)),
        ])),
        const SizedBox(height:12),
        if(bytes==null)...[
          Container(height:220,width:double.infinity,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white10)),child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.photo_camera_back_outlined,color:AppTheme.textMuted,size:38),SizedBox(height:9),Text('No photo selected yet',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:3),Text('Use your camera or choose an existing image.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))])),
        ]else...[
          ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.memory(bytes!,height:290,width:double.infinity,fit:BoxFit.cover)),
          const SizedBox(height:7),
          Text('${selected?.name??'Selected photo'} • ${(bytes!.length/1048576).toStringAsFixed(1)} MB',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
        ],
        const SizedBox(height:10),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton.tonalIcon(onPressed:uploading?null:()=>_pick(ImageSource.camera),icon:const Icon(Icons.photo_camera_rounded,size:17),label:Text(bytes==null?'Take photo':'Retake photo')),
          OutlinedButton.icon(onPressed:uploading?null:()=>_pick(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined,size:17),label:Text(bytes==null?'Choose photo':'Choose different photo')),
        ]),
        const SizedBox(height:13),
        TextField(controller:noteController,maxLength:500,maxLines:3,enabled:!uploading,decoration:const InputDecoration(labelText:'Optional note',hintText:'Example: Front exterior photographed today from the sidewalk.',border:OutlineInputBorder())),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:rights,onChanged:uploading?null:(v)=>setState(()=>rights=v==true),controlAffinity:ListTileControlAffinity.leading,title:const Text('I took this photo or have permission to contribute it.',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w800)),subtitle:const Text('Do not upload copyrighted/private images you are not allowed to share.',style:TextStyle(color:AppTheme.textMuted,fontSize:8))),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:privacy,onChanged:uploading?null:(v)=>setState(()=>privacy=v==true),controlAffinity:ListTileControlAffinity.leading,title:const Text('I did not intentionally capture people, license plates, interiors, private documents, or sensitive personal information.',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w800)),subtitle:const Text('BridgePoint may reject or remove a contribution that creates a privacy or safety concern.',style:TextStyle(color:AppTheme.textMuted,fontSize:8))),
        if(error!=null)...[const SizedBox(height:6),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.red.withOpacity(.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.red.withOpacity(.18))),child:Text(error!,style:const TextStyle(color:AppTheme.red,fontSize:8.5,height:1.35)))],
        const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10)),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.verified_user_outlined,color:AppTheme.green,size:16),SizedBox(width:7),Expanded(child:Text('The upload stays in BridgePoint’s private media storage. Other BridgePoint members can see it only after moderation approves it for member display.',style:TextStyle(color:Colors.white60,fontSize:8.2,height:1.4))) ])),
        const SizedBox(height:14),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:selected!=null&&rights&&privacy&&!uploading?_submit:null,icon:uploading?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.cloud_upload_rounded),label:Text(uploading?'Uploading securely…':'Submit for BridgePoint review'))),
      ])),
    )),
  );
}

class _PropertyMediaThumb extends StatefulWidget{
  const _PropertyMediaThumb({required this.propertyId});final String propertyId;
  @override State<_PropertyMediaThumb> createState()=>_PropertyMediaThumbState();
}
class _PropertyMediaThumbState extends State<_PropertyMediaThumb>{
  late Future<Map<String,dynamic>> request;
  Future<Map<String,dynamic>> _load()async{
    if(widget.propertyId.isEmpty)return <String,dynamic>{};
    return _bridgePointResolvePrivateMediaBundleV267(await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId}));
  }
  @override void initState(){super.initState();request=_load();}
  @override void didUpdateWidget(covariant _PropertyMediaThumb oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.propertyId!=widget.propertyId)request=_load();}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final primary=_bpMap(snapshot.data?['primary']);
      final url='${primary['thumbnail_url']??primary['media_url']??''}'.trim();
      if(url.isEmpty)return Container(width:58,height:58,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.08),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.home_work_outlined,color:AppTheme.cyan,size:20));
      return GestureDetector(
        onTap:()=>_showZoomablePropertyImage(context,'${primary['media_url']??url}',title:'${primary['display_label']??'Property Image'}',subtitle:'${primary['source_name']??primary['provider']??''}'),
        child:Stack(children:[
          ClipRRect(borderRadius:BorderRadius.circular(11),child:Image.network(url,width:58,height:58,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:58,height:58,color:AppTheme.panelSoft,child:const Icon(Icons.photo_outlined,color:AppTheme.textMuted,size:18)))),
          const Positioned(right:3,bottom:3,child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:15)),
        ]),
      );
    },
  );
}

class _PropertyMediaCard extends StatefulWidget {
  const _PropertyMediaCard({required this.propertyId});
  final String propertyId;
  @override State<_PropertyMediaCard> createState()=>_PropertyMediaCardState();
}

class _PropertyMediaCardState extends State<_PropertyMediaCard>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_load();}

  Future<Map<String,dynamic>> _load()async{
    var bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
    if(bundle['front_available']!=true){
      try{
        final result=await Supabase.instance.client.functions.invoke('bridgepoint-property-street-media-v186',body:{'property_id':widget.propertyId});
        final payload=_edgeFunctionPayload(result.data);
        if(result.status>=200&&result.status<300&&payload['discovered']==true){
          bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
        }
      }catch(_){ }
    }
    bundle=await _bridgePointResolvePrivateMediaBundleV267(bundle);
    try{bundle['_photo_contributions']=await _callRpc('bridgepoint_property_photo_contributions_v266',{'p_property_id':widget.propertyId});}catch(_){bundle['_photo_contributions']=<String,dynamic>{};}
    return bundle;
  }

  void _reload(){if(mounted)setState(()=>request=_load());}
  @override void didUpdateWidget(covariant _PropertyMediaCard oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.propertyId!=widget.propertyId)request=_load();}

  Future<void> _contribute()async{
    final submitted=await showDialog<bool>(context:context,builder:(_)=>_FrontPropertyPhotoDialogV267(propertyId:widget.propertyId));
    if(submitted==true){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Front property photo submitted for BridgePoint review.')));
      _reload();
    }
  }

  Widget _contributionPanel(Map<String,dynamic> contributionData){
    final items=_bpRows(contributionData['items']);
    final yours=items.where((e)=>e['is_yours']==true).toList();
    final latest=yours.isEmpty?<String,dynamic>{}:yours.first;
    final status='${latest['moderation_status']??''}'.toUpperCase();
    final statusColor=switch(status){'PUBLIC'=>AppTheme.green,'PENDING'=>AppTheme.amber,'REJECTED'=>AppTheme.red,'REMOVED'=>AppTheme.red,_=>AppTheme.textMuted};
    final statusText=switch(status){'PUBLIC'=>'Approved • visible to BridgePoint members','PENDING'=>'Submitted • BridgePoint review pending','REJECTED'=>'Needs a different photo','REMOVED'=>'Photo removed',_=>'No photo contribution from you yet'};
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(11),
      decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.06),AppTheme.blue.withOpacity(.035)]),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.cyan.withOpacity(.12))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.add_a_photo_outlined,color:AppTheme.cyan,size:17),const SizedBox(width:7),const Expanded(child:Text('Keep the front photo current',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:statusColor.withOpacity(.09),borderRadius:BorderRadius.circular(99)),child:Text(statusText,style:TextStyle(color:statusColor,fontSize:6.9,fontWeight:FontWeight.w900))) ]),
        const SizedBox(height:5),
        const Text('Take or choose a clear exterior photo. BridgePoint reviews member contributions before they can become the shared front-property reference.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.4)),
        if('${latest['moderation_reason']??''}'.trim().isNotEmpty)...[const SizedBox(height:5),Text('Review note: ${latest['moderation_reason']}',style:const TextStyle(color:AppTheme.red,fontSize:8.1,height:1.35))],
        const SizedBox(height:8),
        OutlinedButton.icon(onPressed:_contribute,icon:const Icon(Icons.photo_camera_rounded,size:16),label:Text(yours.isEmpty?'Add front photo':'Add / update front photo')),
      ]),
    );
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData){
        return Container(height:190,alignment:Alignment.center,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:const CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:2));
      }
      if(snapshot.hasError){
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const _PropertyMediaMissing(message:'Property photo not available yet'),const SizedBox(height:8),_contributionPanel(const <String,dynamic>{})]);
      }

      final data=snapshot.data??const <String,dynamic>{};
      final contributionData=_bpMap(data['_photo_contributions']);
      final primary=_bpMap(data['primary']);
      final aerialCurrent=_bpMap(data['aerial_current']);
      final aerialUrl='${aerialCurrent['media_url']??''}'.trim();
      final mediaType='${primary['media_type']??''}'.toUpperCase();
      final url='${primary['media_url']??''}'.trim();
      if(url.isEmpty){
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _PropertyMediaMissing(message:'${data['display_message']??'Property photo not available yet'}'),
          const SizedBox(height:8),_contributionPanel(contributionData),
        ]);
      }

      final fallback='${data['fallback_kind']??''}'=='AERIAL';
      final label='${primary['display_label']??(mediaType=='AERIAL'?'Aerial View':mediaType=='STREET_VIEW'?'Street-Level Property View':'Property Photo')}';
      final source='${primary['source_name']??primary['provider']??'BridgePoint property media'}';
      final isStreet=mediaType=='STREET_VIEW';
      final isCommunity=mediaType=='COMMUNITY_PHOTO';
      final captured=primary['captured_at']==null&&primary['observed_at']==null?'Date not available':_bpDateTime(primary['captured_at']??primary['observed_at']);
      final aerialHistory=_bpRows(data['aerial_history']);

      return Container(width:double.infinity,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.13))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Stack(children:[
          SizedBox(width:double.infinity,height:260,child:Image.network(url,fit:BoxFit.cover,errorBuilder:(context,error,stackTrace)=>const _PropertyMediaMissing(message:'Property photo not available yet',compact:true))),
          Positioned.fill(child:Material(color:Colors.transparent,child:InkWell(onTap:()=>_showZoomablePropertyImage(context,url,title:label,subtitle:'$source • $captured'),child:const Align(alignment:Alignment.bottomRight,child:Padding(padding:EdgeInsets.all(10),child:CircleAvatar(radius:17,backgroundColor:Colors.black54,child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:19)))))),
          Positioned(left:10,top:10,child:_OpportunityChip(label:label.toUpperCase(),color:fallback?AppTheme.blue:isCommunity?AppTheme.cyan:AppTheme.green)),
          if(isCommunity)const Positioned(right:10,top:10,child:_OpportunityChip(label:'MEMBER CONTRIBUTED • REVIEWED',color:AppTheme.cyan)),
        ]),
        Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(source,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:3),
          Text('$captured${fallback?' • automatic aerial fallback':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
          if(isCommunity)...[const SizedBox(height:5),const Text('BridgePoint member contribution • approved for member display. Treat it as a visual reference, not proof of damage, cause, claim status, or repair need.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))],
          if(isStreet)...[const SizedBox(height:5),Text('Street-level reference • $source. BridgePoint selected a nearby public camera frame facing toward the parcel; verify the structure before relying on it as field evidence.',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))],
          if(fallback)...[const SizedBox(height:5),const Text('BridgePoint did not find a higher-priority displayable exterior or field photo, so it is showing the authoritative aerial reference instead.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))],
          if(aerialUrl.isNotEmpty&&aerialUrl!=url)...[const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>_showZoomablePropertyImage(context,aerialUrl,title:'Current Aerial View',subtitle:'${aerialCurrent['source_name']??aerialCurrent['provider']??'Authoritative aerial source'}'),icon:const Icon(Icons.satellite_alt_outlined,size:16),label:const Text('Open aerial • pinch / scroll to zoom'))],
          if(aerialHistory.length>1)...[const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>_showPropertyImageHistory(context,aerialHistory),icon:const Icon(Icons.history_rounded,size:16),label:Text('Image history • ${aerialHistory.length} dates'))],
          const SizedBox(height:10),_contributionPanel(contributionData),
        ])),
      ]));
    },
  );
}

'''
body=body[:start]+replacement+body[end:]
body += "\nconst String _bridgePointFrontPropertyPhotoV267='bridgepoint-v267-front-property-photo | bridgepoint_submit_property_photo_v266 | Add / update front photo | Submit for BridgePoint review';\n"
main.write_text(body,encoding='utf-8')
print('Applied private moderated front property photo contribution UX v267.')
