from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v265-simplified-owner-center'
if marker in body:
    print('Simplified Owner Center v265 already applied.')
    raise SystemExit(0)

state_anchor="""class _OwnerCenterPageState extends State<_OwnerCenterPage>{
  late Future<Map<String,dynamic>> request;
"""
state_replace="""class _OwnerCenterPageState extends State<_OwnerCenterPage>{
  late Future<Map<String,dynamic>> request;
  bool showDetailedMetrics=false;
  bool showOperations=false;
  bool showAdvanced=false;
"""
if body.count(state_anchor)!=1:
    raise SystemExit(f'v265 owner state anchor count {body.count(state_anchor)}')
body=body.replace(state_anchor,state_replace,1)

body=body.replace(
  "_PageHeading(title:'Owner Center',subtitle:'Revenue • customers • outreach • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting)",
  "_PageHeading(title:'Owner Center',subtitle:'Today’s decisions first • deeper controls only when you need them',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting)",
  1,
)
body=body.replace(
  "message:healthy?'Start here each day. This page combines customer growth, revenue readiness, promotion use, automation health, and intelligence production.':'BridgePoint detected a current automation issue. The recovery panel only shows jobs whose latest run still needs attention and clears automatically after a successful rerun.',",
  "message:healthy?'Your critical owner numbers are summarized below. Open Growth & Operations or Advanced Admin only when you need the deeper controls.':'BridgePoint detected a current automation issue. Open Growth & Operations to inspect Automation Recovery; recovered jobs clear automatically after a successful rerun.',",
  1,
)

