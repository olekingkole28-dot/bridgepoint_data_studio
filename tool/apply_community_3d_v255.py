from pathlib import Path

main=Path('lib/main.dart')
body=main.read_text(encoding='utf-8')
marker='bridgepoint-v255-community-3d'
if marker in body:
    print('v255 already applied')
    raise SystemExit(0)

pubspec=Path('pubspec.yaml')
yaml=pubspec.read_text(encoding='utf-8')
if '  maplibre_gl:' not in yaml:
    dep_anchor='  latlong2: ^0.9.1\n'
    if dep_anchor not in yaml: raise SystemExit('v255 pubspec dependency anchor missing')
    yaml=yaml.replace(dep_anchor,dep_anchor+'  maplibre_gl: ^0.26.2\n',1)
    pubspec.write_text(yaml,encoding='utf-8')

web=Path('web/index.html')
html=web.read_text(encoding='utf-8')
if 'maplibre-gl@^5.24.0' not in html:
    head='</head>'
    if head not in html: raise SystemExit('v255 web head anchor missing')
    html=html.replace(head,"  <link href='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.css' rel='stylesheet'>\n  <script src='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.js'></script>\n</head>",1)
    web.write_text(html,encoding='utf-8')

imp="import 'package:latlong2/latlong.dart';\n"
if body.count(imp)!=1: raise SystemExit(f'v255 import anchor {body.count(imp)}')
body=body.replace(imp,imp+"import 'package:maplibre_gl/maplibre_gl.dart' as ml;\n",1)

