from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text
def checkpoint(label):
    print('v847 v189 checkpoint',label,{'len':len(text),'wms':text.count('WMSTileLayerOptions('),'maps':text.count('class _IntelligenceMapPage')})
checkpoint('start')

# Section color system: controlled, repeatable accents instead of random colors.
anchor='class _WorkspaceAtmosphere extends StatelessWidget{'
if anchor not in text: raise SystemExit('workspace atmosphere anchor missing')
if 'Color _bridgePointPageAccent(int index)' not in text:
    helper="""Color _bridgePointPageAccent(int index)=>switch(index){
  0=>const Color(0xFF42D6C7),1=>const Color(0xFFFFB35A),2=>const Color(0xFF59C98B),
  3=>const Color(0xFF5CB7FF),4=>const Color(0xFF9A86FF),5=>const Color(0xFFFF78C6),
  6=>const Color(0xFF67C8D7),7=>const Color(0xFF7EDB8F),8=>const Color(0xFFFF9557),
  9=>const Color(0xFF72A7FF),10=>const Color(0xFFD9B65C),11=>const Color(0xFFB88CFF),
  12=>const Color(0xFF67B8C7),13=>const Color(0xFFFF8A72),_=>AppTheme.cyan,
};

"""
    text=text.replace(anchor,helper+anchor,1)

# Side navigation uses the selected section accent.
text=text.replace("final selected = index == selectedIndex;\n\n                return InkWell(","final selected = index == selectedIndex;\n                final accent=_bridgePointPageAccent(index);\n\n                return InkWell(",1)
text=text.replace("? AppTheme.cyan.withOpacity(0.12)\n                          : Colors.transparent,","? accent.withOpacity(0.14)\n                          : Colors.transparent,",1)
text=text.replace("? AppTheme.cyan.withOpacity(0.25)\n                            : Colors.transparent,","? accent.withOpacity(0.36)\n                            : Colors.transparent,",1)
text=text.replace("color: selected ? AppTheme.cyan : AppTheme.textMuted,","color: selected ? accent : AppTheme.textMuted,",1)

# Mobile top bar inherits the current section accent.
old_ctor="""  const _TopBar({
    required this.desktop,
    required this.package,
"""
new_ctor="""  const _TopBar({
    required this.desktop,
    required this.accent,
    required this.package,
"""
if old_ctor not in text: raise SystemExit('TopBar constructor anchor missing')
text=text.replace(old_ctor,new_ctor,1)
text=text.replace("final bool desktop;\n  final String package;","final bool desktop;\n  final Color accent;\n  final String package;",1)
mobile_top="""      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
"""
mobile_top_new="""      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration:BoxDecoration(
          gradient:LinearGradient(colors:[accent.withOpacity(.18),Colors.transparent],begin:Alignment.centerLeft,end:Alignment.centerRight),
          border:Border(bottom:BorderSide(color:accent.withOpacity(.34),width:2)),
        ),
        child: Column(
"""
if mobile_top not in text: raise SystemExit('responsive mobile TopBar anchor missing')
text=text.replace(mobile_top,mobile_top_new,1)
desktop_top="""    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
"""
desktop_top_new="""    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[accent.withOpacity(.07),Colors.transparent],begin:Alignment.centerLeft,end:Alignment.centerRight),
        border:Border(bottom:BorderSide(color:accent.withOpacity(.16),width:1)),
      ),
      child: Row(
"""
if desktop_top not in text: raise SystemExit('responsive desktop TopBar anchor missing')
text=text.replace(desktop_top,desktop_top_new,1)
text=text.replace("_TopBar(\n                        desktop: desktop,","_TopBar(\n                        desktop: desktop,\n                        accent:_bridgePointPageAccent(selectedNavigation),",1)

# Mobile/compact nav chips use per-page accents.
old_compact="""          final item = items[index];
          final selected = index == selectedIndex;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(index),
            avatar: Icon(item.icon, size: 17),
            label: Text(item.label),
          );
"""
new_compact="""          final item = items[index];
          final selected = index == selectedIndex;
          final accent=_bridgePointPageAccent(index);
          return ChoiceChip(
            selected: selected,
            selectedColor:accent.withOpacity(.22),
            side:BorderSide(color:selected?accent.withOpacity(.55):Colors.white10),
            onSelected: (_) => onSelected(index),
            avatar: Icon(item.icon, size: 17,color:selected?accent:AppTheme.textMuted),
            label: Text(item.label,style:TextStyle(color:selected?Colors.white:AppTheme.textMuted,fontWeight:selected?FontWeight.w800:FontWeight.w600)),
          );
"""
if old_compact not in text: raise SystemExit('compact nav anchor missing')
text=text.replace(old_compact,new_compact,1)
checkpoint('navigation')

