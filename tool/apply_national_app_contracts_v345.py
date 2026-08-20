from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text
marker = 'bridgepoint-v345-national-app-contracts'

if marker in text:
    print('National app contracts v345 already applied')
    raise SystemExit(0)


def once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 anchor, found {count}')
    text = text.replace(old, new, 1)

# Workspace state: one generic selected state drives every core customer surface.
once(
    "  String selectedPackage = 'BridgePoint Home';\n",
    "  String selectedPackage = 'BridgePoint Home';\n  String selectedStateCode = 'CT';\n",
    'workspace selected state',
)

# Dashboard is now the state truth contract plus package-safe opportunities. It no longer
# depends on the legacy Connecticut dashboard payload.
start = text.find('  Future<Map<String, dynamic>> _loadDashboard() async {')
end = text.find('\n  Future<Map<String, dynamic>> _loadSources() async {', start)
if start < 0 or end < 0:
    raise SystemExit('dashboard loader anchors missing')
text = text[:start] + """  Future<Map<String, dynamic>> _loadDashboard() async {
    final status = await _callRpc('bridgepoint_flutter_state_status_v345', {
      'p_state_code': selectedStateCode,
    });
    final opportunities = await _callRpc('bridgepoint_flutter_opportunities_state_v341', {
      'p_state_code': selectedStateCode,
      'p_model_key': packageModelKeys[selectedPackage] ?? 'all',
      'p_limit': 10,
      'p_offset': 0,
      'p_priority': null,
      'p_stage': null,
    });
    return <String,dynamic>{
      ...status,
      'top_opportunities': opportunities['opportunities'] ?? const <dynamic>[],
      'active_opportunities': opportunities['total_results'] ?? status['active_opportunities'] ?? 0,
      'package_locked': opportunities['locked'] == true,
    };
  }
""" + text[end:]

# Changing state is a first-class workspace action; preserve the current package and page.
needle = "  void _selectPackage(String value) {\n"
idx = text.find(needle)
if idx < 0:
    raise SystemExit('select package anchor missing')
method = """  void _selectState(String value) {
    final next = value.trim().toUpperCase();
    if(next.length != 2 || next == selectedStateCode) return;
    setState(() {
      selectedStateCode = next;
      dashboardRequest = _loadDashboard();
      _liveRefreshTick++;
    });
  }

"""
text = text[:idx] + method + text[idx:]

# Core page constructors now receive the selected state. v350 has already added ownerMode
# to the map constructor by the time this release layer runs.
once(
    "          modelKey: packageModelKeys[selectedPackage] ?? 'all',\n          packageName: selectedPackage,\n        );\n      case 2:\n        return _FieldModePage(\n",
    "          modelKey: packageModelKeys[selectedPackage] ?? 'all',\n          packageName: selectedPackage,\n          stateCode: selectedStateCode,\n        );\n      case 2:\n        return _FieldModePage(\n",
    'opportunity state arg',
)
once(
    "          modelKey: packageModelKeys[selectedPackage] ?? 'all',\n          packageName: selectedPackage,\n        );\n      case 3:\n        return _IntelligenceMapPage(\n",
    "          modelKey: packageModelKeys[selectedPackage] ?? 'all',\n          packageName: selectedPackage,\n          stateCode: selectedStateCode,\n        );\n      case 3:\n        return _IntelligenceMapPage(\n",
    'field state arg',
)
# Map call can contain the ownerMode line injected by v350.
map_call = "          packageName: selectedPackage,\n          ownerMode: _effectiveOwnerMode,\n        );"
if map_call in text:
    text = text.replace(map_call, "          packageName: selectedPackage,\n          stateCode: selectedStateCode,\n          ownerMode: _effectiveOwnerMode,\n        );", 1)
else:
    map_call_raw = "          packageName: selectedPackage,\n        );\n      case 4:"
    if map_call_raw not in text:
        raise SystemExit('map state arg anchor missing')
    text = text.replace(map_call_raw, "          packageName: selectedPackage,\n          stateCode: selectedStateCode,\n        );\n      case 4:", 1)