anchor='class _CommunityMapAndChatV212 extends StatefulWidget'
if body.count(anchor)!=1: raise SystemExit(f'v255 community anchor {body.count(anchor)}')
widget=r'''
class _Community3DMapV255 extends StatefulWidget{
  const _Community3DMapV255();
  @override State<_Community3DMapV255> createState()=>_Community3DMapV255State();
}

class _Community3DMapV255State extends State<_Community3DMapV255>{
  static const _style='https://tiles.openfreemap.org/styles/liberty';
  ml.MapLibreMapController? controller;
  bool styleReady=false,loading=false,buildingsVisible=true,clustersVisible=true,precisionVisible=true;
  int precisionBuildings=0,clusterCount=0;
  String coverage='U.S. 3D BUILDINGS';
  String? error;
  Timer? debounce;
  ml.CameraPosition camera=const ml.CameraPosition(target:ml.LatLng(41.5623,-72.6506),zoom:15.2,tilt:58,bearing:-18);
  int requestSerial=0;

  @override void dispose(){debounce?.cancel();super.dispose();}

  Future<void> _styleLoaded()async{
    final c=controller;if(c==null)return;
    try{
      await c.addSource('bp-national-buildings',const ml.VectorSourceProperties(
        url:'https://tiles.openfreemap.org/planet',
        attribution:'OpenFreeMap © OpenMapTiles • Data © OpenStreetMap contributors',
      ));
      await c.addFillExtrusionLayer(
        'bp-national-buildings','bp-national-buildings-3d',
        const ml.FillExtrusionLayerProperties(
          fillExtrusionColor:['interpolate',['linear'],['get','render_height'],0,'#25384B',45,'#2D7088',120,'#35D2E8',260,'#7B8DFF'],
          fillExtrusionHeight:['interpolate',['linear'],['zoom'],13.5,0,15,['get','render_height']],
          fillExtrusionBase:['case',['>=',['zoom'],15],['get','render_min_height'],0],
          fillExtrusionOpacity:.78,
          fillExtrusionVerticalGradient:true,
        ),
        sourceLayer:'building',minzoom:13.0,
        filter:['!=',['get','hide_3d'],true],
      );
      await c.addGeoJsonSource('bp-ct-precision',const {'type':'FeatureCollection','features':[]});
      await c.addFillExtrusionLayer('bp-ct-precision','bp-ct-precision-3d',
        const ml.FillExtrusionLayerProperties(
          fillExtrusionColor:['interpolate',['linear'],['get','height_m'],0,'#38D49A',25,'#35D2E8',65,'#4F7CFF',140,'#9B7BFF'],
          fillExtrusionHeight:['interpolate',['linear'],['zoom'],14,0,15,['get','height_m']],
          fillExtrusionBase:['get','base_m'],
          fillExtrusionOpacity:.86,
          fillExtrusionVerticalGradient:true,
        ),minzoom:13.5);
      await c.addGeoJsonSource('bp-community-clusters',const {'type':'FeatureCollection','features':[]});
      await c.addCircleLayer('bp-community-clusters','bp-community-clusters-glow',
        const ml.CircleLayerProperties(
          circleRadius:['interpolate',['linear'],['get','strength'],0,10,100,27],
          circleColor:['match',['get','state'],'PEAK','#FF6677','EMERGING','#FFC857','RECOVERY','#4F7CFF','HISTORICAL','#718096','#38D49A'],
          circleOpacity:.22,circleBlur:.55,circleStrokeWidth:2,
          circleStrokeColor:['match',['get','state'],'PEAK','#FF6677','EMERGING','#FFC857','RECOVERY','#4F7CFF','HISTORICAL','#718096','#38D49A'],
          circleStrokeOpacity:.88,
        ),minzoom:5);
      if(mounted)setState(()=>styleReady=true);
      unawaited(_refreshViewport());
      unawaited(_centerOnMe(quiet:true));
    }catch(e){if(mounted)setState(()=>error='3D layers could not initialize: $e');}
  }

  void _queueRefresh(){
    debounce?.cancel();debounce=Timer(const Duration(milliseconds:350),(){unawaited(_refreshViewport());});
  }

  Future<void> _refreshViewport()async{
    final c=controller;if(c==null||!styleReady||loading)return;
    final serial=++requestSerial;
    setState(()=>loading=true);
    try{
      final bounds=await c.getVisibleRegion();
      final cp=c.cameraPosition??camera;camera=cp;
      final west=bounds.southwest.longitude,south=bounds.southwest.latitude,east=bounds.northeast.longitude,north=bounds.northeast.latitude;
      final ctIntersects=east>=-73.75&&west<=-71.78&&north>=40.95&&south<=42.10;
      final zoom=cp.zoom;
      final futures=<Future<Map<String,dynamic>>>[
        _callRpc('bridgepoint_live_clusters_v250',{
          'p_model_key':'all','p_west':west,'p_south':south,'p_east':east,'p_north':north,'p_zoom':zoom.round(),'p_limit':180,
        }).catchError((_)=> <String,dynamic>{'clusters':<dynamic>[]}),
        if(ctIntersects&&zoom>=13.5)
          _callRpc('bridgepoint_community_3d_buildings_v241',{'p_west':west,'p_south':south,'p_east':east,'p_north':north,'p_limit':1500})
            .catchError((_)=> <String,dynamic>{'buildings':<dynamic>[]})
        else Future.value(<String,dynamic>{'buildings':<dynamic>[]}),
      ];
      final result=await Future.wait(futures);
      if(serial!=requestSerial)return;
      final clusters=_detailList(result[0]['clusters']);
      final buildings=_detailList(result[1]['buildings']);
      final clusterGeo=<String,dynamic>{'type':'FeatureCollection','features':clusters.map((x)=>{
        'type':'Feature','geometry':{'type':'Point','coordinates':[(x['lng'] as num?)?.toDouble()??0,(x['lat'] as num?)?.toDouble()??0]},
        'properties':{'state':'${x['state']??'ACTIVE'}','strength':(x['cluster_strength'] as num?)?.toDouble()??0,'count':x['property_count']??0,'plain':'${x['plain_language']??''}'},
      }).toList()};
      final buildingGeo=<String,dynamic>{'type':'FeatureCollection','features':buildings.where((x)=>x['geometry'] is Map).map((x)=>{
        'type':'Feature','geometry':x['geometry'],
        'properties':{'height_m':((x['height_m'] as num?)?.toDouble()??8).clamp(2,450),'base_m':0,'source_year':x['source_year'],'property_id':x['property_id']},
      }).toList()};
      await c.setGeoJsonSource('bp-community-clusters',clusterGeo);
      await c.setGeoJsonSource('bp-ct-precision',buildingGeo);
      if(mounted)setState((){
        clusterCount=clusters.length;precisionBuildings=buildings.length;
        coverage=buildings.isNotEmpty?'BRIDGEPOINT CT PRECISION 3D':'U.S. 3D BUILDINGS';error=null;
      });
    }catch(e){if(mounted)setState(()=>error='BridgePoint kept the last good 3D view. Refresh detail failed: $e');}
    finally{if(mounted&&serial==requestSerial)setState(()=>loading=false);}
  }

  Future<void> _centerOnMe({bool quiet=false})async{
    final c=controller;if(c==null)return;
    try{
      Position? p=_BridgePointLiveLocation.position.value;
      if(p==null){
        var permission=await Geolocator.checkPermission();
        if(permission==LocationPermission.denied){
          if(quiet)return;
          permission=await Geolocator.requestPermission();
        }
        if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('Location permission is off. You can still explore the 3D map anywhere.');
        if(!await Geolocator.isLocationServiceEnabled())throw Exception('Turn on Location Services to center the 3D map on you.');
        p=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:8)));
      }
      camera=ml.CameraPosition(target:ml.LatLng(p.latitude,p.longitude),zoom:16.1,tilt:62,bearing:-18);
      await c.animateCamera(ml.CameraUpdate.newCameraPosition(camera),duration:const Duration(milliseconds:650));
      _queueRefresh();
    }catch(e){if(!quiet&&mounted)_showInfoDialog(context,'3D map location',e.toString().replaceFirst('Exception: ',''));}
  }

  Future<void> _reset3d()async{
    final c=controller;if(c==null)return;final cp=c.cameraPosition??camera;
    final next=ml.CameraPosition(target:cp.target,zoom:cp.zoom<14?15.3:cp.zoom,tilt:62,bearing:-18);
    await c.animateCamera(ml.CameraUpdate.newCameraPosition(next),duration:const Duration(milliseconds:500));
  }

  Future<void> _toggleBuildings()async{
    final c=controller;if(c==null)return;final next=!buildingsVisible;
    try{await c.setLayerVisibility('bp-national-buildings-3d',next);await c.setLayerVisibility('bp-ct-precision-3d',next&&precisionVisible);}catch(_){ }
    if(mounted)setState(()=>buildingsVisible=next);
  }
  Future<void> _togglePrecision()async{
    final c=controller;if(c==null)return;final next=!precisionVisible;
    try{await c.setLayerVisibility('bp-ct-precision-3d',next&&buildingsVisible);}catch(_){ }
    if(mounted)setState(()=>precisionVisible=next);
  }
  Future<void> _toggleClusters()async{
    final c=controller;if(c==null)return;final next=!clustersVisible;
    try{await c.setLayerVisibility('bp-community-clusters-glow',next);}catch(_){ }
    if(mounted)setState(()=>clustersVisible=next);
  }

  @override Widget build(BuildContext context){
    final compact=MediaQuery.sizeOf(context).width<700;
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:42,height:42,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(13),boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.16),blurRadius:18)]),child:const Icon(Icons.view_in_ar_rounded,color:Colors.white)),
        const SizedBox(width:10),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('BRIDGEPOINT COMMUNITY 3D',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,letterSpacing:.5)),SizedBox(height:3),Text('Tilt • rotate • zoom • explore buildings and live property activity around you',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.35))])),
        if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)),
      ]),
      const SizedBox(height:9),
      Wrap(spacing:6,runSpacing:6,children:[
        _OpportunityChip(label:coverage,color:precisionBuildings>0?AppTheme.cyan:AppTheme.blue),
        _OpportunityChip(label:'$clusterCount LIVE CLUSTERS',color:AppTheme.green),
        if(precisionBuildings>0)_OpportunityChip(label:'$precisionBuildings CT PRECISION BUILDINGS',color:const Color(0xFF9B7BFF)),
        const _OpportunityChip(label:'OPEN MAP • NO PAID MAP KEY',color:AppTheme.amber),
      ]),
      const SizedBox(height:9),
      Stack(children:[
        SizedBox(height:compact?390:510,child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
          initialCameraPosition:camera,
          trackCameraPosition:true,
          compassEnabled:true,
          rotateGesturesEnabled:true,
          tiltGesturesEnabled:true,
          zoomGesturesEnabled:true,
          scrollGesturesEnabled:true,
          minMaxZoomPreference:const ml.MinMaxZoomPreference(3,20),
          onMapCreated:(c)=>controller=c,
          onStyleLoadedCallback:_styleLoaded,
          onCameraMove:(position)=>camera=position,
          onCameraIdle:_queueRefresh,
        ))),
        Positioned(top:10,right:10,child:Column(children:[
          _Community3DControlV255(icon:Icons.my_location_rounded,tooltip:'Center on my location',active:true,onTap:()=>_centerOnMe()),
          const SizedBox(height:6),_Community3DControlV255(icon:Icons.threed_rotation_rounded,tooltip:'Reset 3D angle',active:true,onTap:_reset3d),
          const SizedBox(height:6),_Community3DControlV255(icon:Icons.apartment_rounded,tooltip:'3D buildings',active:buildingsVisible,onTap:_toggleBuildings),
          const SizedBox(height:6),_Community3DControlV255(icon:Icons.verified_rounded,tooltip:'BridgePoint precision buildings',active:precisionVisible,onTap:_togglePrecision),
          const SizedBox(height:6),_Community3DControlV255(icon:Icons.blur_on_rounded,tooltip:'Live opportunity clusters',active:clustersVisible,onTap:_toggleClusters),
        ])),
        Positioned(left:10,bottom:10,right:10,child:IgnorePointer(child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xD907111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white12)),child:Row(children:[const Icon(Icons.touch_app_rounded,color:AppTheme.cyan,size:15),const SizedBox(width:6),Expanded(child:Text(compact?'Drag • pinch • rotate • two-finger tilt':'Drag to move • scroll/pinch to zoom • rotate • tilt the camera • live layers refresh when you stop moving',style:const TextStyle(color:Colors.white70,fontSize:8,fontWeight:FontWeight.w700)))])))),
      ]),
      if(error!=null)...[const SizedBox(height:7),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:8.5,height:1.35))],
      const SizedBox(height:7),const Text('Nationwide 3D buildings use OpenStreetMap-derived OpenFreeMap geometry/height where available. Connecticut automatically adds BridgePoint’s 2023 state building-height layer when you zoom into supported areas. Building shape or height can still be incomplete; BridgePoint keeps source provenance separate from property conclusions.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.3,height:1.4)),
    ])));
  }
}

class _Community3DControlV255 extends StatelessWidget{
  const _Community3DControlV255({required this.icon,required this.tooltip,required this.active,required this.onTap});
  final IconData icon;final String tooltip;final bool active;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Tooltip(message:tooltip,child:Material(color:const Color(0xE90B1727),borderRadius:BorderRadius.circular(10),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(10),child:Container(width:38,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),border:Border.all(color:active?AppTheme.cyan.withOpacity(.35):Colors.white12)),child:Icon(icon,size:18,color:active?AppTheme.cyan:AppTheme.textMuted)))));
}

'''
body=body.replace(anchor,widget+anchor,1)

