from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v253-live-clusters-ui'
if marker in body:
    print('v253 already applied')
    raise SystemExit(0)

old="""  bool _showRadar=true;
  bool _showClouds=false;
"""
new="""  bool _showRadar=true;
  bool _showClusters=true;
  bool _showClouds=false;
"""
if body.count(old)!=1: raise SystemExit(f'v253 field anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""    final signalBody={
      'p_min_lat':showPropertyIntelligence?bounds?.southWest.latitude:null,
      'p_max_lat':showPropertyIntelligence?bounds?.northEast.latitude:null,
      'p_min_lng':showPropertyIntelligence?bounds?.southWest.longitude:null,
      'p_max_lng':showPropertyIntelligence?bounds?.northEast.longitude:null,
      'p_limit':signalLimit,
    };
    final results=await Future.wait<Object>([
"""
new="""    final signalBody={
      'p_min_lat':showPropertyIntelligence?bounds?.southWest.latitude:null,
      'p_max_lat':showPropertyIntelligence?bounds?.northEast.latitude:null,
      'p_min_lng':showPropertyIntelligence?bounds?.southWest.longitude:null,
      'p_max_lng':showPropertyIntelligence?bounds?.northEast.longitude:null,
      'p_limit':signalLimit,
    };
    final clusterBody={
      'p_model_key':widget.modelKey,
      'p_west':bounds?.southWest.longitude??-180.0,
      'p_south':bounds?.southWest.latitude??-85.0,
      'p_east':bounds?.northEast.longitude??180.0,
      'p_north':bounds?.northEast.latitude??85.0,
      'p_zoom':_viewportZoom.round(),
      'p_limit':_compactMapV218?120:220,
    };
    final results=await Future.wait<Object>([
"""
if body.count(old)!=1: raise SystemExit(f'v253 request anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""      showPropertyIntelligence
        ? _callRpc('bridgepoint_flutter_signal_map_v80',signalBody).catchError((_)=> <String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'signal_type_count':0,'fallback':true})
        : Future.value(<String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'map_mode':'WEATHER_OVERVIEW'}),
    ]);
"""
new="""      showPropertyIntelligence
        ? _callRpc('bridgepoint_flutter_signal_map_v80',signalBody).catchError((_)=> <String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'signal_type_count':0,'fallback':true})
        : Future.value(<String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'map_mode':'WEATHER_OVERVIEW'}),
      _showClusters&&_viewportZoom>=4.0
        ? _callRpc('bridgepoint_live_clusters_v250',clusterBody).catchError((_)=> <String,dynamic>{'complete':true,'clusters':<dynamic>[],'fallback':true})
        : Future.value(<String,dynamic>{'complete':true,'clusters':<dynamic>[],'disabled':true}),
    ]);
"""
if body.count(old)!=1: raise SystemExit(f'v253 Future.wait anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""      'coverage_catalog':results[1],
      'signal_map':results[2],
    };
"""
new="""      'coverage_catalog':results[1],
      'signal_map':results[2],
      'live_clusters':results[3],
    };
"""
if body.count(old)!=1: raise SystemExit(f'v253 response anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""        final signalPoints=signalRaw is List
            ?signalRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList()
            :<Map<String,dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
"""
new="""        final signalPoints=signalRaw is List
            ?signalRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList()
            :<Map<String,dynamic>>[];
        final liveClusterMap=data?['live_clusters'] is Map?Map<String,dynamic>.from(data!['live_clusters'] as Map):<String,dynamic>{};
        final liveClusters=_detailList(liveClusterMap['clusters']);
        final loading = snapshot.connectionState == ConnectionState.waiting;
"""
if body.count(old)!=1: raise SystemExit(f'v253 cluster parse anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""        final markers = <Marker>[];
        if(_visibleLayer!='signals')for (final point in visibleOpportunityPoints) {
"""
new="""        final markers = <Marker>[];
        if(_showClusters)for(final cluster in liveClusters.take(_compactMapV218?90:180)){
          final lat=(cluster['lat'] as num?)?.toDouble(),lng=(cluster['lng'] as num?)?.toDouble();
          if(lat==null||lng==null)continue;
          final count=(cluster['property_count'] as num?)?.toInt()??0;
          final strength=(cluster['cluster_strength'] as num?)?.toDouble()??0;
          final state='${cluster['state']??'ACTIVE'}';
          final color=switch(state){'PEAK'=>AppTheme.red,'EMERGING'=>AppTheme.amber,'RECOVERY'=>AppTheme.blue,'HISTORICAL'=>AppTheme.textMuted,_=>AppTheme.green};
          final size=(34.0+(count.clamp(1,30)*1.05)+(strength/100*10)).clamp(38.0,72.0);
          markers.add(Marker(point:LatLng(lat,lng),width:size,height:size,child:Tooltip(
            message:'${cluster['plain_language']??'$count opportunities'}',
            child:Container(
              alignment:Alignment.center,
              decoration:BoxDecoration(shape:BoxShape.circle,color:color.withOpacity(.16),border:Border.all(color:color.withOpacity(.86),width:2),boxShadow:[BoxShadow(color:color.withOpacity(.18),blurRadius:12,spreadRadius:2)]),
              child:Column(mainAxisSize:MainAxisSize.min,children:[Text('$count',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)),Text(state,style:TextStyle(color:color,fontSize:5.8,fontWeight:FontWeight.w900,letterSpacing:.35))]),
            ),
          )));
        }
        if(_visibleLayer!='signals')for (final point in visibleOpportunityPoints) {
"""
if body.count(old)!=1: raise SystemExit(f'v253 marker anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""                    const SizedBox(width:8),
                    PopupMenuButton<double?>(
                      tooltip: 'Minimum opportunity score',
"""
new="""                    const SizedBox(width:7),
                    FilterChip(
                      selected:_showClusters,
                      showCheckmark:false,
                      avatar:Icon(Icons.blur_on_rounded,size:15,color:_showClusters?AppTheme.green:AppTheme.textMuted),
                      label:Text(_showClusters?'Live clusters':'Clusters',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
                      onSelected:(value){setState(()=>_showClusters=value);_reload();},
                      side:BorderSide(color:_showClusters?AppTheme.green.withOpacity(.30):Colors.white12),
                      backgroundColor:AppTheme.panelSoft,
                      selectedColor:AppTheme.green.withOpacity(.10),
                    ),
                    const SizedBox(width:8),
                    PopupMenuButton<double?>(
                      tooltip: 'Minimum opportunity score',
"""
if body.count(old)!=1: raise SystemExit(f'v253 cluster toggle anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""                    const SizedBox(width:12),
                    PopupMenuButton<String>(tooltip:'Choose visible intelligence',onSelected:(value)=>setState(()=>_visibleLayer=value),itemBuilder:(context)=>const [
"""
new="""                    const SizedBox(width:12),
                    if(_showClusters&&liveClusters.isNotEmpty)Container(
                      padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                      decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.green.withOpacity(.18))),
                      child:Text('${liveClusters.length} LIVE CLUSTERS',style:const TextStyle(color:AppTheme.green,fontSize:7.5,fontWeight:FontWeight.w900,letterSpacing:.4)),
                    ),
                    if(_showClusters&&liveClusters.isNotEmpty)const SizedBox(width:8),
                    PopupMenuButton<String>(tooltip:'Choose visible intelligence',onSelected:(value)=>setState(()=>_visibleLayer=value),itemBuilder:(context)=>const [
"""
if body.count(old)!=1: raise SystemExit(f'v253 cluster count anchor {body.count(old)}')
body=body.replace(old,new,1)

body += "\nconst String _bridgePointLiveClustersUiV253='bridgepoint-v253-live-clusters-ui | EMERGING | ACTIVE | PEAK | RECOVERY | HISTORICAL';\n"
path.write_text(body,encoding='utf-8')
print('Applied live calibrated opportunity clusters UI v253.')