once("      case 4:\n        return const _PropertiesPage();", "      case 4:\n        return _PropertiesPage(stateCode:selectedStateCode);", 'properties state arg')

# Dashboard overview receives state for truthful labels.
once(
    "            selectedPackage: selectedPackage,\n            dashboardRequest: dashboardRequest,",
    "            selectedPackage: selectedPackage,\n            selectedStateCode: selectedStateCode,\n            dashboardRequest: dashboardRequest,",
    'overview state arg',
)

# Top bar receives a generic state selector. This intentionally uses the geographic catalog
# only as a selector/catalog; all intelligence still comes from v345/v341 contracts.
once(
    "                        package: selectedPackage,\n",
    "                        package: selectedPackage,\n                        stateCode: selectedStateCode,\n                        onStateChanged: _selectState,\n",
    'topbar state call',
)

once(
    "    required this.package,\n    required this.packages,",
    "    required this.package,\n    required this.stateCode,\n    required this.onStateChanged,\n    required this.packages,",
    'topbar ctor state',
)
once(
    "  final String package;\n  final List<String> packages;",
    "  final String package;\n  final String stateCode;\n  final ValueChanged<String> onStateChanged;\n  final List<String> packages;",
    'topbar fields state',
)

# Insert reusable state selector before the top bar.
topbar_class = 'class _TopBar extends StatelessWidget {'
idx = text.find(topbar_class)
if idx < 0:
    raise SystemExit('topbar class missing')
selector = r'''class _NationalStateSelector extends StatefulWidget {
  const _NationalStateSelector({required this.stateCode,required this.onChanged,this.compact=false});
  final String stateCode;
  final ValueChanged<String> onChanged;
  final bool compact;
  @override State<_NationalStateSelector> createState()=>_NationalStateSelectorState();
}

class _NationalStateSelectorState extends State<_NationalStateSelector>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,
    builder:(context,snapshot){
      final markets=_detailList(snapshot.data?['markets']);
      markets.sort((a,b)=>'${a['state_name']??a['state_code']}'.compareTo('${b['state_name']??b['state_code']}'));
      final codes=<String>{widget.stateCode,...markets.map((m)=>'${m['state_code']}'.toUpperCase()).where((v)=>v.length==2)};
      final byCode=<String,Map<String,dynamic>>{for(final m in markets)'${m['state_code']}'.toUpperCase():m};
      return Container(
        constraints:BoxConstraints(maxWidth:widget.compact?126:166),
        padding:const EdgeInsets.symmetric(horizontal:10),
        decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.08))),
        child:DropdownButtonHideUnderline(child:DropdownButton<String>(
          value:widget.stateCode,
          dropdownColor:AppTheme.panelSoft,
          isExpanded:true,
          icon:const Icon(Icons.expand_more_rounded,size:18),
          items:codes.map((code){final m=byCode[code];final name='${m?['state_name']??code}';final truth='${m?['data_status']??''}';return DropdownMenuItem(value:code,child:Tooltip(message:'$name${truth.isEmpty?'':' • $truth'}',child:Text(widget.compact?code:'$code • $name',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))));}).toList(),
          onChanged:(value){if(value!=null)widget.onChanged(value);},
        )),
      );
    },
  );
}

'''
text = text[:idx] + selector + text[idx:]

# Add state selector to both responsive top-bar layouts.
once(
    "                Expanded(child: _packageSelector()),\n                const SizedBox(width: 8),\n                _IconButton(\n                  icon: Icons.ios_share_rounded,",
    "                Expanded(child: _packageSelector()),\n                const SizedBox(width: 8),\n                _NationalStateSelector(stateCode:stateCode,onChanged:onStateChanged,compact:true),\n                const SizedBox(width: 8),\n                _IconButton(\n                  icon: Icons.ios_share_rounded,",
    'mobile state selector',
)
once(
    "          _packageSelector(),\n          const SizedBox(width: 12),\n          _IconButton(\n            icon: Icons.ios_share_rounded,",
    "          _packageSelector(),\n          const SizedBox(width: 10),\n          _NationalStateSelector(stateCode:stateCode,onChanged:onStateChanged),\n          const SizedBox(width: 12),\n          _IconButton(\n            icon: Icons.ios_share_rounded,",
    'desktop state selector',
)

