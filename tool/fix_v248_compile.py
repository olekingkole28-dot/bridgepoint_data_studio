from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='_bridgePointV248CompileRepair'
if marker in body:
    print('v248 compile repair already applied')
    raise SystemExit(0)

old="onTap:()=>widget.onPropertySelected(p)))]"
new="onTap:()=>widget.onPropertySelected(p))))]"
count=body.count(old)
if count!=1:
    raise SystemExit(f'v248 expected one AI property-result closure, found {count}')
body=body.replace(old,new,1)
body += "\nconst String _bridgePointV248CompileRepair='bridgepoint-v248-compile-repair';\n"
path.write_text(body,encoding='utf-8')
print('Repaired v248 BridgePoint AI property result widget closure.')
