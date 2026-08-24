from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# Idempotent branch marker used by the workflow verification step.
if '// bridgepoint-ui-refresh-v691' not in text:
    marker = '// bridgepoint-v690-national-live-demo\n'
    if marker not in text:
        raise SystemExit('Expected v690 source marker not found')
    text = text.replace(marker, marker + '// bridgepoint-ui-refresh-v691\n', 1)

# Global search: submitting Enter should let Flutter Autocomplete commit the
# highlighted property instead of navigating away to the generic Properties page.
old_submit = """onSubmitted: (value) {\n            onSubmitted(value);\n            onFieldSubmitted();\n          },"""
new_submit = """onSubmitted: (_) => onFieldSubmitted(),"""
if old_submit in text:
    text = text.replace(old_submit, new_submit, 1)
elif new_submit not in text:
    raise SystemExit('Global search submit block not found')

text = text.replace(
    "hintText: 'Start typing an address or parcel',",
    "hintText: 'Search any property address or parcel',",
    1,
)

# Never leak the founder initials into customer chrome. Keep a neutral account
# glyph until a real customer profile/avatar is available.
kj_pattern = re.compile(
    r"child:\s*Text\(\s*'KJ',\s*style:\s*TextStyle\(.*?\),\s*\),",
    re.S,
)
text, avatar_replacements = kj_pattern.subn(
    "child: Icon(\n                    Icons.account_circle_outlined,\n                    color: Colors.white,\n                    size: 22,\n                  ),",
    text,
    count=2,
)
if avatar_replacements == 0 and "Icons.account_circle_outlined" not in text:
    raise SystemExit('Expected KJ avatar blocks not found')

# The data contract is no longer CT-hardcoded. Keep CT-specific source panels
# where they are genuinely CT-specific, but make the generic property and
# opportunity navigation describe the actual entitlement-aware scope.
text = text.replace(
    "'Connecticut property universe • search, inspect, and open intelligence',",
    "'Entitled U.S. property universe • search, inspect, and open intelligence',",
    1,
)
text = text.replace(
    "'${widget.packageName} • live ranked Connecticut property intelligence',",
    "'${widget.packageName} • live ranked intelligence for your entitled markets',",
    1,
)

if text == original:
    print('UI refresh already applied; no changes required.')
else:
    path.write_text(text, encoding='utf-8')
    print('Applied BridgePoint UI refresh v691 national search/avatar patch.')