# Global property autocomplete now uses the v345 state property contract rather than CT-only suggestions.
once(
    "    required this.onSubmitted,\n    required this.onPropertySelected,",
    "    required this.onSubmitted,\n    required this.onPropertySelected,\n    required this.stateCode,",
    'searchbox ctor state',
)
once(
    "  final ValueChanged<String> onSubmitted;\n  final ValueChanged<Map<String, dynamic>> onPropertySelected;",
    "  final ValueChanged<String> onSubmitted;\n  final ValueChanged<Map<String, dynamic>> onPropertySelected;\n  final String stateCode;",
    'searchbox field state',
)
once(
    "              onSubmitted: onSearch,\n              onPropertySelected: onPropertySelected,",
    "              onSubmitted: onSearch,\n              onPropertySelected: onPropertySelected,\n              stateCode: stateCode,",
    'searchbox call state',
)
once(
    "            final result=await _callRpc('bridgepoint_flutter_property_suggestions_v77',{\n              'p_query':query,'p_state_code':'CT','p_limit':8,\n            });\n            return _detailList(result['suggestions']);",
    "            final result=await _callRpc('bridgepoint_flutter_properties_state_v345',{\n              'p_state_code':stateCode,'p_search':query,'p_municipality':null,'p_property_type':null,'p_limit':8,'p_offset':0,\n            });\n            return _detailList(result['properties']);",
    'national search contract',
)
once("                          Text('${option['municipality']??'Connecticut'} • Parcel ${option['parcel_number']??'not listed'}'", "                          Text('${option['municipality']??stateCode} • ${option['state_code']??stateCode} • Parcel ${option['parcel_number']??'not listed'}'", 'search result state copy')

# Sync strip is truthful even when the selected state has foundation only.
text = text.replace("const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green", "const Text('LIVE WORKSPACE SYNC',style:TextStyle(color:AppTheme.green", 1)

# Overview: state truth replaces Connecticut-only dashboard semantics.
once(
    "    required this.selectedPackage,\n    required this.dashboardRequest,",
    "    required this.selectedPackage,\n    required this.selectedStateCode,\n    required this.dashboardRequest,",
    'overview ctor state',
)
once(
    "  final String selectedPackage;\n  final Future<Map<String, dynamic>> dashboardRequest;",
    "  final String selectedPackage;\n  final String selectedStateCode;\n  final Future<Map<String, dynamic>> dashboardRequest;",
    'overview field state',
)
once("                      '$selectedPackage • Connecticut statewide',", "                      '$selectedPackage • $selectedStateCode • state-aware national workspace',", 'overview subtitle')

# Add state truth banner before metrics.
once(
    "            const SizedBox(height: 22),\n            if (snapshot.hasError)",
    "            const SizedBox(height: 14),\n            if(data!=null)_StateTruthBanner(status:data),\n            const SizedBox(height: 18),\n            if (snapshot.hasError)",
    'state truth banner placement',
)

# Make the dashboard metric grid use only fields guaranteed by state_status_v345.
metric_start = text.find('class _MetricGrid extends StatelessWidget {')
metric_end = text.find('\nclass _MetricCard extends StatelessWidget {', metric_start)
if metric_start < 0 or metric_end < 0:
    raise SystemExit('metric grid anchors missing')
