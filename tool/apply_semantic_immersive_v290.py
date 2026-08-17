from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v290-semantic-immersive-backgrounds'
if marker in body:
    print('v290 already applied')
    raise SystemExit(0)

old_accent="""Color _bridgePointPageAccent(int index)=>switch(index){
  0=>const Color(0xFF42D6C7),1=>const Color(0xFFFFB35A),2=>const Color(0xFF59C98B),
  3=>const Color(0xFF5CB7FF),4=>const Color(0xFF9A86FF),5=>const Color(0xFFFF78C6),
  6=>const Color(0xFF67C8D7),7=>const Color(0xFF7EDB8F),8=>const Color(0xFFFF9557),
  9=>const Color(0xFF72A7FF),10=>const Color(0xFFD9B65C),11=>const Color(0xFFB88CFF),
  12=>const Color(0xFF67B8C7),13=>const Color(0xFFFF8A72),_=>AppTheme.cyan,
};

class _WorkspaceAtmosphere extends StatelessWidget{
  const _WorkspaceAtmosphere({required this.pageIndex});
  final int pageIndex;
  @override Widget build(BuildContext context){
    final daily=pageIndex==0||pageIndex==9||pageIndex==10||pageIndex==12||pageIndex==13;
    final map=pageIndex==2||pageIndex==3||pageIndex==8;
    final asset=daily
      ?'assets/images/bridgepoint-daily-brief-background-v2.webp'
      :map?'assets/images/bridgepoint-map-background-v2.webp'
      :'assets/images/bridgepoint-intelligence-background-v1.webp';
    return IgnorePointer(child:_BridgePointMotionBackdropV278(
      asset:asset,accent:_bridgePointPageAccent(pageIndex),dim:map?0.80:daily?0.77:0.84,
      imageOpacity:daily ? .12 : map ? .10 : .08,child:const SizedBox.expand(),
    ));
  }
}
"""
new_accent="""Color _bridgePointPageAccent(int index)=>switch(index){
  0=>const Color(0xFF42D6C7),1=>const Color(0xFFFFB35A),2=>const Color(0xFF59C98B),
  3=>const Color(0xFF5CB7FF),4=>const Color(0xFF9A86FF),5=>const Color(0xFFFF78C6),
  6=>const Color(0xFF67C8D7),7=>const Color(0xFF7EDB8F),8=>const Color(0xFFFF9557),
  9=>const Color(0xFF72A7FF),10=>const Color(0xFFD9B65C),11=>const Color(0xFFB88CFF),
  12=>const Color(0xFF67B8C7),13=>const Color(0xFFFF8A72),_=>AppTheme.cyan,
};

class _BridgePointBackdropSpecV290{
  const _BridgePointBackdropSpecV290(this.asset,this.accent,this.scene,{this.dim=.76,this.imageOpacity=.18});
  final String asset,scene;final Color accent;final double dim,imageOpacity;
}
_BridgePointBackdropSpecV290 _bridgePointBackdropSpecV290(String label)=>switch(label){
  'Daily Brief'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFF42D6C7),'brief',dim:.72,imageOpacity:.22),
  'Opportunities'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFFFFB35A),'opportunities',dim:.75,imageOpacity:.19),
  'Intelligence Map'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFF5CB7FF),'map',dim:.76,imageOpacity:.22),
  'Properties'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFF59C98B),'properties',dim:.77,imageOpacity:.18),
  'My Home'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFF9A86FF),'home',dim:.72,imageOpacity:.20),
  'My Work'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFFFF78C6),'workflow',dim:.76,imageOpacity:.16),
  'Field Mode'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFF67C8D7),'field',dim:.75,imageOpacity:.20),
  'Weather Center'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFF72A7FF),'weather',dim:.73,imageOpacity:.23),
  'Signals'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFFFF9557),'signals',dim:.77,imageOpacity:.16),
  'Community'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFF7EDB8F),'community',dim:.74,imageOpacity:.18),
  'Pattern Intelligence'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFFD9B65C),'patterns',dim:.76,imageOpacity:.17),
  'Packages'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFFB88CFF),'packages',dim:.78,imageOpacity:.15),
  'About BridgePoint'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFF67B8C7),'bridge',dim:.70,imageOpacity:.24),
  'Sources'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFF48D7F0),'sources',dim:.77,imageOpacity:.16),
  'Permit Context'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFFFF8A72),'permits',dim:.77,imageOpacity:.17),
  'Coverage'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-map-background-v2.webp',Color(0xFF6FA8FF),'coverage',dim:.75,imageOpacity:.20),
  'Models'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFF9B8CFF),'models',dim:.77,imageOpacity:.16),
  'Settings'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFF62D4DB),'settings',dim:.80,imageOpacity:.14),
  'Owner Center'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFF4FE0C1),'command',dim:.73,imageOpacity:.18),
  'Founder Command'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',Color(0xFF38D49A),'founder',dim:.70,imageOpacity:.20),
  'Owner Demo'=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-daily-brief-background-v2.webp',Color(0xFF35D2E8),'demo',dim:.71,imageOpacity:.22),
  _=>const _BridgePointBackdropSpecV290('assets/images/bridgepoint-intelligence-background-v1.webp',AppTheme.cyan,'intelligence',dim:.78,imageOpacity:.16),
};
Color _bridgePointPageAccentV290(String label)=>_bridgePointBackdropSpecV290(label).accent;

class _WorkspaceAtmosphere extends StatelessWidget{
  const _WorkspaceAtmosphere({required this.pageLabel});
  final String pageLabel;
  @override Widget build(BuildContext context){
    final spec=_bridgePointBackdropSpecV290(pageLabel);
    return IgnorePointer(child:_BridgePointMotionBackdropV278(
      asset:spec.asset,accent:spec.accent,scene:spec.scene,dim:spec.dim,imageOpacity:spec.imageOpacity,child:const SizedBox.expand(),
    ));
  }
}
"""
if body.count(old_accent)!=1:
    raise SystemExit(f'v290 workspace atmosphere anchor {body.count(old_accent)}')
