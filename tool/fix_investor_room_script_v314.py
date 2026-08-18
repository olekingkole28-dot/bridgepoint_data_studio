from pathlib import Path

path=Path('tool/apply_investor_room_v314.py')
body=path.read_text(encoding='utf-8')
if 'widget=r"""' in body:
    print('v314 Investor Room generator quote delimiter already repaired.')
    raise SystemExit(0)

old_start="widget=r'''"
old_end="\n'''\nif body.count(class_anchor)!=1:"
if body.count(old_start)!=1:
    raise SystemExit(f'v314 generator start delimiter count {body.count(old_start)}')
if body.count(old_end)!=1:
    raise SystemExit(f'v314 generator end delimiter count {body.count(old_end)}')
body=body.replace(old_start,'widget=r"""',1)
body=body.replace(old_end,'\n"""\nif body.count(class_anchor)!=1:',1)
path.write_text(body,encoding='utf-8')
print('Repaired v314 Investor Room generator quote delimiter.')
