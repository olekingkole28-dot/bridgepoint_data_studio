from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# Add owner-only 60-day campaign status/activation helpers to Growth Center.
state_start=text.find('class _OwnerGrowthPanelState extends State<_OwnerGrowthPanel>{')
state_end=text.find('class _EmergencyAdminPanel',state_start)
if state_start<0 or state_end<0: raise SystemExit('Owner Growth panel block missing')
block=text[state_start:state_end]

method_anchor='  Future<void> saveSettings()async{\n'
methods=r'''  Future<Map<String,dynamic>> _load60DayStatus()=>_callRpc('bridgepoint_social_60_day_status_v196',const {});
  Future<void> _activate60Day()async{
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_activate_social_60_day_v196',const {});
      if(!mounted)return;
      await _showInfoDialog(context,'60-day social campaign activated',
        'Start: ${result['start_date']??'—'}\nEnd: ${result['end_date']??'—'}\nQueue rows: ${result['queue_rows']??0}\nPlatform variants: ${result['variant_rows']??0}\n\nBridgePoint only activates this calendar after all six providers are configured, connected, and every required media asset is attached.');
      refresh();
    }catch(e){if(mounted)_showInfoDialog(context,'Campaign is not publish-ready',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

'''
if method_anchor not in block: raise SystemExit('Growth saveSettings method anchor missing')
if '_load60DayStatus' not in block:block=block.replace(method_anchor,methods+method_anchor,1)

insert_anchor="""        const SizedBox(height:14),
        const Text('NEXT SCHEDULED POSTS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:8),
"""
readiness=r'''        const SizedBox(height:14),
        FutureBuilder<Map<String,dynamic>>(
          future:_load60DayStatus(),
          builder:(context,socialSnap){
            final social=socialSnap.data??const <String,dynamic>{};
            final ready=social['ready_to_activate']==true;
            final connected=(social['connected_platforms'] as num?)?.toInt()??0;
            final configured=(social['configured_platforms'] as num?)?.toInt()??0;
            final missing=(social['missing_media_assets'] as num?)?.toInt()??0;
            final briefs=(social['creative_briefs'] as num?)?.toInt()??0;
            final state='${social['state']??'STAGED'}';
            final pRows=rows(social['platforms']);
            return Container(
              width:double.infinity,padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:(ready?AppTheme.green:AppTheme.amber).withOpacity(.055),borderRadius:BorderRadius.circular(13),border:Border.all(color:(ready?AppTheme.green:AppTheme.amber).withOpacity(.20))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Icon(ready?Icons.verified_rounded:Icons.pending_actions_rounded,color:ready?AppTheme.green:AppTheme.amber,size:20),const SizedBox(width:8),const Expanded(child:Text('60-DAY SOCIAL LAUNCH BANK',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.7))),_OpportunityChip(label:state,color:ready?AppTheme.green:AppTheme.amber)]),
                const SizedBox(height:8),
                Wrap(spacing:7,runSpacing:7,children:[
                  _OpportunityChip(label:'60 DAYS',color:AppTheme.cyan),
                  _OpportunityChip(label:'6 POSTS / DAY',color:AppTheme.blue),
                  _OpportunityChip(label:'$briefs PLATFORM BRIEFS',color:briefs==2160?AppTheme.green:AppTheme.amber),
                  _OpportunityChip(label:'$connected / 6 CONNECTED',color:connected==6?AppTheme.green:AppTheme.amber),
                  _OpportunityChip(label:'$configured / 6 CONFIGURED',color:configured==6?AppTheme.green:AppTheme.amber),
                  _OpportunityChip(label:'$missing MEDIA MISSING',color:missing==0?AppTheme.green:AppTheme.amber),
                ]),
                if(pRows.isNotEmpty)...[const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:pRows.map((r){final live=r['connected']==true;final configured=r['configured']==true;final label='${r['platform']}'.replaceAll('_',' ');return _OpportunityChip(label:'$label • ${live?'CONNECTED':configured?'CONFIGURED':'SETUP NEEDED'}',color:live?AppTheme.green:configured?AppTheme.cyan:AppTheme.amber);}).toList())],
                const SizedBox(height:10),
                Text(ready?'Everything required for automatic publishing is present. Activation creates the complete 60-day schedule only once.':'${social['blocking_reason']??'BridgePoint is holding this campaign until every publish-safety gate passes.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
                const SizedBox(height:10),
                Row(children:[FilledButton.icon(onPressed:busy||!ready?null:_activate60Day,icon:const Icon(Icons.calendar_month_rounded),label:Text(ready?'Activate 60-day calendar':'Waiting for connections + media')),const SizedBox(width:8),const Expanded(child:Text('No social post is marked published unless the provider returns a real publishing response.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)))]),
              ]),
            );
          },
        ),
        const SizedBox(height:14),
        const Text('NEXT SCHEDULED POSTS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:8),
'''
if insert_anchor not in block: raise SystemExit('Growth next-posts insertion anchor missing')
block=block.replace(insert_anchor,readiness,1)
text=text[:state_start]+block+text[state_end:]

# Expansion ETA: explicit manual-approval label instead of a fake near-zero timer.
old="""final etaText='${e?['eta_text']??(status=='SUCCEEDED'?'Complete':'Calculating…')}';"""
new="""final etaText='${s['step_key']=='ACTIVATION_APPROVAL'&&status!='SUCCEEDED'?'Owner approval required':e?['eta_text']??(status=='SUCCEEDED'?'Complete':'Calculating…')}';"""
if old not in text: raise SystemExit('Expansion ETA text anchor missing')
text=text.replace(old,new,1)

for marker in ['60-DAY SOCIAL LAUNCH BANK','bridgepoint_social_60_day_status_v196','Activate 60-day calendar','Owner approval required']:
    if marker not in text: raise SystemExit(f'missing v196 UI marker: {marker}')
if text==original: raise SystemExit('No social readiness/ETA polish changes applied')
p.write_text(text,encoding='utf-8')
print('Applied 60-day social readiness UI and owner-approval ETA polish v196')
