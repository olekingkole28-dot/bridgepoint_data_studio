from pathlib import Path

P = Path('lib/v2/bridgepoint_app_v2.dart')
text = P.read_text(encoding='utf-8')


def transition(old: str, new: str, label: str) -> None:
    global text
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        text = text.replace(old, new, 1)
        print(f'fixed {label}')
        return
    if old_count == 0 and new_count == 1:
        print(f'already fixed {label}')
        return
    raise SystemExit(f'{label}: contract drift old={old_count} new={new_count}')


transition(
    "import 'bridgepoint_map_weather_v2.dart';",
    "import 'bridgepoint_world_embed_v2.dart';",
    'map import',
)
transition(
    "_Area.map => const BridgePointMapWeatherV2()",
    "_Area.map => const BridgePointWorldEmbedV2()",
    'Intelligence Map replacement widget',
)
transition(
    "_Area.map=>'Property Map & Weather'",
    "_Area.map=>'BridgePoint World'",
    'map title',
)
transition(
    "final width=MediaQuery.sizeOf(context).width;final compact=width<820;final body=BridgePointMotionBackgroundV2(child:selected==_Area.owner?Padding(padding:const EdgeInsets.all(8),child:SizedBox.expand(child:_page())):SingleChildScrollView(padding:const EdgeInsets.all(16),child:_page()));",
    "final width=MediaQuery.sizeOf(context).width;final compact=width<820;final isWorld=selected==_Area.map;final body=isWorld?const BridgePointWorldEmbedV2():BridgePointMotionBackgroundV2(child:selected==_Area.owner?Padding(padding:const EdgeInsets.all(8),child:SizedBox.expand(child:_page())):SingleChildScrollView(padding:const EdgeInsets.all(16),child:_page()));",
    'immersive non-scrolling map body',
)
transition(
    "return Scaffold(appBar:_appBar(compact:true),body:body,bottomNavigationBar:NavigationBar",
    "return Scaffold(appBar:isWorld?null:_appBar(compact:true),body:body,bottomNavigationBar:NavigationBar",
    'hide compact map toolbar',
)
transition(
    "Expanded(child:Column(children:[_appBar(compact:false),Expanded(child:body)]))",
    "Expanded(child:isWorld?body:Column(children:[_appBar(compact:false),Expanded(child:body)]))",
    'hide desktop map toolbar',
)

P.write_text(text, encoding='utf-8')
print('BridgePoint Clean V2 Intelligence Map now points to World V2500.')
