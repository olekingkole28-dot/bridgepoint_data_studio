from pathlib import Path
import hashlib

path=Path('lib/main.dart')
expected_pre='d1aa4c6e972937b7053bfe94dc9f9c8c677c0cac716b0800bbc3fec48eac3755'
expected_post='81f4d0efea6d22a6bdaeb427d82a83bc3fa4e08848fb2f0c61569ddd80d3ccf3'
raw=path.read_bytes()
actual=hashlib.sha256(raw).hexdigest()
if actual==expected_post:
    print('BridgePoint v325 analyzer-tail repair already applied.')
    raise SystemExit(0)
if actual!=expected_pre:
    raise SystemExit(f'v325 analyzer-tail baseline mismatch: expected {expected_pre}, got {actual}')

body=raw.decode('utf-8')

def once(old,new,label):
    global body
    count=body.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    body=body.replace(old,new,1)

once("""    'Solar Opportunity',
  ];

    'BridgePoint Company',
  List<String> get packages => <String>[
""","""    'Solar Opportunity',
    'BridgePoint Company',
  ];

  List<String> get packages => <String>[
""",'customer package list')

once("""  Future<void> _restoreWorkspaceState()async{
    try{
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final nextPackage=widget.ownerMode?'All Intelligence':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:selectedPackage);
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&packages.contains(savedPackage)?savedPackage:selectedPackage);
      final maxIndex=visibleNavigationItems.length-1;
""","""  Future<void> _restoreWorkspaceState()async{
    try{
      final prefs=SharedPreferencesAsync();
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final fallbackPackage=allowedPackages.contains(selectedPackage)?selectedPackage:(allowedPackages.isNotEmpty?allowedPackages.first:selectedPackage);
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:fallbackPackage);
      final maxIndex=visibleNavigationItems.length-1;
""",'workspace restore')

once("""                      _TopBar(
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
                        packages: packages,
""","""                      _TopBar(
                        desktop: desktop,
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
""",'top bar arguments')

once("""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""","""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  DateTime? get _cloudFrame=>_cloudFrames.isEmpty?null:_cloudFrames[_cloudFrameIndex.clamp(0,_cloudFrames.length-1)];
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""",'cloud frame getter')

out=body.encode('utf-8')
post=hashlib.sha256(out).hexdigest()
if post!=expected_post:
    raise SystemExit(f'v325 analyzer-tail output mismatch: expected {expected_post}, got {post}')
path.write_bytes(out)
print('BridgePoint v325 remaining analyzer blockers repaired.')
