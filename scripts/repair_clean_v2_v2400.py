from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'fixed {path}')


# 1. Close the outer hero Container on the customer plans screen.
replace_once(
    'lib/v2/bridgepoint_products_settings_v2.dart',
    "label:const Text('Help me choose'))]),\n    if(snapshot.connectionState",
    "label:const Text('Help me choose'))])),\n    if(snapshot.connectionState",
)

# 2. Flutter 3.47 accepts fontFamily on ThemeData construction, not copyWith.
replace_once(
    'lib/v2/bridgepoint_app_v2.dart',
    "final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);\n  return base.copyWith(\n    fontFamily: 'BridgePointGrotesk',",
    "final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'BridgePointGrotesk');\n  return base.copyWith(",
)

# 3. Disambiguate Flutter's drawing Path from latlong2's generic Path type.
replace_once(
    'lib/v2/bridgepoint_map_weather_v2.dart',
    "import 'dart:math' as math;\n",
    "import 'dart:math' as math;\nimport 'dart:ui' as ui;\n",
)
path = Path('lib/v2/bridgepoint_map_weather_v2.dart')
text = path.read_text(encoding='utf-8')
old_count = text.count('final path=Path()')
branch_count = text.count('final branch=Path()')
if old_count != 2 or branch_count != 1:
    raise SystemExit(f'map painter Path contract changed: path={old_count}, branch={branch_count}')
text = text.replace('final path=Path()', 'final path=ui.Path()')
text = text.replace('final branch=Path()', 'final branch=ui.Path()')
path.write_text(text, encoding='utf-8')
print('fixed lib/v2/bridgepoint_map_weather_v2.dart Path collision')

# 4. The hero ConstrainedBox cannot be const because its subtree resolves runtime state.
replace_once(
    'lib/v2/bridgepoint_public_landing_v2.dart',
    '          const ConstrainedBox(\n            constraints: BoxConstraints(maxWidth: 820),',
    '          ConstrainedBox(\n            constraints: const BoxConstraints(maxWidth: 820),',
)

print('Clean V2 V2400 repair complete.')