metric = r'''class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data,required this.loading,required this.onNavigate});
  final Map<String,dynamic>? data;
  final bool loading;
  final ValueChanged<int> onNavigate;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints){
    final width=constraints.maxWidth;final columns=width>=1050?4:(width>=620?2:1);const gap=14.0;final itemWidth=(width-gap*(columns-1))/columns;
    final foundation=data?['foundation_available']==true;final intelligence=data?['intelligence_available']==true;final strict=data?['strict_ready']==true;
    final truth='${data?['coverage_truth']??'NOT_AVAILABLE'}';
    return Wrap(spacing:gap,runSpacing:gap,children:[
      _MetricCard(width:itemWidth,label:'${data?['state_code']??'STATE'} PROPERTIES',value:loading?'—':_formatInteger(data?['canonical_property_count']),detail:foundation?'Canonical parcel/property foundation':'Foundation not available',icon:Icons.home_work_outlined,accent:AppTheme.cyan,onTap:()=>onNavigate(4)),
      _MetricCard(width:itemWidth,label:'ACTIVE SIGNALS',value:loading?'—':_formatInteger(data?['active_signals']),detail:intelligence?'Real property-linked intelligence exists':'No property intelligence published yet',icon:Icons.radar_rounded,accent:AppTheme.blue,onTap:()=>onNavigate(5)),
      _MetricCard(width:itemWidth,label:'COVERAGE TRUTH',value:loading?'SYNCING':(strict?'STRICT READY':intelligence?'PARTIAL':foundation?'FOUNDATION':'NOT READY'),detail:truth.replaceAll('_',' '),icon:Icons.fact_check_outlined,accent:strict?AppTheme.green:AppTheme.amber),
      _MetricCard(width:itemWidth,label:'STRICT OPPORTUNITIES',value:loading?'—':_formatInteger(data?['active_opportunities']),detail:'Verified package-safe opportunities; zero is a valid result',icon:Icons.bolt_rounded,accent:AppTheme.green,onTap:()=>onNavigate(1)),
    ]);
  });
}

class _StateTruthBanner extends StatelessWidget{
  const _StateTruthBanner({required this.status});
  final Map<String,dynamic> status;
  @override Widget build(BuildContext context){
    final foundation=status['foundation_available']==true;final intelligence=status['intelligence_available']==true;final strict=status['strict_ready']==true;final truth='${status['coverage_truth']??'NOT_AVAILABLE'}';
    final color=strict?AppTheme.green:foundation?AppTheme.amber:AppTheme.textMuted;
    final title=strict?'STRICT INTELLIGENCE READY':foundation?'FOUNDATION BUILDING / PARTIAL':'NOT AVAILABLE';
    final body=strict
      ?'This state has a property foundation plus production intelligence that cleared BridgePoint strict readiness gates.'
      :foundation&&intelligence
        ?'The property foundation is live and real intelligence exists, but the state has not cleared full strict-readiness gates. Scores/evidence may be visible where valid; missing opportunities are not filled in.'
        :foundation
          ?'The property foundation is available. Customer intelligence is intentionally empty until real signals, scores, and strict opportunities exist.'
          :'BridgePoint does not yet have a production property foundation for this state.';
    return Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:color.withOpacity(.07),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withOpacity(.24))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(strict?Icons.verified_rounded:foundation?Icons.construction_rounded:Icons.lock_outline_rounded,color:color),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${status['state_name']??status['state_code']??'State'} • $title',style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45)),const SizedBox(height:5),Text('Contract truth: $truth • foundation ${foundation?'yes':'no'} • intelligence ${intelligence?'yes':'no'} • strict ${strict?'yes':'no'}',style:TextStyle(color:Colors.white.withOpacity(.42),fontSize:8.5,fontWeight:FontWeight.w700))]))]));
  }
}
'''
text = text[:metric_start] + metric + text[metric_end:]

# Replace Connecticut coverage card with a generic status-driven card.
cov_start = text.find('class _CoveragePanel extends StatelessWidget {')
cov_end = text.find('\nclass _SourcesPanel extends StatelessWidget {', cov_start)
if cov_start < 0 or cov_end < 0:
    raise SystemExit('coverage panel anchors missing')
