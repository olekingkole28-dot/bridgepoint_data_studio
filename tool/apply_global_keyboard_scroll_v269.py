from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v269-global-keyboard-scroll'
if marker in body:
    print('Global keyboard scrolling v269 already applied.')
    raise SystemExit(0)

insert_anchor='class BridgePointApp extends StatelessWidget {\n'
if body.count(insert_anchor)!=1:
    raise SystemExit(f'v269 BridgePointApp anchor count {body.count(insert_anchor)}')

helper=r'''
class _BridgePointKeyboardScrollV269 extends StatefulWidget{
  const _BridgePointKeyboardScrollV269({required this.child});
  final Widget child;
  @override State<_BridgePointKeyboardScrollV269> createState()=>_BridgePointKeyboardScrollV269State();
}
class _BridgePointKeyboardScrollV269State extends State<_BridgePointKeyboardScrollV269>{
  late final FocusNode _focusNode;
  @override void initState(){super.initState();_focusNode=FocusNode(debugLabel:'BridgePoint global keyboard scroll');}
  @override void dispose(){_focusNode.dispose();super.dispose();}

  ScrollPosition? _activeScrollPosition(){
    final focused=FocusManager.instance.primaryFocus?.context;
    if(focused!=null){
      final editable=focused.findAncestorWidgetOfExactType<EditableText>();
      if(editable!=null)return null;
      final scrollable=Scrollable.maybeOf(focused);
      if(scrollable!=null&&scrollable.position.hasContentDimensions)return scrollable.position;
    }
    final primary=PrimaryScrollController.maybeOf(context);
    if(primary!=null&&primary.hasClients)return primary.position;
    return null;
  }

  KeyEventResult _handleKey(FocusNode node,KeyEvent event){
    if(event is! KeyDownEvent&&event is! KeyRepeatEvent)return KeyEventResult.ignored;
    final key=event.logicalKey;
    if(key!=LogicalKeyboardKey.arrowDown&&key!=LogicalKeyboardKey.arrowUp&&key!=LogicalKeyboardKey.pageDown&&key!=LogicalKeyboardKey.pageUp&&key!=LogicalKeyboardKey.home&&key!=LogicalKeyboardKey.end){
      return KeyEventResult.ignored;
    }
    final position=_activeScrollPosition();
    if(position==null)return KeyEventResult.ignored;
    double target=position.pixels;
    if(key==LogicalKeyboardKey.arrowDown)target+=72;
    if(key==LogicalKeyboardKey.arrowUp)target-=72;
    if(key==LogicalKeyboardKey.pageDown)target+=position.viewportDimension*.82;
    if(key==LogicalKeyboardKey.pageUp)target-=position.viewportDimension*.82;
    if(key==LogicalKeyboardKey.home)target=position.minScrollExtent;
    if(key==LogicalKeyboardKey.end)target=position.maxScrollExtent;
    target=target.clamp(position.minScrollExtent,position.maxScrollExtent);
    if((target-position.pixels).abs()<1)return KeyEventResult.handled;
    position.animateTo(target,duration:const Duration(milliseconds:150),curve:Curves.easeOutCubic);
    return KeyEventResult.handled;
  }

  @override Widget build(BuildContext context)=>Focus(
    autofocus:true,
    focusNode:_focusNode,
    canRequestFocus:true,
    onKeyEvent:_handleKey,
    child:widget.child,
  );
}

'''
body=body.replace(insert_anchor,helper+insert_anchor,1)

old="""            child: child ?? const SizedBox.shrink(),
"""
new="""            child: _BridgePointKeyboardScrollV269(child:child ?? const SizedBox.shrink()),
"""
if body.count(old)!=1:
    raise SystemExit(f'v269 MaterialApp builder child anchor count {body.count(old)}')
body=body.replace(old,new,1)

body += "\nconst String _bridgePointGlobalKeyboardScrollV269='bridgepoint-v269-global-keyboard-scroll | arrowDown | arrowUp | pageDown | pageUp';\n"
path.write_text(body,encoding='utf-8')
print('Applied global BridgePoint keyboard scrolling v269.')