method_anchor="""  Future<void> post()async{final text=message.text.trim();if(text.isEmpty||channel==null)return;setState(()=>busy=true);try{final r=await _callRpc('bridgepoint_post_community_message_v212',{'p_channel_key':channel,'p_body':text});if(r['blocked']==true){if(mounted)_showInfoDialog(context,'Message not posted','${r['message']}');}else{message.clear();await loadMessages(channel!);}}catch(e){if(mounted)_showInfoDialog(context,'Could not post message','$e');}finally{if(mounted)setState(()=>busy=false);}}
"""
if body.count(method_anchor)!=1: raise SystemExit(f'v255 post method anchor {body.count(method_anchor)}')
method_add=method_anchor+"""  Future<void> reportMessage(Map<String,dynamic> item)async{final id='${item['message_id']??''}';if(id.isEmpty)return;try{final r=await _callRpc('bridgepoint_report_community_message_v212',{'p_message_id':id});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${r['message']??'Thanks. BridgePoint sent this to the owner moderation queue.'}')));}catch(e){if(mounted)_showInfoDialog(context,'Could not report message','$e');}}
"""
body=body.replace(method_anchor,method_add,1)

build_anchor="""  @override Widget build(BuildContext context)=>Column(children:[
    FutureBuilder<Map<String,dynamic>>(future:mapRequest"""