owner_start=body.find('class _OwnerCenterPageState extends State<_OwnerCenterPage>')
if owner_start<0: raise SystemExit('v265 owner class missing')
metrics_start=body.find("        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;",owner_start)
metrics_end=body.find("        const SizedBox(height:18),",metrics_start)
if metrics_start<0 or metrics_end<0: raise SystemExit(f'v265 metrics anchors {metrics_start} {metrics_end}')
new_metrics=r'''        Card(child:Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showDetailedMetrics=!showDetailedMetrics),
            icon:Icon(showDetailedMetrics?Icons.expand_less_rounded:Icons.insights_rounded,size:17),
            label:Text(showDetailedMetrics?'Hide detailed metrics':'Detailed metrics'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOperations=!showOperations),
            icon:Icon(showOperations?Icons.expand_less_rounded:Icons.workspaces_outline,size:17),
            label:Text(showOperations?'Hide growth & operations':'Growth & operations'),
          ),
          OutlinedButton.icon(
            onPressed:()=>setState(()=>showAdvanced=!showAdvanced),
            icon:Icon(showAdvanced?Icons.expand_less_rounded:Icons.admin_panel_settings_outlined,size:17),
            label:Text(showAdvanced?'Hide advanced admin':'Advanced admin'),
          ),
          if(!healthy)OutlinedButton.icon(
            onPressed:()=>setState(()=>showOperations=true),
            icon:const Icon(Icons.warning_amber_rounded,color:AppTheme.red,size:17),
            label:const Text('Open recovery'),
          ),
        ]))),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:w,label:'CUSTOMERS',value:_formatInteger(customers['total_accounts']??0),detail:'${customers['new_24h']??0} today • ${customers['new_7d']??0} this week',icon:Icons.groups_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'ACTIVE MRR',value:money(revenue['active_mrr']),detail:'${customers['active_paid']??0} active paid accounts',icon:Icons.payments_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'TRIAL PIPELINE',value:money(revenue['trial_pipeline_mrr']),detail:'${customers['active_trials']??0} active customer trials',icon:Icons.hourglass_top_rounded,accent:AppTheme.amber),
          _MetricCard(width:w,label:'VERIFIED OPPORTUNITIES',value:_formatInteger(intel['verified_unique_opportunities']??0),detail:'Unique properties with named direct evidence',icon:Icons.verified_rounded,accent:AppTheme.red),
          _MetricCard(width:w,label:'CUSTOMER PROSPECT TARGET',value:'${_formatInteger(outreach['tracked_contacts']??0)} / ${_formatInteger(outreach['target_contacts']??500)}',detail:'${_formatInteger(outreach['remaining_to_target']??500)} remaining',icon:Icons.campaign_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'OUTREACH REPLIES',value:_formatInteger(outreach['replies']??0),detail:'${_formatInteger(outreach['interested']??0)} interested • ${_formatInteger(outreach['not_interested']??0)} not interested',icon:Icons.mark_email_read_rounded,accent:AppTheme.blue),
          if(showDetailedMetrics)...[
            _MetricCard(width:w,label:'USING NOW',value:_formatInteger(usage['active_now']??0),detail:'Very recent authenticated activity',icon:Icons.online_prediction_rounded,accent:AppTheme.cyan),
            _MetricCard(width:w,label:'TODAY / 7 DAYS',value:'${_formatInteger(usage['daily_active']??0)} / ${_formatInteger(usage['weekly_active']??0)}',detail:'Unique people who opened BridgePoint',icon:Icons.insights_rounded,accent:AppTheme.blue),
            _MetricCard(width:w,label:'30-DAY USERS',value:_formatInteger(usage['monthly_active']??0),detail:'${usage['page_views_7d']??0} page views this week',icon:Icons.calendar_month_rounded,accent:const Color(0xFF9B7BFF)),
            _MetricCard(width:w,label:'EMAILS SENT',value:_formatInteger(outreach['emails_sent']??0),detail:'${_formatInteger(outreach['emails_delivered']??0)} delivered',icon:Icons.outgoing_mail,accent:AppTheme.blue),
            _MetricCard(width:w,label:'OUTREACH CONVERSIONS',value:_formatInteger(outreach['trials_started']??0),detail:'${_formatInteger(outreach['paid_customers']??0)} paid customers',icon:Icons.trending_up_rounded,accent:AppTheme.amber),
            _MetricCard(width:w,label:'STRATEGIC TARGETS',value:_formatInteger(strategic['total']??0),detail:'${_formatInteger(strategic['high_priority']??0)} high priority • ${_formatInteger(strategic['sent']??0)} sent',icon:Icons.account_balance_rounded,accent:const Color(0xFF9B7BFF)),
          ],
        ]);}),
'''
body=body[:metrics_start]+new_metrics+body[metrics_end:]

operations_start=body.find("        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;",metrics_start+len(new_metrics))
if operations_start<0: raise SystemExit('v265 operations layout missing')
body=body[:operations_start]+"        if(showOperations)"+body[operations_start:]

advanced_anchor="""        const SizedBox(height:18),const _OwnerExpansionPanel(),
"""
if body.count(advanced_anchor)!=1:
    raise SystemExit(f'v265 advanced anchor count {body.count(advanced_anchor)}')
body=body.replace(advanced_anchor,"""        if(showAdvanced)...[
        const SizedBox(height:18),const _OwnerExpansionPanel(),
""",1)

error_anchor="""        if(snapshot.hasError)...[const SizedBox(height:16),_DashboardError(message:snapshot.error.toString(),onRetry:refresh)],
"""
if body.count(error_anchor)!=1:
    raise SystemExit(f'v265 owner error anchor count {body.count(error_anchor)}')
body=body.replace(error_anchor,"""        ],
        if(snapshot.hasError)...[const SizedBox(height:16),_DashboardError(title:'Owner Center could not load',message:snapshot.error.toString(),onRetry:refresh)],
""",1)

body += "\nconst String _bridgePointSimplifiedOwnerCenterV265='bridgepoint-v265-simplified-owner-center | Today’s decisions first | Growth & operations | Advanced admin';\n"
path.write_text(body,encoding='utf-8')
print('Applied simplified executive-first Owner Center v265.')