coverage_panel = r'''class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.data,required this.loading});
  final Map<String,dynamic>? data;
  final bool loading;
  @override Widget build(BuildContext context){
    final state='${data?['state_name']??data?['state_code']??'Selected state'}';final code='${data?['state_code']??''}';final truth='${data?['coverage_truth']??'NOT_AVAILABLE'}'.replaceAll('_',' ');
    return Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _PanelHeader(title:'$state Coverage',subtitle:'Production state truth • no simulated completeness',action:code),
      const SizedBox(height:16),
      Container(height:132,width:double.infinity,decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.08),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.location_on_rounded,color:AppTheme.cyan,size:34),const SizedBox(height:6),Text(code.isEmpty?'STATE':code,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18,letterSpacing:1.4)),const SizedBox(height:3),Text(truth,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,fontWeight:FontWeight.w800))]))),
      const SizedBox(height:14),
      _CoverageRow('Canonical properties',loading?'—':_formatCompact(data?['canonical_property_count']),AppTheme.cyan),
      _CoverageRow('Active property signals',loading?'—':_formatInteger(data?['active_signals']),AppTheme.blue),
      _CoverageRow('Strict opportunities',loading?'—':_formatInteger(data?['active_opportunities']),AppTheme.green),
      _CoverageRow('Strict readiness',loading?'—':(data?['strict_ready']==true?'READY':'PARTIAL'),data?['strict_ready']==true?AppTheme.green:AppTheme.amber),
    ])));
  }
}
'''
text = text[:cov_start] + coverage_panel + text[cov_end:]

# Opportunities page: constructor + v341 state contract.
once(
    "  const _OpportunitiesPage({\n    required this.modelKey,\n    required this.packageName,\n  });",
    "  const _OpportunitiesPage({\n    required this.modelKey,\n    required this.packageName,\n    required this.stateCode,\n  });",
    'opportunities ctor',
)
once(
    "  final String modelKey;\n  final String packageName;\n\n  @override\n  State<_OpportunitiesPage>",
    "  final String modelKey;\n  final String packageName;\n  final String stateCode;\n\n  @override\n  State<_OpportunitiesPage>",
    'opportunities fields',
)
# Two legacy opportunity RPCs exist: the page and Field Mode. Rename both first.
legacy_opp_count = text.count('bridgepoint_flutter_opportunities_v57')
if legacy_opp_count != 2:
    raise SystemExit(f'expected 2 legacy opportunity calls, found {legacy_opp_count}')
text = text.replace('bridgepoint_flutter_opportunities_v57','bridgepoint_flutter_opportunities_state_v341')
# Add state code immediately before model key in both opportunity bodies.
opp_body = "'p_model_key':widget.modelKey"
count = text.count(opp_body)
if count < 2:
    raise SystemExit(f'opportunity body anchors missing: {count}')
text = text.replace(opp_body, "'p_state_code':widget.stateCode,'p_model_key':widget.modelKey", 2)
# Reload opportunities when state changes.
text = text.replace("if (oldWidget.modelKey != widget.modelKey) {", "if (oldWidget.modelKey != widget.modelKey || oldWidget.stateCode != widget.stateCode) {", 1)
# Opportunity heading becomes state-aware if the known v341 copy is present.
text = text.replace("'${widget.packageName} • live ranked property intelligence'", "'${widget.packageName} • ${widget.stateCode} • live ranked property intelligence'", 1)

# Field Mode gets the same state contract and update behavior.
once(
    "  const _FieldModePage({required this.modelKey,required this.packageName});\n  final String modelKey;\n  final String packageName;",
    "  const _FieldModePage({required this.modelKey,required this.packageName,required this.stateCode});\n  final String modelKey;\n  final String packageName;\n  final String stateCode;",
    'field ctor state',
)
once(
    "if(oldWidget.modelKey!=widget.modelKey){selected.clear();request=_load();}",
    "if(oldWidget.modelKey!=widget.modelKey||oldWidget.stateCode!=widget.stateCode){selected.clear();request=_load();}",
    'field update state',
)
text = text.replace("'${widget.packageName} • top houses • simple routing • fast follow-up'", "'${widget.packageName} • ${widget.stateCode} • top houses • simple routing • fast follow-up'", 1)

# Map gets selected-state filtering through v345; remove the legacy signal-map call so a
# non-CT state cannot inherit Connecticut signal markers. Geographic catalog remains for
# nationwide build/lock dots and weather remains nationwide.
map_ctor_old = "    required this.packageName,\n    required this.ownerMode,\n  });\n\n  final String modelKey;\n  final String packageName;\n  final bool ownerMode;"
map_ctor_new = "    required this.packageName,\n    required this.stateCode,\n    required this.ownerMode,\n  });\n\n  final String modelKey;\n  final String packageName;\n  final String stateCode;\n  final bool ownerMode;"
if map_ctor_old in text:
    text=text.replace(map_ctor_old,map_ctor_new,1)
