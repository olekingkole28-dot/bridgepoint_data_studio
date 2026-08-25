from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _PropertyListCard extends StatelessWidget')
end=text.find('\nclass ',start+1)
if start<0:
    raise SystemExit('v821 PropertyListCard missing')
if end<0:
    end=len(text)
block=text[start:end]

# v188 expects this compact identity line. Normalize only the matching
# municipality/county/parcel Text widget inside PropertyListCard.
expected_identity="""              Text([municipality, if (county.isNotEmpty) '$county County', parcel].join(' • '), maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.35)),
"""
if expected_identity not in block:
    identity_pattern=re.compile(
        r"(?P<indent>[ \t]*)Text\(\s*\[\s*municipality\s*,\s*"
        r"if\s*\(county\.isNotEmpty\)\s*'\$county County'\s*,\s*parcel\s*\]"
        r"\.join\(\s*' • '\s*\)\s*,\s*maxLines:\s*compact\s*\?\s*2\s*:\s*1\s*,\s*"
        r"overflow:\s*TextOverflow\.ellipsis\s*,\s*style:\s*const TextStyle\(\s*"
        r"color:\s*AppTheme\.textMuted\s*,\s*fontSize:\s*9\s*,\s*height:\s*1\.35\s*\)\s*\)\s*,",
        re.S,
    )
    if len(identity_pattern.findall(block))!=1:
        raise SystemExit(f'v821 property identity expected 1 match, found {len(identity_pattern.findall(block))}')
    block=identity_pattern.sub(expected_identity.rstrip('\n'),block,count=1)

# Normalize the CT fallback display address boundary v188 upgrades to state-aware.
expected_display="""    final displayAddress =
        address.trim().isEmpty || address == '${property['postal_code']}, CT'
            ? '$municipality, CT • $parcel'
            : address;
"""
if expected_display not in block:
    display_pattern=re.compile(
        r"[ \t]*final displayAddress\s*=\s*address\.trim\(\)\.isEmpty\s*\|\|\s*"
        r"address\s*==\s*'\$\{property\['postal_code'\]\}, CT'\s*\?\s*"
        r"'\$municipality, CT • \$parcel'\s*:\s*address\s*;",
        re.S,
    )
    if len(display_pattern.findall(block))!=1:
        raise SystemExit(f'v821 display address expected 1 match, found {len(display_pattern.findall(block))}')
    block=display_pattern.sub(expected_display.rstrip('\n'),block,count=1)

text=text[:start]+block+text[end:]

# v188 enriches this fact group with state + current-owner provenance. Normalize
# the current formatted group to its historical compact form.
expected_facts="""                              _DetailFact('Tax year', property['tax_year']),
                              _DetailFact('County', property['county']),
                              _DetailFact('Postal', property['postal_code']),
"""
if expected_facts not in text:
    facts_pattern=re.compile(
        r"(?P<indent>[ \t]*)_DetailFact\(\s*'Tax year'\s*,\s*property\['tax_year'\]\s*\)\s*,\s*"
        r"_DetailFact\(\s*'County'\s*,\s*property\['county'\]\s*\)\s*,\s*"
        r"_DetailFact\(\s*'Postal'\s*,\s*property\['postal_code'\]\s*\)\s*,",
        re.S,
    )
    matches=list(facts_pattern.finditer(text))
    if len(matches)!=1:
        raise SystemExit(f'v821 property detail fact group expected 1 match, found {len(matches)}')
    text=facts_pattern.sub(expected_facts.rstrip('\n'),text,count=1)

for marker in [expected_identity.rstrip('\n'),expected_display.rstrip('\n'),expected_facts.rstrip('\n')]:
    if marker not in text:
        raise SystemExit(f'v821 compatibility marker missing: {marker[:80]}')

if text==original:
    print('Multistate/current-owner v188 compatibility already normalized v821')
else:
    path.write_text(text,encoding='utf-8')
    print('Normalized responsive property-card boundaries for multistate/current-owner v188/v821')

# Prepare historical v189 for the modern phone-first NavigationBar and the
# v675 Owner Global Control architecture. This edits only the release-workspace
# generator; v189 still owns the actual premium navigation/map changes.
v189=Path('tool/apply_premium_navigation_expansion_v189.py')
source=v189.read_text(encoding='utf-8')
source_original=source

