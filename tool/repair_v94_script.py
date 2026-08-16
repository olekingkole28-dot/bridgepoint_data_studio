from pathlib import Path
p=Path('tool/apply_launch_v94.py')
s=p.read_text(encoding='utf-8')
old='''"""                  const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  Text(\n                    technology\n'''
new='''"""                  child: const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  child: Text(\n                    technology\n'''
if old not in s:
    raise SystemExit('v94 banner matcher repair target not found')
p.write_text(s.replace(old,new,1),encoding='utf-8')
print('Repaired v94 banner matcher')
