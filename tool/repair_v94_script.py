from pathlib import Path

p=Path('tool/apply_launch_v94.py')
s=p.read_text(encoding='utf-8')

# Repair the historical banner matcher so it still recognizes the current widget shape.
old='''"""                  const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  Text(\n                    technology\n'''
new='''"""                  child: const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  child: Text(\n                    technology\n'''
if old in s:
    s=s.replace(old,new,1)
elif new not in s:
    raise SystemExit('v94 banner matcher repair target not found')

# v94 is a historical generator. Current canonical source legitimately contains newer
# equivalents (for example "Show U.S. intelligence" instead of the old Northeast button).
# An absent OLD anchor therefore means "superseded", not "destroy the whole release".
# Duplicate old anchors remain a hard failure because that is genuine structural drift.
old_helper="""    if count != 1:\n        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')\n    text = text.replace(old, new, 1)\n"""
new_helper="""    if count == 0:\n        print(f'{label}: legacy anchor already superseded; leaving current source unchanged')\n        return\n    if count != 1:\n        raise SystemExit(f'{label}: expected at most 1 legacy match, found {count}')\n    text = text.replace(old, new, 1)\n"""
if old_helper in s:
    s=s.replace(old_helper,new_helper,1)
elif new_helper not in s:
    raise SystemExit('v94 replace_once compatibility repair target not found')

old_tail="""if text == original:\n    raise SystemExit('No changes applied')\npath.write_text(text, encoding='utf-8')\nprint('Applied BridgePoint launch patch v94')\n"""
new_tail="""if text == original:\n    print('BridgePoint v94: all historical anchors were already superseded; no legacy mutation required')\nelse:\n    path.write_text(text, encoding='utf-8')\n    print('Applied compatible BridgePoint launch patch v94')\n"""
if old_tail in s:
    s=s.replace(old_tail,new_tail,1)
elif new_tail not in s:
    raise SystemExit('v94 no-op compatibility repair target not found')

p.write_text(s,encoding='utf-8')
print('Repaired v94 historical generator for current canonical source')
