from __future__ import annotations

from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v352-national-dashboard-low-io'

if marker in text:
    print('National dashboard v352 already applied')
    raise SystemExit(0)


def once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'v352 {label}: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)


# Daily Brief owns the first incremental national state selection. Other customer
# surfaces remain intentionally untouched until they receive their own compatible layer.
once(
    "  String selectedPackage = 'BridgePoint Home';\n",
    "  String selectedPackage = 'BridgePoint Home';\n  String selectedDashboardStateCode = 'CT';\n  Map<String,dynamic>? _nationalDashboardMarketShellCache;\n  DateTime? _nationalDashboardMarketShellFetchedAt;\n",
    'dashboard state fields',
)

# Replace the legacy CT-only dashboard RPC with a low-I/O state-aware loader.
# BUILDING states read only the lightweight V349 market shell. The expensive V345
# live-count contract is called only when the selected state is actually LIVE and
# customer-visible. The market shell itself is cached for five minutes in the client.
pattern = re.compile(
    r"  Future<Map<String, dynamic>> _loadDashboard\(\) async \{.*?\n  \}\n\n  Future<Map<String, dynamic>> _loadSources\(\) async \{",
    re.S,
)
match = pattern.search(text)
if not match:
    raise SystemExit('v352 dashboard loader anchors missing')
replacement = r'''  Future<Map<String,dynamic>> _loadNationalDashboardMarketShellV352() async {
    final now=DateTime.now();
    final cached=_nationalDashboardMarketShellCache;
    final fetched=_nationalDashboardMarketShellFetchedAt;
    if(cached!=null&&fetched!=null&&now.difference(fetched)<const Duration(minutes:5)){
      return cached;
    }
    final shell=await _callRpc('bridgepoint_flutter_map_state_status_v349',const {});
    _nationalDashboardMarketShellCache=shell;
    _nationalDashboardMarketShellFetchedAt=now;
    return shell;
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final shell=await _loadNationalDashboardMarketShellV352();
    final markets=_detailList(shell['markets']);
    Map<String,dynamic>? market;
    for(final item in markets){
      if('${item['state_code']??''}'.toUpperCase()==selectedDashboardStateCode){market=item;break;}
    }
    if(market==null){
      return <String,dynamic>{
        'complete':true,'state_code':selectedDashboardStateCode,'coverage_truth':'NOT_AVAILABLE',
        'foundation_available':false,'intelligence_available':false,'strict_ready':false,
        'canonical_property_count':0,'active_signals':0,'active_opportunities':0,
        'top_opportunities':const <dynamic>[],'locked':true,'dashboard_low_io_v352':true,
      };
    }
    final foundationCount=market['canonical_property_count']??0;
    final foundation=foundationCount is num?foundationCount>0:'$foundationCount'!='0';
    final hasAccess=market['has_access']==true;
    final live=market['data_status']=='LIVE'&&market['customer_visible']==true&&hasAccess;
    if(!live){
      return <String,dynamic>{
        ...market,
        'complete':true,
        'state_code':selectedDashboardStateCode,
        'coverage_truth':foundation?'FOUNDATION_BUILDING':'NOT_AVAILABLE',
        'foundation_available':foundation,
        'intelligence_available':false,
        'strict_ready':false,
        'active_signals':0,
        'scores':0,
        'active_opportunities':0,
        'top_opportunities':const <dynamic>[],
        'locked':!hasAccess,
        'dashboard_low_io_v352':true,
        'live_count_rpc_used':false,
      };
    }
    final status=await _callRpc('bridgepoint_flutter_state_status_v345',{
      'p_state_code':selectedDashboardStateCode,
    });
    return <String,dynamic>{
      ...market,
      ...status,
      'top_opportunities':const <dynamic>[],
      'dashboard_low_io_v352':true,
      'live_count_rpc_used':true,
    };
  }

  Future<Map<String, dynamic>> _loadSources() async {'''
text = text[:match.start()] + replacement + text[match.end():]

# State changes refresh only Daily Brief. This deliberately does not imply that the
# still-unmigrated opportunities/field/properties surfaces have switched state.
select_package = "  void _selectPackage(String value) {\n"
idx = text.find(select_package)
if idx < 0:
    raise SystemExit('v352 select package anchor missing')
state_method = r'''  void _selectDashboardStateV352(String value) {
    final next=value.trim().toUpperCase();
    if(next.length!=2||next==selectedDashboardStateCode)return;
    setState(() {
      selectedDashboardStateCode=next;
      dashboardRequest=_loadDashboard();
      _liveRefreshTick++;
    });
  }

'''
text = text[:idx] + state_method + text[idx:]

