from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _PropertiesPage extends StatefulWidget')
property_card=text.find('class _PropertyListCard extends StatelessWidget',start)
map_page=text.find('class _IntelligenceMapPage extends StatefulWidget',start)
if start<0 or property_card<0:
    raise SystemExit('Properties page anchors missing')
# Modern generated source places Intelligence Map between PropertiesPage and
# _PropertyListCard. Stop at the first top-level successor so the multistate
# replacement cannot delete map/radar classes.
end=map_page if map_page>start and map_page<property_card else property_card
removed=text[start:end]
print('v846 v188 boundaries',{'len_before':len(text),'start':start,'end':end,'property_card':property_card,'map_page':map_page,'removed_len':len(removed),'wms_before':text.count('WMSTileLayerOptions('),'wms_removed':removed.count('WMSTileLayerOptions(')})
if 'class _IntelligenceMapPage' in removed or 'WMSTileLayerOptions(' in removed:
    raise SystemExit('v188 unsafe PropertiesPage boundary would remove Intelligence Map')

page=r'''class _PropertiesPage extends StatefulWidget {
  const _PropertiesPage();
  @override State<_PropertiesPage> createState()=>_PropertiesPageState();
}

class _PropertiesPageState extends State<_PropertiesPage>{
  static const int _pageSize=50;
  final _searchController=TextEditingController();
  final _countyController=TextEditingController();
  final _municipalityController=TextEditingController();
  final _typeController=TextEditingController();
  final _opportunityController=TextEditingController();
  final _minScoreController=TextEditingController();
  late Future<Map<String,dynamic>> _workspaceRequest;
  late Future<Map<String,dynamic>> _request;
  Set<String> _selectedStates=<String>{};
  int _offset=0;
  String? _search,_county,_municipality,_propertyType,_opportunityType;
  bool? _ownerAvailable;
  double? _minScore;
  String _sort='OPPORTUNITY_SCORE';

  @override void initState(){super.initState();_workspaceRequest=_callRpc('bridgepoint_state_workspace_v188',const {});_request=_load();}
  @override void dispose(){_searchController.dispose();_countyController.dispose();_municipalityController.dispose();_typeController.dispose();_opportunityController.dispose();_minScoreController.dispose();super.dispose();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_property_browser_v188',{
    'p_state_codes':_selectedStates.isEmpty?null:_selectedStates.toList(),
    'p_query':_search,'p_county':_county,'p_municipality':_municipality,'p_property_type':_propertyType,
    'p_owner_available':_ownerAvailable,'p_min_score':_minScore,'p_opportunity_type':_opportunityType,
    'p_sort':_sort,'p_limit':_pageSize,'p_offset':_offset,
  });
  void _reload(){setState(()=>_request=_load());}
  String? _clean(String v){final x=v.trim();return x.isEmpty?null:x;}
  void _apply(){_offset=0;_search=_clean(_searchController.text);_county=_clean(_countyController.text);_municipality=_clean(_municipalityController.text);_propertyType=_clean(_typeController.text);_opportunityType=_clean(_opportunityController.text);_minScore=double.tryParse(_minScoreController.text.trim());_reload();}
  void _clear(){for(final c in [_searchController,_countyController,_municipalityController,_typeController,_opportunityController,_minScoreController]){c.clear();}_selectedStates.clear();_search=_county=_municipality=_propertyType=_opportunityType=null;_ownerAvailable=null;_minScore=null;_sort='OPPORTUNITY_SCORE';_offset=0;_reload();}
  Widget _field(TextEditingController c,String label,IconData icon,{double width=190})=>SizedBox(width:width,child:TextField(controller:c,onSubmitted:(_)=>_apply(),style:const TextStyle(fontSize:11),decoration:InputDecoration(isDense:true,labelText:label,prefixIcon:Icon(icon,size:17),border:const OutlineInputBorder())));

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:_request,builder:(context,snap)=>FutureBuilder<Map<String,dynamic>>(
      future:_workspaceRequest,builder:(context,wsSnap){
        final data=snap.data??const <String,dynamic>{};
        final props=_detailList(data['properties']);
        final states=_detailList(wsSnap.data?['states']);
        final ownerMode=wsSnap.data?['owner_mode']==true;
        final loading=snap.connectionState==ConnectionState.waiting;
        final total=(data['total_matches'] as num?)?.toInt()??0;
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _PageHeading(title:'Properties',subtitle:ownerMode?'All-state owner workspace • switch, combine and filter every BridgePoint market':'Your property workspace • switch or combine the states included with your account',onRefresh:_reload,loading:loading),
          const SizedBox(height:12),
          Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            LayoutBuilder(builder:(context,constraints){
              final narrow=constraints.maxWidth<620;
              final title=Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.public_rounded,color:AppTheme.cyan,size:18),const SizedBox(width:8),Flexible(child:Text(ownerMode?'ALL BRIDGEPOINT STATES':'MY STATES',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.7)))]);
              final summary=Text('${_selectedStates.isEmpty?'All selectable states':_selectedStates.join(', ')} • $total matches',style:const TextStyle(color:AppTheme.textMuted,fontSize:9));
              return narrow?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[title,const SizedBox(height:7),summary]):Row(children:[Expanded(child:title),const SizedBox(width:10),summary]);
            }),
            const SizedBox(height:10),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
              ChoiceChip(label:const Text('All My States'),selected:_selectedStates.isEmpty,onSelected:(_){setState((){_selectedStates.clear();_offset=0;_request=_load();});}),
              const SizedBox(width:7),
              ...states.where((s)=>s['selectable']==true).map((s){final code='${s['state_code']}';final status='${s['data_status']}';final selected=_selectedStates.contains(code);final color=status=='LIVE'?AppTheme.green:status=='BUILDING'?AppTheme.amber:AppTheme.blue;return Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(
                avatar:Icon(status=='BUILDING'?Icons.construction_rounded:status=='LIVE'?Icons.verified_rounded:Icons.public_rounded,size:15,color:color),
                label:Text('$code • $status'),selected:selected,onSelected:(v){setState((){if(v){_selectedStates.add(code);}else{_selectedStates.remove(code);}_offset=0;_request=_load();});},
              ));}),
            ])),
          ]))),
          const SizedBox(height:12),
          Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
            Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
              _field(_searchController,'Address, parcel or owner',Icons.search_rounded,width:250),
              _field(_countyController,'County',Icons.map_outlined),_field(_municipalityController,'Town / city',Icons.location_city_outlined),
              _field(_typeController,'Property type',Icons.category_outlined),_field(_opportunityController,'Opportunity type',Icons.bolt_rounded),
              _field(_minScoreController,'Minimum score',Icons.speed_rounded,width:150),
              SizedBox(width:175,child:DropdownButtonFormField<bool?>(value:_ownerAvailable,decoration:const InputDecoration(isDense:true,labelText:'Owner record',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:null,child:Text('Any owner status')),DropdownMenuItem(value:true,child:Text('Current owner known')),DropdownMenuItem(value:false,child:Text('Owner unavailable'))],onChanged:(v)=>setState(()=>_ownerAvailable=v))),
              SizedBox(width:185,child:DropdownButtonFormField<String>(value:_sort,decoration:const InputDecoration(isDense:true,labelText:'Sort',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'OPPORTUNITY_SCORE',child:Text('Best opportunity')),DropdownMenuItem(value:'SCORE',child:Text('Intelligence score')),DropdownMenuItem(value:'ADDRESS',child:Text('Address')),DropdownMenuItem(value:'STATE',child:Text('State')),DropdownMenuItem(value:'OWNER',child:Text('Owner'))],onChanged:(v){if(v!=null)setState(()=>_sort=v);})),
            ]),const SizedBox(height:10),
            Align(alignment:Alignment.centerLeft,child:Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
              FilledButton.icon(onPressed:loading?null:_apply,icon:const Icon(Icons.filter_alt_rounded,size:17),label:const Text('Apply filters')),
              OutlinedButton.icon(onPressed:loading?null:_clear,icon:const Icon(Icons.clear_rounded,size:17),label:const Text('Clear')),
              const Text('State access is enforced server-side by BridgePoint entitlements.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
            ])),
          ]))),
          const SizedBox(height:14),
          if(snap.hasError)_DashboardError(message:snap.error.toString(),onRetry:_reload)
          else if(loading&&snap.data==null)const Card(child:SizedBox(height:250,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan))))
          else if(props.isEmpty)const Card(child:SizedBox(height:210,child:Center(child:Text('No properties match these state and property filters.',style:TextStyle(color:AppTheme.textMuted)))))
          else Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _PanelHeader(title:_selectedStates.isEmpty?'All My States':'${_selectedStates.join(' + ')} Properties',subtitle:'Current property records • recorded owner • attached BridgePoint intelligence',action:'Open property'),const SizedBox(height:12),
            ...props.map((p)=>_PropertyListCard(property:p)),const SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
              OutlinedButton.icon(onPressed:_offset>0&&!loading?(){_offset=(_offset-_pageSize).clamp(0,1<<30);_reload();}:null,icon:const Icon(Icons.chevron_left_rounded),label:const Text('Previous')),
              OutlinedButton.icon(onPressed:data['has_more']==true&&!loading?(){_offset+=_pageSize;_reload();}:null,icon:const Icon(Icons.chevron_right_rounded),label:const Text('Next')),
              Text('${props.length} shown • $total matches',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
            ])
          ]))),
        ]);
      },
    ),
  );
}

'''
text=text[:start]+page+text[end:]

