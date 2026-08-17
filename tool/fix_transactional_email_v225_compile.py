from pathlib import Path

path=Path('lib/main.dart')
s=path.read_text(encoding='utf-8')
old="border:Border.all(color:AppTheme.border)"
new="border:Border.all(color:AppTheme.textMuted.withOpacity(.16))"
if old in s:
    s=s.replace(old,new,1)
elif new not in s:
    raise SystemExit('v225 mail compile repair anchor missing')
path.write_text(s,encoding='utf-8')
print('Repaired v225 transactional email theme compile point.')
