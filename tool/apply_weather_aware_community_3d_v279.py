from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v279-community-3d-live-weather'
if marker in body:
    print('Community 3D live weather v279 already applied.')
    raise SystemExit(0)

body=body.replace("class _Community3DMapV255State extends State<_Community3DMapV255>{", "class _Community3DMapV255State extends State<_Community3DMapV255> with SingleTickerProviderStateMixin{",1)

old_fields="""  int precisionBuildings=0,clusterCount=0;
  String coverage='U.S. 3D BUILDINGS';
  String? error;
  Timer? debounce;
  ml.CameraPosition camera=const ml.CameraPosition(target:ml.LatLng(41.5623,-72.6506),zoom:15.2,tilt:58,bearing:-18);
  int requestSerial=0;

  @override void dispose(){debounce?.cancel();super.dispose();}
"""
new_fields="""  int precisionBuildings=0,clusterCount=0;
  String coverage='U.S. 3D BUILDINGS';
  String weatherEffect='CLEAR',weatherText='Weather checking';
  double weatherIntensity=0;
  String? error;
  Timer? debounce;
  DateTime? lastWeatherAt;
  ml.LatLng? lastWeatherTarget;
  late final AnimationController weatherMotion;
  ml.CameraPosition camera=const ml.CameraPosition(target:ml.LatLng(41.5623,-72.6506),zoom:15.2,tilt:58,bearing:-18);
  int requestSerial=0;

  @override void initState(){super.initState();weatherMotion=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));_displayPreferences.addListener(_syncWeatherMotion);}
  void _syncWeatherMotion(){final animate=weatherEffect!='CLEAR'&&!_displayPreferences.value.reducedMotion;if(animate&&!weatherMotion.isAnimating)weatherMotion.repeat();else if(!animate&&weatherMotion.isAnimating)weatherMotion.stop();}
  @override void dispose(){debounce?.cancel();_displayPreferences.removeListener(_syncWeatherMotion);weatherMotion.dispose();super.dispose();}
"""
if body.count(old_fields)!=1:
    raise SystemExit(f'v279 fields anchor {body.count(old_fields)}')
body=body.replace(old_fields,new_fields,1)

refresh_anchor="""  Future<void> _refreshViewport()async{
"""
weather_method=r'''  Future<void> _refreshWeatherForCamera({bool force=false})async{
    final target=(controller?.cameraPosition??camera).target;
    final now=DateTime.now();
    final moved=lastWeatherTarget==null||((target.latitude-lastWeatherTarget!.latitude).abs()+(target.longitude-lastWeatherTarget!.longitude).abs())>.08;
    if(!force&&!moved&&lastWeatherAt!=null&&now.difference(lastWeatherAt!)<const Duration(minutes:2))return;
    lastWeatherAt=now;lastWeatherTarget=target;
    try{
      final response=await Supabase.instance.client.functions.invoke('bridgepoint-weather-center-v136',body:{'latitude':target.latitude,'longitude':target.longitude,'radius_km':10,'opportunity_limit':1});
      final payload=_edgeFunctionPayload(response.data);
      if(response.status<200||response.status>=300||payload['complete']!=true)return;
      final current=_bpMap(payload['current']);
      final hourly=_detailList(payload['hourly']);
      final description='${current['textDescription']??(hourly.isNotEmpty?hourly.first['shortForecast']:'Clear')}'.trim();
      final first=hourly.isNotEmpty?hourly.first:<String,dynamic>{};
      final pop=(first['probabilityOfPrecipitation'] as num?)?.toDouble()??0;
      final lower=description.toLowerCase();
      var kind='CLEAR';
      if(RegExp(r'snow|flurr|blizzard|snow shower').hasMatch(lower))kind='SNOW';
      else if(RegExp(r'rain|shower|drizzle|thunder|storm').hasMatch(lower))kind='RAIN';
      else if(pop>=65){final forecast='${first['shortForecast']??''}'.toLowerCase();kind=forecast.contains('snow')?'SNOW':forecast.contains('rain')||forecast.contains('shower')||forecast.contains('storm')?'RAIN':'CLEAR';}
      if(mounted){setState((){weatherEffect=kind;weatherText=description.isEmpty?'Current weather':description;weatherIntensity=(pop/100).clamp(.20,1.0);});_syncWeatherMotion();}
    }catch(_){/* Weather effects are additive and can never block Community 3D. */}
  }

'''
if body.count(refresh_anchor)!=1:
    raise SystemExit(f'v279 refresh method anchor {body.count(refresh_anchor)}')
body=body.replace(refresh_anchor,weather_method+refresh_anchor,1)

old_cp="""      final cp=c.cameraPosition??camera;camera=cp;
      final west=bounds.southwest.longitude,south=bounds.southwest.latitude,east=bounds.northeast.longitude,north=bounds.northeast.latitude;
"""
new_cp="""      final cp=c.cameraPosition??camera;camera=cp;
      unawaited(_refreshWeatherForCamera());
      final west=bounds.southwest.longitude,south=bounds.southwest.latitude,east=bounds.northeast.longitude,north=bounds.northeast.latitude;
"""
if body.count(old_cp)!=1:
    raise SystemExit(f'v279 viewport camera anchor {body.count(old_cp)}')
