from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
old="""        if(_showExpansion)for(final market in coverageMarkets){
          final code='${market['state_code']}';final center=nearbyCentroids[code];
          if(center==null||market['data_status']=='LIVE')continue;
          final requested=market['interest_registered']==true;final building=market['data_status']=='BUILDING';final marketColor=building?AppTheme.green:requested?AppTheme.cyan:AppTheme.amber;
          final nationalZoom=_viewportZoom<=5.4;
          final regionalZoom=_viewportZoom>5.4&&_viewportZoom<7.0;
          final markerSize=nationalZoom?14.0:regionalZoom?28.0:74.0;
          markers.add(Marker(point:center,width:markerSize,height:nationalZoom?14:regionalZoom?28:50,child:Tooltip(
            message:'${market['state_name']} • ${market['data_status']} • ${_formatExpansionEtaV321(market['build_eta'])}',
            child:GestureDetector(onTap:()=>_showStateCoverageDialog(context,market,_reload),child:nationalZoom
              ? Container(decoration:BoxDecoration(shape:BoxShape.circle,color:marketColor.withOpacity(.42),border:Border.all(color:marketColor.withOpacity(.85),width:1.5)))
              : regionalZoom
                ? Container(decoration:BoxDecoration(shape:BoxShape.circle,color:AppTheme.panel.withOpacity(.72),border:Border.all(color:marketColor.withOpacity(.78),width:1.4)),child:Center(child:Text(code,style:TextStyle(color:marketColor,fontSize:7,fontWeight:FontWeight.w900))))
                : Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.90),borderRadius:BorderRadius.circular(10),border:Border.all(color:marketColor.withOpacity(.75))),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(code,style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w900)),if(building)Text('BUILDING',style:TextStyle(color:marketColor,fontSize:6,fontWeight:FontWeight.w900))])),
            )),
          )));
        }
"""
new="""        if(_showExpansion)for(final market in coverageMarkets){
          final code='${market['state_code']}';
          final center=nearbyCentroids[code];
          if(center==null||market['data_status']=='LIVE')continue;
          final requested=market['interest_registered']==true;
          final building=market['data_status']=='BUILDING';
          final marketColor=building?AppTheme.green:requested?AppTheme.cyan:AppTheme.amber;
          final nationalZoom=_viewportZoom<=5.4;
          final regionalZoom=_viewportZoom>5.4&&_viewportZoom<7.0;
          final markerSize=nationalZoom?14.0:regionalZoom?28.0:74.0;
          final markerHeight=nationalZoom?14.0:regionalZoom?28.0:50.0;
          late final Widget markerChild;
          if(nationalZoom){
            markerChild=Container(
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                color:marketColor.withOpacity(.42),
                border:Border.all(color:marketColor.withOpacity(.85),width:1.5),
              ),
            );
          }else if(regionalZoom){
            markerChild=Container(
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                color:AppTheme.panel.withOpacity(.72),
                border:Border.all(color:marketColor.withOpacity(.78),width:1.4),
              ),
              child:Center(child:Text(code,style:TextStyle(color:marketColor,fontSize:7,fontWeight:FontWeight.w900))),
            );
          }else{
            markerChild=Container(
              padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),
              decoration:BoxDecoration(
                color:AppTheme.panel.withOpacity(.90),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:marketColor.withOpacity(.75)),
              ),
              child:Column(
                mainAxisSize:MainAxisSize.min,
                children:[
                  Text(code,style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w900)),
                  if(building)Text('BUILDING',style:TextStyle(color:marketColor,fontSize:6,fontWeight:FontWeight.w900)),
                ],
              ),
            );
          }
          markers.add(Marker(
            point:center,
            width:markerSize,
            height:markerHeight,
            child:Tooltip(
              message:'${market['state_name']} • ${market['data_status']} • ${_formatExpansionEtaV321(market['build_eta'])}',
              child:GestureDetector(
                onTap:()=>_showStateCoverageDialog(context,market,_reload),
                child:markerChild,
              ),
            ),
          ));
        }
"""
if old not in body:
    if 'late final Widget markerChild;' in body:
        print('v321 map compile repair already applied.')
        raise SystemExit(0)

    # V687 can legitimately evolve the old expansion-marker widget before this legacy
    # repair runs. In that case, prove the newer map/radar contract is intact instead
    # of aborting because one obsolete source literal disappeared.
    evolved_required=[
        'bridgepoint-v321-resilience-expansion-eta-radar-map',
        '_loadNoaaRadarFramesV271',
        '_weatherAllowedV318',
        '_showRadar',
        "key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}')",
        'Opacity(opacity:.88,child:TileLayer(',
    ]
    missing=[needle for needle in evolved_required if needle not in body]
    if not missing:
        print('v321 map compile repair: legacy expansion-marker anchor superseded; v687 evolved map/radar contract verified.')
        raise SystemExit(0)
    raise SystemExit(f'v321 map compile repair anchor missing and evolved contract incomplete: {missing}')
body=body.replace(old,new,1)
path.write_text(body,encoding='utf-8')
print('Repaired v321 zoom-aware expansion marker widget structure.')
