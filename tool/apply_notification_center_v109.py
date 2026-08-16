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

# Make the Daily Brief unread-alert metric actually open the alert inbox and
# immediately refresh its count when the inbox closes.
replace_once(
"""            _MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
""",
"""            InkWell(
              borderRadius:BorderRadius.circular(12),
              onTap:()async{
                await showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog());
                if(mounted)setState(()=>request=_callRpc('bridgepoint_daily_brief_v74',const {}));
              },
              child:_MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
            ),
""",
'unread-alerts-opens-center')

# Explain the inbox interaction directly in the dialog.
replace_once(
"""    const SizedBox(height:10),Row(children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),const SizedBox(width:8),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),const Divider(),
""",
"""    const SizedBox(height:10),Row(children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),const SizedBox(width:8),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),
    const SizedBox(height:6),const Align(alignment:Alignment.centerLeft,child:Text('Tap any alert to read the full message, source/action target, and timestamp. Opening an unread alert marks it read.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))),const Divider(),
""",
'notification-center-help')

# Existing notification rows were display-only. Make every row interactive,
# show full alert details, and persist read state.
old="""Expanded(child:snapshot.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('No alerts yet. BridgePoint will add them as your intelligence changes.',style:TextStyle(color:AppTheme.textMuted))):ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){final n=items[i];final unread=n['read_at']==null;return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),leading:CircleAvatar(backgroundColor:(unread?AppTheme.cyan:AppTheme.textMuted).withOpacity(.12),child:Icon(_notificationIcon('${n['notification_type']}'),color:unread?AppTheme.cyan:AppTheme.textMuted,size:20)),title:Text('${n['title']}',style:TextStyle(color:Colors.white,fontWeight:unread?FontWeight.w800:FontWeight.w500)),subtitle:Text('${n['message']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),trailing:unread?const Icon(Icons.circle,color:AppTheme.cyan,size:8):null);}))
"""
new="""Expanded(child:snapshot.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('No alerts yet. BridgePoint will add them as your intelligence changes.',style:TextStyle(color:AppTheme.textMuted))):ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){
      final n=items[i];final unread=n['read_at']==null;
      final created=DateTime.tryParse('${n['created_at']??''}')?.toLocal();
      final createdLabel=created==null?'Time unavailable':'${created.month}/${created.day}/${created.year} • ${(created.hour%12)==0?12:created.hour%12}:${created.minute.toString().padLeft(2,'0')} ${created.hour>=12?'PM':'AM'}';
      final action='${n['action_page']??''}'.trim();
      return ListTile(
        contentPadding:const EdgeInsets.symmetric(vertical:4),
        leading:CircleAvatar(backgroundColor:(unread?AppTheme.cyan:AppTheme.textMuted).withOpacity(.12),child:Icon(_notificationIcon('${n['notification_type']}'),color:unread?AppTheme.cyan:AppTheme.textMuted,size:20)),
        title:Text('${n['title']}',style:TextStyle(color:Colors.white,fontWeight:unread?FontWeight.w800:FontWeight.w500)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const SizedBox(height:3),Text('${n['message']}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),
          const SizedBox(height:4),Text('$createdLabel${action.isEmpty?'':' • ${action.replaceAll('_',' ').toUpperCase()}'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w700)),
        ]),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[if(unread)...[const Icon(Icons.circle,color:AppTheme.cyan,size:8),const SizedBox(width:8)],const Icon(Icons.chevron_right_rounded,color:AppTheme.textMuted)]),
        onTap:()async{
          if(unread){
            try{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':n['notification_id']});}catch(_){/* detail still opens even if read-state persistence fails */}
          }
          if(!mounted)return;
          await showDialog<void>(context:context,builder:(detailContext)=>AlertDialog(
            backgroundColor:AppTheme.panel,
            title:Row(children:[Icon(_notificationIcon('${n['notification_type']}'),color:AppTheme.cyan),const SizedBox(width:9),Expanded(child:Text('${n['title']}'))]),
            content:SizedBox(width:580,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${n['message']}',style:const TextStyle(color:Colors.white,fontSize:11,height:1.55)),
              const SizedBox(height:14),Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('TYPE • ${'${n['notification_type']??'ALERT'}'.replaceAll('_',' ')}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),
                const SizedBox(height:5),Text('WHEN • $createdLabel',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
                if(action.isNotEmpty)...[const SizedBox(height:5),Text('RELATED AREA • ${action.replaceAll('_',' ').toUpperCase()}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))],
                if(n['action_id']!=null)...[const SizedBox(height:5),Text('REFERENCE • ${n['action_id']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))],
              ])),
            ])),
            actions:[TextButton(onPressed:()=>Navigator.pop(detailContext),child:const Text('Done'))],
          ));
          if(mounted)setState(()=>request=_load());
        },
      );
    }))
"""
replace_once(old,new,'notification-rows-interactive')

if text==original:
    raise SystemExit('No notification center changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint notification center patch v109')
