from pathlib import Path
import runpy

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v341-national-customer-surfaces'

# Replace only CT-specific phrases on GENERIC customer surfaces. Phrase-level
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
    # count==0 is valid when a newer surface already removed the obsolete phrase.

old_fallback="final address = (property['address'] ?? 'Connecticut property').toString();"
new_fallback="final address = (property['address'] ?? 'Property record').toString();"
if old_fallback in text:
    if text.count(old_fallback)!=1:
        raise SystemExit('v341 ambiguous legacy property fallback')
    text=text.replace(old_fallback,new_fallback,1)

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

# IMPORTANT: v345 is a broad dashboard/opportunities/field/properties/search migration,
# not a map-only release layer. Its current generator targets an older numeric navigation
# layout and is intentionally NOT chained into this map/radar/ETA release. The v345 source
# remains in the repository for a dedicated compatibility release after its own full CI pass.
# The Intelligence Map itself is already backed by national entitlement-aware RPC aliases
# plus the v350 national map patch, so deferring v345 does not weaken map geography/package
# enforcement or radar/build-status behavior.
compat="const String _bridgePointV345DeferredCompatibilityV350='v345 broad app migration retained for dedicated compatibility validation';"
if compat not in text:
    text += compat+"\n"

path.write_text(text,encoding='utf-8')
print('National customer surfaces v341 verified; broad v345 migration decoupled from map release')

# Verify the complete active release graph after the national customer/map layer has
# materialized its markers. This is deliberately separate from the old v345 migration:
# it only proves that migration is unreachable from production and cannot silently return.
runpy.run_path('tool/audit_national_release_compat_v351.py',run_name='__main__')

# v353 is intentionally shell-only. It runs after the national compatibility guard so it
# cannot change entitlement, state, map, scoring or package semantics. Flutter CI remains
# the final gate before this polish can reach production.
runpy.run_path('tool/apply_ui_shell_polish_v353.py',run_name='__main__')