# Keep Daily Brief keyed to its selected state and pass state/control to overview.
once(
    "          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),\n",
    "          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage-$selectedDashboardStateCode'),\n",
    'daily brief key',
)
once(
    "            selectedPackage: selectedPackage,\n            dashboardRequest: dashboardRequest,",
    "            selectedPackage: selectedPackage,\n            selectedStateCode: selectedDashboardStateCode,\n            onStateChanged: _selectDashboardStateV352,\n            dashboardRequest: dashboardRequest,",
    'overview state call',
)
once(
    "    required this.selectedPackage,\n    required this.dashboardRequest,",
    "    required this.selectedPackage,\n    required this.selectedStateCode,\n    required this.onStateChanged,\n    required this.dashboardRequest,",
    'overview constructor',
)
once(
    "  final String selectedPackage;\n  final Future<Map<String, dynamic>> dashboardRequest;",
    "  final String selectedPackage;\n  final String selectedStateCode;\n  final ValueChanged<String> onStateChanged;\n  final Future<Map<String, dynamic>> dashboardRequest;",
    'overview fields',
)
once(
    "                      '$selectedPackage • Connecticut statewide',",
    "                      '$selectedPackage • $selectedStateCode • national Daily Brief',",
    'overview subtitle',
)

# Insert a no-database selector: the U.S. state catalog is stable and the backend
# remains authoritative about availability/access when the dashboard request runs.
metric_class = 'class _MetricGrid extends StatelessWidget {'
idx = text.find(metric_class)
if idx < 0:
    raise SystemExit('v352 metric grid class missing')
selector = r'''const Map<String,String> _bridgePointUsStatesV352={
  'AL':'Alabama','AK':'Alaska','AZ':'Arizona','AR':'Arkansas','CA':'California','CO':'Colorado','CT':'Connecticut','DE':'Delaware','FL':'Florida','GA':'Georgia',
  'HI':'Hawaii','ID':'Idaho','IL':'Illinois','IN':'Indiana','IA':'Iowa','KS':'Kansas','KY':'Kentucky','LA':'Louisiana','ME':'Maine','MD':'Maryland',
  'MA':'Massachusetts','MI':'Michigan','MN':'Minnesota','MS':'Mississippi','MO':'Missouri','MT':'Montana','NE':'Nebraska','NV':'Nevada','NH':'New Hampshire','NJ':'New Jersey',
  'NM':'New Mexico','NY':'New York','NC':'North Carolina','ND':'North Dakota','OH':'Ohio','OK':'Oklahoma','OR':'Oregon','PA':'Pennsylvania','RI':'Rhode Island','SC':'South Carolina',
  'SD':'South Dakota','TN':'Tennessee','TX':'Texas','UT':'Utah','VT':'Vermont','VA':'Virginia','WA':'Washington','WV':'West Virginia','WI':'Wisconsin','WY':'Wyoming',
};

class _DashboardStateSelectorV352 extends StatelessWidget{
  const _DashboardStateSelectorV352({required this.stateCode,required this.onChanged});
  final String stateCode;
  final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context)=>Container(
    constraints:const BoxConstraints(maxWidth:230),
    padding:const EdgeInsets.symmetric(horizontal:10),
    decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.08))),
    child:DropdownButtonHideUnderline(child:DropdownButton<String>(
      value:stateCode,dropdownColor:AppTheme.panelSoft,isExpanded:true,
      icon:const Icon(Icons.expand_more_rounded,size:18),
      items:_bridgePointUsStatesV352.entries.map((entry)=>DropdownMenuItem(value:entry.key,child:Text('${entry.key} • ${entry.value}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)))).toList(),
      onChanged:(value){if(value!=null)onChanged(value);},
    )),
  );
}

class _StateTruthBannerV352 extends StatelessWidget{
  const _StateTruthBannerV352({required this.status});
  final Map<String,dynamic> status;
  @override Widget build(BuildContext context){
    final foundation=status['foundation_available']==true;
    final strict=status['strict_ready']==true&&status['coverage_truth']=='LIVE_INTELLIGENCE';
    final locked=status['locked']==true||status['has_access']==false;
    final color=strict?AppTheme.green:foundation?AppTheme.amber:AppTheme.textMuted;
    final title=strict?'LIVE INTELLIGENCE':foundation?'FOUNDATION BUILDING':'NOT AVAILABLE';
    final body=locked
      ?'This state is visible in the national build map, but your current state entitlement is locked.'
      :strict
        ?'This state has cleared BridgePoint strict readiness. Daily Brief may show verified production intelligence.'
        :foundation
          ?'Canonical property coverage is building. BridgePoint intentionally shows zero intelligence/opportunities here until strict readiness is real.'
          :'BridgePoint does not yet have a production property foundation for this state.';
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:color.withOpacity(.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:color.withOpacity(.28))),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(strict?Icons.verified_rounded:foundation?Icons.construction_rounded:Icons.lock_clock_rounded,color:color,size:20),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('$title • ${status['state_code']??''}',style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.4)),
          const SizedBox(height:4),Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.4)),
        ])),
      ]),
    );
  }
}

'''
text = text[:idx] + selector + text[idx:]

