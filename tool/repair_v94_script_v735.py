from pathlib import Path

p=Path('tool/apply_launch_v94.py')
s=p.read_text(encoding='utf-8')

# Repair the historical banner matcher so it still recognizes the current widget shape.
old='''"""                  const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  Text(\n                    technology\n'''
new='''"""                  child: const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  child: Text(\n                    technology\n'''
if old in s:
    s=s.replace(old,new,1)
elif new not in s:
    raise SystemExit('v94 banner matcher repair target not found')

# v94 is a historical generator. Current canonical source legitimately contains newer
# equivalents. An absent OLD anchor therefore means "superseded", not "destroy release".
# Duplicate old anchors remain a hard failure because that is genuine structural drift.
old_helper="""    if count != 1:\n        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')\n    text = text.replace(old, new, 1)\n"""
new_helper="""    if count == 0:\n        print(f'{label}: legacy anchor already superseded; leaving current source unchanged')\n        return\n    if count != 1:\n        raise SystemExit(f'{label}: expected at most 1 legacy match, found {count}')\n    text = text.replace(old, new, 1)\n"""
if old_helper in s:
    s=s.replace(old_helper,new_helper,1)
elif new_helper not in s:
    raise SystemExit('v94 replace_once compatibility repair target not found')

old_tail="""if text == original:\n    raise SystemExit('No changes applied')\npath.write_text(text, encoding='utf-8')\nprint('Applied BridgePoint launch patch v94')\n"""
new_tail="""if text == original:\n    print('BridgePoint v94: all historical anchors were already superseded; no legacy mutation required')\nelse:\n    path.write_text(text, encoding='utf-8')\n    print('Applied compatible BridgePoint launch patch v94')\n"""
if old_tail in s:
    s=s.replace(old_tail,new_tail,1)
elif new_tail not in s:
    raise SystemExit('v94 no-op compatibility repair target not found')

# Current canonical main uses the same guarded U.S. control in a multiline V794 shape.
# Accept exactly one semantic marker; absence or duplication still fails closed.
old_us_guard="""elif text.count(_new_us_weather) >= 1:
    print('map-us-weather-button: already applied by a newer canonical source; continuing')
else:
    raise SystemExit('map-us-weather-button: neither historical nor current control found')
"""
new_us_guard="""elif text.count(_new_us_weather) >= 1:
    print('map-us-weather-button: already applied by a newer canonical source; continuing')
elif text.count("tooltip: 'Show U.S. intelligence'") == 1:
    print('map-us-weather-button: current V794 U.S. intelligence control verified; continuing')
else:
    raise SystemExit('map-us-weather-button: neither historical nor current control found')
"""
if old_us_guard in s:
    s=s.replace(old_us_guard,new_us_guard,1)
elif new_us_guard not in s:
    raise SystemExit('v94 U.S. control compatibility guard not found')


# v843: current main replaced the historical inline _OwnerExpansionPanel with the
# modular owner-only V2 command center. Teach v94 to verify that canonical surface
# instead of requiring the removed _EmergencyAdminPanel insertion anchor.
old_owner_guard="""marker = "class _EmergencyAdminPanel extends StatefulWidget{"
if text.count(marker) != 1:
    raise SystemExit('owner-expansion-class-marker not found exactly once')
owner_class = r\'\'\'
"""
new_owner_guard="""marker = "class _EmergencyAdminPanel extends StatefulWidget{"
marker_count = text.count(marker)
owner_global = Path('lib/screens/bridgepoint_owner_global_control.dart')
owner_v2 = Path('lib/screens/bridgepoint_owner_command_center_v2.dart')
canonical_owner_global = False
if owner_global.exists() and owner_v2.exists():
    global_source = owner_global.read_text(encoding='utf-8')
    v2_source = owner_v2.read_text(encoding='utf-8')
    canonical_owner_global = all((
        'class BridgePointOwnerGlobalControl' in global_source,
        'bridgepoint_owner_global_command_v675' in global_source,
        "'START_US_ALL'" in global_source,
        "'START_WORLD_DISCOVERY'" in global_source,
        "'START_JURISDICTION'" in global_source,
        'These actions queue discovery/build work. They never bypass validation or customer-readiness gates.' in global_source,
        "import 'bridgepoint_owner_global_control.dart';" in v2_source,
        'const BridgePointOwnerGlobalControl()' in v2_source,
    ))
if marker_count > 1:
    raise SystemExit(f'owner-expansion-class-marker duplicated: {marker_count}')
if marker_count == 0 and not canonical_owner_global:
    raise SystemExit('owner expansion control missing: neither legacy panel anchor nor canonical owner global control verified')
if marker_count == 0:
    print('owner-expansion-class-marker: canonical owner-only V2 global control verified; legacy insertion skipped')
owner_class = r\'\'\'
"""
if old_owner_guard in s:
    s=s.replace(old_owner_guard,new_owner_guard,1)
elif new_owner_guard not in s:
    raise SystemExit('v94 owner class guard compatibility target not found')

old_owner_insert="""text = text.replace(marker, owner_class + marker, 1)
"""
new_owner_insert="""if marker_count == 1:
    text = text.replace(marker, owner_class + marker, 1)
else:
    print('owner-expansion-class-insert: modular owner-only control already wired; no legacy class inserted')
"""
if old_owner_insert in s:
    s=s.replace(old_owner_insert,new_owner_insert,1)
