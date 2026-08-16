from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

call="""        return _DailyBriefPage(
          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),
          overview:_OverviewContent("""
if call not in text:raise SystemExit('Daily Brief call marker missing')
text=text.replace(call,"""        return _DailyBriefPage(
          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),
          onNavigateLabel:_navigateTrainingLabel,
          overview:_OverviewContent(""",1)

old='''class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview});
  final Widget overview;
'''
new='''class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview,required this.onNavigateLabel});
  final Widget overview;
  final ValueChanged<String> onNavigateLabel;
'''
if old not in text:raise SystemExit('Daily Brief constructor marker missing')
text=text.replace(old,new,1)

panel='''          future:widgetRequest,builder:(context,widgetSnapshot)=>_DashboardWidgetsPanel(
            snapshot:widgetSnapshot,
            onRefresh:()=>setState(()=>widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {})),
          ),
'''
if panel not in text:raise SystemExit('dashboard widgets panel call missing')
text=text.replace(panel,'''          future:widgetRequest,builder:(context,widgetSnapshot)=>_DashboardWidgetsPanel(
            snapshot:widgetSnapshot,
            onRefresh:()=>setState(()=>widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {})),
            onNavigateLabel:widget.onNavigateLabel,
          ),
''',1)

old_panel='''class _DashboardWidgetsPanel extends StatelessWidget{
  const _DashboardWidgetsPanel({required this.snapshot,required this.onRefresh});
  final AsyncSnapshot<Map<String,dynamic>> snapshot;
  final VoidCallback onRefresh;
'''
if old_panel not in text:raise SystemExit('dashboard widgets class marker missing')
text=text.replace(old_panel,'''class _DashboardWidgetsPanel extends StatelessWidget{
  const _DashboardWidgetsPanel({required this.snapshot,required this.onRefresh,required this.onNavigateLabel});
  final AsyncSnapshot<Map<String,dynamic>> snapshot;
  final VoidCallback onRefresh;
  final ValueChanged<String> onNavigateLabel;
''',1)
text=text.replace('child:_DashboardWidgetTile(config:w,data:data)','child:_DashboardWidgetTile(config:w,data:data,onNavigateLabel:onNavigateLabel)')

old_tile='''class _DashboardWidgetTile extends StatelessWidget{
  const _DashboardWidgetTile({required this.config,required this.data});
  final Map<String,dynamic> config,data;
'''
if old_tile not in text:raise SystemExit('dashboard widget tile marker missing')
text=text.replace(old_tile,'''class _DashboardWidgetTile extends StatelessWidget{
  const _DashboardWidgetTile({required this.config,required this.data,required this.onNavigateLabel});
  final Map<String,dynamic> config,data;
  final ValueChanged<String> onNavigateLabel;
''',1)

tap="onTap:()=>_showInfoDialog(context,_dashboardWidgetTitle(key),detail),"
if tap not in text:raise SystemExit('generic widget tap handler missing')
action=r'''onTap:(){
        if(key=='UNREAD_ALERTS'){
          showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog());
          return;
        }
        final target=switch(key){
          'NEW_OPPORTUNITIES'=>'Opportunities',
          'ROUTE_PROGRESS'=>'Field Mode',
          'WATCHLISTS'=>'My Work',
          'RECENT_CHANGES'=>'Opportunities',
          'TERRITORY_POTENTIAL'=>'Intelligence Map',
          'WEATHER'=>'Weather Center',
          'SUPPORT'=>'Settings',
          _=>null,
        };
        if(target!=null)onNavigateLabel(target);
        else _showInfoDialog(context,_dashboardWidgetTitle(key),detail);
      },'''
text=text.replace(tap,action,1)
text=text.replace(
  "Text('Your layout • drag to reorder • turn widgets on or off'",
  "Text('Your layout • tap a widget to open its tool • Customize to reorder or change it'",
  1,
)

# The Daily Brief unread count should itself open the alert center too.
metric="_MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),"
if metric in text:
    text=text.replace(metric,"""InkWell(
              borderRadius:BorderRadius.circular(10),
              onTap:()=>showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog()),
              child:_MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
            ),""",1)

for needle in ['tap a widget to open its tool','onNavigateLabel:widget.onNavigateLabel',"key=='UNREAD_ALERTS'"]:
    if needle not in text:raise SystemExit(f'missing widget repair marker: {needle}')
if text==original:raise SystemExit('no interactive widget changes applied')
path.write_text(text,encoding='utf-8')
print('Applied interactive widgets + alert navigation v175')