body=body.replace(old_accent,new_accent,1)

old_ctor="""class _BridgePointMotionBackdropV278 extends StatefulWidget{
  const _BridgePointMotionBackdropV278({required this.asset,required this.accent,required this.child,this.dim=.78,this.imageOpacity=.28});
  final String asset;final Color accent;final Widget child;final double dim;final double imageOpacity;
"""
new_ctor="""class _BridgePointMotionBackdropV278 extends StatefulWidget{
  const _BridgePointMotionBackdropV278({required this.asset,required this.accent,required this.child,this.dim=.78,this.imageOpacity=.28,this.scene='intelligence'});
  final String asset;final Color accent;final Widget child;final double dim;final double imageOpacity;final String scene;
"""
if body.count(old_ctor)!=1: raise SystemExit('v290 backdrop ctor anchor')
body=body.replace(old_ctor,new_ctor,1)

old_builder="""    AnimatedBuilder(animation:controller,builder:(context,_)=>CustomPaint(painter:_BridgePointSpatialAtmospherePainterV287(t:controller.value,accent:widget.accent))),
"""
new_builder="""    AnimatedBuilder(animation:controller,builder:(context,_)=>Stack(fit:StackFit.expand,children:[
      CustomPaint(painter:_BridgePointSpatialAtmospherePainterV287(t:controller.value,accent:widget.accent)),
      CustomPaint(painter:_BridgePointSemanticScenePainterV290(t:controller.value,accent:widget.accent,scene:widget.scene)),
    ])),
"""
if body.count(old_builder)!=1: raise SystemExit('v290 backdrop painter anchor')
body=body.replace(old_builder,new_builder,1)