elif new_owner_insert not in s:
    raise SystemExit('v94 owner class insertion compatibility target not found')

p.write_text(s,encoding='utf-8')
print('Repaired v94 historical generator for current canonical source')

# v124 used the exact v94 tooltip as a final sanity check even though newer source calls
# the same control "Show U.S. intelligence". Make that one check semantic instead of stale.
v124=Path('tool/apply_map_viewport_v124.py')
t=v124.read_text(encoding='utf-8')
old_check="""if text.count(controls)!=1:\n    raise SystemExit(f'US weather control missing: found {text.count(controls)}')\ntext=text.replace(controls,replacement,1)\n"""
new_check="""if text.count(controls)==1:\n    text=text.replace(controls,replacement,1)\nelif text.count(\"_MapControlButton(icon:Icons.public_rounded,tooltip:'Show U.S. intelligence'\")==1:\n    print('v124: current U.S. intelligence control already supersedes historical weather tooltip')\nelse:\n    raise SystemExit(f'US map control missing or ambiguous: historical={text.count(controls)}')\n"""
if old_check in t:
    t=t.replace(old_check,new_check,1)
elif "us_control = \"tooltip: 'Show U.S. intelligence'\"" in t and "viewport v794 marker" in t:
    print('v124: current structurally resilient U.S. intelligence control already supersedes the historical matcher')
elif new_check not in t:
    raise SystemExit('v124 U.S. control compatibility repair target not found')
v124.write_text(t,encoding='utf-8')
print('Repaired v124 U.S. map control compatibility')

# v189 still searches for the pre-national Connecticut map subtitle. Update only its
# historical matcher to the current canonical U.S. subtitle.
v189=Path('tool/apply_premium_navigation_expansion_v189.py')
u=v189.read_text(encoding='utf-8')
old_sub="${widget.packageName} • live Connecticut intelligence with visible expansion markets"
current_sub="${widget.packageName} • live U.S. property intelligence • property-linked signals and expansion coverage"
if old_sub in u:
    u=u.replace(old_sub,current_sub,1)
elif current_sub not in u:
    raise SystemExit('v189 map heading compatibility target not found')
v189.write_text(u,encoding='utf-8')
print('Repaired v189 national map heading compatibility')

# v192 itself introduced the all-state suggestion RPC in an older release. Canonical
# source already uses that RPC, so only its first matcher needs to be idempotent.
v192=Path('tool/apply_global_search_location_v192.py')
v=v192.read_text(encoding='utf-8')
old_guard="""if old not in text: raise SystemExit('global CT search anchor missing')\ntext=text.replace(old,new,1)\n"""
new_guard="""if old in text:\n    text=text.replace(old,new,1)\nelif new in text:\n    print('v192: global property suggestions RPC already present; continuing with location repairs')\nelse:\n    raise SystemExit('global property search anchor missing or ambiguous')\n"""
if old_guard in v:
    v=v.replace(old_guard,new_guard,1)
elif new_guard not in v:
    raise SystemExit('v192 global-search compatibility repair target not found')
v192.write_text(v,encoding='utf-8')
print('Repaired v192 global-search idempotency')

# v271 enriches the U.S. map control so it explicitly turns on/loading NOAA radar. Its
# old matcher still expects the v94 tooltip and zoom. Teach it the current canonical
# "Show U.S. intelligence" control while preserving the v271 live-radar behavior.
v271=Path('tool/fix_noaa_live_weather_v271.py')
w=v271.read_text(encoding='utf-8')
old_guard271="""if body.count(old_us_button)!=1:\n    raise SystemExit(f'v271 US weather button anchor {body.count(old_us_button)}')\nbody=body.replace(old_us_button,new_us_button,1)\n"""
new_guard271="""if body.count(old_us_button)==1:\n    body=body.replace(old_us_button,new_us_button,1)\nelse:\n    current_us_button=\"\"\"                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show U.S. intelligence',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.0)),\n\"\"\"\n    current_us_live=\"\"\"                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show U.S. intelligence',onTap:(){\n                              setState((){_showRadar=true;_radarPlaying=true;_radarFrameIndex=_radarFrames.length-1;_radarRevision++;});\n                              _mapController.move(const LatLng(39.50,-98.35),4.0);\n                              unawaited(_loadNoaaRadarFramesV271());\n                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration:Duration(seconds:2),content:Text('U.S. intelligence view on • loading the latest NOAA precipitation radar…')));\n                            }),\n\"\"\"\n    if body.count(current_us_button)!=1:\n        raise SystemExit(f'v271 U.S. map control missing or ambiguous: legacy={body.count(old_us_button)} current={body.count(current_us_button)}')\n    body=body.replace(current_us_button,current_us_live,1)\n"""
if old_guard271 in w:
    w=w.replace(old_guard271,new_guard271,1)
elif new_guard271 not in w:
    raise SystemExit('v271 U.S. map control compatibility repair target not found')
v271.write_text(w,encoding='utf-8')
print('Repaired v271 NOAA/U.S. map control compatibility')
