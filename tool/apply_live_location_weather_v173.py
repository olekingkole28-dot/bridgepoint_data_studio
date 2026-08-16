from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

marker="Map<String, String> _apiHeaders() {"
if marker not in text:
    raise SystemExit('api header marker missing')
helper=r'''
class _BridgePointLiveLocation{
  static StreamSubscription<Position>? _subscription;
  static final ValueNotifier<Position?> position=ValueNotifier<Position?>(null);
  static final ValueNotifier<bool> active=ValueNotifier<bool>(false);

  static Future<Position> start()async{
    var permission=await Geolocator.checkPermission();
    if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
    if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever){
      throw Exception('Location permission is required for live local weather. You can still search a city, ZIP, or address.');
    }
    if(!await Geolocator.isLocationServiceEnabled())throw Exception('Turn on Location Services to use live local weather.');
    final first=await Geolocator.getCurrentPosition(desiredAccuracy:LocationAccuracy.high);
    position.value=first;active.value=true;
    await _subscription?.cancel();
    const settings=LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:200);
    _subscription=Geolocator.getPositionStream(locationSettings:settings).listen((next){
      position.value=next;active.value=true;
    },onError:(_){active.value=false;});
    return first;
  }

  static Future<void> stop()async{
    await _subscription?.cancel();_subscription=null;active.value=false;
  }
}

'''
text=text.replace(marker,helper+marker,1)

start=text.find('class _WeatherCenterPageState extends State<_WeatherCenterPage>{')
end=text.find('class _MyHomePage',start)
if start<0 or end<0:
    raise SystemExit('weather center block missing')
block=text[start:end]
block=block.replace(
    '  List<Map<String,dynamic>> saved=[];\n',
    "  List<Map<String,dynamic>> saved=[];\n  DateTime? _lastLiveWeatherRefresh;\n  bool _liveLocationOn=_BridgePointLiveLocation.active.value;\n",
    1,
)
old_init='  @override void initState(){super.initState();_loadSaved();}\n  @override void dispose(){search.dispose();super.dispose();}\n'
new_init=r'''  @override void initState(){
    super.initState();
    _BridgePointLiveLocation.position.addListener(_livePositionChanged);
    _BridgePointLiveLocation.active.addListener(_liveActiveChanged);
    _loadSaved();
    final current=_BridgePointLiveLocation.position.value;
    if(_BridgePointLiveLocation.active.value&&current!=null){
      WidgetsBinding.instance.addPostFrameCallback((_)=>_refreshFromLivePosition(current,force:true));
    }
  }
  @override void dispose(){
    _BridgePointLiveLocation.position.removeListener(_livePositionChanged);
    _BridgePointLiveLocation.active.removeListener(_liveActiveChanged);
    search.dispose();super.dispose();
  }
  void _liveActiveChanged(){if(mounted)setState(()=>_liveLocationOn=_BridgePointLiveLocation.active.value);}
  void _livePositionChanged(){
    final current=_BridgePointLiveLocation.position.value;
    if(current!=null)unawaited(_refreshFromLivePosition(current));
  }
  Future<void> _refreshFromLivePosition(Position pos,{bool force=false})async{
    final now=DateTime.now();
    if(!force&&_lastLiveWeatherRefresh!=null&&now.difference(_lastLiveWeatherRefresh!)<const Duration(minutes:2))return;
    _lastLiveWeatherRefresh=now;
    await _load(latitude:pos.latitude,longitude:pos.longitude);
  }
'''
if old_init not in block:
    raise SystemExit('weather init/dispose marker missing')
block=block.replace(old_init,new_init,1)

use_start=block.find('  Future<void> _useLocation()async{')
save_start=block.find('  Future<void> _saveCurrent()async{',use_start)
if use_start<0 or save_start<0:
    raise SystemExit('weather location method missing')
methods=r'''  Future<void> _useLocation()async{
    if(_BridgePointLiveLocation.active.value){
      await _BridgePointLiveLocation.stop();
      if(mounted)setState(()=>_liveLocationOn=false);
      return;
    }
    try{
      setState(()=>loading=true);
      final first=await _BridgePointLiveLocation.start();
      if(mounted)setState(()=>_liveLocationOn=true);
      await _refreshFromLivePosition(first,force:true);
    }catch(e){if(mounted)_showInfoDialog(context,'Live location unavailable','$e');}
    finally{if(mounted)setState(()=>loading=false);}
  }

'''
block=block[:use_start]+methods+block[save_start:]

button="OutlinedButton.icon(onPressed:loading?null:_useLocation,icon:const Icon(Icons.my_location_rounded),label:const Text('My location'))"
if button not in block:
    raise SystemExit('weather location button marker missing')
block=block.replace(button,"""OutlinedButton.icon(
        onPressed:loading?null:_useLocation,
        icon:Icon(_liveLocationOn?Icons.location_on_rounded:Icons.my_location_rounded),
        label:Text(_liveLocationOn?'Stop live location':'Start live location'),
      )""",1)

saved="      if(saved.isNotEmpty)...[const SizedBox(height:8),Wrap("
if saved not in block:
    raise SystemExit('weather saved locations marker missing')
status=r'''      const SizedBox(height:8),
      ValueListenableBuilder<bool>(
        valueListenable:_BridgePointLiveLocation.active,
        builder:(context,isLive,_)=>Container(
          width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
          decoration:BoxDecoration(
            color:(isLive?AppTheme.green:AppTheme.panelSoft).withOpacity(isLive?.08:.55),
            borderRadius:BorderRadius.circular(10),
            border:Border.all(color:(isLive?AppTheme.green:Colors.white).withOpacity(isLive?.22:.07)),
          ),
          child:Row(children:[
            Icon(isLive?Icons.location_searching_rounded:Icons.location_disabled_outlined,color:isLive?AppTheme.green:AppTheme.textMuted,size:17),
            const SizedBox(width:8),
            Expanded(child:Text(
              isLive
                ? 'LIVE LOCATION ON • BridgePoint follows this session and refreshes local weather when you move.'
                : 'Live location is off. Start it to keep weather and local context tied to where you actually are.',
              style:TextStyle(color:isLive?Colors.white:AppTheme.textMuted,fontSize:8.8,fontWeight:isLive?FontWeight.w800:FontWeight.w500),
            )),
          ]),
        ),
      ),
'''.replace('isLive?.08:.55','isLive ? .08 : .55').replace('isLive?.22:.07','isLive ? .22 : .07')
block=block.replace(saved,status+saved,1)
text=text[:start]+block+text[end:]

for needle in ['class _BridgePointLiveLocation','Start live location','LIVE LOCATION ON']:
    if needle not in text:raise SystemExit(f'missing live location marker: {needle}')
if text==original:raise SystemExit('no live location weather changes applied')
path.write_text(text,encoding='utf-8')
print('Applied live location weather repair v173')
