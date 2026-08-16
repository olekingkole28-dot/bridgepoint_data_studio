from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')

def class_range(name):
    a=s.find('class '+name)
    if a<0:
        raise SystemExit('Missing class '+name)
    j=s.find('{',a)
    depth=0
    for k in range(j,len(s)):
        if s[k]=='{': depth+=1
        elif s[k]=='}':
            depth-=1
            if depth==0:
                return a,k+1
    raise SystemExit('Unclosed class '+name)

def replace_class(name,body):
    global s
    a,b=class_range(name)
    s=s[:a]+body+s[b:]

def remove_class(name):
    global s
    a,b=class_range(name)
    s=s[:a]+s[b:]

s=s.replace('withOpacity(active?.18:.07)','withOpacity(active ? .18 : .07)',1)
if 'class _BrandContactProfileV212State' in s:
    remove_class('_BrandContactProfileV212State')

noaa=r'''class _NoaaSatelliteLoopV215State extends State<_NoaaSatelliteLoopV215>{
  final List<DateTime> frames=<DateTime>[];
  int index=0;
  bool playing=true;
  bool loading=true;
  bool checking=false;
  Timer? timer;
  Map<String,dynamic>? health;
  String? error;

  @override
  void initState(){
    super.initState();
    _load();
    timer=Timer.periodic(const Duration(milliseconds:900),(_){
      if(!mounted||!playing||frames.isEmpty)return;
      setState(()=>index=index>=frames.length-1?0:index+1);
    });
  }

  @override
  void dispose(){timer?.cancel();super.dispose();}

  String _clock(DateTime value){
    final l=value.toLocal();
    final hour=l.hour%12==0?12:l.hour%12;
    return '$hour:${l.minute.toString().padLeft(2,'0')} ${l.hour>=12?'PM':'AM'}';
  }

  Future<void> _load()async{
    try{
      final response=await Supabase.instance.client.functions.invoke(
        'bridgepoint-noaa-cloud-frames-v215',body:const {},
      );
      final payload=_edgeFunctionPayload(response.data);
      if(response.status<200||response.status>=300||payload['complete']!=true){
        throw Exception('${payload['error']??'NOAA cloud frames unavailable'}');
      }
      final raw=payload['frames'];
      final next=raw is List
          ? raw.map((x)=>DateTime.tryParse('$x')).whereType<DateTime>().toList()
          : <DateTime>[];
      if(next.isEmpty)throw Exception('NOAA returned no satellite frame times.');
      if(!mounted)return;
      setState((){
        frames..clear()..addAll(next);
        index=frames.length-1;
        loading=false;
        error=null;
      });
    }catch(e){
      if(mounted)setState((){loading=false;error='$e';});
    }
  }

  Future<void> _test()async{
    if(checking)return;
    setState(()=>checking=true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(duration:Duration(seconds:1),content:Text('NOAA button pressed • testing live services…')),
    );
    try{
      final response=await Supabase.instance.client.functions.invoke(
        'bridgepoint-noaa-live-health-v212',body:const {},
      );
      final payload=_edgeFunctionPayload(response.data);
      if(response.status<200||response.status>=300||payload['complete']!=true){
        throw Exception('${payload['error']??'NOAA test failed'}');
      }
      if(!mounted)return;
      setState(()=>health=payload);
      final alerts=_bpMap(payload['alerts']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('NOAA CONNECTED ✓ • ${alerts['active_count']??'—'} active U.S. alerts')),
      );
    }catch(e){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('NOAA check failed: $e')));
      }
    }finally{
      if(mounted)setState(()=>checking=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final frame=frames.isEmpty?null:frames[index.clamp(0,frames.length-1)];
    final radarOk=_bpMap(health?['radar'])['ok']==true;
    final buttonColor=checking?AppTheme.amber:(radarOk?AppTheme.green:AppTheme.cyan);

    Widget mapBody;
    if(loading){
      mapBody=const Center(child:CircularProgressIndicator(color:AppTheme.cyan));
    }else if(error!=null){
      mapBody=Center(
        child:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            const Icon(Icons.cloud_off_rounded,color:AppTheme.amber,size:30),
            const SizedBox(height:8),
            Padding(
              padding:const EdgeInsets.symmetric(horizontal:16),
              child:Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.amber,fontSize:9)),
            ),
            const SizedBox(height:8),
            OutlinedButton.icon(
              onPressed:(){setState(()=>loading=true);_load();},
              icon:const Icon(Icons.refresh_rounded),
              label:const Text('Retry NOAA clouds'),
            ),
          ],
        ),
      );
    }else{
      mapBody=FlutterMap(
        options:const MapOptions(
          initialCenter:LatLng(39.5,-98.35),
          initialZoom:3.35,
          minZoom:2.5,
          maxZoom:8,
          interactionOptions:InteractionOptions(flags:InteractiveFlag.all),
        ),
        children:[
          TileLayer(
            urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:'com.bridgepoint.data_studio',
          ),
          if(frame!=null)
            TileLayer(
              key:ValueKey('bp-cloud-${frame.toIso8601String()}'),
              wmsOptions:WMSTileLayerOptions(
                baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',
                layers:const ['global_visible_imagery_mosaic'],
                format:'image/png',
                transparent:true,
                version:'1.3.0',
                otherParameters:{'TIME':frame.toUtc().toIso8601String()},
              ),
              maxNativeZoom:8,
              userAgentPackageName:'com.bridgepoint.data_studio',
            ),
        ],
      );
    }

    return Container(
      width:double.infinity,
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[const Color(0xFF071321),AppTheme.blue.withOpacity(.09),AppTheme.panel]),
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:AppTheme.cyan.withOpacity(.22)),
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Row(
            children:[
              const _PulseDot(color:AppTheme.green),
              const SizedBox(width:7),
              const Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('NOAA SATELLITE CLOUD MOTION',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.5)),
                    SizedBox(height:2),
                    Text('Actual NOAA nowCOAST satellite imagery • play, pause and scrub',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
                  ],
                ),
              ),
              FilledButton.icon(
                style:FilledButton.styleFrom(backgroundColor:buttonColor.withOpacity(.18),foregroundColor:buttonColor),
                onPressed:checking?null:_test,
                icon:Icon(checking?Icons.sync_rounded:(radarOk?Icons.check_circle_rounded:Icons.touch_app_rounded),size:16),
                label:Text(checking?'Pressed • testing…':(radarOk?'NOAA CONNECTED ✓':'Test NOAA live')),
              ),
            ],
          ),
          const SizedBox(height:8),
          SizedBox(
            height:widget.height,
            child:ClipRRect(borderRadius:BorderRadius.circular(12),child:mapBody),
          ),
          const SizedBox(height:8),
          Row(
            children:[
              IconButton.filledTonal(
                tooltip:playing?'Pause cloud motion':'Play cloud motion',
                onPressed:frames.isEmpty?null:()=>setState(()=>playing=!playing),
                icon:Icon(playing?Icons.pause_rounded:Icons.play_arrow_rounded),
              ),
              const SizedBox(width:7),
              Expanded(
                child:Slider(
                  value:frames.isEmpty?0:index.toDouble(),
                  min:0,
                  max:frames.isEmpty?1:(frames.length-1).toDouble(),
                  divisions:frames.length>1?frames.length-1:null,
                  onChanged:frames.isEmpty?null:(v)=>setState((){playing=false;index=v.round();}),
                ),
              ),
              const SizedBox(width:8),
              Text(frame==null?'No frame':_clock(frame),style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),
            ],
          ),
          const Text(
            'Cloud imagery is a visual satellite product. Radar shows precipitation. Follow official warnings for safety decisions.',
            style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4),
          ),
        ],
      ),
    );
  }
}'''
replace_class('_NoaaSatelliteLoopV215State',noaa)

