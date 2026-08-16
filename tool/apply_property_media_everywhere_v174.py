from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

marker='class _PropertyMediaCard extends StatefulWidget'
if marker not in text:raise SystemExit('property media card marker missing')

# Replace historical-image browser first so later helper insertion is not overwritten.
hs=text.find('Future<void> _showPropertyImageHistory(')
he=text.find('class _PropertyMediaCard',hs)
if hs>=0 and he>hs:
    fn=r'''Future<void> _showPropertyImageHistory(BuildContext context,List<Map<String,dynamic>> history)async{
  await showDialog<void>(context:context,builder:(d)=>Dialog(
    backgroundColor:AppTheme.panel,
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:980,maxHeight:790),child:Padding(
      padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.history_rounded,color:AppTheme.cyan),const SizedBox(width:8),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Property Image History',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
            SizedBox(height:3),Text('Tap any dated image to open the full zoomable aerial view.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)),
          ])),
          IconButton(onPressed:()=>Navigator.pop(d),icon:const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height:12),
        Expanded(child:GridView.builder(
          gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:430,childAspectRatio:1.25,crossAxisSpacing:10,mainAxisSpacing:10),
          itemCount:history.length,
          itemBuilder:(context,index){
            final item=history[index];
            final thumb='${item['thumbnail_url']??item['media_url']??''}';
            final full='${item['media_url']??thumb}';
            final year='${item['captured_year']??'Unknown date'}';
            final source='${item['source_name']??'Source imagery'}';
            return InkWell(
              borderRadius:BorderRadius.circular(12),
              onTap:full.isEmpty?null:()=>_showZoomablePropertyImage(context,full,title:'$year Aerial',subtitle:source),
              child:Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Expanded(child:Stack(fit:StackFit.expand,children:[
                  thumb.isEmpty?const _PropertyMediaMissing(message:'Image not available',compact:true):Image.network(thumb,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const _PropertyMediaMissing(message:'Image not available',compact:true)),
                  if(full.isNotEmpty)const Positioned(right:8,top:8,child:CircleAvatar(radius:14,backgroundColor:Colors.black54,child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:17))),
                ])),
                Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('$year Aerial',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:2),
                  Text(source,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                ])),
              ])),
            );
          },
        )),
      ]),
    )),
  ));
}

'''
    text=text[:hs]+fn+text[he:]

# Add reusable zoom viewer and lean Properties-list thumbnail after history replacement.
marker='class _PropertyMediaCard extends StatefulWidget'
helpers=r'''
Future<void> _showZoomablePropertyImage(BuildContext context,String url,{String title='Property Image',String? subtitle})async{
  if(url.trim().isEmpty)return;
  await showDialog<void>(context:context,builder:(d)=>Dialog(
    backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(12),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1180,maxHeight:900),child:Padding(
      padding:const EdgeInsets.all(14),child:Column(children:[
        Row(children:[
          const Icon(Icons.zoom_in_map_rounded,color:AppTheme.cyan),const SizedBox(width:8),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
            if(subtitle!=null&&subtitle!.isNotEmpty)Text(subtitle!,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
          ])),
          const Text('PINCH / SCROLL TO ZOOM',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5,fontWeight:FontWeight.w800)),
          IconButton(onPressed:()=>Navigator.pop(d),icon:const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height:8),
        Expanded(child:ClipRect(child:InteractiveViewer(
          minScale:.7,maxScale:10,boundaryMargin:const EdgeInsets.all(220),
          child:Center(child:Image.network(url,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const _PropertyMediaMissing(message:'Property photo not available yet',compact:true))),
        ))),
      ]),
    )),
  ));
}

class _PropertyMediaThumb extends StatefulWidget{
  const _PropertyMediaThumb({required this.propertyId});final String propertyId;
  @override State<_PropertyMediaThumb> createState()=>_PropertyMediaThumbState();
}
class _PropertyMediaThumbState extends State<_PropertyMediaThumb>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=widget.propertyId.isEmpty?Future.value(<String,dynamic>{}):_callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});}
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

'''
if marker not in text:raise SystemExit('property media card missing after history replacement')
text=text.replace(marker,helpers+marker,1)

# Primary media is tap-to-zoom.
cs=text.find('class _PropertyMediaCard extends StatefulWidget')
ce=text.find('class _PropertyMediaMissing',cs)
if cs<0 or ce<0:raise SystemExit('property media implementation missing')
card=text[cs:ce]
chip='''                  Positioned(
                    left: 10,
                    top: 10,
'''
pos=card.find(chip)
if pos<0:raise SystemExit('property media chip marker missing')
overlay=r'''                  Positioned.fill(
                    child:Material(color:Colors.transparent,child:InkWell(
                      onTap:()=>_showZoomablePropertyImage(context,url,title:label,subtitle:'$source • $captured'),
                      child:const Align(alignment:Alignment.bottomRight,child:Padding(
                        padding:EdgeInsets.all(10),child:CircleAvatar(radius:17,backgroundColor:Colors.black54,child:Icon(Icons.zoom_in_rounded,color:Colors.white,size:19)),
                      )),
                    )),
                  ),
'''
card=card[:pos]+overlay+card[pos:]
text=text[:cs]+card+text[ce:]

# Properties list now shows a real/lawful photo or aerial thumbnail.
old=r'''            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: AppTheme.cyan,
                size: 20,
              ),
            ),
'''
if old not in text:raise SystemExit('property list icon marker missing')
text=text.replace(old,"            _PropertyMediaThumb(propertyId:'${property['property_id']??''}'),\n",1)

# Full Properties detail gets photo/aerial + image history just like Opportunities.
ps=text.find('class _PropertyIntelligenceDialogState')
pe=text.find('List<Map<String, dynamic>> _detailList',ps)
if ps<0 or pe<0:raise SystemExit('property detail block missing')
block=text[ps:pe]
children='''                      children: [
                        Wrap(
'''
if children not in block:raise SystemExit('property detail content marker missing')
block=block.replace(children,'''                      children: [
                        _PropertyMediaCard(propertyId:widget.propertyId),
                        const SizedBox(height:16),
                        Wrap(
''',1)
text=text[:ps]+block+text[pe:]

# Homeowner image also opens the same zoom viewer.
home="child:Image.network('${primary['media_url']}',width:wide?280:double.infinity,height:190,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const _HomePhotoMissing()),"
if home in text:
    text=text.replace(home,"""child:GestureDetector(
                      onTap:()=>_showZoomablePropertyImage(context,'${primary['media_url']}',title:'${passport['home_name']??'My Home'}',subtitle:'${home['address']??''}'),
                      child:Image.network('${primary['media_url']}',width:wide?280:double.infinity,height:190,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const _HomePhotoMissing()),
                    ),""",1)

for needle in ['_PropertyMediaThumb(propertyId:', 'PINCH / SCROLL TO ZOOM','Tap any dated image to open the full zoomable aerial view.']:
    if needle not in text:raise SystemExit(f'missing media marker: {needle}')
if text==original:raise SystemExit('no property media changes applied')
path.write_text(text,encoding='utf-8')
print('Applied property media everywhere + zoom v174')
