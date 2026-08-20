from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v341-national-customer-surfaces'

# Replace only the CT-specific phrases on generic customer surfaces. Phrase-level
# matching survives responsive/newline formatting changes while remaining narrow
# enough not to touch genuinely Connecticut-specific tools.
phrase_replacements=[
    ('Live source registry • Connecticut intelligence','Live source registry • national intelligence coverage'),
    ('live ranked Connecticut property intelligence','live ranked property intelligence'),
    ('Canonical Connecticut property record','Canonical property record'),
]
for old,new in phrase_replacements:
    if new in text:
        continue
    count=text.count(old)
    if count==1:
        text=text.replace(old,new,1)
    elif count>1:
        raise SystemExit(f'v341 ambiguous customer phrase count {count}: {old}')
    # count==0 is valid when a newer surface already removed that obsolete phrase.

# Older generic property dialogs used this exact fallback. Replace it when present;
# newer V3xx property components already use neutral property-record wording.
old_fallback="final address = (property['address'] ?? 'Connecticut property').toString();"
new_fallback="final address = (property['address'] ?? 'Property record').toString();"
if old_fallback in text:
    if text.count(old_fallback)!=1:
        raise SystemExit('v341 ambiguous legacy property fallback')
    text=text.replace(old_fallback,new_fallback,1)

# These generic source/opportunity surfaces are known national surfaces and must
# be national after the patch. Do not require obsolete property-detail strings.
for needle in ['national intelligence coverage','live ranked property intelligence']:
    if needle not in text:
        raise SystemExit(f'missing v341 national customer marker: {needle}')

for forbidden in [
    'Live source registry • Connecticut intelligence',
    'live ranked Connecticut property intelligence',
    old_fallback,
]:
    if forbidden in text:
        raise SystemExit(f'generic CT-only customer copy remains after v341: {forbidden}')

if marker not in text:
    text += (
        "\nconst String _bridgePointNationalCustomerSurfacesV341="
        "'bridgepoint-v341-national-customer-surfaces | national coverage copy | truthful partial-state support';\n"
    )

path.write_text(text,encoding='utf-8')
print('National customer surfaces v341 verified')