about=r'''class _AboutBridgePointPage extends StatelessWidget{
  const _AboutBridgePointPage({required this.ownerMode});
  final bool ownerMode;

  Widget _card(IconData icon,String title,String body,Color color){
    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:AppTheme.panelSoft,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:color.withOpacity(.20)),
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Icon(icon,color:color,size:22),
          const SizedBox(height:7),
          Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context){
    return Padding(
      padding:const EdgeInsets.all(18),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Container(
            height:330,
            width:double.infinity,
            clipBehavior:Clip.antiAlias,
            decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(20),
              border:Border.all(color:AppTheme.cyan.withOpacity(.22)),
            ),
            child:Stack(
              fit:StackFit.expand,
              children:[
                Image.asset('assets/images/bridgepoint-intelligence-background-v1.webp',fit:BoxFit.cover),
                Container(
                  decoration:BoxDecoration(
                    gradient:LinearGradient(
                      begin:Alignment.centerLeft,
                      end:Alignment.centerRight,
                      colors:[const Color(0xF5071321),const Color(0xD8071321),AppTheme.cyan.withOpacity(.10)],
                    ),
                  ),
                ),
                Padding(
                  padding:const EdgeInsets.all(26),
                  child:Align(
                    alignment:Alignment.centerLeft,
                    child:ConstrainedBox(
                      constraints:const BoxConstraints(maxWidth:760),
                      child:Column(
                        mainAxisSize:MainAxisSize.min,
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          const Text('ABOUT BRIDGEPOINT INTELLIGENCE',style:TextStyle(color:AppTheme.cyan,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2)),
                          const SizedBox(height:9),
                          const Text('A simpler way to understand what is happening to a property—and what may deserve attention next.',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,height:1.08)),
                          const SizedBox(height:10),
                          const Text('BridgePoint connects property, public-record, weather, map, field and workflow information to the correct place, then turns those disconnected facts into one understandable property story.',style:TextStyle(color:Color(0xFFD8E4F0),fontSize:12,height:1.6)),
                          const SizedBox(height:12),
                          Wrap(spacing:7,runSpacing:7,children:const [
                            _OpportunityChip(label:'PROPERTY',color:AppTheme.cyan),
                            _OpportunityChip(label:'EVIDENCE',color:AppTheme.blue),
                            _OpportunityChip(label:'PATTERNS',color:AppTheme.green),
                            _OpportunityChip(label:'OPPORTUNITIES',color:AppTheme.amber),
                            _OpportunityChip(label:'ACTION',color:AppTheme.cyan),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height:9),
          const Center(child:Text('SCROLL TO EXPLORE ↓',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1))),
          const SizedBox(height:18),
          const _PanelHeader(title:'BridgePoint in plain English',subtitle:'You should not need to be a data scientist to understand it',action:'Start here'),
          const SizedBox(height:9),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:const [
                  Text('Imagine having to check ten different places before deciding whether one property matters.',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
                  SizedBox(height:8),
                  Text('One place has the parcel. Another has the owner. Another has a permit. Another has storm information. Another has a fire record. Another has a public complaint. Another has environmental information. Your team has notes. None of those systems were built to tell the whole property story together.',style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65)),
                  SizedBox(height:9),
                  Text('BridgePoint connects those pieces without pretending they prove more than they do. It asks what property a record belongs to, what happened, when it happened, how reliable the match is, what supports or contradicts it, whether a pattern exists, and whether the result deserves human review.',style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65)),
                  SizedBox(height:9),
                  Text('The result is not “trust our secret score.” The result is a property story you can inspect.',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:AppTheme.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height:16),
          LayoutBuilder(builder:(context,c){
            final width=c.maxWidth>=780?(c.maxWidth-10)/2:c.maxWidth;
            return Wrap(
              spacing:10,runSpacing:10,
              children:[
                SizedBox(width:width,child:_card(Icons.home_work_outlined,'Property','The canonical home, building, parcel or place that all other observations connect back to.',AppTheme.cyan)),
                SizedBox(width:width,child:_card(Icons.fact_check_outlined,'Evidence','A dated source record or observation with a named source and a known matching method.',AppTheme.blue)),
                SizedBox(width:width,child:_card(Icons.bolt_outlined,'Signal','A useful observation extracted from evidence—such as weather exposure, a transfer, permit, fire, change or other condition.',AppTheme.amber)),
                SizedBox(width:width,child:_card(Icons.hub_outlined,'Pattern','Several signals that become more meaningful when they occur together, repeat or accelerate over time.',AppTheme.green)),
                SizedBox(width:width,child:_card(Icons.auto_graph_rounded,'Opportunity','A property that cleared the required evidence rules for a specific use case and deserves human review.',AppTheme.cyan)),
                SizedBox(width:width,child:_card(Icons.verified_outlined,'Confidence','How reliable and consistent the supporting evidence appears—not a guarantee that an outcome will happen.',AppTheme.green)),
              ],
            );
          }),
          const SizedBox(height:18),
          const _PanelHeader(title:'How BridgePoint turns data into action',subtitle:'Collect → match → connect → recognize → prioritize → learn',action:'The intelligence loop'),
          const SizedBox(height:9),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:const [
                  Text('1. Collect lawful public, licensed, customer and field sources.',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:7),
                  Text('2. Match each record to the right property, place or entity.',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:7),
                  Text('3. Connect evidence, dates, confidence and counter-signals.',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:7),
                  Text('4. Recognize patterns and relationships across time.',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:7),
                  Text('5. Prioritize opportunities for the selected package or use case.',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:7),
                  Text('6. Save, route, inspect, follow up, record the outcome and improve.',style:TextStyle(fontWeight:FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height:18),
          Container(
            width:double.infinity,
            padding:const EdgeInsets.all(19),
            decoration:BoxDecoration(
              gradient:LinearGradient(colors:[AppTheme.green.withOpacity(.09),AppTheme.panel,AppTheme.blue.withOpacity(.05)]),
              borderRadius:BorderRadius.circular(16),
              border:Border.all(color:AppTheme.green.withOpacity(.20)),
            ),
            child:const Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('WHY BRIDGEPOINT WAS BUILT',style:TextStyle(color:AppTheme.green,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)),
                SizedBox(height:7),
                Text('Because the property world is connected in real life, but the information usually is not.',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
                SizedBox(height:8),
                Text('A storm can change a roof. A permit can explain a change. A transfer can change the decision-maker. A fire can create restoration work. A complaint can reveal maintenance issues. Environmental records can change development options. Field observations add evidence. Customer outcomes teach the system which combinations were actually useful.',style:TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65)),
                SizedBox(height:8),
                Text('BridgePoint is building a living intelligence layer for properties: what the property is, what changed, what evidence exists, what is unknown, what deserves attention, and what happened next.',style:TextStyle(color:Color(0xFFD9E7F4),fontSize:11,height:1.65)),
              ],
            ),
          ),
          const SizedBox(height:18),
          _BrandContactProfileV215(ownerMode:ownerMode),
          const SizedBox(height:18),
        ],
      ),
    );
  }
}'''
replace_class('_AboutBridgePointPage',about)

p.write_text(s,encoding='utf-8')
print('Repaired v215 generated Flutter compile points: contact, NOAA loop, About page, legacy contact state.')
