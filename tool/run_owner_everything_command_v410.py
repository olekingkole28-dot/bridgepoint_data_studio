from pathlib import Path

script_path=Path('tool/apply_owner_everything_command_v410.py')
source=script_path.read_text(encoding='utf-8')
old="""heading = \"_PageHeading(title:'Owner Center',subtitle:'Revenue • customers • outreach • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),\"
replacement = heading + \"\\n        const SizedBox(height:14),\\n        const _OwnerEverythingCommandV410(),\"
if text.count(heading) != 1:
    raise SystemExit(f'V410 owner heading anchor count {text.count(heading)}')
text = text.replace(heading, replacement, 1)
"""
new="""if 'bridgepoint-v341-national-customer-surfaces' not in text:
    raise SystemExit('V410 must run after the final national customer release')
heading_needle=\"_PageHeading(title:'Owner Center'\"
if text.count(heading_needle)!=1:
    raise SystemExit(f'V410 structural Owner Center heading count {text.count(heading_needle)}')
heading_pos=text.index(heading_needle)
line_start=text.rfind('\\n',0,heading_pos)+1
line_end=text.find('\\n',heading_pos)
if line_end<0: line_end=len(text)
heading_line=text[line_start:line_end]
if not heading_line.strip().endswith('),'):
    raise SystemExit('V410 Owner Center heading is not a complete one-line PageHeading call')
indent=heading_line[:len(heading_line)-len(heading_line.lstrip())]
insertion=f\"\\n{indent}const SizedBox(height:14),\\n{indent}const _OwnerEverythingCommandV410(),\"
text=text[:line_end]+insertion+text[line_end:]
"""
if source.count(old)!=1:
    raise SystemExit(f'V410 wrapper expected one legacy anchor block, found {source.count(old)}')
source=source.replace(old,new,1)
exec(compile(source,str(script_path),'exec'),{'__name__':'__main__','__file__':str(script_path)})