else:
    raw="    required this.packageName,\n  });\n\n  final String modelKey;\n  final String packageName;"
    if raw not in text: raise SystemExit('map ctor state anchor missing')
    text=text.replace(raw,"    required this.packageName,\n    required this.stateCode,\n  });\n\n  final String modelKey;\n  final String packageName;\n  final String stateCode;",1)
# Map update guard (first map-specific occurrence after map class).
map_idx=text.find('class _IntelligenceMapPageState')
map_guard="if (oldWidget.modelKey != widget.modelKey) {"
guard_idx=text.find(map_guard,map_idx)
if guard_idx<0: raise SystemExit('map update guard missing')
text=text[:guard_idx]+text[guard_idx:].replace(map_guard,"if (oldWidget.modelKey != widget.modelKey || oldWidget.stateCode != widget.stateCode) {",1)

map_load_start=text.find('  Future<Map<String, dynamic>> _load() async {',map_idx)
map_load_end=text.find('\n  void _reload() => setState(() => _request = _load());',map_load_start)
if map_load_start<0 or map_load_end<0: raise SystemExit('map loader anchors missing')
map_loader=r'''  Future<Map<String, dynamic>> _load() async {
    final results=await Future.wait<Map<String,dynamic>>([
      _callRpc('bridgepoint_flutter_intelligence_map_state_v345',{
        'p_state_code':widget.stateCode,'p_model_key':widget.modelKey,
        'p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,
        'p_min_score':_minimumScore,'p_limit':500,
      }),
      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}),
      _callRpc('bridgepoint_flutter_state_status_v345',{'p_state_code':widget.stateCode}),
    ]);
    return <String,dynamic>{
      ...results[0],
      'coverage_catalog':results[1],
      'state_status':results[2],
      'signal_map':const <String,dynamic>{'signals':<dynamic>[]},
    };
  }
'''
text=text[:map_load_start]+map_loader+text[map_load_end:]
# Score field in v345 points is `score`, not legacy `opportunity_score`.
text=text.replace("((p['opportunity_score'] as num?)?.toDouble() ?? 0)","((p['score'] as num?)?.toDouble() ?? 0)",1)
text=text.replace("(point['opportunity_score'] as num?)?.toDouble()","(point['score'] as num?)?.toDouble()",1)
text=text.replace("(point['opportunity_confidence_percent'] as num?)?.toDouble()","(point['confidence_score'] as num?)?.toDouble()",1)
# Add selected state to the final v350 subtitle rather than implying every state has intelligence.
text=text.replace("'${widget.packageName} • nationwide weather + build status for everyone • purchased intelligence only inside entitled states'", "'${widget.packageName} • ${widget.stateCode} intelligence • nationwide weather + build status • state truth enforced'",1)

# Properties page: state-aware v345 inventory, no hard-coded CT counts/copy.
once("class _PropertiesPage extends StatefulWidget {\n  const _PropertiesPage();", "class _PropertiesPage extends StatefulWidget {\n  const _PropertiesPage({required this.stateCode});\n  final String stateCode;", 'properties ctor state')
# Insert didUpdateWidget after initState method.
prop_state=text.find('class _PropertiesPageState')
init_end=text.find('  @override\n  void dispose()',prop_state)
if init_end<0: raise SystemExit('properties init anchor missing')
insert="  @override\n  void didUpdateWidget(covariant _PropertiesPage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.stateCode!=widget.stateCode){_offset=0;_request=_load();}}\n\n"
text=text[:init_end]+insert+text[init_end:]
text=text.replace('bridgepoint_flutter_properties\'','bridgepoint_flutter_properties_state_v345\'',1)
prop_body="          body: jsonEncode({\n            'p_search': _search,"
if prop_body not in text: raise SystemExit('properties body anchor missing')
text=text.replace(prop_body,"          body: jsonEncode({\n            'p_state_code': widget.stateCode,\n            'p_search': _search,",1)
text=text.replace("'Connecticut property universe • search, inspect, and open intelligence'","'${widget.stateCode} property universe • foundation facts + truthful attached intelligence'",1)
text=text.replace("value: '1,282,833',\n                      detail: 'Imported Connecticut CAMA / parcel rows',","value: _formatInteger(data?['total_results']),\n                      detail: '${widget.stateCode} canonical property records',",1)
text=text.replace("title: 'Connecticut Properties',","title: '${widget.stateCode} Properties',",1)

