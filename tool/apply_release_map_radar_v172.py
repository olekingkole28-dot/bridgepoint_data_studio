from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

text=text.replace(
    "const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';",
    "const _bridgePointLiveUrl = 'https://olekingkole28-dot.github.io/bridgepoint-live/';",
)

start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
end=text.find('class _MapLegendDot extends StatelessWidget',start)
if start<0 or end<0:
    raise SystemExit('intelligence map block missing')
block=text[start:end]
block=block.replace(
    'if (loading)\n                        Positioned.fill(',
    'if (loading && data == null)\n                        Positioned.fill(',
    1,
)
marker='                      if (loading && data == null)\n'
if marker not in block:
    raise SystemExit('map initial-loading marker missing')
inset=r'''                      if (_showRadar)
                        Positioned(
                          left:14,bottom:14,
                          child:GestureDetector(
                            onTap:()=>_showAnimatedRadarLoop(context,_radarRevision),
                            child:Container(
                              width:214,height:142,clipBehavior:Clip.antiAlias,
                              decoration:BoxDecoration(
                                color:AppTheme.panel.withOpacity(.94),
                                borderRadius:BorderRadius.circular(12),
                                border:Border.all(color:AppTheme.cyan.withOpacity(.32)),
                                boxShadow:[BoxShadow(color:Colors.black.withOpacity(.32),blurRadius:14)],
                              ),
                              child:Stack(fit:StackFit.expand,children:[
                                Image.network(
                                  'https://radar.weather.gov/ridge/standard/NORTHEAST_loop.gif?bp=$_radarRevision',
                                  fit:BoxFit.cover,gaplessPlayback:true,
                                  errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.radar_rounded,color:AppTheme.cyan)),
                                ),
                                Positioned(left:7,top:7,child:Container(
                                  padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
                                  decoration:BoxDecoration(color:Colors.black.withOpacity(.72),borderRadius:BorderRadius.circular(7)),
                                  child:const Row(mainAxisSize:MainAxisSize.min,children:[
                                    _PulseDot(color:AppTheme.green),SizedBox(width:5),
                                    Text('LIVE NOAA LOOP • TAP TO ZOOM',style:TextStyle(color:Colors.white,fontSize:7.5,fontWeight:FontWeight.w900)),
                                  ]),
                                )),
                              ]),
                            ),
                          ),
                        ),
'''
block=block.replace(marker,inset+marker,1)
text=text[:start]+block+text[end:]

helper=r'''
Future<void> _showAnimatedRadarLoop(BuildContext context,int revision)async{
  await showDialog<void>(context:context,builder:(d)=>Dialog(
    backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(18),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:980,maxHeight:820),child:Padding(
      padding:const EdgeInsets.all(16),child:Column(children:[
        Row(children:[
          const Icon(Icons.radar_rounded,color:AppTheme.cyan),const SizedBox(width:8),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Animated NOAA Radar Loop',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
            SizedBox(height:3),Text('Official Northeast radar loop. The main map keeps the georeferenced MRMS current layer underneath.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)),
          ])),
          IconButton(onPressed:()=>Navigator.pop(d),icon:const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height:10),
        Expanded(child:InteractiveViewer(
          minScale:.8,maxScale:7,boundaryMargin:const EdgeInsets.all(120),
          child:Center(child:Image.network(
            'https://radar.weather.gov/ridge/standard/NORTHEAST_loop.gif?bp=$revision',
            fit:BoxFit.contain,gaplessPlayback:true,
            errorBuilder:(_,__,___)=>const _InlineError(message:'The animated NOAA radar loop is temporarily unavailable.'),
          )),
        )),
        const SizedBox(height:8),
        const Text('Radar is weather context, not proof of damage at a specific property.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
      ]),
    )),
  ));
}

'''
legend='class _MapLegendDot extends StatelessWidget {'
if legend not in text:
    raise SystemExit('map legend marker missing')
text=text.replace(legend,helper+legend,1)

for needle in [
    'https://olekingkole28-dot.github.io/bridgepoint-live/',
    'LIVE NOAA LOOP • TAP TO ZOOM',
    'loading && data == null',
]:
    if needle not in text:
        raise SystemExit(f'missing map repair marker: {needle}')
if text==original:
    raise SystemExit('no map/radar repairs applied')
path.write_text(text,encoding='utf-8')
print('Applied map/radar/public release repair v172')