old_compact_handler="""if old_compact not in text: raise SystemExit('compact nav anchor missing')
text=text.replace(old_compact,new_compact,1)
"""
new_compact_handler="""if old_compact in text:
    text=text.replace(old_compact,new_compact,1)
elif 'class _CompactNavigation extends StatelessWidget' in text and 'child: NavigationBar(' in text:
    # Modern v767 mobile navigation is authoritative. Accent its selected
    # destination instead of replacing it with the retired ChoiceChip strip.
    modern_indicator='indicatorColor: AppTheme.cyan.withOpacity(.15),'
    if modern_indicator not in text:
        raise SystemExit('modern compact NavigationBar indicator anchor missing')
    text=text.replace(modern_indicator,'indicatorColor: _bridgePointPageAccent(selectedIndex).withOpacity(.18),',1)
else:
    raise SystemExit('compact navigation surface missing')
"""
if old_compact_handler not in source:
    raise SystemExit('v821 could not patch v189 compact-nav handler')
source=source.replace(old_compact_handler,new_compact_handler,1)

# The legacy v90 expansion-control card was superseded by Owner Global Control
# v675. Keep v189's ETA enhancement when that legacy card exists, otherwise
# skip only the retired card-specific transforms. Readiness gates remain server-side.
for label in ['loadControl','vars','progress','steps UI']:
    pass
legacy_pairs=[
("if old_load not in text: raise SystemExit('expansion loadControl anchor missing')\ntext=text.replace(old_load,new_load,1)\n",
 "if old_load in text:\n    text=text.replace(old_load,new_load,1)\nelif 'BridgePointOwnerCommandCenter' in text:\n    print('Legacy v189 expansion loadControl superseded by Owner Global Control v675; continuing')\nelse:\n    raise SystemExit('expansion control surface missing')\n"),
("if old_vars not in text: raise SystemExit('expansion vars anchor missing')\ntext=text.replace(old_vars,new_vars,1)\n",
 "if old_vars in text:\n    text=text.replace(old_vars,new_vars,1)\nelif 'BridgePointOwnerCommandCenter' not in text:\n    raise SystemExit('expansion vars anchor missing')\n"),
("if old_progress not in text: raise SystemExit('expansion progress anchor missing')\ntext=text.replace(old_progress,new_progress,1)\n",
 "if old_progress in text:\n    text=text.replace(old_progress,new_progress,1)\nelif 'BridgePointOwnerCommandCenter' not in text:\n    raise SystemExit('expansion progress anchor missing')\n"),
("if old_steps not in text: raise SystemExit('expansion steps UI anchor missing')\ntext=text.replace(old_steps,new_steps,1)\n",
 "if old_steps in text:\n    text=text.replace(old_steps,new_steps,1)\nelif 'BridgePointOwnerCommandCenter' not in text:\n    raise SystemExit('expansion steps UI anchor missing')\n"),
]
for old,new in legacy_pairs:
    if old not in source:
        raise SystemExit(f'v821 could not patch v189 legacy expansion handler: {old[:60]}')
    source=source.replace(old,new,1)

old_validation="""for marker in ['_bridgePointPageAccent','bridgepoint_expansion_eta_v188','BUILDING NOW','Current step ETA:']:
    if marker not in text: raise SystemExit(f'missing v189 marker {marker}')
"""
new_validation="""for marker in ['_bridgePointPageAccent','BUILDING NOW']:
    if marker not in text: raise SystemExit(f'missing v189 marker {marker}')
if 'bridgepoint_expansion_control_center_v90' in text:
    for marker in ['bridgepoint_expansion_eta_v188','Current step ETA:']:
        if marker not in text: raise SystemExit(f'missing legacy v189 ETA marker {marker}')
else:
    print('Legacy v189 ETA card superseded by v675/v212 expansion progress surfaces')
"""
if old_validation not in source:
    raise SystemExit('v821 could not patch v189 validation')
source=source.replace(old_validation,new_validation,1)

if source==source_original:
    raise SystemExit('v821 made no premium-navigation generator compatibility changes')
v189.write_text(source,encoding='utf-8')
print('Prepared premium navigation v189 for modern NavigationBar + Owner Global Control v675/v821')
