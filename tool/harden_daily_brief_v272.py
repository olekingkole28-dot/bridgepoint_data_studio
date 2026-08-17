from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v272-daily-brief-resilience'
if marker in body:
    print('Daily Brief resilience v272 already applied.')
    raise SystemExit(0)

helper_anchor='class _DailyBriefPage extends StatefulWidget{\n'
if body.count(helper_anchor)!=1:
    raise SystemExit(f'v272 daily brief helper anchor {body.count(helper_anchor)}')
helper=r'''
Future<Map<String,dynamic>> _bridgePointReadRpcV272(
  String name,
  Map<String,dynamic> body,{
  Duration delay=Duration.zero,
})async{
  if(delay>Duration.zero)await Future<void>.delayed(delay);
  Object? lastError;
  for(var attempt=0;attempt<2;attempt++){
    try{return await _callRpc(name,body);}catch(e){
      lastError=e;
      if(attempt==0)await Future<void>.delayed(const Duration(milliseconds:650));
    }
  }
  throw lastError??Exception('BridgePoint read failed');
}

'''
body=body.replace(helper_anchor,helper+helper_anchor,1)

old_init="""  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {});}
"""
new_init="""  @override void initState(){
    super.initState();
    request=_bridgePointReadRpcV272('bridgepoint_daily_brief_v74',const {});
    widgetRequest=_bridgePointReadRpcV272('bridgepoint_dashboard_widgets_v163',const {},delay:const Duration(milliseconds:300));
    fieldNoteRequest=_bridgePointReadRpcV272('bridgepoint_field_note_of_day_v81',const {},delay:const Duration(milliseconds:650));
  }
  void _refreshAllV272(){
    setState((){
      request=_bridgePointReadRpcV272('bridgepoint_daily_brief_v74',const {});
      widgetRequest=_bridgePointReadRpcV272('bridgepoint_dashboard_widgets_v163',const {},delay:const Duration(milliseconds:300));
      fieldNoteRequest=_bridgePointReadRpcV272('bridgepoint_field_note_of_day_v81',const {},delay:const Duration(milliseconds:650));
    });
  }
"""
if body.count(old_init)!=1:
    raise SystemExit(f'v272 Daily Brief init anchor {body.count(old_init)}')
body=body.replace(old_init,new_init,1)

old_refresh="""            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {});}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
"""
new_refresh="""            IconButton(tooltip:'Refresh Daily Brief',onPressed:_refreshAllV272,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
"""
if body.count(old_refresh)!=1:
    raise SystemExit(f'v272 Daily Brief refresh anchor {body.count(old_refresh)}')
body=body.replace(old_refresh,new_refresh,1)

old_error="""          if(snapshot.hasError)...[const SizedBox(height:12),Text('The Daily Brief could not load yet. Your main workspace is still available.',style:TextStyle(color:AppTheme.amber))],
"""
new_error="""          if(snapshot.hasError)...[
            const SizedBox(height:12),
            _DashboardError(
              title:'Daily Brief could not load',
              message:'BridgePoint could not refresh the main brief on this attempt. Your workspace and stored intelligence are still available.',
              onRetry:_refreshAllV272,
            ),
          ],
"""
if body.count(old_error)!=1:
    raise SystemExit(f'v272 Daily Brief error anchor {body.count(old_error)}')
body=body.replace(old_error,new_error,1)

old_nested="""            InkWell(
              borderRadius:BorderRadius.circular(12),
              onTap:()async{
                await showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog());
                if(mounted)setState(()=>request=_callRpc('bridgepoint_daily_brief_v74',const {}));
              },
              child:InkWell(
              borderRadius:BorderRadius.circular(10),
              onTap:()=>showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog()),
              child:_MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
            ),
            ),
"""
new_nested="""            InkWell(
              borderRadius:BorderRadius.circular(12),
              onTap:()async{
                await showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog());
                if(mounted)setState(()=>request=_bridgePointReadRpcV272('bridgepoint_daily_brief_v74',const {}));
              },
              child:_MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
            ),
"""
if body.count(old_nested)!=1:
    raise SystemExit(f'v272 unread alerts nested InkWell anchor {body.count(old_nested)}')
