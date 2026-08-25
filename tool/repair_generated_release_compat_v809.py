from pathlib import Path

legacy_path = Path('tool/repair_generated_release_v160.py')
legacy = legacy_path.read_text(encoding='utf-8')
original = legacy

old = "founder_end=text.find('class _OwnerCenterPage extends StatefulWidget{',founder_start)"
new = "founder_end=text.find('class _FieldModePage extends StatefulWidget {',founder_start)"

if old in legacy:
    legacy = legacy.replace(old, new, 1)
elif new not in legacy:
    raise SystemExit('v809 could not find the historical or modern generated training/founder boundary')

# The modern v159 compatibility layer inserts the entire training/founder block
# directly before Field Mode. Keep v160's strict generated-source repair, but
# teach it that current structural boundary instead of the retired Owner Center.
if "founder_start=text.find('IconData _trainingIcon(String key)=>')" not in legacy:
    raise SystemExit('v809 training/founder start marker missing from v160 repair')

if legacy != original:
    legacy_path.write_text(legacy, encoding='utf-8')
    print('Prepared generated release repair for modern training/founder boundary v809')
else:
    print('Generated release repair v809 compatibility already present')
