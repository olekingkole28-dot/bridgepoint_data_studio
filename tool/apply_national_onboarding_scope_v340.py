from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text
marker='bridgepoint-v340-national-onboarding-scope'

# Legacy onboarding used a Connecticut-specific territory list. Keep the old
# default when that exact UI is present, but expand the choices nationally.
legacy_old="['Statewide Connecticut','One municipality','One county','Multiple counties','New England']"
legacy_new="['Statewide Connecticut','One municipality','One county','Multiple counties','One state','Multiple states','New England','Nationwide']"
if legacy_old in text and legacy_new not in text:
    text=text.replace(legacy_old,legacy_new,1)

# The current V315 package-fit questionnaire already uses a newer data-driven
# territory vocabulary: One property / Local / Statewide / Multi-state / National.
# Recognize that as the preferred national implementation instead of forcing it
# back into the old V70 wording.
modern_territory=False
m=re.search(r"static const territories=<String>\[(.*?)\];",text,re.S)
if m:
    block=m.group(1)
    modern_territory=('Statewide' in block and ('Multi-state' in block or 'Multiple states' in block) and ('National' in block or 'Nationwide' in block))
legacy_territory=legacy_new in text

if not (modern_territory or legacy_territory):
    raise SystemExit('national onboarding territory contract missing')

# Update the old prompt when that old surface still exists. The V315 form has
# its own numbered, package-fit wording and does not need this legacy label.
old_label="'Where do you work?'"
new_label="'What territory do you work?'"
if old_label in text and new_label not in text:
    text=text.replace(old_label,new_label,1)

# Require a real onboarding/package-fit save route, not merely national copy.
if 'bridgepoint_complete_onboarding_v315' not in text and 'bridgepoint_complete_onboarding_v70' not in text:
    raise SystemExit('national onboarding save route missing')

if marker not in text:
    text += "\nconst String _bridgePointNationalOnboardingScopeV340='bridgepoint-v340-national-onboarding-scope | state + multistate + national territory selection';\n"

# Fail closed if a future release somehow removes the national choice.
if not (("'Multi-state'" in text or "'Multiple states'" in text) and ("'National'" in text or "'Nationwide'" in text)):
    raise SystemExit('national onboarding choices not present after v340')

path.write_text(text,encoding='utf-8')
print('National onboarding territory scope v340 verified', 'modern-v315' if modern_territory else 'legacy-expanded')