# Expansion control center now loads adaptive ETAs with the live control response.
old_load="""  Future<void> loadControl()async{
    final state=selectedState;if(state==null)return;
    try{final next=await _callRpc('bridgepoint_expansion_control_center_v90',{'p_run_id':null,'p_state':state});if(mounted)setState(()=>control=next);}catch(e){if(mounted)_showInfoDialog(context,'Expansion status unavailable',e.toString());}
  }
"""
new_load="""  Future<void> loadControl()async{
    final state=selectedState;if(state==null)return;
    try{
      final next=await _callRpc('bridgepoint_expansion_control_center_v90',{'p_run_id':null,'p_state':state});
      final run=next['run'];
      if(next['found']==true&&run is Map&&run['run_id']!=null){
        try{next['eta']=await _callRpc('bridgepoint_expansion_eta_v188',{'p_run_id':run['run_id']});}catch(_){ }
      }
      if(mounted)setState(()=>control=next);
    }catch(e){if(mounted)_showInfoDialog(context,'Expansion status unavailable',e.toString());}
  }
"""
if old_load not in text: raise SystemExit('expansion loadControl anchor missing')
text=text.replace(old_load,new_load,1)

# Add ETA model in expansion card.
old_vars="""        final steps=rows(control!['steps']),approvals=rows(control!['pending_approvals']),incidents=rows(control!['open_incidents']);
        final done=steps.where((s)=>['SUCCEEDED','SKIPPED'].contains('${s['step_status']}')).length;
"""
new_vars="""        final steps=rows(control!['steps']),approvals=rows(control!['pending_approvals']),incidents=rows(control!['open_incidents']);
        final eta=control!['eta'] is Map?Map<String,dynamic>.from(control!['eta'] as Map):<String,dynamic>{};
        final etaSteps=rows(eta['steps']);
        Map<String,dynamic>? etaFor(String key){for(final e in etaSteps){if('${e['step_key']}'==key)return e;}return null;}
        final done=steps.where((s)=>['SUCCEEDED','SKIPPED'].contains('${s['step_status']}')).length;
"""
if old_vars not in text: raise SystemExit('expansion vars anchor missing')
text=text.replace(old_vars,new_vars,1)
old_progress="""          const SizedBox(height:8),LinearProgressIndicator(value:progress,minHeight:7,color:AppTheme.cyan,backgroundColor:AppTheme.panelSoft),const SizedBox(height:5),Text('${(progress*100).round()}% governed steps complete • ${approvals.length} approval${approvals.length==1?'':'s'} waiting • ${incidents.length} incident${incidents.length==1?'':'s'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
"""
new_progress="""          const SizedBox(height:8),LinearProgressIndicator(value:progress,minHeight:7,color:_bridgePointPageAccent(13),backgroundColor:AppTheme.panelSoft),const SizedBox(height:5),Text('${(progress*100).round()}% governed steps complete • ${approvals.length} approval${approvals.length==1?'':'s'} waiting • ${incidents.length} incident${incidents.length==1?'':'s'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
          if(eta.isNotEmpty)...[const SizedBox(height:8),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.05),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:Row(children:[const Icon(Icons.schedule_rounded,color:AppTheme.cyan,size:18),const SizedBox(width:8),Expanded(child:Text('Current step ETA: ${eta['current_step_eta_minutes']==null?'calculating':'${((eta['current_step_eta_minutes'] as num).toDouble()/60).toStringAsFixed(1)} hours'} • estimates recalculate from live throughput',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))) ]))],
"""
if old_progress not in text: raise SystemExit('expansion progress anchor missing')
text=text.replace(old_progress,new_progress,1)

old_steps="""          const SizedBox(height:12),const Text('BUILD PROGRESS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...steps.map((s){final status='${s['step_status']}';return Padding(padding:const EdgeInsets.only(top:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:9,height:9,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:statusColor(status),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['step_name']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)),Text('$status${s['last_error']!=null?' • ${s['last_error']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35))]))]));}),
"""
new_steps="""          const SizedBox(height:12),const Text('BUILD PROGRESS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...steps.map((s){final status='${s['step_status']}';final e=etaFor('${s['step_key']}');final etaText='${e?['eta_text']??(status=='SUCCEEDED'?'Complete':'Calculating…')}';final pct=(e?['progress_pct'] as num?)?.toDouble();return Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:statusColor(status).withOpacity(.035),borderRadius:BorderRadius.circular(9),border:Border.all(color:statusColor(status).withOpacity(.10))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:9,height:9,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:statusColor(status),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['step_name']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)),const SizedBox(height:2),Text('$status • ETA $etaText${e?['estimate_basis']!=null?' • ${e?['estimate_basis']}':''}${s['last_error']!=null?' • ${s['last_error']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35)),if(pct!=null&&status!='SUCCEEDED')...[const SizedBox(height:5),LinearProgressIndicator(value:(pct/100).clamp(0.0,1.0),minHeight:3,color:statusColor(status),backgroundColor:Colors.white10)] ]))]));}),
"""
if old_steps not in text: raise SystemExit('expansion steps UI anchor missing')
text=text.replace(old_steps,new_steps,1)
checkpoint('expansion')

