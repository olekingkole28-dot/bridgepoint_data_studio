from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# Keep the existing CT default for backwards compatibility, but remove the
# national-expansion blocker by making broader service areas selectable.
old="['Statewide Connecticut','One municipality','One county','Multiple counties','New England']"
new="['Statewide Connecticut','One municipality','One county','Multiple counties','One state','Multiple states','New England','Nationwide']"

if new not in text:
    if old not in text:
        raise SystemExit('onboarding territory options anchor missing')
    text=text.replace(old,new,1)

# Make the prompt accurately describe the now-national territory choice.
old_label="'Where do you work?'"
new_label="'What territory do you work?'"
if new_label not in text and old_label in text:
    text=text.replace(old_label,new_label,1)

# Guard the release layer so CI fails instead of silently shipping the old CT-only selector.
for marker in ["'Multiple states'","'Nationwide'","bridgepoint_complete_onboarding_v70"]:
    if marker not in text:
        raise SystemExit(f'missing national onboarding marker: {marker}')

if text==original:
    print('National onboarding territory scope v340 already applied')
else:
    path.write_text(text,encoding='utf-8')
    print('Applied national onboarding territory scope v340')
