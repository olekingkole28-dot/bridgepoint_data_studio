from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
original = s

marker = '// bridgepoint-visible-national-v726'
if marker not in s:
    s = s.replace('// bridgepoint-v690-national-live-demo', '// bridgepoint-v690-national-live-demo\n' + marker, 1)

old_submit = "onSubmitted:(value){onSubmitted(value);onFieldSubmitted();},"
new_submit = "onSubmitted:(_){onFieldSubmitted();},"
if old_submit in s:
    s = s.replace(old_submit, new_submit, 1)
elif new_submit not in s:
    raise SystemExit('global autocomplete submit pattern not found')

s = s.replace(
    "Connecticut property universe • search, inspect, and open intelligence",
    "Authorized U.S. property universe • search, inspect, and open intelligence",
)

# Remove founder initials from customer shell avatars while preserving the surrounding layout.
avatar_pattern = re.compile(
    r"const CircleAvatar\(\s*radius:\s*(18|19),\s*backgroundColor:\s*AppTheme\.blue,\s*child:\s*Text\(\s*'KJ',\s*style:\s*TextStyle\(.*?\),\s*\),\s*\)",
    re.S,
)
s, avatar_count = avatar_pattern.subn(
    lambda m: f"const Icon(Icons.account_circle_outlined, color: AppTheme.textMuted, size: {int(m.group(1))*2})",
    s,
)

if "'KJ'" in s:
    raise SystemExit('hard-coded KJ remains in main.dart')
if 'Authorized U.S. property universe' not in s:
    raise SystemExit('national properties copy was not applied')
if new_submit not in s:
    raise SystemExit('autocomplete enter fix was not applied')
if avatar_count < 1 and 'Icons.account_circle_outlined' not in s:
    raise SystemExit('customer-safe avatar fix was not applied')

if s == original:
    print('V726 already applied')
else:
    p.write_text(s, encoding='utf-8')
    print(f'Applied V726; avatar replacements={avatar_count}')
