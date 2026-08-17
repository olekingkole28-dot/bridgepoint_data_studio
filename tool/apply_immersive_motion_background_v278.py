from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v278-immersive-motion-background'
if marker in body:
    print('Immersive motion background v278 already applied.')
    raise SystemExit(0)

old_exp=r'''class _ExperienceBackground extends StatelessWidget {
  const _ExperienceBackground({required this.child});
  final Widget child;
  @override Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(image:DecorationImage(
      image:AssetImage('assets/images/bridgepoint-intelligence-background-v1.webp'),fit:BoxFit.cover)),
    child:Container(
      decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[AppTheme.navy.withOpacity(.30),AppTheme.navy.withOpacity(.72)])),
      child:child,
    ),
  );
}
'''
new_exp=r'''class _ExperienceBackground extends StatelessWidget {
  const _ExperienceBackground({required this.child});
  final Widget child;
  @override Widget build(BuildContext context)=>_BridgePointMotionBackdropV278(
    asset:'assets/images/bridgepoint-intelligence-background-v1.webp',accent:AppTheme.cyan,dim:0.54,child:child,
  );
}
'''
if body.count(old_exp)!=1:
    raise SystemExit(f'v278 experience background anchor {body.count(old_exp)}')
body=body.replace(old_exp,new_exp,1)