body=body.replace(old_nested,new_nested,1)

old_widget_error="""    if(snapshot.hasError)return _InlineError(message:snapshot.error.toString());
"""
new_widget_error="""    if(snapshot.hasError)return _DashboardError(title:'Dashboard widgets could not load',message:'The main Daily Brief can still be used. Retry only this widget section.',onRetry:onRefresh);
"""
if body.count(old_widget_error)!=1:
    raise SystemExit(f'v272 widget error anchor {body.count(old_widget_error)}')
body=body.replace(old_widget_error,new_widget_error,1)

old_widget_refresh="""            onRefresh:()=>setState(()=>widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {})),
"""
new_widget_refresh="""            onRefresh:()=>setState(()=>widgetRequest=_bridgePointReadRpcV272('bridgepoint_dashboard_widgets_v163',const {})),
"""
if body.count(old_widget_refresh)!=1:
    raise SystemExit(f'v272 widget refresh anchor {body.count(old_widget_refresh)}')
body=body.replace(old_widget_refresh,new_widget_refresh,1)

old_field_note="""          future:fieldNoteRequest,builder:(context,noteSnapshot){
            final note=noteSnapshot.data;
            if(note==null||note['enabled']!=true)return const SizedBox.shrink();
            return _FieldNoteCard(note:note);
          },
"""
new_field_note="""          future:fieldNoteRequest,builder:(context,noteSnapshot){
            if(noteSnapshot.connectionState==ConnectionState.waiting&&!noteSnapshot.hasData){
              return const Card(child:Padding(padding:EdgeInsets.all(14),child:LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)));
            }
            if(noteSnapshot.hasError){
              return _DashboardError(title:'Field Note could not load',message:'The rest of Daily Brief is still live. Retry this small section when you want.',onRetry:()=>setState(()=>fieldNoteRequest=_bridgePointReadRpcV272('bridgepoint_field_note_of_day_v81',const {})));
            }
            final note=noteSnapshot.data;
            if(note==null||note['enabled']!=true)return const SizedBox.shrink();
            return _FieldNoteCard(note:note);
          },
"""
if body.count(old_field_note)!=1:
    raise SystemExit(f'v272 field note anchor {body.count(old_field_note)}')
body=body.replace(old_field_note,new_field_note,1)

old_overview_error="""            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: onRefresh,
              )
"""
new_overview_error="""            if (snapshot.hasError)
              _DashboardError(
                title:'Intelligence Overview could not load',
                message:'Daily Brief is still available above. This deeper overview feed did not finish on this attempt.',
                onRetry: onRefresh,
              )
"""
overview_count=body.count(old_overview_error)
if overview_count==1:
    body=body.replace(old_overview_error,new_overview_error,1)
else:
    print(f'v272 left ambiguous overview error block unchanged ({overview_count} matches); section-level Daily Brief resilience still applied safely.')

summary_anchor="""          if(top.isNotEmpty)...[const SizedBox(height:18),const Text('Start here today',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:8),
"""
summary_replacement="""          if(snapshot.hasData&&data['generated_at']!=null)...[
            const SizedBox(height:10),
            Text(_bpUpdatedTimeV270(data['generated_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,fontWeight:FontWeight.w700)),
          ],
          if(top.isNotEmpty)...[const SizedBox(height:18),const Text('Start here today',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:8),
"""
if body.count(summary_anchor)!=1:
    raise SystemExit(f'v272 Daily Brief updated time anchor {body.count(summary_anchor)}')
body=body.replace(summary_anchor,summary_replacement,1)

body += "\nconst String _bridgePointDailyBriefResilienceV272='bridgepoint-v272-daily-brief-resilience | Daily Brief could not load | Intelligence Overview could not load | staggered retry';\n"
path.write_text(body,encoding='utf-8')
print('Hardened Daily Brief loading, retries, and section-aware errors v272.')
