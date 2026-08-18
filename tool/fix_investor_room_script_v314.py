from pathlib import Path

path=Path('tool/apply_investor_room_v314.py')
body=path.read_text(encoding='utf-8')
changed=False

# The Investor Room widget contains an HTML string that uses triple single quotes,
# so the outer Python raw string must use triple double quotes.
old_start="widget=r'''"
old_end="\n'''\nif body.count(class_anchor)!=1:"
if old_start in body:
    if body.count(old_start)!=1 or body.count(old_end)!=1:
        raise SystemExit(f'v314 generator delimiter counts start={body.count(old_start)} end={body.count(old_end)}')
    body=body.replace(old_start,'widget=r"""',1)
    body=body.replace(old_end,'\n"""\nif body.count(class_anchor)!=1:',1)
    changed=True
elif 'widget=r"""' not in body:
    raise SystemExit('v314 Investor Room widget raw-string delimiter not found')

# Close the ListTile in the Readiness & open items map callback. The generated Dart
# previously closed TextStyle and Text but missed the final ListTile parenthesis.
old="height:1.35));})]),"
new="height:1.35)));})]),"
if old in body:
    if body.count(old)!=1:
        raise SystemExit(f'v314 readiness ListTile repair count {body.count(old)}')
    body=body.replace(old,new,1)
    changed=True
elif new not in body:
    raise SystemExit('v314 readiness ListTile closure target not found')

if changed:
    path.write_text(body,encoding='utf-8')
    print('Repaired v314 Investor Room generator delimiter and Readiness ListTile closure.')
else:
    print('v314 Investor Room generator repairs already applied.')
