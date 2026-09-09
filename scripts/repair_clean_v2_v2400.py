from pathlib import Path


def ensure_transition(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        p.write_text(text.replace(old, new, 1), encoding='utf-8')
        print(f'fixed {label}: {path}')
        return
    if old_count == 0 and new_count == 1:
        print(f'already fixed {label}: {path}')
        return
    raise SystemExit(f'{path}: repair contract drift for {label}; old={old_count}, new={new_count}')


ensure_transition(
    'lib/v2/bridgepoint_products_settings_v2.dart',
    "label:const Text('Help me choose'))]),\n    if(snapshot.connectionState",
    "label:const Text('Help me choose'))])),\n    if(snapshot.connectionState",
    'plans hero Container closure',
)

ensure_transition(
    'lib/v2/bridgepoint_app_v2.dart',
    "final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);\n  return base.copyWith(\n    fontFamily: 'BridgePointGrotesk',",
    "final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'BridgePointGrotesk');\n  return base.copyWith(",
    'Flutter 3.47 ThemeData font family',
)

map_path = Path('lib/v2/bridgepoint_map_weather_v2.dart')
map_text = map_path.read_text(encoding='utf-8')
if "import 'dart:ui' as ui;" not in map_text:
    marker = "import 'dart:math' as math;\n"
    if map_text.count(marker) != 1:
        raise SystemExit('map weather: dart:math import contract drift')
    map_text = map_text.replace(marker, marker + "import 'dart:ui' as ui;\n", 1)
old_paths = map_text.count('final path=Path()')
old_branches = map_text.count('final branch=Path()')
new_paths = map_text.count('final path=ui.Path()')
new_branches = map_text.count('final branch=ui.Path()')
if (old_paths, old_branches, new_paths, new_branches) == (2, 1, 0, 0):
    map_text = map_text.replace('final path=Path()', 'final path=ui.Path()')
    map_text = map_text.replace('final branch=Path()', 'final branch=ui.Path()')
elif (old_paths, old_branches, new_paths, new_branches) != (0, 0, 2, 1):
    raise SystemExit(
        f'map painter Path contract drift: oldPath={old_paths}, oldBranch={old_branches}, '
        f'uiPath={new_paths}, uiBranch={new_branches}'
    )
map_path.write_text(map_text, encoding='utf-8')
print('verified map painter uses dart:ui Path')

ensure_transition(
    'lib/v2/bridgepoint_public_landing_v2.dart',
    '          const ConstrainedBox(\n            constraints: BoxConstraints(maxWidth: 820),',
    '          ConstrainedBox(\n            constraints: const BoxConstraints(maxWidth: 820),',
    'landing hero ConstrainedBox',
)

print('Clean V2 V2400 compiler repairs verified.')