# Property cards must not synthesize CT addresses.
once(
    "    final displayAddress = address.trim().isEmpty || address == '${property['postal_code']}, CT'\n        ? '$municipality, CT • $parcel'\n        : address;",
    "    final stateCode='${property['state_code']??''}';\n    final displayAddress = address.trim().isEmpty\n        ? '$municipality${stateCode.isEmpty?'':', $stateCode'} • $parcel'\n        : address;",
    'property address state',
)
# v345 uses best_score rather than legacy final_score.
text=text.replace("final score = property['final_score'] as num?;","final score = (property['best_score'] ?? property['final_score']) as num?;",1)

# Property detail gets state from the selected property and calls v345.
once(
    "  final propertyId = property['property_id']?.toString();\n  if (propertyId == null || propertyId.isEmpty) return;",
    "  final propertyId = property['property_id']?.toString();\n  final stateCode='${property['state_code']??''}'.trim().toUpperCase();\n  if (propertyId == null || propertyId.isEmpty || stateCode.length!=2) return;",
    'property detail state extraction',
)
once(
    "builder: (context) => _PropertyIntelligenceDialog(propertyId: propertyId),",
    "builder: (context) => _PropertyIntelligenceDialog(propertyId: propertyId,stateCode:stateCode),",
    'property detail dialog state call',
)
once(
    "  const _PropertyIntelligenceDialog({required this.propertyId});\n\n  final String propertyId;",
    "  const _PropertyIntelligenceDialog({required this.propertyId,required this.stateCode});\n\n  final String propertyId;\n  final String stateCode;",
    'property detail ctor state',
)
text=text.replace('bridgepoint_flutter_property_detail_v57','bridgepoint_flutter_property_detail_state_v345',1)
once("body: jsonEncode({'p_property_id': widget.propertyId}),","body: jsonEncode({'p_state_code':widget.stateCode,'p_property_id': widget.propertyId}),",'property detail body state')

# The state contract returns no legacy summary/physical extras. Existing UI already treats
# them as optional maps/lists; keep the rich CT timeline when available but never fabricate it.

# Final national guard: legacy core RPCs must be absent from generated customer surfaces.
for forbidden in (
    'bridgepoint_flutter_dashboard_v57',
    'bridgepoint_flutter_intelligence_map_v57',
    'bridgepoint_flutter_opportunities_v57',
    "bridgepoint_flutter_properties'",
    'bridgepoint_flutter_property_detail_v57',
):
    if forbidden in text:
        raise SystemExit(f'legacy national core dependency remains: {forbidden}')

required=[
    'bridgepoint_flutter_state_status_v345',
    'bridgepoint_flutter_properties_state_v345',
    'bridgepoint_flutter_property_detail_state_v345',
    'bridgepoint_flutter_intelligence_map_state_v345',
    'bridgepoint_flutter_opportunities_state_v341',
    'FOUNDATION BUILDING / PARTIAL',
    'LIVE WORKSPACE SYNC',
    'selectedStateCode',
]
for needle in required:
    if needle not in text:
        raise SystemExit(f'missing national app contract marker: {needle}')

text += "\nconst String _bridgePointNationalAppContractsV345='bridgepoint-v345-national-app-contracts | state-aware v345/v341 core surfaces | truthful foundation/intelligence/strict readiness';\n"
if text == original:
    raise SystemExit('national app v345 produced no changes')
path.write_text(text,encoding='utf-8')
print('Applied national app contracts v345')
