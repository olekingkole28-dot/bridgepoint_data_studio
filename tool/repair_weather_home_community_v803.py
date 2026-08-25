from pathlib import Path

main_path = Path('lib/main.dart')
legacy_path = Path('tool/apply_weather_home_community_v145.py')
text = main_path.read_text(encoding='utf-8')
original = text
legacy = legacy_path.read_text(encoding='utf-8')
marker = '// bridgepoint-weather-home-community-v803'

if marker in text:
    print('Weather/Home/Community v803 already applied')
    # The historical workflow will call v145 later. Make that call an audited
    # no-op in this ephemeral release workspace so it cannot rewind navigation.
    legacy_path.write_text(
        "from pathlib import Path\n"
        "text=Path('lib/main.dart').read_text(encoding='utf-8')\n"
        "required=['// bridgepoint-weather-home-community-v803','class _WeatherCenterPage','class _MyHomePage','class _CommunityPage']\n"
        "missing=[x for x in required if x not in text]\n"
        "if missing: raise SystemExit(f'v145 supersession missing markers: {missing}')\n"
        "print('Legacy v145 superseded by modern Weather/Home/Community v803')\n",
        encoding='utf-8',
    )
    raise SystemExit(0)

# Reuse the proven v145 page implementations, but wire them into the current
# navigation model rather than forcing the app back to its pre-Studio layout.
class_prefix = "classes=r'''\n"
class_suffix = "\n'''\ntext=text.replace(marker,classes+marker,1)"
start = legacy.find(class_prefix)
end = legacy.rfind(class_suffix)
if start < 0 or end < 0 or end <= start:
    raise SystemExit('Could not extract v145 Weather/Home/Community classes')
classes = legacy[start + len(class_prefix):end]

nav_anchor = """    _NavigationItem('Intelligence Studio', Icons.schema_rounded),
    _NavigationItem('Integrations', Icons.cable_rounded),
  ];
"""
nav_new = """    _NavigationItem('Intelligence Studio', Icons.schema_rounded),
    _NavigationItem('Integrations', Icons.cable_rounded),
    _NavigationItem('Weather Center', Icons.cloud_outlined),
    _NavigationItem('My Home', Icons.home_rounded),
    _NavigationItem('Community', Icons.groups_2_outlined),
  ];
"""
if text.count(nav_anchor) != 1:
    raise SystemExit(f'v803 navigation anchor expected 1 match, found {text.count(nav_anchor)}')
text = text.replace(nav_anchor, nav_new, 1)

switch_anchor = """      case 14:
        return const BridgePointIntegrationsHub();
      case 15:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(
          title: 'Owner Center',
          icon: Icons.admin_panel_settings_rounded,
        );
"""
switch_new = """      case 14:
        return const BridgePointIntegrationsHub();
      case 15:
        return _WeatherCenterPage(onOpenMap: () => _navigateTo(3));
      case 16:
        return _MyHomePage(
          onOpenWeather: () => _navigateTo(15),
          onOpenMap: () => _navigateTo(3),
        );
      case 17:
        return const _CommunityPage();
      case 18:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(
          title: 'Owner Center',
          icon: Icons.admin_panel_settings_rounded,
        );
"""
if text.count(switch_anchor) != 1:
    raise SystemExit(f'v803 switch anchor expected 1 match, found {text.count(switch_anchor)}')
text = text.replace(switch_anchor, switch_new, 1)

insert_anchor = 'class _FieldModePage extends StatefulWidget {'
if text.count(insert_anchor) != 1:
    raise SystemExit(f'v803 class insertion anchor expected 1 match, found {text.count(insert_anchor)}')
text = text.replace(insert_anchor, marker + '\n' + classes + '\n\n' + insert_anchor, 1)

for required in [
    "_NavigationItem('Weather Center'",
    "_NavigationItem('My Home'",
    "_NavigationItem('Community'",
    'class _WeatherCenterPage',
    'class _MyHomePage',
    'class _CommunityPage',
    'case 18:',
    'BridgePointOwnerCommandCenter',
]:
    if required not in text:
        raise SystemExit(f'v803 required marker missing after repair: {required}')

if text == original:
    raise SystemExit('No Weather/Home/Community v803 changes applied')
main_path.write_text(text, encoding='utf-8')

# The historical workflow calls v145 after v121. Convert that legacy call into
# a strict marker verifier only for this runner checkout; the repository's
# source file stays available as the implementation source above.
legacy_path.write_text(
    "from pathlib import Path\n"
    "text=Path('lib/main.dart').read_text(encoding='utf-8')\n"
    "required=['// bridgepoint-weather-home-community-v803','class _WeatherCenterPage','class _MyHomePage','class _CommunityPage']\n"
    "missing=[x for x in required if x not in text]\n"
    "if missing: raise SystemExit(f'v145 supersession missing markers: {missing}')\n"
    "print('Legacy v145 superseded by modern Weather/Home/Community v803')\n",
    encoding='utf-8',
)
print('Applied modern Weather Center + My Home + Community UI v803')