old_workspace=r'''class _WorkspaceAtmosphere extends StatelessWidget{
  const _WorkspaceAtmosphere({required this.pageIndex});
  final int pageIndex;
  @override Widget build(BuildContext context){
    final daily=pageIndex==0||pageIndex==9||pageIndex==10||pageIndex==12||pageIndex==13;
    final map=pageIndex==2||pageIndex==3||pageIndex==8;
    final asset=daily
      ?'assets/images/bridgepoint-daily-brief-background-v2.webp'
      :map?'assets/images/bridgepoint-map-background-v2.webp'
      :'assets/images/bridgepoint-intelligence-background-v1.webp';
    return IgnorePointer(child:Stack(fit:StackFit.expand,children:[
      Image.asset(asset,fit:BoxFit.cover,alignment:map?Alignment.center:Alignment.topCenter,
        color:Colors.white.withOpacity(daily ? .18 : map ? .16 : .11),colorBlendMode:BlendMode.modulate),
      DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[AppTheme.navy.withOpacity(.70),AppTheme.navy.withOpacity(.90),AppTheme.navy.withOpacity(.97)]))),
    ]));
  }
}
'''
new_workspace=r'''class _WorkspaceAtmosphere extends StatelessWidget{
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
      imageOpacity:daily?.24:map?.22:.16,child:const SizedBox.expand(),
    ));
  }
}

class _BridgePointMotionBackdropV278 extends StatefulWidget{
  const _BridgePointMotionBackdropV278({required this.asset,required this.accent,required this.child,this.dim=.78,this.imageOpacity=.28});
  final String asset;final Color accent;final Widget child;final double dim;final double imageOpacity;
  @override State<_BridgePointMotionBackdropV278> createState()=>_BridgePointMotionBackdropV278State();
}
class _BridgePointMotionBackdropV278State extends State<_BridgePointMotionBackdropV278> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){super.initState();controller=AnimationController(vsync:this,duration:const Duration(seconds:18));_syncMotion();_displayPreferences.addListener(_syncMotion);}
  void _syncMotion(){if(_displayPreferences.value.reducedMotion){controller.stop();controller.value=.18;}else if(!controller.isAnimating){controller.repeat();}}
  @override void dispose(){_displayPreferences.removeListener(_syncMotion);controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    Image.asset(widget.asset,fit:BoxFit.cover,color:Colors.white.withOpacity(widget.imageOpacity),colorBlendMode:BlendMode.modulate,filterQuality:FilterQuality.medium),
    AnimatedBuilder(animation:controller,builder:(context,_)=>CustomPaint(painter:_BridgePointAtmospherePainterV278(t:controller.value,accent:widget.accent))),
    DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[AppTheme.navy.withOpacity(widget.dim*.70),AppTheme.navy.withOpacity(widget.dim*.90),AppTheme.navy.withOpacity((widget.dim+.10).clamp(0.0,1.0))]))),
    widget.child,
  ]);
}

class _BridgePointAtmospherePainterV278 extends CustomPainter{
  const _BridgePointAtmospherePainterV278({required this.t,required this.accent});
  final double t;final Color accent;
  @override void paint(Canvas canvas,Size size){
    if(size.isEmpty)return;
    final route=Paint()..style=PaintingStyle.stroke..strokeWidth=1.0..color=accent.withOpacity(.16);
    final routeBright=Paint()..style=PaintingStyle.stroke..strokeWidth=1.8..strokeCap=StrokeCap.round..color=accent.withOpacity(.25);
    for(var i=0;i<6;i++){
      final phase=(t+i*.17)%1.0;
      final y=size.height*(.12+i*.145);
      final path=Path()..moveTo(-size.width*.08,y+sin((t+i)*pi*2)*20)
        ..cubicTo(size.width*.28,y-75+sin(i*1.7)*25,size.width*.62,y+72*cos(i*.8),size.width*1.08,y-15);
      canvas.drawPath(path,route);
      final metric=path.computeMetrics().firstOrNull;
      if(metric!=null){final pos=metric.getTangentForOffset(metric.length*phase)?.position;if(pos!=null){canvas.drawCircle(pos,3.0,Paint()..color=accent.withOpacity(.55));canvas.drawCircle(pos,8.5,Paint()..color=accent.withOpacity(.07));}}
    }
    for(var i=0;i<34;i++){
      final seed=i*37.19;
      final x=((seed*13.7)%997)/997*size.width;
      final base=((seed*7.3)%991)/991;
      final y=((base+t*(.05+(i%5)*.012))%1.0)*size.height;
      final pulse=.35+.65*((sin((t*2*pi)+(i*.71))+1)/2);
      final r=1.0+(i%4)*.45;
      canvas.drawCircle(Offset(x,y),r,Paint()..color=(i%3==0?Colors.white:accent).withOpacity(.06+.12*pulse));
    }
    final sweepY=((t*1.4)%1.0)*size.height;
    final sweep=Paint()..shader=ui.Gradient.linear(Offset(0,sweepY-34),Offset(0,sweepY+34),[Colors.transparent,accent.withOpacity(.045),Colors.transparent],[0,.5,1]);
    canvas.drawRect(Rect.fromLTWH(0,sweepY-34,size.width,68),sweep);
    final glow=Paint()..shader=ui.Gradient.radial(Offset(size.width*(.72+.05*sin(t*2*pi)),size.height*.18),size.width*.36,[accent.withOpacity(.10),Colors.transparent]);
    canvas.drawRect(Offset.zero&size,glow);
  }
  @override bool shouldRepaint(covariant _BridgePointAtmospherePainterV278 old)=>old.t!=t||old.accent!=accent;
}
'''
if body.count(old_workspace)!=1:
    raise SystemExit(f'v278 workspace atmosphere anchor {body.count(old_workspace)}')
body=body.replace(old_workspace,new_workspace,1)

# Dart PathMetric iterable has no firstOrNull getter in core; provide a tiny extension once.
extension_anchor="""class _BridgePointAtmospherePainterV278 extends CustomPainter{
"""
# Replace unsupported firstOrNull expression with a core-safe local metrics list.
body=body.replace("final metric=path.computeMetrics().firstOrNull;\n      if(metric!=null){final pos=metric.getTangentForOffset(metric.length*phase)?.position;if(pos!=null){", "final metrics=path.computeMetrics().toList();final metric=metrics.isEmpty?null:metrics.first;\n      if(metric!=null){final pos=metric.getTangentForOffset(metric.length*phase)?.position;if(pos!=null){",1)

body += "\nconst String _bridgePointImmersiveMotionBackgroundV278='bridgepoint-v278-immersive-motion-background | animated intelligence routes | depth particles | reduced-motion aware | performance-first';\n"
path.write_text(body,encoding='utf-8')
print('Applied immersive BridgePoint motion background v278.')