# Intelligence map: visibly advertise markets actively being built.
old_cov="""        final coverageMarkets=_detailList(coverage['markets']);
        final highPriority = points.where((p) {
"""
new_cov="""        final coverageMarkets=_detailList(coverage['markets']);
        final buildingMarkets=coverageMarkets.where((m)=>'${m['data_status']}'=='BUILDING').toList();
        final highPriority = points.where((p) {
"""
if old_cov not in text: raise SystemExit('coverage market anchor missing')
text=text.replace(old_cov,new_cov,1)
checkpoint('map_coverage')

old_marker="""          final requested=market['interest_registered']==true;
          markers.add(Marker(point:center,width:74,height:56,child:Tooltip(
            message:'${market['state_name']} • ${market['data_status']}',
            child:GestureDetector(onTap:()=>_showStateCoverageDialog(context,market,_reload),child:Container(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
              decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.93),borderRadius:BorderRadius.circular(12),border:Border.all(color:(requested?AppTheme.cyan:AppTheme.amber).withOpacity(.8)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.28),blurRadius:8)]),
              child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(requested?Icons.notifications_active_rounded:Icons.lock_outline_rounded,color:requested?AppTheme.cyan:AppTheme.amber,size:18),Text(code,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))]),
            )),
          )));
"""
new_marker="""          final requested=market['interest_registered']==true;final building=market['data_status']=='BUILDING';final marketColor=building?AppTheme.green:requested?AppTheme.cyan:AppTheme.amber;
          markers.add(Marker(point:center,width:92,height:64,child:Tooltip(
            message:'${market['state_name']} • ${market['data_status']}${building?' • BridgePoint is actively building this state now':''}',
            child:GestureDetector(onTap:()=>_showStateCoverageDialog(context,market,_reload),child:Container(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
              decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.95),borderRadius:BorderRadius.circular(12),border:Border.all(color:marketColor.withOpacity(.9),width:1.5),boxShadow:[BoxShadow(color:marketColor.withOpacity(.20),blurRadius:12,spreadRadius:1)]),
              child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(building?Icons.construction_rounded:requested?Icons.notifications_active_rounded:Icons.lock_outline_rounded,color:marketColor,size:18),Text(code,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)),if(building)Text('BUILDING NOW',style:TextStyle(color:marketColor,fontSize:6.5,fontWeight:FontWeight.w900,letterSpacing:.4))]),
            )),
          )));
"""
if old_marker not in text: raise SystemExit('coverage marker anchor missing')
text=text.replace(old_marker,new_marker,1)
checkpoint('map_marker')

old_heading="""            _PageHeading(
              title: 'Intelligence Map',
              subtitle:
                  '${widget.packageName} • live Connecticut intelligence with visible expansion markets',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
"""
new_heading="""            _PageHeading(
              title: 'Intelligence Map',
              subtitle:'${widget.packageName} • live property intelligence with visible expansion markets',
              onRefresh: _reload,loading: loading,
            ),
            if(buildingMarkets.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.22))),child:Row(children:[const _PulseDot(color:AppTheme.green),const SizedBox(width:9),Expanded(child:Text('BUILDING NOW • ${buildingMarkets.map((m)=>'${m['state_name']} (${m['state_code']})').join(' • ')} • Tap the state marker to see coverage status.',style:const TextStyle(color:Colors.white,fontSize:9.5,fontWeight:FontWeight.w800))) ]))],
            const SizedBox(height: 18),
"""
if old_heading not in text: raise SystemExit('map heading anchor missing')
text=text.replace(old_heading,new_heading,1)
checkpoint('map_heading')

if text.count('WMSTileLayerOptions(')<3 or len(text)<int(len(original)*0.8):
    raise SystemExit(f'v189 destructive mutation blocked: before={len(original)} after={len(text)} wms={text.count("WMSTileLayerOptions(")}')
for marker in ['_bridgePointPageAccent','bridgepoint_expansion_eta_v188','BUILDING NOW','Current step ETA:']:
    if marker not in text: raise SystemExit(f'missing v189 marker {marker}')
if text==original: raise SystemExit('No v189 premium navigation/expansion changes applied')
p.write_text(text,encoding='utf-8')
print('Applied premium navigation colors, build-state map status, and expansion ETAs v189')
