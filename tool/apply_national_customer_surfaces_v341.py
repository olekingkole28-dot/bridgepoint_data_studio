from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text
marker='bridgepoint-v341-national-customer-surfaces'

# Remove Connecticut-only wording only from GENERIC customer surfaces. Genuine
# Connecticut-specific tools and source descriptions remain explicitly CT.
replacements=[
    (
        "subtitle: 'Live source registry • Connecticut intelligence',",
        "subtitle: 'Live source registry • national intelligence coverage',",
    ),
    (
        "subtitle: '${widget.packageName} • live ranked Connecticut property intelligence',",
        "subtitle: '${widget.packageName} • live ranked property intelligence',",
    ),
    (
        "subtitle: 'Canonical Connecticut property record',",
        "subtitle: 'Canonical property record',",
    ),
]
for old,new in replacements:
    if new in text:
        continue
    count=text.count(old)
    if count==1:
        text=text.replace(old,new,1)
    elif count>1:
        raise SystemExit(f'v341 ambiguous customer-surface anchor count {count}: {old}')
    # count==0 is valid when a newer customer surface has already removed that legacy copy.

# Older generic property dialogs used this fallback. Replace it when present;
# newer V3xx property components already use neutral 'Property record' copy.
old_fallback="final address = (property['address'] ?? 'Connecticut property').toString();"
new_fallback="final address = (property['address'] ?? 'Property record').toString();"
if old_fallback in text:
    if text.count(old_fallback)!=1:
        raise SystemExit('v341 ambiguous legacy property fallback')
    text=text.replace(old_fallback,new_fallback,1)

# These two generic surfaces are known national surfaces and therefore must be
# national after the patch. Do not require obsolete UI strings that no longer
# exist in the current generated property detail layout.
required=['national intelligence coverage','live ranked property intelligence']
for needle in required:
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