body=body.replace(old_cp,new_cp,1)

old_center="""      await c.animateCamera(ml.CameraUpdate.newCameraPosition(camera),duration:const Duration(milliseconds:650));
      _queueRefresh();
"""
new_center="""      await c.animateCamera(ml.CameraUpdate.newCameraPosition(camera),duration:const Duration(milliseconds:650));
      _queueRefresh();unawaited(_refreshWeatherForCamera(force:true));
"""
if body.count(old_center)!=1:
    raise SystemExit(f'v279 center anchor {body.count(old_center)}')
body=body.replace(old_center,new_center,1)

old_chips="""        _OpportunityChip(label:'$clusterCount LIVE CLUSTERS',color:AppTheme.green),
        if(precisionBuildings>0)_OpportunityChip(label:'$precisionBuildings CT PRECISION BUILDINGS',color:const Color(0xFF9B7BFF)),
        const _OpportunityChip(label:'OPEN MAP • NO PAID MAP KEY',color:AppTheme.amber),
"""
new_chips="""        _OpportunityChip(label:'$clusterCount LIVE CLUSTERS',color:AppTheme.green),
        _OpportunityChip(label:'WEATHER • $weatherText',color:weatherEffect=='RAIN'?AppTheme.blue:weatherEffect=='SNOW'?const Color(0xFFBBDFFF):AppTheme.cyan),
        if(precisionBuildings>0)_OpportunityChip(label:'$precisionBuildings CT PRECISION BUILDINGS',color:const Color(0xFF9B7BFF)),
        const _OpportunityChip(label:'OPEN MAP • NO PAID MAP KEY',color:AppTheme.amber),
"""
if body.count(old_chips)!=1:
    raise SystemExit(f'v279 chips anchor {body.count(old_chips)}')
body=body.replace(old_chips,new_chips,1)

map_end="""        ))),
        Positioned(top:10,right:10,child:Column(children:[
"""
map_overlay="""        ))),
        if(weatherEffect!='CLEAR')Positioned.fill(child:IgnorePointer(child:AnimatedBuilder(animation:weatherMotion,builder:(context,_)=>CustomPaint(painter:_CommunityWeatherPainterV279(t:weatherMotion.value,kind:weatherEffect,intensity:weatherIntensity))))),
        Positioned(top:10,right:10,child:Column(children:[
"""
if body.count(map_end)!=1:
    raise SystemExit(f'v279 map overlay anchor {body.count(map_end)}')
body=body.replace(map_end,map_overlay,1)

control_anchor="""class _Community3DControlV255 extends StatelessWidget{
"""
painter=r'''class _CommunityWeatherPainterV279 extends CustomPainter{
  const _CommunityWeatherPainterV279({required this.t,required this.kind,required this.intensity});
  final double t;final String kind;final double intensity;
  @override void paint(Canvas canvas,Size size){
    if(kind=='CLEAR'||size.isEmpty)return;
    final count=kind=='SNOW'?52:70;
    for(var i=0;i<count;i++){
      final seed=i*91.731;
      final baseX=((seed*13.37)%997)/997;
      final speed=kind=='SNOW'?.30+(i%5)*.028:.72+(i%6)*.055;
      final y=((seed/997+t*speed)%1.12-.06)*size.height;
      final drift=kind=='SNOW'?sin((t*2*pi)+(i*.83))*12:-(size.height*.06);
      final x=(baseX*size.width+drift+(kind=='RAIN'?y*.07:0))%size.width;
      if(kind=='SNOW'){
        final r=1.2+(i%4)*.55;
        canvas.drawCircle(Offset(x,y),r,Paint()..color=Colors.white.withOpacity((.28+(i%5)*.07)*intensity.clamp(.35,1.0)));
      }else{
        final p=Paint()..color=const Color(0xFFB8E4FF).withOpacity((.18+(i%6)*.045)*intensity.clamp(.35,1.0))..strokeWidth=.7+(i%3)*.25..strokeCap=StrokeCap.round;
        canvas.drawLine(Offset(x,y),Offset(x-4,y+13+(i%4)*2),p);
      }
    }
    final haze=Paint()..shader=ui.Gradient.linear(Offset(0,0),Offset(0,size.height),[Colors.transparent,(kind=='SNOW'?const Color(0xFFDBEEFF):const Color(0xFF4D8FD8)).withOpacity(.05*intensity),Colors.transparent],[0,.55,1]);
    canvas.drawRect(Offset.zero&size,haze);
  }
  @override bool shouldRepaint(covariant _CommunityWeatherPainterV279 old)=>old.t!=t||old.kind!=kind||old.intensity!=intensity;
}

'''
if body.count(control_anchor)!=1:
    raise SystemExit(f'v279 painter anchor {body.count(control_anchor)}')
body=body.replace(control_anchor,painter+control_anchor,1)

body += "\nconst String _bridgePointCommunity3DLiveWeatherV279='bridgepoint-v279-community-3d-live-weather | NOAA/NWS weather aware | rain animation | snow animation | two-minute cache';\n"
path.write_text(body,encoding='utf-8')
print('Applied weather-aware Community 3D precipitation v279.')
runpy.run_path('tool/fix_v277_v279_compile_v280.py', run_name='__main__')
