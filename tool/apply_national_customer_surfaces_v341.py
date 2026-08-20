from pathlib import Path
import runpy

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text
marker = 'bridgepoint-v341-national-customer-surfaces'

# Remove Connecticut-only wording from customer surfaces that now consume
# multi-state/national data. CT-specific tools remain explicitly CT-specific.
replacements = [
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

for old, new in replacements:
    if new in text:
        continue
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'v341 customer-surface anchor count {count}: {old}')
    text = text.replace(old, new, 1)

# The generic property dialog must not call every non-CT record a Connecticut
# property when an address is temporarily unavailable.
old = "final address = (property['address'] ?? 'Connecticut property').toString();"
new = "final address = (property['address'] ?? 'Property record').toString();"
if new not in text:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'v341 property fallback anchor count {count}')
    text = text.replace(old, new, 1)

# Guard the release layer so CI fails rather than silently reverting to
# Connecticut-only customer copy after future release-layer regeneration.
required = [
    "national intelligence coverage",
    "live ranked property intelligence",
    "Canonical property record",
    "'Property record'",
]
for needle in required:
    if needle not in text:
        raise SystemExit(f'missing v341 national customer marker: {needle}')

if marker not in text:
    text += (
        "\nconst String _bridgePointNationalCustomerSurfacesV341="
        "'bridgepoint-v341-national-customer-surfaces | national coverage copy | truthful partial-state support';\n"
    )

if text == original:
    print('National customer surfaces v341 already applied')
else:
    path.write_text(text, encoding='utf-8')
    print('Applied national customer surfaces v341')

# v345 is the state-aware customer contract layer. It must run after v350 map + v341
# copy normalization so its state selector and national RPC rewrites see the final generated UI.
runpy.run_path('tool/apply_national_app_contracts_v345.py', run_name='__main__')
