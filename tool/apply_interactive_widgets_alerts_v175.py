from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# Add the navigation callback to the current Daily Brief route call. Accept both
# the historical compact call and the current dart-formatted call.
if 'onNavigateLabel:_navigateTrainingLabel,' not in text:
    call_pattern=re.compile(
        r"(?P<indent>[ \t]*)return\s+_DailyBriefPage\(\s*"
        r"key:\s*ValueKey\(\s*'brief-\$_liveRefreshTick-\$selectedPackage'\s*\)\s*,\s*"
        r"overview:\s*_OverviewContent\(",
        re.S,
    )
    m=call_pattern.search(text)
    if m is None:
        raise SystemExit('Daily Brief call marker missing v816')
    indent=m.group('indent')
    replacement=(f"{indent}return _DailyBriefPage(\n"
                 f"{indent}  key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),\n"
                 f"{indent}  onNavigateLabel:_navigateTrainingLabel,\n"
                 f"{indent}  overview:_OverviewContent(")
    text=call_pattern.sub(replacement,text,count=1)

old='''class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview});
  final Widget overview;
'''
new='''class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview,required this.onNavigateLabel});
  final Widget overview;
  final ValueChanged<String> onNavigateLabel;
'''
if old not in text:
    # Accept the formatted pre-v164 declaration if a formatter touched this block.
    formatted_pattern=re.compile(
        r"class _DailyBriefPage extends StatefulWidget\s*\{\s*"
        r"const _DailyBriefPage\(\{super\.key,\s*required this\.overview\}\);\s*"
        r"final Widget overview;",
        re.S,
    )
    if len(formatted_pattern.findall(text))!=1:
        raise SystemExit('Daily Brief constructor marker missing v816')
    text=formatted_pattern.sub(new.rstrip('\n'),text,count=1)
else:
    text=text.replace(old,new,1)

panel='''          future:widgetRequest,builder:(context,widgetSnapshot)=>_DashboardWidgetsPanel(
            snapshot:widgetSnapshot,
            onRefresh:()=>setState(()=>widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {})),
          ),
'''
if panel not in text:
    raise SystemExit('dashboard widgets panel call missing')
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
if old_panel not in text:
    raise SystemExit('dashboard widgets class marker missing')
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
if old_tile not in text:
    raise SystemExit('dashboard widget tile marker missing')
text=text.replace(old_tile,'''class _DashboardWidgetTile extends StatelessWidget{
  const _DashboardWidgetTile({required this.config,required this.data,required this.onNavigateLabel});
  final Map<String,dynamic> config,data;
  final ValueChanged<String> onNavigateLabel;
''',1)

tap="onTap:()=>_showInfoDialog(context,_dashboardWidgetTitle(key),detail),"
if tap not in text:
    raise SystemExit('generic widget tap handler missing')
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

for needle in ['tap a widget to open its tool','onNavigateLabel:widget.onNavigateLabel',"key=='UNREAD_ALERTS'",'onNavigateLabel:_navigateTrainingLabel']:
    if needle not in text:
        raise SystemExit(f'missing widget repair marker: {needle}')
if text==original:
    raise SystemExit('no interactive widget changes applied')
path.write_text(text,encoding='utf-8')
print('Applied interactive widgets + alert navigation v175/v816')
