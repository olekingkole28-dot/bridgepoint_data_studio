from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
fixes=[
    ("child:const Text('Reject'))])]))],","child:const Text('Reject'))])])))]",),
    ("backgroundColor:Colors.white10)] ]);}).toList()),","backgroundColor:Colors.white10)] ]));}).toList()),"),
]
for old,new in fixes:
    count=body.count(old)
    if count:
        body=body.replace(old,new)
        print(f'v228 compile repair replaced {count} occurrence(s): {old[-50:]}')
    else:
        print(f'v228 compile repair anchor already repaired or absent: {old[-50:]}')
path.write_text(body,encoding='utf-8')
