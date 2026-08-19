from pathlib import Path

path = Path('tool/apply_property_media_everywhere_v174.py')
text = path.read_text(encoding='utf-8')
old_logic = '''if old not in text:raise SystemExit('property list icon marker missing')
text=text.replace(old,"            _PropertyMediaThumb(propertyId:'${property['property_id']??''}'),\\n",1)
'''
new_logic = """responsive_icon=r'''            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.home_work_outlined, color: AppTheme.cyan, size: 20),
            ),
'''
thumb=\"            _PropertyMediaThumb(propertyId:'${property['property_id']??''}'),\\\\n\"
if old in text:
    text=text.replace(old,thumb,1)
elif responsive_icon in text:
    text=text.replace(responsive_icon,thumb,1)
elif '_PropertyMediaThumb(propertyId:' not in text:
    raise SystemExit('property list icon marker missing')
"""
if old_logic not in text:
    if 'responsive_icon=' in text:
        print('v174 responsive fallback already installed')
    else:
        raise SystemExit('v174 icon replacement logic not found')
else:
    text = text.replace(old_logic, new_logic, 1)
    path.write_text(text, encoding='utf-8')
    print('Repaired v174 to support responsive Property cards')
