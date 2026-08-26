from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text


def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)


# Imports are independently idempotent so the patch can safely rerun after Dart
# formatting or after one of the modules has already been wired.
owner_import = "import 'screens/bridgepoint_owner_command_center.dart';\n"
if "import 'bridgepoint_intelligence_studio_v790.dart';" not in text:
    if text.count(owner_import) != 1:
        raise SystemExit('enterprise-import-anchor: owner command center import missing/duplicated')
    text = text.replace(
        owner_import,
        owner_import
        + "import 'bridgepoint_intelligence_studio_v790.dart';\n"
        + "import 'bridgepoint_integrations_hub_v790.dart';\n",
        1,
    )
elif "import 'bridgepoint_integrations_hub_v790.dart';" not in text:
    raise SystemExit('enterprise-imports: partial wiring detected')

# Append enterprise surfaces after Settings so all existing customer page indices
# 0-12 remain stable. Owner Center naturally moves from 13 to 15 in owner mode.
nav_anchor = "    _NavigationItem('Settings', Icons.settings_rounded),\n"
if "_NavigationItem('Intelligence Studio', Icons.schema_rounded)" not in text:
    if text.count(nav_anchor) != 1:
        raise SystemExit(f'enterprise-nav-anchor: expected Settings once, found {text.count(nav_anchor)}')
    text = text.replace(
        nav_anchor,
        nav_anchor
        + "    _NavigationItem('Intelligence Studio', Icons.schema_rounded),\n"
        + "    _NavigationItem('Integrations', Icons.cable_rounded),\n",
        1,
    )
elif "_NavigationItem('Integrations', Icons.cable_rounded)" not in text:
    raise SystemExit('enterprise-nav: partial wiring detected')

old_case = """      case 13:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(
          title: 'Owner Center',
          icon: Icons.admin_panel_settings_rounded,
        );
"""
new_case = """      case 13:
        return BridgePointIntelligenceStudio(
          onNavigate: _navigateTo,
          ownerMode: widget.ownerMode,
        );
      case 14:
        return const BridgePointIntegrationsHub();
      case 15:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(
          title: 'Owner Center',
          icon: Icons.admin_panel_settings_rounded,
        );
"""
if 'return BridgePointIntelligenceStudio(' not in text:
    replace_once(old_case, new_case, 'enterprise-route-switch')
else:
    required = [
        'case 14:',
        'return const BridgePointIntegrationsHub();',
        'case 15:',
        'return const BridgePointOwnerCommandCenter();',
    ]
    missing = [marker for marker in required if marker not in text]
    if missing:
        raise SystemExit(f'enterprise-route-switch: partial wiring: {missing}')

# Owner Center used to be page 13; after appending the two enterprise pages it is
# page 15. Keep Studio/Integrations on the intelligence background instead of the
# Daily/owner atmosphere.
old_atmosphere = """        pageIndex == 10 ||
        pageIndex == 12 ||
        pageIndex == 13;
"""
new_atmosphere = """        pageIndex == 10 ||
        pageIndex == 12 ||
        pageIndex == 15;
"""
if old_atmosphere in text:
    text = text.replace(old_atmosphere, new_atmosphere, 1)
elif new_atmosphere not in text:
    raise SystemExit('enterprise-atmosphere: expected owner page index marker not found')

if text == original:
    print('Enterprise Studio / Integrations wiring already applied v790')
else:
    path.write_text(text, encoding='utf-8')
    print('Applied Enterprise Studio / Integrations wiring v790')