if body.count(build_anchor)!=1: raise SystemExit(f'v255 community build anchor {body.count(build_anchor)}')
body=body.replace(build_anchor,"""  @override Widget build(BuildContext context)=>Column(children:[
    const _Community3DMapV255(),
    const SizedBox(height:10),
    FutureBuilder<Map<String,dynamic>>(future:mapRequest""",1)

old="""const _PanelHeader(title:'BridgePoint Community Chat',subtitle:'Package-based channels • moderated • customer connection without sacrificing trust',action:'Connected intelligence'),const SizedBox(height:7),Text(rules"""
if body.count(old)!=1: raise SystemExit(f'v255 chat header anchor {body.count(old)}')
new="""const _PanelHeader(title:'BridgePoint Community Chat',subtitle:'Visible to signed-in BridgePoint members with access to this channel • automatically moderated',action:'Member-visible'),const SizedBox(height:7),Container(width:double.infinity,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.06),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.blue.withOpacity(.14))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.groups_rounded,color:AppTheme.blue,size:16),SizedBox(width:7),Expanded(child:Text('Community chat is not private property memory. Messages here can be seen by other signed-in BridgePoint members who can access this channel. Do not post private occupant, financial, claim, access-code or other sensitive information. Unsafe content is blocked server-side and reports go to BridgePoint owners.',style:TextStyle(color:Colors.white70,fontSize:8.7,height:1.4))) ])),const SizedBox(height:7),Text(rules"""
body=body.replace(old,new,1)

old="""Row(children:[Expanded(child:Text('${m['display_name']??'BridgePoint member'}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text(_bpDateTime(m['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5))])"""
if body.count(old)!=1: raise SystemExit(f'v255 message row anchor {body.count(old)}')
new="""Row(children:[Expanded(child:Text('${m['display_name']??'BridgePoint member'}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text(_bpDateTime(m['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5)),const SizedBox(width:3),SizedBox(width:28,height:28,child:IconButton(padding:EdgeInsets.zero,tooltip:'Report message',onPressed:()=>reportMessage(m),icon:const Icon(Icons.flag_outlined,size:14,color:AppTheme.textMuted)))])"""
body=body.replace(old,new,1)

body += "\nconst String _bridgePointCommunity3dV255='bridgepoint-v255-community-3d | BRIDGEPOINT COMMUNITY 3D | U.S. 3D BUILDINGS | CT PRECISION BUILDINGS | Member-visible';\n"
main.write_text(body,encoding='utf-8')
print('Applied nationwide Community 3D and member-visible moderated chat v255.')