painter_anchor="class _BridgePointSpatialAtmospherePainterV287 extends CustomPainter{\n"
semantic=r'''class _BridgePointSemanticScenePainterV290 extends CustomPainter{
  const _BridgePointSemanticScenePainterV290({required this.t,required this.accent,required this.scene});
  final double t;final Color accent;final String scene;
  Paint _line([double opacity=.18,double width=1.15])=>Paint()..style=PaintingStyle.stroke..strokeWidth=width..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..color=accent.withOpacity(opacity);
  Paint _fill([double opacity=.08])=>Paint()..style=PaintingStyle.fill..color=accent.withOpacity(opacity);
  void _node(Canvas c,Offset p,{double r=3,double pulse=1}){c.drawCircle(p,r+5*pulse,_fill(.018+.015*pulse));c.drawCircle(p,r,_fill(.26+.12*pulse));}
  void _house(Canvas c,Offset base,double s){final p=ui.Path()..moveTo(base.dx-s*.55,base.dy)..lineTo(base.dx-s*.55,base.dy-s*.55)..lineTo(base.dx,base.dy-s)..lineTo(base.dx+s*.55,base.dy-s*.55)..lineTo(base.dx+s*.55,base.dy)..close();c.drawPath(p,_line(.17,1.05));c.drawRect(Rect.fromLTWH(base.dx-s*.12,base.dy-s*.38,s*.24,s*.38),_fill(.05));}
  void _radar(Canvas c,Offset center,double r){for(var i=1;i<=4;i++)c.drawCircle(center,r*i/4,_line(.10,1));final a=t*pi*2;final end=center+Offset(cos(a),sin(a))*r;c.drawLine(center,end,_line(.28,1.6));_node(c,end,r:2.6,pulse:.8);}
  @override void paint(Canvas canvas,Size size){
    if(size.isEmpty)return;
    final w=size.width,h=size.height,pulse=.5+.5*sin(t*pi*2);
    final right=Offset(w*.79,h*.28),left=Offset(w*.18,h*.69),mid=Offset(w*.53,h*.60);
    switch(scene){
      case 'brief':
        final sun=Offset(w*.78,h*.22);canvas.drawCircle(sun,34+4*pulse,_fill(.055));canvas.drawCircle(sun,8,_fill(.23));
        for(var i=0;i<5;i++){final y=h*(.48+i*.075);canvas.drawLine(Offset(w*.08,y),Offset(w*(.25+i*.085),y),_line(.10+i*.018,1));_node(canvas,Offset(w*(.25+i*.085),y),r:2.3,pulse:pulse);}
        break;
      case 'opportunities':
        for(var i=0;i<4;i++){final b=Offset(w*(.18+i*.19),h*(.79-(i%2)*.05));_house(canvas,b,42+(i%2)*7);_node(canvas,Offset(b.dx,b.dy-58-(i%2)*7),r:3.1,pulse:pulse);canvas.drawLine(Offset(b.dx,b.dy-49),Offset(b.dx,b.dy-21),_line(.18,1));}
        break;
      case 'map': _radar(canvas,right,w*.15);for(var i=0;i<6;i++)_node(canvas,Offset(w*(.13+i*.13),h*(.73-.12*sin(i*.8))),r:2.2,pulse:pulse);break;
      case 'properties':
        for(var i=0;i<4;i++){final x=w*(.14+i*.19),y=h*(.69+(i%2)*.07);canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,y),width:118,height:74),const Radius.circular(8)),_line(.10,1));_house(canvas,Offset(x,y+24),31);}
        break;
      case 'home': _house(canvas,Offset(w*.73,h*.76),105);canvas.drawCircle(Offset(w*.73,h*.50),70,_line(.06,1));canvas.drawCircle(Offset(w*.73,h*.50),92+6*pulse,_line(.035,1));break;
      case 'workflow':
        final p=ui.Path()..moveTo(w*.16,h*.78)..cubicTo(w*.28,h*.55,w*.38,h*.80,w*.50,h*.57)..cubicTo(w*.62,h*.34,w*.70,h*.62,w*.84,h*.33);canvas.drawPath(p,_line(.22,2));for(final q in [Offset(w*.16,h*.78),Offset(w*.50,h*.57),Offset(w*.84,h*.33)])_node(canvas,q,r:3,pulse:pulse);break;
      case 'field':
        final p=ui.Path()..moveTo(w*.10,h*.80)..lineTo(w*.25,h*.61)..lineTo(w*.42,h*.71)..lineTo(w*.60,h*.46)..lineTo(w*.83,h*.54);canvas.drawPath(p,_line(.24,2));for(final q in [Offset(w*.10,h*.80),Offset(w*.25,h*.61),Offset(w*.42,h*.71),Offset(w*.60,h*.46),Offset(w*.83,h*.54)])_node(canvas,q,r:2.7,pulse:pulse);_radar(canvas,Offset(w*.84,h*.28),54);break;
      case 'weather':
        _radar(canvas,Offset(w*.79,h*.29),w*.13);for(var i=0;i<5;i++){final x=w*(.12+i*.11);canvas.drawCircle(Offset(x,h*.35),24+(i%2)*8,_fill(.035));canvas.drawCircle(Offset(x+22,h*.36),30,_fill(.03));for(var r=0;r<3;r++)canvas.drawLine(Offset(x-8+r*15,h*.43),Offset(x-14+r*15,h*.49),_line(.10,1));}final bolt=ui.Path()..moveTo(w*.36,h*.46)..lineTo(w*.32,h*.58)..lineTo(w*.38,h*.58)..lineTo(w*.34,h*.70);canvas.drawPath(bolt,_line(.30,2.2));break;
      case 'signals':
        final p=ui.Path()..moveTo(w*.08,h*.60);for(var i=0;i<18;i++){final x=w*(.08+i*.047),y=h*(.60+sin(i*.92+t*pi*2)*(.025+(i%4==0?.08:.035)));p.lineTo(x,y);}canvas.drawPath(p,_line(.28,1.8));_radar(canvas,right,64);break;
      case 'community':
        for(var i=0;i<5;i++)_house(canvas,Offset(w*(.16+i*.15),h*(.77-(i%2)*.04)),30+(i%3)*6);for(var i=0;i<4;i++)canvas.drawLine(Offset(w*(.16+i*.15),h*.67),Offset(w*(.31+i*.15),h*.63),_line(.08,1));break;
      case 'patterns':
        final pts=<Offset>[];for(var i=0;i<10;i++)pts.add(Offset(w*(.12+((i*31)%75)/100),h*(.30+((i*47)%48)/100)));for(var i=0;i<pts.length;i++){for(var j=i+1;j<pts.length;j++)if((pts[i]-pts[j]).distance<w*.23)canvas.drawLine(pts[i],pts[j],_line(.07,1));_node(canvas,pts[i],r:2.6,pulse:.4+.6*((i%3)/2));}break;
      case 'packages':
        for(var i=0;i<4;i++){final r=Rect.fromLTWH(w*(.19+i*.11),h*(.38+i*.07),w*.42,h*.22);canvas.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(18)),_line(.08+i*.025,1.2));}break;
      case 'bridge':
        final y=h*.70;canvas.drawLine(Offset(w*.09,y),Offset(w*.91,y),_line(.24,2));final lx=w*.30,rx=w*.70;canvas.drawLine(Offset(lx,y),Offset(lx,h*.35),_line(.20,2));canvas.drawLine(Offset(rx,y),Offset(rx,h*.35),_line(.20,2));final cable=ui.Path()..moveTo(w*.10,h*.47)..quadraticBezierTo(lx,h*.36,w*.50,h*.58)..quadraticBezierTo(rx,h*.36,w*.90,h*.47);canvas.drawPath(cable,_line(.18,1.5));for(var i=0;i<9;i++){final x=w*(.14+i*.09);canvas.drawLine(Offset(x,y),Offset(x,h*(.48+.09*sin(i*.7))),_line(.07,1));}break;
      case 'sources':
        final core=Offset(w*.73,h*.55);for(var i=0;i<7;i++){final p=Offset(w*(.10+(i%3)*.16),h*(.30+(i~/3)*.20));canvas.drawLine(p,core,_line(.08,1));_node(canvas,p,r:2.4,pulse:pulse);}canvas.drawCircle(core,24+3*pulse,_line(.20,1.5));_node(canvas,core,r:4,pulse:pulse);break;
      case 'permits':
        for(var i=0;i<8;i++){final x=w*(.12+i*.08);canvas.drawLine(Offset(x,h*.34),Offset(x,h*.80),_line(.04,1));}for(var i=0;i<7;i++){final y=h*(.36+i*.065);canvas.drawLine(Offset(w*.10,y),Offset(w*.72,y),_line(.04,1));}canvas.drawRect(Rect.fromLTWH(w*.30,h*.48,w*.26,h*.28),_line(.16,1.5));canvas.drawLine(Offset(w*.30,h*.48),Offset(w*.43,h*.38),_line(.16,1.5));canvas.drawLine(Offset(w*.43,h*.38),Offset(w*.56,h*.48),_line(.16,1.5));break;
      case 'coverage':
        for(var r=0;r<3;r++)for(var c=0;c<7;c++){final x=w*(.16+c*.095+(r%2)*.045),y=h*(.42+r*.12);final p=Offset(x,y);canvas.drawCircle(p,22,_line(.06+(c%3)*.02,1));if((r+c)%2==0)_node(canvas,p,r:2.2,pulse:pulse);}break;
      case 'models':
        final cols=[.16,.36,.58,.80];final counts=[4,6,5,3];final pts=<List<Offset>>[];for(var c=0;c<cols.length;c++){final col=<Offset>[];for(var i=0;i<counts[c];i++)col.add(Offset(w*cols[c],h*(.32+i*(.46/(counts[c]-1)))));pts.add(col);}for(var c=0;c<pts.length-1;c++)for(final a in pts[c])for(final b in pts[c+1])canvas.drawLine(a,b,_line(.028,1));for(final col in pts)for(final p in col)_node(canvas,p,r:2.3,pulse:pulse);break;
      case 'settings':
        for(var i=0;i<5;i++){final y=h*(.36+i*.09);canvas.drawLine(Offset(w*.20,y),Offset(w*.75,y),_line(.08,1.4));final x=w*(.30+((i*17)%40)/100);_node(canvas,Offset(x,y),r:3,pulse:pulse);}for(var i=0;i<3;i++)canvas.drawCircle(Offset(w*(.79+i*.035),h*(.30+i*.10)),20+i*8,_line(.07,1));break;
      case 'command': case 'founder':
        final rects=[Rect.fromLTWH(w*.10,h*.32,w*.25,h*.18),Rect.fromLTWH(w*.39,h*.32,w*.22,h*.18),Rect.fromLTWH(w*.65,h*.32,w*.25,h*.18),Rect.fromLTWH(w*.18,h*.57,w*.28,h*.18),Rect.fromLTWH(w*.51,h*.57,w*.31,h*.18)];for(final r in rects)canvas.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(10)),_line(.10,1.2));_radar(canvas,Offset(w*.77,h*.25),44);break;
      case 'demo':
        final center=Offset(w*.52,h*.54);for(var i=0;i<4;i++)canvas.drawCircle(center,36+i*25+5*pulse,_line(.055+i*.02,1));canvas.drawLine(Offset(w*.10,h*.78),Offset(w*.90,h*.78),_line(.12,1.4));for(var i=0;i<6;i++)_node(canvas,Offset(w*(.17+i*.13),h*.78),r:2.3,pulse:pulse);break;
      default:
        canvas.drawLine(left,right,_line(.10,1));canvas.drawLine(right,mid,_line(.10,1));_node(canvas,left,pulse:pulse);_node(canvas,right,pulse:pulse);_node(canvas,mid,pulse:pulse);
    }
  }
  @override bool shouldRepaint(covariant _BridgePointSemanticScenePainterV290 old)=>old.t!=t||old.accent!=accent||old.scene!=scene;
}

'''
if body.count(painter_anchor)!=1: raise SystemExit('v290 semantic painter anchor')
body=body.replace(painter_anchor,semantic+painter_anchor,1)