# Place the state selector and truth banner immediately before the existing dashboard
# metrics/error area. This anchor is already used by the isolated broad migration and
# is intentionally narrow/fail-closed here.
once(
    "            const SizedBox(height: 22),\n            if (snapshot.hasError)",
    "            const SizedBox(height: 14),\n            _DashboardStateSelectorV352(stateCode:selectedStateCode,onChanged:onStateChanged),\n            const SizedBox(height: 12),\n            if(data!=null)_StateTruthBannerV352(status:data),\n            const SizedBox(height: 18),\n            if (snapshot.hasError)",
    'dashboard state controls placement',
)

# Replace only the dashboard metric grid so it consumes fields guaranteed by V349/V345.
metric_start = text.find('class _MetricGrid extends StatelessWidget {')
metric_end = text.find('\nclass _MetricCard extends StatelessWidget {', metric_start)
if metric_start < 0 or metric_end < 0:
    raise SystemExit('v352 metric grid boundaries missing')
metric = r'''class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data,required this.loading,required this.onNavigate});
  final Map<String,dynamic>? data;
  final bool loading;
  final ValueChanged<int> onNavigate;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints){
    final width=constraints.maxWidth;final columns=width>=1050?4:(width>=620?2:1);const gap=14.0;final itemWidth=(width-gap*(columns-1))/columns;
    final foundation=data?['foundation_available']==true;final strict=data?['strict_ready']==true&&data?['coverage_truth']=='LIVE_INTELLIGENCE';
    final truth='${data?['coverage_truth']??'NOT_AVAILABLE'}';
    return Wrap(spacing:gap,runSpacing:gap,children:[
      _MetricCard(width:itemWidth,label:'${data?['state_code']??'STATE'} PROPERTIES',value:loading?'—':_formatInteger(data?['canonical_property_count']),detail:foundation?'Canonical property foundation':'Foundation not available',icon:Icons.home_work_outlined,accent:AppTheme.cyan),
      _MetricCard(width:itemWidth,label:'ACTIVE SIGNALS',value:loading?'—':_formatInteger(data?['active_signals']),detail:strict?'Strict live property intelligence':'Zero until strict readiness',icon:Icons.radar_rounded,accent:AppTheme.blue,onTap:strict?()=>onNavigate(5):null),
      _MetricCard(width:itemWidth,label:'COVERAGE TRUTH',value:loading?'SYNCING':(strict?'LIVE':foundation?'BUILDING':'NOT READY'),detail:truth.replaceAll('_',' '),icon:Icons.fact_check_outlined,accent:strict?AppTheme.green:AppTheme.amber),
      _MetricCard(width:itemWidth,label:'STRICT OPPORTUNITIES',value:loading?'—':_formatInteger(data?['active_opportunities']),detail:strict?'Verified production opportunities':'Zero is intentional until LIVE_INTELLIGENCE',icon:Icons.bolt_rounded,accent:AppTheme.green,onTap:strict?()=>onNavigate(1):null),
    ]);
  });
}
'''
text = text[:metric_start] + metric + text[metric_end:]

# The old green strip implied intelligence was live regardless of state readiness.
if "const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green" in text:
    text = text.replace("const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green", "const Text('LIVE WORKSPACE SYNC',style:TextStyle(color:AppTheme.green", 1)

text += "\nconst String _bridgePointNationalDashboardV352='bridgepoint-v352-national-dashboard-low-io | v349 building truth | v345 live-only counts';\n"

# Fail closed on the important performance/truth invariants.
for required in (
    marker,
    'bridgepoint_flutter_map_state_status_v349',
    "'bridgepoint_flutter_state_status_v345'",
    "'live_count_rpc_used':false",
    "'coverage_truth':foundation?'FOUNDATION_BUILDING':'NOT_AVAILABLE'",
    '_DashboardStateSelectorV352',
    '_StateTruthBannerV352',
):
    if required not in text:
        raise SystemExit(f'v352 missing generated marker: {required}')
if '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_dashboard_v57' in text:
    raise SystemExit('v352 legacy CT-only dashboard RPC remains active')

path.write_text(text, encoding='utf-8')
print('BRIDGEPOINT NATIONAL DASHBOARD V352 APPLIED')
print(' - BUILDING states use cached V349 market truth only')
print(' - V345 live counts run only for LIVE + customer-visible + entitled states')
print(' - state selector is local to Daily Brief; other surfaces remain isolated for later migrations')
