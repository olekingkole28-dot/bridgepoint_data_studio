from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v312-cinematic-parallax-background'
if marker in body:
    print('v312 already applied')
    raise SystemExit(0)

old_builder="""    AnimatedBuilder(animation:controller,builder:(context,_)=>Stack(fit:StackFit.expand,children:[
      CustomPaint(painter:_BridgePointSpatialAtmospherePainterV287(t:controller.value,accent:widget.accent)),
      CustomPaint(painter:_BridgePointSemanticScenePainterV290(t:controller.value,accent:widget.accent,scene:widget.scene)),
    ])),
"""
new_builder="""    AnimatedBuilder(animation:controller,builder:(context,_)=>CustomPaint(
      painter:_BridgePointCinematicAtmosphereV312(t:controller.value,accent:widget.accent,scene:widget.scene),
    )),
"""
if body.count(old_builder)!=1:
    raise SystemExit(f'v312 active backdrop builder anchor {body.count(old_builder)}')
body=body.replace(old_builder,new_builder,1)

anchor="class _BridgePointSemanticScenePainterV290 extends CustomPainter{\n"
cinematic=r'''class _BridgePointCinematicAtmosphereV312 extends CustomPainter{
  const _BridgePointCinematicAtmosphereV312({required this.t,required this.accent,required this.scene});
  final double t;final Color accent;final String scene;

  double _seed(int i)=>((i*73+19)%997)/997.0;
  double _sceneHorizon(){
    return switch(scene){
      'weather'=>0.60,'map'=>0.64,'field'=>0.66,'community'=>0.70,'home'=>0.72,
      'brief'=>0.68,'opportunities'=>0.69,'command'=>0.63,'founder'=>0.62,_=>0.67,
    };
  }

  @override void paint(Canvas canvas,Size size){
    if(size.isEmpty)return;
    final w=size.width,h=size.height;
    final phase=t*pi*2;
    final horizon=h*_sceneHorizon();

    // Large moving volumetric glow — slow enough to feel like camera/environment motion.
    final glowCenter=Offset(w*(0.68+0.10*sin(phase*0.55)),h*(0.20+0.07*cos(phase*0.42)));
    final glow=Paint()..shader=ui.Gradient.radial(
      glowCenter,w*0.55,
      [accent.withOpacity(0.18),accent.withOpacity(0.065),const Color(0xFF07111F).withOpacity(0.02),Colors.transparent],
      [0.0,0.28,0.62,1.0],
    );
    canvas.drawRect(Offset.zero&size,glow);

    // Cinematic light shafts drifting across the workspace.
    for(var i=0;i<3;i++){
      final drift=((t*(0.08+i*0.018)+_seed(i))%1.0);
      final x=w*(-0.22+drift*1.44);
      final shaft=ui.Path()
        ..moveTo(x-w*0.09,-h*0.05)
        ..lineTo(x+w*0.05,-h*0.05)
        ..lineTo(x+w*0.27,h*1.05)
        ..lineTo(x+w*0.08,h*1.05)
        ..close();
      final shaftPaint=Paint()..shader=ui.Gradient.linear(
        Offset(x,0),Offset(x+w*0.20,h),
        [Colors.transparent,accent.withOpacity(0.018+i*0.006),accent.withOpacity(0.055+i*0.008),Colors.transparent],
        [0.0,0.32,0.70,1.0],
      );
      canvas.drawPath(shaft,shaftPaint);
    }

    // Atmospheric ribbons: broad, fluid layers instead of technical diagrams/grids.
    for(var layer=0;layer<4;layer++){
      final base=h*(0.30+layer*0.075);
      final amp=h*(0.018+layer*0.008);
      final speed=0.32+layer*0.11;
      final p=ui.Path()..moveTo(-w*0.08,h);
      p.lineTo(-w*0.08,base);
      for(var step=0;step<=14;step++){
        final x=w*(-0.08+step/13.0*1.16);
        final y=base+sin(step*0.72+phase*speed+layer*1.13)*amp+cos(step*0.31-phase*0.21)*amp*0.45;
        p.lineTo(x,y);
      }
      p.lineTo(w*1.08,h);p.close();
      final ribbonPaint=Paint()..shader=ui.Gradient.linear(
        Offset(0,base-amp),Offset(0,h),
        [accent.withOpacity(0.018+layer*0.008),const Color(0xFF07111F).withOpacity(0.06+layer*0.05),const Color(0xFF030811).withOpacity(0.22+layer*0.10)],
        [0.0,0.46,1.0],
      );
      canvas.drawPath(p,ribbonPaint);
    }

    // Three parallax terrain silhouettes create depth and a slow camera-travel feel.
    for(var layer=0;layer<3;layer++){
      final y0=horizon+h*layer*0.07;
      final p=ui.Path()..moveTo(-40,h);
      p.lineTo(-40,y0);
      final travel=phase*(0.08+layer*0.035);
      for(var step=0;step<=18;step++){
        final x=w*(-0.04+step/17.0*1.08);
        final y=y0
          +sin(step*0.67+travel+layer*0.9)*h*(0.030+layer*0.008)
          +cos(step*0.23-travel*0.6)*h*0.014;
        p.lineTo(x,y);
      }
      p.lineTo(w+40,h);p.close();
      final terrain=Paint()..shader=ui.Gradient.linear(
        Offset(0,y0-h*0.05),Offset(0,h),
        [accent.withOpacity(0.035+layer*0.012),const Color(0xFF081522).withOpacity(0.56+layer*0.12),const Color(0xFF02070D).withOpacity(0.93)],
        [0.0,0.30,1.0],
      );
      canvas.drawPath(p,terrain);
    }

    // Sparse particles at different parallax speeds — like intelligence moving through depth.
    for(var i=0;i<30;i++){
      final depth=0.30+_seed(i+41)*0.70;
      final speed=0.020+depth*0.055;
      final x=((_seed(i)+t*speed*8.0)%1.08-0.04)*w;
      final wave=sin(phase*(0.18+depth*0.18)+i*1.17);
      final y=h*(0.10+_seed(i+17)*0.76)+wave*(5.0+depth*7.0);
      final r=0.7+depth*2.1;
      final opacity=(0.025+depth*0.12)*(0.72+0.28*sin(phase*0.25+i));
      canvas.drawCircle(Offset(x,y),r,Paint()..color=accent.withOpacity(opacity.clamp(0.018,0.16).toDouble()));
    }

    // Moving horizon bloom gives the lower scene a soft spatial glow.
    final bloomX=w*(0.50+0.22*sin(phase*0.28));
    final bloom=Paint()..shader=ui.Gradient.radial(
      Offset(bloomX,horizon),w*0.34,
      [accent.withOpacity(0.11),accent.withOpacity(0.025),Colors.transparent],
      [0.0,0.42,1.0],
    );
    canvas.drawOval(Rect.fromCenter(center:Offset(bloomX,horizon),width:w*0.72,height:h*0.30),bloom);

    // Edge vignette keeps text/card contrast cinematic and readable.
    final vignette=Paint()..shader=ui.Gradient.radial(
      size.center(Offset.zero),size.longestSide*0.68,
      [Colors.transparent,const Color(0x5E020811),const Color(0xD9020710)],
      [0.45,0.78,1.0],
    );
    canvas.drawRect(Offset.zero&size,vignette);
  }

  @override bool shouldRepaint(covariant _BridgePointCinematicAtmosphereV312 old)=>old.t!=t||old.accent!=accent||old.scene!=scene;
}

'''
if body.count(anchor)!=1:
    raise SystemExit(f'v312 painter insertion anchor {body.count(anchor)}')
body=body.replace(anchor,cinematic+anchor,1)

body += "\nconst String _bridgePointCinematicParallaxBackgroundV312='bridgepoint-v312-cinematic-parallax-background | no grid/network diagram motion | parallax terrain | atmospheric ribbons | volumetric glow | light shafts | depth particles';\n"
path.write_text(body,encoding='utf-8')
print('Applied v312 cinematic parallax immersive background.')