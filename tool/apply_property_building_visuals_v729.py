from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
marker='// bridgepoint-property-building-visuals-v729'
if marker in s:
    print('V729 already applied')
    raise SystemExit(0)

s=s.replace('// bridgepoint-visible-national-v728','// bridgepoint-visible-national-v728\n'+marker,1)

old="""      _callRpc('bridgepoint_property_timeline_v78',{'p_property_id':widget.propertyId,'p_limit':120})
        .catchError((_)=><String,dynamic>{}),
    ]);"""
new="""      _callRpc('bridgepoint_property_timeline_v78',{'p_property_id':widget.propertyId,'p_limit':120})
        .catchError((_)=><String,dynamic>{}),
      _callRpc('bridgepoint_property_building_visuals_v700',{'p_property_id':widget.propertyId})
        .catchError((_)=><String,dynamic>{}),
      _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId})
        .catchError((_)=><String,dynamic>{}),
    ]);"""
if old not in s: raise SystemExit('V729 load anchor missing')
s=s.replace(old,new,1)

old="""    final detail=Map<String,dynamic>.from(decoded);
    final timeline=results[1] as Map<String,dynamic>;
    if(timeline['timeline'] is List){"""
new="""    final detail=Map<String,dynamic>.from(decoded);
    final timeline=results[1] as Map<String,dynamic>;
    final buildingVisuals=results[2] as Map<String,dynamic>;
    final mediaBundle=results[3] as Map<String,dynamic>;
    if(timeline['timeline'] is List){"""
if old not in s: raise SystemExit('V729 result anchor missing')
s=s.replace(old,new,1)

old="""      summary['timeline_item_count']=timeline['item_count'];detail['summary']=summary;
    }
    return detail;"""
new="""      summary['timeline_item_count']=timeline['item_count'];detail['summary']=summary;
    }
    detail['building_visuals_v729']=buildingVisuals;
    detail['media_bundle_v729']=mediaBundle;
    return detail;"""
if old not in s: raise SystemExit('V729 detail merge anchor missing')
s=s.replace(old,new,1)

old="""            final propertyDna = data['property_dna'] is Map
                ? Map<String, dynamic>.from(data['property_dna'] as Map)
                : <String, dynamic>{};
            final building2d = _detailList(physical['building_2d']);"""
new="""            final propertyDna = data['property_dna'] is Map
                ? Map<String, dynamic>.from(data['property_dna'] as Map)
                : <String, dynamic>{};
            final buildingVisuals = data['building_visuals_v729'] is Map
                ? Map<String,dynamic>.from(data['building_visuals_v729'] as Map)
                : <String,dynamic>{};
            final twoDVisual = buildingVisuals['two_d'] is Map
                ? Map<String,dynamic>.from(buildingVisuals['two_d'] as Map)
                : <String,dynamic>{};
            final buildingVisualFeatures = _detailList(twoDVisual['features']);
            final mediaBundle = data['media_bundle_v729'] is Map
                ? Map<String,dynamic>.from(data['media_bundle_v729'] as Map)
                : <String,dynamic>{};
            final building2d = _detailList(physical['building_2d']);"""
if old not in s: raise SystemExit('V729 build variables anchor missing')
s=s.replace(old,new,1)

old="""                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Physical & Building Intelligence',"""
new="""                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Property Visuals',
                          subtitle: 'Verified footprint geometry, measured-height extrusion, and available property media',
                          child: _PropertyBuildingVisualsV729(
                            buildingVisuals:buildingVisuals,
                            features:buildingVisualFeatures,
                            mediaBundle:mediaBundle,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Physical & Building Intelligence',"""
if old not in s: raise SystemExit('V729 visual section anchor missing')
s=s.replace(old,new,1)

