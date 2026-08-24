from pathlib import Path
import re

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
original=s
marker='// bridgepoint-visible-national-v728'
if marker not in s:
    s=s.replace('// bridgepoint-v690-national-live-demo','// bridgepoint-v690-national-live-demo\n'+marker,1)

old="onSubmitted:(value){onSubmitted(value);onFieldSubmitted();},"
new="onSubmitted:(_){onFieldSubmitted();},"
if old in s:
    s=s.replace(old,new,1)
elif new not in s:
    raise SystemExit('autocomplete submit pattern missing')

s=s.replace('Connecticut property universe • search, inspect, and open intelligence','Authorized U.S. property universe • search, inspect, and open intelligence')

patterns=[
"""const CircleAvatar(
            radius: 19,
            backgroundColor: AppTheme.blue,
            child: Text(
              'KJ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          )""",
"""const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.blue,
                  child: Text(
                    'KJ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                )"""
]
repls=[
"const Icon(Icons.account_circle_outlined, color: AppTheme.textMuted, size: 38)",
"const Icon(Icons.account_circle_outlined, color: AppTheme.textMuted, size: 36)"
]
for a,b in zip(patterns,repls):
    s=s.replace(a,b)

if "'KJ'" in s: raise SystemExit('hard-coded KJ remains')
if 'Authorized U.S. property universe' not in s: raise SystemExit('national Properties copy missing')
if new not in s: raise SystemExit('Enter-selection fix missing')
if marker not in s: raise SystemExit('marker missing')
if s!=original: p.write_text(s,encoding='utf-8')
print('V728 patch OK')
