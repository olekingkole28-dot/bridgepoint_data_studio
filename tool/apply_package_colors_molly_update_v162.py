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

replace_once(
"""const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';
""",
"""const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';
const _bridgePointRelease = String.fromEnvironment('BRIDGEPOINT_RELEASE', defaultValue: 'development');
""",
'release-constant')

replace_once(
"""    if(widget.ownerMode)selectedPackage='All Intelligence';
    dashboardRequest = _loadDashboard();
""",
"""    if(widget.ownerMode)selectedPackage='All Intelligence';
    dashboardRequest = _loadDashboard();
    unawaited(_restoreWorkspaceState());
""",
'workspace-restore-init')

marker="""  Future<void> _recordAppActivity(String eventType, String pageName) async {
"""
if text.count(marker)!=1:
    raise SystemExit('workspace persistence marker missing')
persistence=r'''  Future<void> _restoreWorkspaceState()async{
    try{
      final prefs=SharedPreferencesAsync();
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final nextPackage=widget.ownerMode?'All Intelligence':(savedPackage!=null&&packages.contains(savedPackage)?savedPackage:selectedPackage);
      final maxIndex=visibleNavigationItems.length-1;
      final nextNav=savedNav==null?selectedNavigation:savedNav.clamp(0,maxIndex);
      if(!mounted)return;
      setState((){
        selectedPackage=nextPackage;
        selectedNavigation=nextNav;
        dashboardRequest=_loadDashboard();
      });
    }catch(_){/* State restoration is convenience only. */}
  }

  Future<void> _persistWorkspaceState({int? navigation,String? package})async{
    try{
      final prefs=SharedPreferencesAsync();
      await prefs.setInt('bp_workspace_navigation',navigation??selectedNavigation);
      await prefs.setString('bp_workspace_package',package??selectedPackage);
    }catch(_){/* Never interrupt the workspace for local persistence. */}
  }

'''
text=text.replace(marker,persistence+marker,1)

replace_once(
"""  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
  }
""",
"""  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
    unawaited(_persistWorkspaceState(package:value));
  }
""",
'persist-package')

replace_once(
"""    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
""",
"""    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
    unawaited(_persistWorkspaceState(navigation:index));
""",
'persist-navigation')

package_marker="""class _LivePackageCard extends StatelessWidget {
"""
if text.count(package_marker)!=1:
    raise SystemExit('Live package card marker missing')
helper=r'''Color _bridgePointPackageAccent(String key,String type){
  final k=key.toLowerCase();
  final t=type.toLowerCase();
  if(k.startsWith('technology_')||t.contains('technology'))return const Color(0xFFFFC857);
  if(k.contains('all_intelligence')||k=='all')return const Color(0xFF63E6FF);
  if(k.contains('homeowner'))return const Color(0xFF56D6A4);
  if(k.contains('commercial'))return const Color(0xFF9D8CFF);
  if(k.contains('roof'))return const Color(0xFFFF9F5A);
  if(k.contains('solar'))return const Color(0xFFFFD65A);
  if(k.contains('invest'))return const Color(0xFF69D27C);
  if(k.contains('develop'))return const Color(0xFFE67ED1);
  if(k.contains('mitigation')||k.contains('restoration'))return const Color(0xFF4FD6C8);
  if(k.contains('home'))return const Color(0xFF5FA8FF);
  if(k.contains('custom'))return const Color(0xFFB98CFF);
  if(k.contains('general'))return const Color(0xFF67B8FF);
  return const Color(0xFF6ECFE8);
}

'''
text=text.replace(package_marker,helper+package_marker,1)

replace_once(
"""    final type = '${package['package_type'] ?? 'standard'}';
    final technology='${package['package_key']??''}'.startsWith('technology_');

    return Card(
      child: InkWell(
""",
"""    final type = '${package['package_type'] ?? 'standard'}';
    final key='${package['package_key']??''}';
    final technology=key.startsWith('technology_')||type.toLowerCase().contains('technology');
    final accent=_bridgePointPackageAccent(key,type);

    return Card(
      color:accent.withOpacity(technology ? .20 : .13),
      shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(18),
        side:BorderSide(color:accent.withOpacity(technology ? .52 : .30),width:technology?1.35:1),
      ),
      child: InkWell(
""",
'package-card-whole-color')

replace_once(
"""                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
""",
"""                      color: accent.withOpacity(.16),
                      borderRadius: BorderRadius.circular(11),
                      border:Border.all(color:accent.withOpacity(.22)),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: accent,
""",
'package-icon-color')

replace_once(
"""                        Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
""",
"""                        Text(
                          technology?'ENTERPRISE TECHNOLOGY':type.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
""",
'package-type-color')

replace_once(
"""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:AppTheme.amber),
""",
"""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:Color(0xFFFFC857)),
""",
'package-tech-chip-gold')

footer_anchor="""            const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () => _callSupport(context),
              child: const Text(
                'Questions or Concerns: 203-605-2389',
                style: TextStyle(fontSize: 9),
              ),
            ),
"""
footer_replacement=footer_anchor+"""            const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            Tooltip(
              message:'Running BridgePoint release $_bridgePointRelease',
              child:Text(
                'Build ${_bridgePointRelease.length>12?_bridgePointRelease.substring(0,12):_bridgePointRelease}',
                style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w700),
              ),
            ),
"""
if footer_anchor not in text:
    raise SystemExit('footer build marker anchor missing')
text=text.replace(footer_anchor,footer_replacement,1)

if text==original:
    raise SystemExit('No package colors/update changes applied')
path.write_text(text,encoding='utf-8')
print('Applied package colors + workspace persistence + release marker v162')
