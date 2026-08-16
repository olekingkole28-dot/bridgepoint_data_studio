from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

# Pull the verified auth + telemetry people list returned by owner_dashboard_v84.
replace_once(
"""      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
""",
"""      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
      final recentPeople=rows(usage['recent_people']);
""",
'owner-recent-people-data')

# Clarify the metric so a user understands it combines live heartbeat and recent login evidence.
replace_once(
"""          _MetricCard(width:w,label:'USING NOW',value:_formatInteger(usage['active_now']??0),detail:'Active during the last 5 minutes',icon:Icons.online_prediction_rounded,accent:AppTheme.cyan),
""",
"""          _MetricCard(width:w,label:'USING NOW',value:_formatInteger(usage['active_now']??0),detail:'Heartbeat + very recent authenticated sign-ins',icon:Icons.online_prediction_rounded,accent:AppTheme.cyan),
""",
'owner-active-now-copy')

# Add a visible recent-user panel before the payout card.
marker="""        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(
          alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:18,runSpacing:12,children:[
            SizedBox(width:c.maxWidth>=760?c.maxWidth-260:c.maxWidth,child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Stripe payout readiness',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
"""
if text.count(marker)!=1:
    raise SystemExit('owner payout insertion marker not found exactly once')
panel=r'''        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Recent People Using BridgePoint',subtitle:'Verified Supabase sign-ins + BridgePoint session/activity telemetry',action:'Last 30 days'),
          const SizedBox(height:8),const Text('A real sign-in is counted even if the browser never sends a heartbeat. When telemetry is available, BridgePoint also shows the last page and last activity time.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45)),
          const SizedBox(height:12),
          if(recentPeople.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('No verified sign-ins or BridgePoint activity have been recorded yet.',style:TextStyle(color:AppTheme.textMuted)))
          else ...recentPeople.take(20).map((person){
            final status='${person['presence_status']??'RECENT'}';
            final color=status=='ACTIVE_NOW'?AppTheme.green:status=='TODAY'?AppTheme.cyan:status=='THIS_WEEK'?AppTheme.blue:AppTheme.textMuted;
            final seen=DateTime.tryParse('${person['last_seen_at']??person['last_sign_in_at']??person['account_created_at']??''}')?.toLocal();
            final seenLabel=seen==null?'No activity timestamp':('${seen.month}/${seen.day} • ${(seen.hour%12)==0?12:seen.hour%12}:${seen.minute.toString().padLeft(2,'0')} ${seen.hour>=12?'PM':'AM'}');
            final page='${person['last_page']??''}'.trim();
            final source='${person['tracking_source']??'AUTH'}'.replaceAll('_',' ');
            return Container(
              margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withOpacity(.12))),
              child:Row(children:[
                CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(status=='ACTIVE_NOW'?Icons.person_pin_circle_rounded:Icons.person_outline_rounded,color:color,size:20)),
                const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${person['display_name']??person['email']??'BridgePoint user'}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11)),
                  const SizedBox(height:2),Text('${person['email']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                  const SizedBox(height:3),Text('$seenLabel${page.isEmpty?'':' • last page: $page'} • $source',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
                ])),
                _OpportunityChip(label:status.replaceAll('_',' '),color:color),
              ]),
            );
          }),
        ]))),
'''
text=text.replace("        const SizedBox(height:18),\n        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(\n          alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:18,runSpacing:12,children:[\n            SizedBox(width:c.maxWidth>=760?c.maxWidth-260:c.maxWidth,child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n              Text('Stripe payout readiness',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),\n", panel+"        const SizedBox(height:18),\n        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(\n          alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:18,runSpacing:12,children:[\n            SizedBox(width:c.maxWidth>=760?c.maxWidth-260:c.maxWidth,child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n              Text('Stripe payout readiness',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),\n",1)

if text==original:
    raise SystemExit('No owner recent-user changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint owner recent-people patch v112')
