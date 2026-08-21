from pathlib import Path

p=Path('lib/main.dart')
t=p.read_text(encoding='utf-8')
marker='bridgepoint-v394-national-coverage-copy'
if marker in t:
    print('v394 already applied')
    raise SystemExit(0)
if 'bridgepoint-v393-preview-pages' not in t:
    raise SystemExit('v394 requires v393 generated app')

replacements=[
    ("title: 'Connecticut Coverage'", "title: 'Coverage & Market Readiness'"),
    ("'STATEWIDE CT'", "'U.S. MARKET COVERAGE'"),
    ("'8 counties • 169 municipalities'", "'CT live • additional markets building'"),
    ("Enabled Connecticut sources", "Enabled sources in the live registry"),
]
for old,new in replacements:
    count=t.count(old)
    if count>1:
        raise SystemExit(f'v394 ambiguous replacement {count}: {old}')
    if count==1:
        t=t.replace(old,new,1)

old="""            final address =
                '${property['full_address'] ?? '${property['municipality'] ?? 'Connecticut'} property'}';
"""
new="""            final address = property['full_address']?.toString() ??
                (property['municipality'] == null
                    ? 'Property record'
                    : '${property['municipality']} property');
"""
if t.count(old)!=1:
    raise SystemExit('v394 property fallback anchor missing/ambiguous')
t=t.replace(old,new,1)

for forbidden in [
    'Connecticut Coverage',
    'STATEWIDE CT',
    '8 counties • 169 municipalities',
    "${property['municipality'] ?? 'Connecticut'} property",
    'Enabled Connecticut sources',
]:
    if forbidden in t:
        raise SystemExit(f'v394 generic Connecticut assumption remains: {forbidden}')

for required in [
    'Coverage & Market Readiness',
    'U.S. MARKET COVERAGE',
    'CT live • additional markets building',
    "? 'Property record'",
]:
    if required not in t:
        raise SystemExit(f'v394 required marker missing: {required}')

t += "\nconst String _bridgePointNationalCoverageCopyV394='bridgepoint-v394-national-coverage-copy | generic coverage no longer hardcoded to CT | property fallback neutral';\n"
p.write_text(t,encoding='utf-8')
print('Applied v394 national coverage copy and neutral property fallback')
