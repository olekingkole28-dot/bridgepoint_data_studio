from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _PropertyListCard extends StatelessWidget')
end=text.find('\nclass ',start+1)
if start<0:
    raise SystemExit('v820 PropertyListCard missing')
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
        raise SystemExit(f'v820 property identity expected 1 match, found {len(identity_pattern.findall(block))}')
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
        raise SystemExit(f'v820 display address expected 1 match, found {len(display_pattern.findall(block))}')
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
        raise SystemExit(f'v820 property detail fact group expected 1 match, found {len(matches)}')
    text=facts_pattern.sub(expected_facts.rstrip('\n'),text,count=1)

for marker in [expected_identity.rstrip('\n'),expected_display.rstrip('\n'),expected_facts.rstrip('\n')]:
    if marker not in text:
        raise SystemExit(f'v820 compatibility marker missing: {marker[:80]}')

if text==original:
    print('Multistate/current-owner v188 compatibility already normalized v820')
else:
    path.write_text(text,encoding='utf-8')
    print('Normalized responsive property-card boundaries for multistate/current-owner v188/v820')