# Enrich the responsive Property card without reverting its phone-first layout.
text=text.replace("final yearBuilt = property['year_built'];", "final yearBuilt = property['year_built'];\n    final stateCode=(property['state_code']??'').toString();\n    final owner=(property['current_owner_name']??'').toString().trim();\n    final ownerStatus=(property['owner_record_status']??'UNKNOWN').toString();",1)
text=text.replace("? '$municipality, CT • $parcel'\n          : address;", "? '$municipality${stateCode.isEmpty?'':', $stateCode'} • $parcel'\n          : address;",1)

old_identity="""              Text([municipality, if (county.isNotEmpty) '$county County', parcel].join(' • '), maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.35)),
"""
new_identity="""              Text([municipality, if (county.isNotEmpty) '$county County', if(stateCode.isNotEmpty) stateCode, parcel].join(' • '), maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.35)),
"""
if old_identity not in text:
    raise SystemExit('responsive property identity marker missing')
text=text.replace(old_identity,new_identity,1)

chips_start="""    final chips = <Widget>[
      _OpportunityChip(label: type, color: AppTheme.blue),
"""
if chips_start not in text:
    raise SystemExit('responsive property chips marker missing')
chip_owner="""    final chips = <Widget>[
      _OpportunityChip(label: type, color: AppTheme.blue),
      _OpportunityChip(label:ownerStatus=='CURRENT'?'OWNER VERIFIED':'OWNER $ownerStatus',color:ownerStatus=='CURRENT'?AppTheme.green:AppTheme.textMuted),
"""
text=text.replace(chips_start,chip_owner,1)

