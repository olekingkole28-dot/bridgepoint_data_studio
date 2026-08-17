from pathlib import Path

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v229-network-storm-accuracy'
if marker not in body:
    raise SystemExit('v229 marker not found; refusing compile repair')

old1 = "fontSize:9))])))\n                : Container(height:compact?230:300"
new1 = "fontSize:9))]))))\n                : Container(height:compact?230:300"
count1 = body.count(old1)
if count1 == 1:
    body = body.replace(old1, new1, 1)
elif count1 != 0:
    raise SystemExit(f'Unexpected v229 satellite closure count: {count1}')

old2 = "              ])),\n              const SizedBox(height:3),Text('Nationwide alert feed checked:"
new2 = "              ]))),\n              const SizedBox(height:3),Text('Nationwide alert feed checked:"
count2 = body.count(old2)
if count2 == 1:
    body = body.replace(old2, new2, 1)
elif count2 != 0:
    raise SystemExit(f'Unexpected v229 alert map closure count: {count2}')

if count1 == 0 and count2 == 0:
    print('v229 compile repair already applied.')
else:
    path.write_text(body, encoding='utf-8')
    print(f'Applied v229 compile repair: satellite={count1}, alerts={count2}.')
