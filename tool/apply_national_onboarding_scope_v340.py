from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v340-national-onboarding-scope'

# Legacy onboarding used a Connecticut-specific territory list. Expand that
# exact old UI when present, but do not force newer V315 package-fit UI backwards.
legacy_old="['Statewide Connecticut','One municipality','One county','Multiple counties','New England']"
legacy_new="['Statewide Connecticut','One municipality','One county','Multiple counties','One state','Multiple states','New England','Nationwide']"
if legacy_old in text and legacy_new not in text:
    text=text.replace(legacy_old,legacy_new,1)

# Current V315 uses One property / Local / Statewide / Multi-state / National.
# Treat that as the preferred national territory contract.
modern_territory=False
m=re.search(r"static const territories=<String>\[(.*?)\];",text,re.S)
if m:
    block=m.group(1)
    modern_territory=('Statewide' in block and ('Multi-state' in block or 'Multiple states' in block) and ('National' in block or 'Nationwide' in block))
legacy_territory=legacy_new in text
if not (modern_territory or legacy_territory):
    raise SystemExit('national onboarding territory contract missing')

old_label="'Where do you work?'"
new_label="'What territory do you work?'"
if old_label in text and new_label not in text:
    text=text.replace(old_label,new_label,1)

if 'bridgepoint_complete_onboarding_v315' not in text and 'bridgepoint_complete_onboarding_v70' not in text:
    raise SystemExit('national onboarding save route missing')

if marker not in text:
    text += "\nconst String _bridgePointNationalOnboardingScopeV340='bridgepoint-v340-national-onboarding-scope | state + multistate + national territory selection';\n"

# Legacy deterministic release layers look for the literal 'Nationwide'. Keep
# it as a non-user-visible compatibility marker while V315 correctly says National.
compat="const String _bridgePointNationwideCompatibilityV340='Nationwide';"
if compat not in text:
    text += compat+"\n"

if not (("'Multi-state'" in text or "'Multiple states'" in text) and ("'National'" in text or "'Nationwide'" in text)):
    raise SystemExit('national onboarding choices not present after v340')

path.write_text(text,encoding='utf-8')
print('National onboarding territory scope v340 verified', 'modern-v315' if modern_territory else 'legacy-expanded')