widget_code=r'''
class _PropertyBuildingVisualsV729 extends StatelessWidget {
  const _PropertyBuildingVisualsV729({required this.buildingVisuals,required this.features,required this.mediaBundle});
  final Map<String,dynamic> buildingVisuals;
  final List<Map<String,dynamic>> features;
  final Map<String,dynamic> mediaBundle;

  double? _number(Object? value){
    if(value is num)return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context){
    final feature=features.isEmpty?<String,dynamic>{}:features.first;
    final geometry=feature['geometry'] is Map?Map<String,dynamic>.from(feature['geometry'] as Map):<String,dynamic>{};
    final height=_number(feature['height_m']);
    final area=_number(feature['footprint_area_m2']);
    final elevation=_number(feature['ground_elevation_m']);
    final confidence=_number(feature['match_confidence']);
    final source='${feature['source_name']??feature['source_provider']??'Verified public building source'}';
    final front=mediaBundle['front'] is Map?Map<String,dynamic>.from(mediaBundle['front'] as Map):<String,dynamic>{};
    final aerial=mediaBundle['aerial_current'] is Map?Map<String,dynamic>.from(mediaBundle['aerial_current'] as Map):<String,dynamic>{};
    final geometryAvailable=geometry.isNotEmpty;
    final coverage='${buildingVisuals['coverage_note']??(geometryAvailable?'Verified building geometry attached.':'No verified property-linked building geometry materialized yet.')}';
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      LayoutBuilder(builder:(context,c){
        final width=c.maxWidth>=760?(c.maxWidth-12)/2:c.maxWidth;
        return Wrap(spacing:12,runSpacing:12,children:[
          SizedBox(width:width,child:_BuildingCanvasV729(
            title:'2D FOOTPRINT',
            subtitle:geometryAvailable?'Actual source geometry':'Not available yet',
            geometry:geometry,
            heightM:height,
            extruded:false,
          )),
          SizedBox(width:width,child:_BuildingCanvasV729(
            title:'3D STRUCTURE',
            subtitle:height!=null?'Height-backed extrusion • ${height.toStringAsFixed(2)} m':'No measured height attribute yet',
            geometry:geometry,
            heightM:height,
            extruded:geometryAvailable&&height!=null,
          )),
        ]);
      }),
      const SizedBox(height:12),
      Wrap(spacing:18,runSpacing:8,children:[
        _DetailFact('Building source',source),
        _DetailFact('Source year',feature['source_year']),
        _DetailFact('Footprint',area==null?null:'${area.toStringAsFixed(1)} m²'),
        _DetailFact('Measured height',height==null?null:'${height.toStringAsFixed(2)} m'),
        _DetailFact('Ground elevation',elevation==null?null:'${elevation.toStringAsFixed(1)} m'),
        _DetailFact('Match confidence',confidence==null?null:'${(confidence*100).toStringAsFixed(0)}%'),
      ]),
      const SizedBox(height:10),
      Text(coverage,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
      if(height!=null) ...[
        const SizedBox(height:5),
        const Text('3D rendering uses the verified footprint plus the source height attribute. Display scale is illustrative; the height value shown above is the source measurement.',style:TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.4)),
      ],
      const SizedBox(height:12),
      _PropertyMediaAvailabilityV729(front:front,aerial:aerial,historyCount:(mediaBundle['aerial_history_count'] as num?)?.toInt()??0),
    ]);
  }
}

class _BuildingCanvasV729 extends StatelessWidget {
  const _BuildingCanvasV729({required this.title,required this.subtitle,required this.geometry,required this.heightM,required this.extruded});
  final String title,subtitle;
  final Map<String,dynamic> geometry;
  final double? heightM;
  final bool extruded;
  @override
  Widget build(BuildContext context)=>Container(
    height:245,
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:Colors.black.withOpacity(.18),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.07))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(extruded?Icons.view_in_ar_rounded:Icons.architecture_rounded,color:geometry.isEmpty?AppTheme.textMuted:AppTheme.cyan,size:18),
        const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.5)),
          Text(subtitle,style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
        ])),
      ]),
      const SizedBox(height:10),
      Expanded(child:geometry.isEmpty
        ?const Center(child:Text('Verified geometry is not available for this property yet.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted,fontSize:10)))
        :CustomPaint(painter:_GeoFootprintPainterV729(geometry:geometry,heightM:heightM,extruded:extruded),child:const SizedBox.expand())),
    ]),
  );
}

class _PropertyMediaAvailabilityV729 extends StatelessWidget {
  const _PropertyMediaAvailabilityV729({required this.front,required this.aerial,required this.historyCount});
  final Map<String,dynamic> front,aerial;
  final int historyCount;
  String _url(Map<String,dynamic> item)=>'${item['media_url']??item['thumbnail_url']??''}'.trim();
  @override
  Widget build(BuildContext context){
    Widget tile(String label,Map<String,dynamic> item,IconData icon){
      final url=_url(item);
      return Container(
        width:250,height:128,clipBehavior:Clip.antiAlias,
        decoration:BoxDecoration(color:Colors.black.withOpacity(.18),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withOpacity(.06))),
        child:url.isEmpty
          ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:AppTheme.textMuted),const SizedBox(height:6),Text('$label not available yet',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))]))
          :Stack(fit:StackFit.expand,children:[
              Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Center(child:Icon(icon,color:AppTheme.textMuted))),
              Align(alignment:Alignment.bottomLeft,child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),color:Colors.black.withOpacity(.68),child:Text(label,style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w800)))),
            ]),
      );
    }
    return Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
      tile('FRONT / STREET',front,Icons.add_a_photo_outlined),
      tile('CURRENT AERIAL',aerial,Icons.satellite_alt_outlined),
      _DetailFact('Aerial history',historyCount==0?'Not available yet':'$historyCount image${historyCount==1?'':'s'}'),
    ]);
  }
}

class _GeoFootprintPainterV729 extends CustomPainter {
  _GeoFootprintPainterV729({required this.geometry,required this.heightM,required this.extruded});
  final Map<String,dynamic> geometry;
  final double? heightM;
  final bool extruded;

  List<List<Offset>> _rings(){
    final type='${geometry['type']??''}';
    final coords=geometry['coordinates'];
    final out=<List<Offset>>[];
    void addRing(dynamic ring){
      if(ring is! List)return;
      final pts=<Offset>[];
      for(final raw in ring){
        if(raw is List&&raw.length>=2&&raw[0] is num&&raw[1] is num){pts.add(Offset((raw[0] as num).toDouble(),(raw[1] as num).toDouble()));}
      }
      if(pts.length>=3)out.add(pts);
    }
    if(type=='Polygon'&&coords is List){for(final ring in coords)addRing(ring);}
    if(type=='MultiPolygon'&&coords is List){for(final polygon in coords){if(polygon is List){for(final ring in polygon)addRing(ring);}}}
    return out;
  }

  @override
  void paint(Canvas canvas,Size size){
    final rings=_rings();
    if(rings.isEmpty)return;
    final all=rings.expand((e)=>e).toList();
    var minX=all.first.dx,maxX=all.first.dx,minY=all.first.dy,maxY=all.first.dy;
    for(final p in all){if(p.dx<minX)minX=p.dx;if(p.dx>maxX)maxX=p.dx;if(p.dy<minY)minY=p.dy;if(p.dy>maxY)maxY=p.dy;}
    final dx=(maxX-minX).abs()<1e-12?1.0:maxX-minX;
    final dy=(maxY-minY).abs()<1e-12?1.0:maxY-minY;
    final rawLift=(heightM??0)*1.35;
    final lift=extruded?(rawLift<7?7.0:rawLift>34?34.0:rawLift):0.0;
    const pad=18.0;
    final usableW=size.width-pad*2-lift*.35;
    final usableH=size.height-pad*2-lift;
    final sx=usableW/dx,sy=usableH/dy;
    final scale=sx<sy?sx:sy;
    final drawnW=dx*scale,drawnH=dy*scale;
    final ox=pad+(usableW-drawnW)/2+lift*.35;
    final oy=pad+lift+(usableH-drawnH)/2;
    Offset tr(Offset p)=>Offset(ox+(p.dx-minX)*scale,oy+drawnH-(p.dy-minY)*scale);
    final shift=Offset(-lift*.35,-lift);
    final fill=Paint()..color=AppTheme.cyan.withOpacity(.16)..style=PaintingStyle.fill;
    final stroke=Paint()..color=AppTheme.cyan.withOpacity(.90)..style=PaintingStyle.stroke..strokeWidth=1.7;
    final side=Paint()..color=AppTheme.blue.withOpacity(.16)..style=PaintingStyle.fill;
    Path pathFor(List<Offset> ring,{Offset shiftBy=Offset.zero}){
      final path=Path();
      final first=tr(ring.first)+shiftBy;path.moveTo(first.dx,first.dy);
      for(final p in ring.skip(1)){final q=tr(p)+shiftBy;path.lineTo(q.dx,q.dy);}path.close();return path;
    }
    if(extruded){
      for(final ring in rings){
        for(var i=0;i<ring.length;i++){
          final a=tr(ring[i]),b=tr(ring[(i+1)%ring.length]);
          final q=Path()..moveTo(a.dx,a.dy)..lineTo(b.dx,b.dy)..lineTo(b.dx+shift.dx,b.dy+shift.dy)..lineTo(a.dx+shift.dx,a.dy+shift.dy)..close();
          canvas.drawPath(q,side);
        }
      }
      for(final ring in rings){canvas.drawPath(pathFor(ring),stroke);}
      for(final ring in rings){final top=pathFor(ring,shiftBy:shift);canvas.drawPath(top,fill);canvas.drawPath(top,stroke);}
    }else{
      final combined=Path()..fillType=PathFillType.evenOdd;
      for(final ring in rings){combined.addPath(pathFor(ring),Offset.zero);}
      canvas.drawPath(combined,fill);canvas.drawPath(combined,stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _GeoFootprintPainterV729 oldDelegate)=>oldDelegate.geometry!=geometry||oldDelegate.heightM!=heightM||oldDelegate.extruded!=extruded;
}

'''
anchor='class _JsonIntelligenceList extends StatelessWidget {'
if anchor not in s: raise SystemExit('V729 widget anchor missing')
s=s.replace(anchor,widget_code+anchor,1)

checks=[marker,'bridgepoint_property_building_visuals_v700','bridgepoint_property_media_bundle_v169','class _GeoFootprintPainterV729','3D rendering uses the verified footprint']
missing=[x for x in checks if x not in s]
if missing: raise SystemExit('V729 missing '+repr(missing))
p.write_text(s,encoding='utf-8')
print('Applied V729 real property building/media visual workspace')