old_workspace="Positioned.fill(child:_WorkspaceAtmosphere(pageIndex:selectedNavigation)),"
new_workspace="Positioned.fill(child:_WorkspaceAtmosphere(pageLabel:visibleNavigationItems[selectedNavigation].label)),"
if body.count(old_workspace)!=1: raise SystemExit('v290 workspace call anchor')
body=body.replace(old_workspace,new_workspace,1)

old_topbar="accent:_bridgePointPageAccent(selectedNavigation),"
new_topbar="accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),"
if body.count(old_topbar)!=1: raise SystemExit('v290 topbar accent anchor')
body=body.replace(old_topbar,new_topbar,1)

# Let the background read through cards while preserving strong-contrast mode as opaque.
old_card="""      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
"""
new_card="""      cardTheme: CardThemeData(
        color: panel.withOpacity(.90),
        elevation: 0,
"""
if body.count(old_card)!=1: raise SystemExit('v290 dark card anchor')
body=body.replace(old_card,new_card,1)

body += "\nconst String _bridgePointSemanticImmersiveBackgroundV290='bridgepoint-v290-semantic-immersive-backgrounds | every workspace has a page-specific scene | label-safe owner/customer backgrounds | translucent cards | reduced-motion aware';\n"
path.write_text(body,encoding='utf-8')
print('Applied v290 semantic immersive workspace backgrounds.')