facts_old="""    final facts = [
      if (yearBuilt != null) 'Built $yearBuilt',
      if (assessed != null) '\$${_formatInteger(assessed)} assessed',
    ];
"""
facts_new="""    final facts = [
      if(owner.isNotEmpty) owner else 'Recorded owner unavailable',
      if (yearBuilt != null) 'Built $yearBuilt',
      if (assessed != null) '\$${_formatInteger(assessed)} assessed',
    ];
"""
if facts_old not in text:
    raise SystemExit('responsive property facts marker missing')
text=text.replace(facts_old,facts_new,1)

# Add current owner facts to the property intelligence dialog.
needle3="""                              _DetailFact('Tax year', property['tax_year']),
                              _DetailFact('County', property['county']),
                              _DetailFact('Postal', property['postal_code']),
"""
replacement3="""                              _DetailFact('Tax year', property['tax_year']),
                              _DetailFact('State', property['state_code']),
                              _DetailFact('County', property['county']),
                              _DetailFact('Postal', property['postal_code']),
                              _DetailFact('Current recorded owner', property['current_owner_name']??(property['owner_record_status']=='WITHHELD'?'Withheld by source':'Not available from current source')),
                              _DetailFact('Co-owner', property['current_co_owner_name']),
                              _DetailFact('Owner type', property['owner_entity_type']),
                              _DetailFact('Owner record as of', property['owner_as_of_date']),
                              _DetailFact('Owner source', property['owner_source_name']),
"""
if needle3 not in text: raise SystemExit('property detail fact marker missing')
text=text.replace(needle3,replacement3,1)
text=text.replace("subtitle: 'Canonical Connecticut property record',","subtitle: 'Canonical current property record with recorded ownership and provenance',",1)
text=text.replace("'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? 'CT'} • ${property['parcel_number'] ?? 'No parcel'}'","'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? property['state_code'] ?? 'PROPERTY'} • ${property['state_code'] ?? ''} • ${property['parcel_number'] ?? 'No parcel'}'",1)

for marker in ['bridgepoint_state_workspace_v188','bridgepoint_property_browser_v188','All My States','Current recorded owner','OWNER VERIFIED','constraints.maxWidth<620']:
    if marker not in text: raise SystemExit(f'missing v188 UI marker {marker}')
if text==original: raise SystemExit('No multistate/owner UI changes applied')
print('v846 v188 result',{'len_after':len(text),'wms_after':text.count('WMSTileLayerOptions('),'map_after':text.count('class _IntelligenceMapPage')})
path.write_text(text,encoding='utf-8')
print('Applied phone-responsive multistate property workspace and current-owner UI v188')
