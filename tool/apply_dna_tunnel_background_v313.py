from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-dna-data-tunnel-background'
if marker in body:
    print('v313 DNA data tunnel already applied.')
    raise SystemExit(0)

old_build="""  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    Image.asset(widget.asset,fit:BoxFit.cover,color:Colors.white.withOpacity(widget.imageOpacity),colorBlendMode:BlendMode.modulate,filterQuality:FilterQuality.medium),
    AnimatedBuilder(animation:controller,builder:(context,_)=>CustomPaint(
      painter:_BridgePointCinematicAtmosphereV312(t:controller.value,accent:widget.accent,scene:widget.scene),
    )),
    DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[AppTheme.navy.withOpacity(widget.dim*.70),AppTheme.navy.withOpacity(widget.dim*.90),AppTheme.navy.withOpacity((widget.dim+.10).clamp(0.0,1.0).toDouble())]))),
    widget.child,
  ]);
}

class _BridgePointCinematicAtmosphereV312 extends CustomPainter{
"""
new_build="""  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    Image.asset(widget.asset,fit:BoxFit.cover,color:Colors.white.withOpacity(widget.imageOpacity*.16),colorBlendMode:BlendMode.modulate,filterQuality:FilterQuality.low),
    DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[AppTheme.navy.withOpacity(widget.dim*.76),AppTheme.navy.withOpacity(widget.dim*.84),AppTheme.navy.withOpacity((widget.dim+.06).clamp(0.0,1.0).toDouble())]))),
    AnimatedBuilder(animation:controller,builder:(context,_)=>CustomPaint(
      painter:_BridgePointDnaTunnelV313(t:controller.value,accent:widget.accent,scene:widget.scene),
    )),
    widget.child,
  ]);
}

class _BridgePointDnaTunnelV313 extends CustomPainter{
  const _BridgePointDnaTunnelV313({required this.t,required this.accent,required this.scene});
  final double t;final Color accent;final String scene;

  double _seed(int i)=>((i*89+31)%1009)/1009.0;
  double get _ownerBoost=>scene=='command'||scene=='founder'||scene=='demo'?1.18:1.0;
  Color _mix(Color a,Color b,double x)=>Color.lerp(a,b,x)??a;

  @override void paint(Canvas canvas,Size size){
    if(size.isEmpty)return;
    final w=size.width,h=size.height;
    final phase=t*pi*2;
    final electric=_mix(const Color(0xFF168CFF),accent,.20);
    final cyan=_mix(const Color(0xFF5EF4FF),accent,.12);
    final deep=const Color(0xFF071321);

    final bloomCenter=Offset(w*(.55+.06*sin(phase*.36)),h*(.47+.04*cos(phase*.28)));
    canvas.drawRect(Offset.zero&size,Paint()..shader=ui.Gradient.radial(
      bloomCenter,size.longestSide*.64,
      [electric.withOpacity(.20*_ownerBoost),cyan.withOpacity(.065),deep.withOpacity(.05),Colors.transparent],
      const [0,.28,.64,1],
    ));

    canvas.save();
    canvas.translate(w*.52,h*.51);
    canvas.rotate(-.18);

    final axis=w*1.36;
    final foreground=-axis*.50;
    final distance=axis*.50;

    for(var i=0;i<18;i++){
      final z=((i/18.0+t*.22)%1.0);
      final x=foreground+(distance-foreground)*z;
      final perspective=1-z;
      final rx=h*(.045+.20*perspective);
      final ry=rx*(.52+.06*sin(phase*.24+i));
      final opacity=(.025+.105*perspective)*_ownerBoost;
      final rect=Rect.fromCenter(center:Offset(x,0),width:rx*2,height:ry*2);
      canvas.drawOval(rect,Paint()..style=PaintingStyle.stroke..strokeWidth=1.0+2.0*perspective..color=electric.withOpacity(opacity.clamp(0.02,.17)));
      if(i%4==0){
        final arcPaint=Paint()..style=PaintingStyle.stroke..strokeWidth=2.2+2.8*perspective..strokeCap=StrokeCap.round..color=cyan.withOpacity((opacity*1.65).clamp(.04,.24));
        canvas.drawArc(rect,phase*.20+i*.71,pi*.34,false,arcPaint);
      }
    }

    Offset strandPoint(double z,bool second){
      final x=foreground+(distance-foreground)*z;
      final perspective=1-z;
      final amp=h*(.025+.115*perspective);
      final wave=sin(z*pi*8-phase*1.35+(second?pi:0));
      return Offset(x,wave*amp);
    }
    final strandA=ui.Path(),strandB=ui.Path();
    const n=44;
    for(var i=0;i<=n;i++){
      final z=i/n;
      final a=strandPoint(z,false),b=strandPoint(z,true);
      if(i==0){strandA.moveTo(a.dx,a.dy);strandB.moveTo(b.dx,b.dy);}else{strandA.lineTo(a.dx,a.dy);strandB.lineTo(b.dx,b.dy);}
    }
    canvas.drawPath(strandA,Paint()..style=PaintingStyle.stroke..strokeWidth=7.0..strokeCap=StrokeCap.round..color=electric.withOpacity(.07*_ownerBoost));
    canvas.drawPath(strandB,Paint()..style=PaintingStyle.stroke..strokeWidth=7.0..strokeCap=StrokeCap.round..color=electric.withOpacity(.07*_ownerBoost));
    canvas.drawPath(strandA,Paint()..style=PaintingStyle.stroke..strokeWidth=2.25..strokeCap=StrokeCap.round..color=cyan.withOpacity(.58*_ownerBoost));
    canvas.drawPath(strandB,Paint()..style=PaintingStyle.stroke..strokeWidth=2.25..strokeCap=StrokeCap.round..color=electric.withOpacity(.58*_ownerBoost));

    for(var i=0;i<=n;i+=3){
      final z=i/n;
      final a=strandPoint(z,false),b=strandPoint(z,true);
      final perspective=1-z;
      canvas.drawLine(a,b,Paint()..strokeWidth=.7+1.35*perspective..color=cyan.withOpacity((.06+.20*perspective)*_ownerBoost));
      if(i%6==0){
        final r=1.5+3.1*perspective;
        for(final p in [a,b]){
          canvas.drawCircle(p,r*2.5,Paint()..color=electric.withOpacity(.045*_ownerBoost));
          canvas.drawCircle(p,r,Paint()..color=cyan.withOpacity((.34+.28*perspective).clamp(.25,.72)));
        }
      }
    }

    final scanZ=(t*.72)%1.0;
    final scanX=foreground+(distance-foreground)*scanZ;
    final scanPerspective=1-scanZ;
    final scanRx=h*(.055+.22*scanPerspective),scanRy=scanRx*.54;
    final scanRect=Rect.fromCenter(center:Offset(scanX,0),width:scanRx*2,height:scanRy*2);
    canvas.drawOval(scanRect,Paint()..style=PaintingStyle.stroke..strokeWidth=9..color=cyan.withOpacity(.045*_ownerBoost));
    canvas.drawOval(scanRect,Paint()..style=PaintingStyle.stroke..strokeWidth=2.7..color=cyan.withOpacity(.60*_ownerBoost));

    for(var i=0;i<22;i++){
      final z=((_seed(i)+t*(.10+.07*_seed(i+4)))%1.0);
      final x=foreground+(distance-foreground)*z;
      final perspective=1-z;
      final lane=(i%2==0?1:-1)*h*(.13+.10*perspective);
      final y=lane+sin(phase*.30+i)*h*.018;
      final r=.7+2.4*perspective;
      canvas.drawCircle(Offset(x,y),r*3,Paint()..color=electric.withOpacity(.025+.035*perspective));
      canvas.drawCircle(Offset(x,y),r,Paint()..color=cyan.withOpacity(.14+.24*perspective));
    }

    for(var lane=-2;lane<=2;lane++){
      final y=h*(.19+lane*.052);
      final drift=(t*(36+lane.abs()*7))%(w*.22);
      canvas.drawLine(Offset(-w*.70+drift,y),Offset(w*.64,y),Paint()..strokeWidth=.8..color=electric.withOpacity(.035));
      for(var j=0;j<7;j++){
        final x=-w*.62+j*w*.19+drift;
        canvas.drawCircle(Offset(x,y),1.4,Paint()..color=cyan.withOpacity(.10));
      }
    }
    canvas.restore();

    canvas.drawRect(Offset.zero&size,Paint()..shader=ui.Gradient.radial(
      size.center(Offset.zero),size.longestSide*.74,
      [Colors.transparent,const Color(0x24020A14),const Color(0x9201060D)],
      const [.42,.76,1],
    ));
  }

  @override bool shouldRepaint(covariant _BridgePointDnaTunnelV313 old)=>old.t!=t||old.accent!=accent||old.scene!=scene;
}

class _BridgePointCinematicAtmosphereV312 extends CustomPainter{
"""
if body.count(old_build)!=1:
    raise SystemExit(f'v313 DNA backdrop anchor count {body.count(old_build)}')
body=body.replace(old_build,new_build,1)
body += "\nconst String _bridgePointDnaDataTunnelV313='bridgepoint-v313-dna-data-tunnel-background | electric blue DNA helix | moving scan tunnel | data packets | property evidence lanes | procedural performance';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 BridgePoint DNA/data tunnel background.')
