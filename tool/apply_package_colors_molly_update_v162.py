from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

# Release marker.
release_line="const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';\n"
release_constant="const _bridgePointRelease = String.fromEnvironment('BRIDGEPOINT_RELEASE', defaultValue: 'development');"
if release_constant not in text:
    if text.count(release_line)!=1:
        raise SystemExit('release-constant anchor missing')
    text=text.replace(release_line,release_line+release_constant+'\n',1)

# Workspace restoration/persistence. Accept compact historical and dart-formatted
# owner initialization without changing the modern owner package name.
owner_candidates=[
"""    if(widget.ownerMode)selectedPackage='Owner Full Platform';
    dashboardRequest = _loadDashboard();
""",
"""    if(widget.ownerMode)selectedPackage='All Intelligence';
    dashboardRequest = _loadDashboard();
""",
"""    if (widget.ownerMode) selectedPackage = 'Owner Full Platform';
    dashboardRequest = _loadDashboard();
""",
]
if 'unawaited(_restoreWorkspaceState());' not in text:
    owner_init=next((candidate for candidate in owner_candidates if text.count(candidate)==1),None)
    if owner_init is None:
        raise SystemExit('workspace-restore-init: canonical owner workspace initializer not found')
    text=text.replace(owner_init,
"""    if(widget.ownerMode)selectedPackage='Owner Full Platform';
    dashboardRequest = _loadDashboard();
    unawaited(_restoreWorkspaceState());
""",1)

marker="  Future<void> _recordAppActivity(String eventType, String pageName) async {\n"
persistence=r'''  Future<void> _restoreWorkspaceState()async{
    try{
      final prefs=SharedPreferencesAsync();
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&packages.contains(savedPackage)?savedPackage:selectedPackage);
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
if 'Future<void> _restoreWorkspaceState()' not in text:
    if text.count(marker)!=1:
        raise SystemExit('workspace persistence marker missing')
    text=text.replace(marker,persistence+marker,1)

select_old="""  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
  }
"""
select_new="""  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
    unawaited(_persistWorkspaceState(package:value));
  }
"""
if 'unawaited(_persistWorkspaceState(package:value));' not in text:
    replace_once(select_old,select_new,'persist-package')

nav_old="""    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
"""
nav_new="""    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
    unawaited(_persistWorkspaceState(navigation:index));
"""
if 'unawaited(_persistWorkspaceState(navigation:index));' not in text:
    replace_once(nav_old,nav_new,'persist-navigation')

# Package accent helper.
package_marker='class _LivePackageCard extends StatelessWidget {'
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
if 'Color _bridgePointPackageAccent(' not in text:
    if text.count(package_marker)!=1:
        raise SystemExit('Live package card marker missing')
    text=text.replace(package_marker,helper+package_marker,1)

# Apply v162 coloring on top of the CURRENT package card. Do not remove newer
# server-driven action/delivery state.
card_start=text.find(package_marker)
card_end=text.find('\nclass ',card_start+len(package_marker))
if card_start<0:
    raise SystemExit('Live package card block missing')
if card_end<0:
    card_end=len(text)
block=text[card_start:card_end]

if 'final accent=_bridgePointPackageAccent(key,type);' not in block:
    type_pattern=re.compile(r"(?P<indent>[ \t]*)final type\s*=\s*'\$\{package\['package_type'\]\s*\?\?\s*'standard'\}';\n")
    m=type_pattern.search(block)
    if m is None:
        raise SystemExit('package type semantic anchor missing in modern card')
    indent=m.group('indent')
    addition=(m.group(0)+
              f"{indent}final key='${{package['package_key']??''}}';\n"
              f"{indent}final technology=key.startsWith('technology_')||type.toLowerCase().contains('technology');\n"
              f"{indent}final accent=_bridgePointPackageAccent(key,type);\n")
    block=type_pattern.sub(lambda _:addition,block,count=1)

# Add card-wide color/outline while retaining every modern child/action.
if 'color:accent.withOpacity(technology ? .20 : .13),' not in block:
    card_return=re.compile(r"(?P<indent>[ \t]*)return Card\(\n")
    m=card_return.search(block)
    if m is None:
        raise SystemExit('modern package card return anchor missing')
    indent=m.group('indent')
    replacement=(f"{indent}return Card(\n"
                 f"{indent}  color:accent.withOpacity(technology ? .20 : .13),\n"
                 f"{indent}  shape:RoundedRectangleBorder(\n"
                 f"{indent}    borderRadius:BorderRadius.circular(18),\n"
                 f"{indent}    side:BorderSide(color:accent.withOpacity(technology ? .52 : .30),width:technology?1.35:1),\n"
                 f"{indent}  ),\n")
    block=card_return.sub(replacement,block,count=1)

# Enhance the package icon when the historical icon container is still present;
# otherwise the whole-card accent above is the canonical visual treatment.
icon_old="""                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
"""
icon_new="""                      color: accent.withOpacity(.16),
                      borderRadius: BorderRadius.circular(11),
                      border:Border.all(color:accent.withOpacity(.22)),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: accent,
"""
if icon_old in block:
    block=block.replace(icon_old,icon_new,1)

# Preserve enterprise technology emphasis if that legacy chip still exists.
tech_old="""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:AppTheme.amber),
"""
if tech_old in block:
    block=block.replace(tech_old,
"""                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:Color(0xFFFFC857)),
""",1)

text=text[:card_start]+block+text[card_end:]

# Build/release identifier in legal footer.
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
if 'Running BridgePoint release $_bridgePointRelease' not in text:
    if footer_anchor not in text:
        raise SystemExit('footer build marker anchor missing')
    footer_replacement=footer_anchor+"""            const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            Tooltip(
              message:'Running BridgePoint release $_bridgePointRelease',
              child:Text(
                'Build ${_bridgePointRelease.length>12?_bridgePointRelease.substring(0,12):_bridgePointRelease}',
                style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w700),
              ),
            ),
"""
    text=text.replace(footer_anchor,footer_replacement,1)

required=[
    'unawaited(_restoreWorkspaceState());',
    'unawaited(_persistWorkspaceState(package:value));',
    'unawaited(_persistWorkspaceState(navigation:index));',
    'Color _bridgePointPackageAccent(',
    'final accent=_bridgePointPackageAccent(key,type);',
    'color:accent.withOpacity(technology ? .20 : .13),',
    'Running BridgePoint release $_bridgePointRelease',
]
for item in required:
    if item not in text:
        raise SystemExit(f'v162/v812 marker missing: {item}')

if text==original:
    raise SystemExit('No package colors/update changes applied')
path.write_text(text,encoding='utf-8')
print('Applied modern package colors + workspace persistence + release marker v162/v812')
