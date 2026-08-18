from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v306-live-density-heat'
if marker in body:
    print('v306 already applied')
    raise SystemExit(0)

replacements=[
("""  bool _showRadar=true;
  bool _showClusters=true;
  bool _showClouds=true;
""","""  bool _showRadar=true;
  bool _showClusters=true;
  bool _showHeatmap=!_displayPreferences.value.simplifiedViews;
  bool _showClouds=true;
"""),
("""      _showClusters&&_viewportZoom>=4.0
        ? _callRpc('bridgepoint_live_clusters_v250',clusterBody).catchError((_)=> <String,dynamic>{'complete':true,'clusters':<dynamic>[],'fallback':true})
""","""      (_showClusters||_showHeatmap)&&_viewportZoom>=4.0
        ? _callRpc('bridgepoint_live_clusters_v250',clusterBody).catchError((_)=> <String,dynamic>{'complete':true,'clusters':<dynamic>[],'fallback':true})
"""),
("""        final markers = <Marker>[];
        if(_showClusters)for(final cluster in liveClusters.take(_compactMapV218?90:180)){
""","""        final markers = <Marker>[];
        final heatMarkers=<Marker>[];
        if(_showHeatmap)for(final cluster in liveClusters.take(_compactMapV218?90:180)){
          final lat=(cluster['lat'] as num?)?.toDouble(),lng=(cluster['lng'] as num?)?.toDouble();
          if(lat==null||lng==null)continue;
          final count=(cluster['property_count'] as num?)?.toDouble()??1;
          final strength=(cluster['cluster_strength'] as num?)?.toDouble()??0;
          final state='${cluster['state']??'ACTIVE'}';
          final color=switch(state){'PEAK'=>AppTheme.red,'EMERGING'=>AppTheme.amber,'RECOVERY'=>AppTheme.blue,'HISTORICAL'=>AppTheme.textMuted,_=>AppTheme.green};
          final intensity=((strength.clamp(0,100)/100)*.08+(count.clamp(1,40)/40)*.07+.035).clamp(.045,.18).toDouble();
          final size=(70.0+count.clamp(1,40)*1.7+strength.clamp(0,100)*.45).clamp(76.0,190.0).toDouble();
          heatMarkers.add(Marker(point:LatLng(lat,lng),width:size,height:size,child:IgnorePointer(child:Container(
            decoration:BoxDecoration(shape:BoxShape.circle,color:color.withOpacity(intensity),boxShadow:[
              BoxShadow(color:color.withOpacity(intensity*.80),blurRadius:28,spreadRadius:14),
              BoxShadow(color:color.withOpacity(intensity*.42),blurRadius:52,spreadRadius:26),
            ]),
          ))));
        }
        if(_showClusters)for(final cluster in liveClusters.take(_compactMapV218?90:180)){
"""),
("""                     if(_showClusters&&liveClusters.isNotEmpty)const SizedBox(width:8),
                     PopupMenuButton<String>(tooltip:'Choose visible intelligence',onSelected:(value)=>setState(()=>_visibleLayer=value),itemBuilder:(context)=>const [
""","""                     if(_showClusters&&liveClusters.isNotEmpty)const SizedBox(width:8),
                     if(_showHeatmap&&heatMarkers.isNotEmpty)Container(
                       padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                       decoration:BoxDecoration(color:AppTheme.red.withOpacity(.06),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.red.withOpacity(.18))),
                       child:const Text('DENSITY HEAT',style:TextStyle(color:AppTheme.red,fontSize:7.5,fontWeight:FontWeight.w900,letterSpacing:.4)),
                     ),
                     if(_showHeatmap&&heatMarkers.isNotEmpty)const SizedBox(width:8),
                     PopupMenuButton<String>(tooltip:'Choose visible intelligence',onSelected:(value)=>setState(()=>_visibleLayer=value),itemBuilder:(context)=>const [
"""),
("""                     FilterChip(
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
""","""                     FilterChip(
                       selected:_showClusters,
                       showCheckmark:false,
                       avatar:Icon(Icons.blur_on_rounded,size:15,color:_showClusters?AppTheme.green:AppTheme.textMuted),
                       label:Text(_showClusters?'Live clusters':'Clusters',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
                       onSelected:(value){setState(()=>_showClusters=value);_reload();},
                       side:BorderSide(color:_showClusters?AppTheme.green.withOpacity(.30):Colors.white12),
                       backgroundColor:AppTheme.panelSoft,
                       selectedColor:AppTheme.green.withOpacity(.10),
                     ),
                     const SizedBox(width:7),
                     FilterChip(
                       selected:_showHeatmap,
                       showCheckmark:false,
                       avatar:Icon(Icons.local_fire_department_rounded,size:15,color:_showHeatmap?AppTheme.red:AppTheme.textMuted),
                       label:Text(_showHeatmap?'Density heat':'Heat',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
                       onSelected:(value){setState(()=>_showHeatmap=value);_reload();},
                       side:BorderSide(color:_showHeatmap?AppTheme.red.withOpacity(.30):Colors.white12),
                       backgroundColor:AppTheme.panelSoft,
                       selectedColor:AppTheme.red.withOpacity(.08),
                     ),
                     const SizedBox(width:8),
                     PopupMenuButton<double?>(
"""),
("""                           if(_displayPreferences.value.mapBaseStyle=='satellite')TileLayer(urlTemplate:_bridgePointLabelMapUrl(),userAgentPackageName:'com.bridgepoint.data_studio'),
                           MarkerLayer(markers: markers),
""","""                           if(_displayPreferences.value.mapBaseStyle=='satellite')TileLayer(urlTemplate:_bridgePointLabelMapUrl(),userAgentPackageName:'com.bridgepoint.data_studio'),
                           if(_showHeatmap&&heatMarkers.isNotEmpty)MarkerLayer(markers:heatMarkers),
                           MarkerLayer(markers: markers),
"""),
]

for old,new in replacements:
    count=body.count(old)
    if count!=1:
        raise SystemExit(f'v306 anchor count {count}: {old[:90]!r}')
    body=body.replace(old,new,1)

body += "\nconst String _bridgePointLiveDensityHeatV306='bridgepoint-v306-live-density-heat | live package-aware density glow | cluster-derived | toggleable | lightweight marker underlay';\n"
path.write_text(body,encoding='utf-8')
print('Applied v306 live density heat layer.')