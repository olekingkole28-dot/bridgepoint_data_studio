from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
start_marker = 'class _MyHomePageState extends State<_MyHomePage>{'
end_marker = 'class _HomePhotoMissing extends StatelessWidget'
start = text.find(start_marker)
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('My Home generated block not found')

replacement = r'''class _MyHomePageState extends State<_MyHomePage>{
  bool loading=true;
  String? error;
  List<Map<String,dynamic>> homes=[];
  String? propertyId;
  Map<String,dynamic> dashboard={};
  Map<String,dynamic> actions={};
  Map<String,dynamic> neighborhood={};
  Map<String,dynamic> similar={};
  Map<String,dynamic> scoreChanges={};

  @override
  void initState(){
    super.initState();
    _loadHomes();
  }

  Future<void> _loadHomes() async {
    if(mounted)setState(()=>loading=true);
    try{
      final result=await _callRpc('bridgepoint_home_passports_v142',const {});
      final loaded=_bpRows(result['homes']);
      if(!mounted)return;
      homes=loaded;
      if(homes.isNotEmpty){
        final requested=propertyId;
        final selected=homes.any((h)=>'${h['property_id']}'==requested)
          ? requested!
          : '${homes.first['property_id']}';
        await _loadHome(selected);
      }else{
        setState((){
          propertyId=null;
          dashboard={};actions={};neighborhood={};similar={};scoreChanges={};
          error=null;loading=false;
        });
      }
    }catch(e){
      if(mounted)setState((){error='$e';loading=false;});
    }
  }

  Future<void> _loadHome(String id) async {
    if(mounted)setState(()=>loading=true);
    try{
      final results=await Future.wait([
        _callRpc('bridgepoint_home_dashboard_v139',{'p_property_id':id}),
        _callRpc('bridgepoint_home_action_plan_v140',{'p_property_id':id}),
        _callRpc('bridgepoint_home_neighborhood_intelligence_v140',{'p_property_id':id,'p_radius_km':2.5,'p_days':180,'p_limit':80}),
        _callRpc('bridgepoint_find_similar_properties_v141',{'p_property_id':id,'p_limit':18,'p_same_state':true}),
        _callRpc('bridgepoint_score_change_explanation_v141',{'p_property_id':id,'p_limit':20}),
      ]);
      if(!mounted)return;
      setState((){
        propertyId=id;
        dashboard=results[0];
        actions=results[1];
        neighborhood=results[2];
        similar=results[3];
        scoreChanges=results[4];
        error=null;
        loading=false;
      });
    }catch(e){
      if(mounted)setState((){error='$e';loading=false;});
    }
  }

  Future<void> _findHome() async {
    final property=await showDialog<Map<String,dynamic>>(
      context:context,
      builder:(dialogContext)=>const _BridgePointPropertyFinderDialog(title:'Add a home to My Home'),
    );
    if(property==null)return;
    try{
      await _callRpc('bridgepoint_home_claim_property_v139',{
        'p_property_id':property['property_id'],
        'p_home_name':'My Home',
      });
      propertyId='${property['property_id']}';
      await _loadHomes();
    }catch(e){
      if(mounted)_showInfoDialog(context,'Could not add home','$e');
    }
  }

  Future<void> _weatherForHome() async {
    final home=_bpMap(dashboard['home']);
    if(home['latitude']==null||home['longitude']==null){
      if(mounted)_showInfoDialog(context,'Weather location unavailable','This property does not yet have a verified map location.');
      return;
    }
    try{
      await _callRpc('bridgepoint_weather_save_location_v136',{
        'p_label':'${_bpMap(dashboard['passport'])['home_name']??'My Home'}',
        'p_latitude':home['latitude'],
        'p_longitude':home['longitude'],
        'p_location_name':home['address'],
        'p_postal_code':home['postal_code'],
        'p_is_default':true,
      });
      widget.onOpenWeather();
    }catch(e){
      if(mounted)_showInfoDialog(context,'Could not open home weather','$e');
    }
  }

  Future<String?> _prompt(String title,String label,{String? hint}) async {
    final controller=TextEditingController();
    final value=await showDialog<String>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        backgroundColor:AppTheme.panel,
        title:Text(title),
        content:TextField(
          controller:controller,
          autofocus:true,
          decoration:InputDecoration(labelText:label,hintText:hint,border:const OutlineInputBorder()),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,controller.text.trim()),child:const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _addSystem() async {
    if(propertyId==null)return;
    final input=await _prompt('Add home system','System type',hint:'ROOF, HVAC, WATER_HEATER, SOLAR…');
    if(input==null||input.isEmpty)return;
    final type=input.toUpperCase().replaceAll(' ','_');
    try{
      await _callRpc('bridgepoint_home_add_system_v140',{
        'p_property_id':propertyId,
        'p_system_type':type,
        'p_system_name':input,
      });
      await _loadHome(propertyId!);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not add system','$e');}
  }

  Future<void> _addMaintenance() async {
    if(propertyId==null)return;
    final task=await _prompt('Add maintenance','What needs to be done?',hint:'Clean gutters, service HVAC, test sump pump…');
    if(task==null||task.isEmpty)return;
    try{
      await _callRpc('bridgepoint_home_add_maintenance_v140',{
        'p_property_id':propertyId,
        'p_task_name':task,
        'p_priority':'NORMAL',
      });
      await _loadHome(propertyId!);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not add maintenance','$e');}
  }

  Future<void> _addDocument() async {
    if(propertyId==null)return;
    final title=await _prompt('Add home document','Document title',hint:'Roof warranty, insurance declaration, survey…');
    if(title==null||title.isEmpty)return;
    try{
      await _callRpc('bridgepoint_home_add_document_v140',{
        'p_property_id':propertyId,
        'p_document_type':'OTHER',
        'p_title':title,
      });
      await _loadHome(propertyId!);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not add document','$e');}
  }

  Future<void> _addInventory() async {
    if(propertyId==null)return;
    final item=await _prompt('Add home inventory item','Item',hint:'Living room TV, laptop, refrigerator…');
    if(item==null||item.isEmpty)return;
    try{
      await _callRpc('bridgepoint_home_add_inventory_item_v140',{
        'p_property_id':propertyId,
        'p_room_name':'Unassigned room',
        'p_item_name':item,
      });
      await _loadHome(propertyId!);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not add inventory item','$e');}
  }

  Future<void> _addImprovement() async {
    if(propertyId==null)return;
    final project=await _prompt('Log home improvement','Project',hint:'Roof replacement, new windows, solar installation…');
    if(project==null||project.isEmpty)return;
    try{
      await _callRpc('bridgepoint_home_add_improvement_v140',{
        'p_property_id':propertyId,
        'p_project_name':project,
      });
      await _loadHome(propertyId!);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not log improvement','$e');}
  }

  Widget _empty(String message)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:8),
    child:Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
  );

  @override
  Widget build(BuildContext context){
    final home=_bpMap(dashboard['home']);
    final passport=_bpMap(dashboard['passport']);
    final intel=_bpMap(dashboard['home_intelligence']);
    final photo=_bpMap(dashboard['property_photo']);
    final primary=_bpMap(photo['primary']);
    final systems=_bpRows(dashboard['systems']);
    final maintenance=_bpRows(dashboard['maintenance']);
    final documents=_bpRows(dashboard['documents']);
    final inventory=_bpRows(dashboard['inventory']);
    final improvements=_bpRows(dashboard['improvements']);
    final actionRows=_bpRows(actions['actions']);
    final nearby=_bpRows(neighborhood['items']);
    final twins=_bpRows(similar['similar']);
    final changes=_bpRows(scoreChanges['changes']);

    return Padding(
      padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Expanded(child:_PanelHeader(
            title:'My Home',
            subtitle:'Home Passport • home health • maintenance • documents • weather • neighborhood intelligence',
            action:'Homeowner advantage',
          )),
          OutlinedButton.icon(onPressed:_findHome,icon:const Icon(Icons.add_home_work_outlined),label:Text(homes.isEmpty?'Add my home':'Change / add home')),
        ]),
        if(homes.length>1)...[
          const SizedBox(height:8),
          DropdownButtonFormField<String>(
            initialValue:propertyId,
            dropdownColor:AppTheme.panel,
            decoration:const InputDecoration(labelText:'My homes',border:OutlineInputBorder()),
            items:homes.map((h)=>DropdownMenuItem<String>(value:'${h['property_id']}',child:Text('${h['home_name']} • ${h['full_address']}'))).toList(),
            onChanged:(value){if(value!=null)_loadHome(value);},
          ),
        ],
        if(loading)...[const SizedBox(height:10),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)],
        if(error!=null)...[const SizedBox(height:10),_InlineError(message:error!)],
        if(homes.isEmpty&&!loading)...[
          const SizedBox(height:16),
          const _ExplainerBanner(
            icon:Icons.home_rounded,
            title:'Give yourself the information advantage',
            message:'Add your home to BridgePoint. My Home combines public property records, property timeline intelligence, weather/storm context, your own systems and service history, documents, warranties, improvements, belongings, maintenance, and neighborhood changes in one private Home Passport.',
          ),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:_findHome,icon:const Icon(Icons.search_rounded),label:const Text('Find my home')),
        ],
        if(propertyId!=null&&dashboard.isNotEmpty)...[
          const SizedBox(height:14),
          Card(child:Padding(
            padding:const EdgeInsets.all(16),
            child:LayoutBuilder(builder:(context,constraints){
              final wide=constraints.maxWidth>780;
              final Widget photoWidget=primary['media_url']!=null
                ? ClipRRect(
                    borderRadius:BorderRadius.circular(12),
                    child:Image.network('${primary['media_url']}',width:wide?280:double.infinity,height:190,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const _HomePhotoMissing()),
                  )
                : const _HomePhotoMissing();
              final info=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${passport['home_name']??'My Home'}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
                const SizedBox(height:4),
                Text('${home['address']??''}',style:const TextStyle(color:AppTheme.textMuted)),
                const SizedBox(height:10),
                Wrap(spacing:8,runSpacing:8,children:[
                  _MiniStat(label:'READINESS',value:'${intel['readiness_percent']??0}%'),
                  _MiniStat(label:'SYSTEMS',value:'${intel['systems_documented']??0}'),
                  _MiniStat(label:'OPEN TASKS',value:'${intel['open_maintenance']??0}'),
                  _MiniStat(label:'DOCUMENTS',value:'${intel['documents_saved']??0}'),
                  _MiniStat(label:'INVENTORY',value:'${intel['inventory_items']??0}'),
                ]),
                const SizedBox(height:10),
                Text('${home['property_type']??'Property'} • Built ${home['year_built']??'—'} • Parcel ${home['parcel_number']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                const SizedBox(height:10),
                Wrap(spacing:7,runSpacing:7,children:[
                  FilledButton.tonalIcon(onPressed:_weatherForHome,icon:const Icon(Icons.cloud_outlined),label:const Text('Weather for my home')),
                  OutlinedButton.icon(onPressed:widget.onOpenMap,icon:const Icon(Icons.map_outlined),label:const Text('Open map')),
                ]),
              ]);
              return wide
                ? Row(crossAxisAlignment:CrossAxisAlignment.start,children:[photoWidget,const SizedBox(width:16),Expanded(child:info)])
                : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[photoWidget,const SizedBox(height:12),info]);
            }),
          )),
          const SizedBox(height:12),
          const _ExplainerBanner(
            icon:Icons.fact_check_outlined,
            title:'BridgePoint keeps facts separate from inference',
            message:'Public records, owner-entered facts, professional evidence, and BridgePoint-derived intelligence remain labeled separately. BridgePoint will not tell you a roof, system, or home is “bad” just because of age or a single data point.',
          ),
          const SizedBox(height:14),
          _HomeSection(
            title:'HOME ACTION PLAN',icon:Icons.checklist_rounded,actionLabel:null,onAction:null,
            child:actionRows.isEmpty?_empty('Nothing urgent is currently in your Home Action Plan.'):
              Column(children:actionRows.take(12).map((a)=>ListTile(
                contentPadding:EdgeInsets.zero,
                leading:Icon(a['priority']=='HIGH'?Icons.priority_high_rounded:Icons.task_alt_rounded,color:a['priority']=='HIGH'?AppTheme.amber:AppTheme.cyan),
                title:Text('${a['title']}'),
                subtitle:Text('${a['detail']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                trailing:_OpportunityChip(label:'${a['priority']}',color:a['priority']=='HIGH'?AppTheme.amber:AppTheme.cyan),
              )).toList()),
          ),
          const SizedBox(height:10),
          _HomeSection(
            title:'MY SYSTEMS',icon:Icons.home_repair_service_outlined,actionLabel:'Add system',onAction:_addSystem,
            child:systems.isEmpty?_empty('Add your roof, HVAC, water heater, electrical, plumbing, solar, appliances, and other systems.'):
              Column(children:systems.take(20).map((s)=>ListTile(
                contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.home_repair_service_outlined,color:AppTheme.cyan),
                title:Text('${s['system_name']??s['system_type']}'),
                subtitle:Text('${s['system_type']}'.replaceAll('_',' ')+' • installed ${s['install_date']??'unknown'} • service ${s['last_service_date']??'unknown'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
              )).toList()),
          ),
          const SizedBox(height:10),
          _HomeSection(
            title:'MAINTENANCE',icon:Icons.event_repeat_rounded,actionLabel:'Add task',onAction:_addMaintenance,
            child:maintenance.isEmpty?_empty('No open maintenance tasks yet.'):
              Column(children:maintenance.take(20).map((m)=>ListTile(
                contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.build_circle_outlined,color:AppTheme.cyan),
                title:Text('${m['task_name']}'),
                subtitle:Text('Due ${m['due_on']??'not scheduled'} • ${m['source_type']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                trailing:_OpportunityChip(label:'${m['priority']}',color:m['priority']=='URGENT'||m['priority']=='HIGH'?AppTheme.amber:AppTheme.blue),
              )).toList()),
          ),
          const SizedBox(height:10),
          LayoutBuilder(builder:(context,constraints){
            final width=constraints.maxWidth>=850?(constraints.maxWidth-10)/2:constraints.maxWidth;
            return Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:width,child:_HomeSection(
                title:'DOCUMENTS & WARRANTIES',icon:Icons.folder_copy_outlined,actionLabel:'Add document',onAction:_addDocument,
                child:documents.isEmpty?_empty('Keep deeds, insurance declarations, inspections, warranties, receipts, permits, manuals and other home records together.'):
                  Column(children:documents.take(10).map((d)=>ListTile(
                    dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.description_outlined,color:AppTheme.cyan),
                    title:Text('${d['title']}'),subtitle:Text('${d['document_type']}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                  )).toList()),
              )),
              SizedBox(width:width,child:_HomeSection(
                title:'HOME INVENTORY',icon:Icons.inventory_2_outlined,actionLabel:'Add item',onAction:_addInventory,
                child:inventory.isEmpty?_empty('Create a private room-by-room inventory with receipts, photos, serial numbers, warranties and replacement-value notes.'):
                  Column(children:inventory.take(10).map((item)=>ListTile(
                    dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.chair_outlined,color:AppTheme.cyan),
                    title:Text('${item['item_name']}'),subtitle:Text('${item['room_name']??'Room not set'} • replacement ${item['replacement_value_estimate']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                  )).toList()),
              )),
            ]);
          }),
          const SizedBox(height:10),
          _HomeSection(
            title:'IMPROVEMENTS',icon:Icons.construction_outlined,actionLabel:'Log improvement',onAction:_addImprovement,
            child:improvements.isEmpty?_empty('Log roof replacements, renovations, solar, additions, windows, HVAC upgrades, landscaping, and other major improvements.'):
              Column(children:improvements.take(12).map((item)=>ListTile(
                contentPadding:EdgeInsets.zero,leading:const Icon(Icons.auto_fix_high_outlined,color:AppTheme.green),
                title:Text('${item['project_name']}'),subtitle:Text('${item['project_type']??''} • ${item['completed_on']??'date not set'} • cost ${item['cost']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
              )).toList()),
          ),
          const SizedBox(height:10),
          _HomeSection(
            title:'WHAT CHANGED IN BRIDGEPOINT',icon:Icons.change_circle_outlined,actionLabel:null,onAction:null,
            child:changes.isEmpty?_empty('No stored score changes yet for this property.'):
              Column(children:changes.take(8).map((change){
                final raw=change['score_change'];
                final positive=raw is num?raw>=0:true;
                return ListTile(
                  contentPadding:EdgeInsets.zero,
                  leading:Icon(positive?Icons.trending_up_rounded:Icons.trending_down_rounded,color:positive?AppTheme.green:AppTheme.amber),
                  title:Text('${change['explanation']}'),
                  subtitle:Text(_bpDateTime(change['detected_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                );
              }).toList()),
          ),
          const SizedBox(height:10),
          LayoutBuilder(builder:(context,constraints){
            final width=constraints.maxWidth>=850?(constraints.maxWidth-10)/2:constraints.maxWidth;
            return Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:width,child:_HomeSection(
                title:'NEIGHBORHOOD INTELLIGENCE',icon:Icons.radar_outlined,actionLabel:null,onAction:null,
                child:nearby.isEmpty?_empty('${neighborhood['message']??'No recent nearby BridgePoint signals in the current window.'}'):
                  Column(children:nearby.take(10).map((item)=>ListTile(
                    dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.location_on_outlined,color:AppTheme.cyan),
                    title:Text('${item['title']??item['signal_name']}'),
                    subtitle:Text('${item['distance_km']} km • ${item['full_address']??''} • ${_bpDateTime(item['event_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                  )).toList()),
              )),
              SizedBox(width:width,child:_HomeSection(
                title:'PROPERTY TWINS',icon:Icons.copy_all_outlined,actionLabel:null,onAction:null,
                child:twins.isEmpty?_empty('Similar-property intelligence will appear when enough comparable property facts exist.'):
                  Column(children:twins.take(10).map((item)=>ListTile(
                    dense:true,contentPadding:EdgeInsets.zero,
                    leading:CircleAvatar(backgroundColor:AppTheme.cyan.withOpacity(.12),child:Text('${item['similarity_score']??'—'}',style:const TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900))),
                    title:Text('${item['full_address']}'),
                    subtitle:Text('Built ${item['year_built']??'—'} • value ${item['market_total_value']??'—'} • best opportunity ${item['best_opportunity_score']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
                  )).toList()),
              )),
            ]);
          }),
        ],
      ]),
    );
  }
}
'''

text = text[:start] + replacement + text[end:]
path.write_text(text,encoding='utf-8')
print('Repaired My Home Flutter block v147')
