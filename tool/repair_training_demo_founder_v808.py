from pathlib import Path
import re

main_path = Path('lib/main.dart')
legacy_path = Path('tool/apply_training_demo_founder_v159.py')
text = main_path.read_text(encoding='utf-8')
legacy = legacy_path.read_text(encoding='utf-8')
original = text
legacy_original = legacy

# Normalize formatting-only boundaries that v159 legitimately owns. These are
# applied before v151/v157; those later layers do not change these boundaries.

# Owner navigation getter.
nav_expected = """  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode)
      const _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
  ];
"""
if nav_expected not in text:
    nav_pattern = re.compile(
        r"  List<_NavigationItem> get visibleNavigationItems\s*=>\s*\[\s*"
        r"\.\.\.navigationItems,\s*if \(widget\.ownerMode\)\s*"
        r"const _NavigationItem\(\s*'Owner Center',\s*Icons\.admin_panel_settings_rounded\),\s*\];",
        re.S,
    )
    matches = list(nav_pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f'v808 owner navigation boundary expected 1 match, found {len(matches)}')
    text = nav_pattern.sub(nav_expected.rstrip('\n'), text, count=1)

# Automatic walkthrough boundary.
walk_expected = """    unawaited(_recordAppActivity('SESSION_START', 'Daily Brief'));
    if(!widget.ownerMode){
      WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());
    }
"""
if walk_expected not in text:
    walk_pattern = re.compile(
        r"    unawaited\(_recordAppActivity\('SESSION_START', 'Daily Brief'\)\);\s*"
        r"if \(!widget\.ownerMode\) \{\s*"
        r"WidgetsBinding\.instance\s*\.addPostFrameCallback\(\(_\) => _maybeOfferWalkthrough\(\)\);\s*\}",
        re.S,
    )
    matches = list(walk_pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f'v808 walkthrough boundary expected 1 match, found {len(matches)}')
    text = walk_pattern.sub(walk_expected.rstrip('\n'), text, count=1)

# v159's small settings matcher must affect Settings only, not Studio.
settings_pattern = re.compile(r"(return _SettingsPage\(\s*)ownerMode:\s*widget\.ownerMode,", re.S)
settings_matches = list(settings_pattern.finditer(text))
if len(settings_matches) != 1:
    raise SystemExit(f'v808 settings owner boundary expected 1 match, found {len(settings_matches)}')
text = settings_pattern.sub(r"\1ownerMode:widget.ownerMode,", text, count=1)

# Top-bar notification callback boundary expected by v159.
top_callback_expected = """                        onNotifications: () => showDialog<void>(
                          context:context,
                          builder:(context)=>const _NotificationCenterDialog(),
                        ),
"""
if top_callback_expected not in text:
    callback_pattern = re.compile(
        r"(?P<indent>[ \t]*)onNotifications:\s*\(\)\s*=>\s*showDialog<void>\(\s*"
        r"context:\s*context,\s*builder:\s*\(context\)\s*=>\s*const _NotificationCenterDialog\(\),\s*\),",
        re.S,
    )
    matches = list(callback_pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f'v808 topbar notification callback expected 1 match, found {len(matches)}')
    text = callback_pattern.sub(top_callback_expected.rstrip('\n'), text, count=1)

main_path.write_text(text, encoding='utf-8')

# Modernize only the two semantic assumptions in the historical v159 script:
# owner route indexes/class and the retired _OwnerCenterPage class marker.
old_switch = '''replace_once(
"""      case 17:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
""",
"""      case 17:
        if(_effectiveOwnerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(title:'Owner Center',icon:Icons.admin_panel_settings_rounded);
      case 18:
        if(_effectiveOwnerMode)return _OwnerDemoPage(onNavigateLabel:_navigateTrainingLabel);
        return const _ComingSoonPage(title:'Owner Demo',icon:Icons.slideshow_rounded);
      case 19:
        if(_effectiveOwnerMode)return _FounderCommandPage(
          onReplayWalkthrough:()=>_openWalkthrough(replay:true),
          onOpenDemo:()=>_navigateTo(18),
          onStartCustomerPreview:_startCustomerPreview,
          onNavigateLabel:_navigateTrainingLabel,
        );
        return const _ComingSoonPage(title:'Founder Command',icon:Icons.command_rounded);
""",
'owner-demo-founder-switch')'''
new_switch = '''replace_once(
"""      case 18:
        return const _AboutBridgePointPage();
      case 19:
        if (widget.ownerMode) return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(
          title: 'Owner Center',
          icon: Icons.admin_panel_settings_rounded,
        );
""",
"""      case 18:
        return const _AboutBridgePointPage();
      case 19:
        if(_effectiveOwnerMode)return const BridgePointOwnerCommandCenter();
        return const _ComingSoonPage(title:'Owner Center',icon:Icons.admin_panel_settings_rounded);
      case 20:
        if(_effectiveOwnerMode)return _OwnerDemoPage(onNavigateLabel:_navigateTrainingLabel);
        return const _ComingSoonPage(title:'Owner Demo',icon:Icons.slideshow_rounded);
      case 21:
        if(_effectiveOwnerMode)return _FounderCommandPage(
          onReplayWalkthrough:()=>_openWalkthrough(replay:true),
          onOpenDemo:()=>_navigateTo(20),
          onStartCustomerPreview:_startCustomerPreview,
          onNavigateLabel:_navigateTrainingLabel,
        );
        return const _ComingSoonPage(title:'Founder Command',icon:Icons.command_rounded);
""",
'owner-demo-founder-switch')'''
if old_switch not in legacy:
    raise SystemExit('v808 could not find historical v159 owner switch definition')
legacy = legacy.replace(old_switch, new_switch, 1)
legacy = legacy.replace(
    "owner_marker='class _OwnerCenterPage extends StatefulWidget{'",
    "owner_marker='class _FieldModePage extends StatefulWidget {'",
    1,
)
legacy = legacy.replace(
    "raise SystemExit('Owner Center marker missing for training/founder classes')",
    "raise SystemExit('Field Mode marker missing for training/founder classes')",
    1,
)

if text == original and legacy == legacy_original:
    print('Training/demo/founder v808 compatibility already present')
else:
    legacy_path.write_text(legacy, encoding='utf-8')
    print('Prepared modern Owner Demo + Founder Command compatibility v159/v808')
