from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')

imports="""import 'screens/bridgepoint_owner_ai_cockpit.dart';
import 'screens/bridgepoint_owner_global_control.dart';
"""
if "bridgepoint_owner_ai_cockpit.dart" not in s:
    anchor="import 'package:url_launcher/url_launcher.dart';\n"
    if anchor not in s:
        raise SystemExit('Could not locate Flutter import anchor')
    s=s.replace(anchor,anchor+'\n'+imports,1)

old="""  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode)
      const _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
  ];"""
new="""  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode) ...const [
      _NavigationItem('Owner AI',Icons.auto_awesome_rounded),
      _NavigationItem('Global / Export',Icons.public_rounded),
      _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
    ],
  ];"""
if old in s:
    s=s.replace(old,new,1)
elif "_NavigationItem('Owner AI',Icons.auto_awesome_rounded)" not in s:
    raise SystemExit('Could not locate owner navigation anchor')

old_case="""      case 13:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );"""
new_case="""      case 13:
        if(widget.ownerMode)return const BridgePointOwnerAiCockpit();
        return const _ComingSoonPage(
          title:'Owner AI',icon:Icons.auto_awesome_rounded,
        );
      case 14:
        if(widget.ownerMode)return const BridgePointOwnerGlobalControl();
        return const _ComingSoonPage(
          title:'Global / Export',icon:Icons.public_rounded,
        );
      case 15:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );"""
if old_case in s:
    s=s.replace(old_case,new_case,1)
elif "return const BridgePointOwnerAiCockpit();" not in s:
    raise SystemExit('Could not locate owner page switch anchor')

marker='// bridgepoint-v678-native-owner-global-ai'
if marker not in s:
    s=s.replace("const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';",
                "const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';\n"+marker,1)

required=[
    "bridgepoint_owner_ai_cockpit.dart",
    "bridgepoint_owner_global_control.dart",
    "_NavigationItem('Owner AI',Icons.auto_awesome_rounded)",
    "_NavigationItem('Global / Export',Icons.public_rounded)",
    "return const BridgePointOwnerAiCockpit();",
    "return const BridgePointOwnerGlobalControl();",
    marker,
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('Missing V678 markers: '+repr(missing))

p.write_text(s,encoding='utf-8')
print('Applied native owner AI + global/export controls V678')
