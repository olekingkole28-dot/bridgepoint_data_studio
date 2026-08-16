from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
old="withOpacity(active?.18:.07)"
new="withOpacity(active ? .18 : .07)"
if old not in s:
    raise SystemExit('v215 contact opacity compile point not found')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('Repaired v215 contact opacity expression.')
