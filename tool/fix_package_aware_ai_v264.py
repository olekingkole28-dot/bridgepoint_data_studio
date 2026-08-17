from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v264-package-aware-ai-compile'
if marker in body:
    print('Package-aware AI compile repair v264 already applied.')
    raise SystemExit(0)

metric_anchor="""  Widget _metric(String label,String value,IconData icon,Color color)=>Container(
    constraints:const BoxConstraints(minWidth:122),padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(color:color.withOpacity(.075),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.18))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:16),const SizedBox(height:6),Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w700))]));

"""
if body.count(metric_anchor)!=1:
    raise SystemExit(f'v264 metric anchor count {body.count(metric_anchor)}')
helpers=metric_anchor+r'''  Widget _opportunityCardV264(Map<String,dynamic> o)=>Container(
    margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(11),
    decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.green.withOpacity(.08),AppTheme.panelSoft.withOpacity(.8)]),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.15))),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${o['title']??o['model_name']??'Opportunity'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),
        const SizedBox(height:3),
        Text('${o['explanation']??o['description']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60,fontSize:8,height:1.35)),
      ])),
      const SizedBox(width:8),
      _OpportunityChip(label:'${o['score']??'—'}',color:AppTheme.green),
    ]),
  );

  Widget _patternCardV264(Map<String,dynamic> p)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
    decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.07),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.blue.withOpacity(.13))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${p['pattern_name']??'Pattern'}',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w900)),
      const SizedBox(height:2),
      Text('${p['intelligence_stage']??''}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.2)),
    ]),
  );

  Widget _upgradeCardV264(Map<String,dynamic> u,Map<String,dynamic> data)=>Container(
    margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(color:AppTheme.navy.withOpacity(.45),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withOpacity(.06))),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${u['package_name']??'BridgePoint package'}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text('${u['description']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,height:1.3)),
      ])),
      const SizedBox(width:8),
      Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text('${_bridgePointAiMoneyV263(u['monthly_price'])}/mo',style:const TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        TextButton(onPressed:()=>_action('PACKAGES',data),child:const Text('View plan',style:TextStyle(fontSize:8))),
      ]),
    ]),
  );

'''
body=body.replace(metric_anchor,helpers,1)

start=body.find("          if(opportunities.isNotEmpty)...[")
end=body.find("          if(patterns.isNotEmpty)...[",start)
if start<0 or end<0:
    raise SystemExit('v264 opportunity block anchors missing')
body=body[:start]+"""          if(opportunities.isNotEmpty)...[
            const SizedBox(height:15),
            const Row(children:[Icon(Icons.bolt_rounded,color:AppTheme.green,size:18),SizedBox(width:7),Text('Opportunities your package unlocks',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))]),
            const SizedBox(height:8),
            ...opportunities.take(5).map((o)=>_opportunityCardV264(o)),
          ],

"""+body[end:]

start=body.find("          if(patterns.isNotEmpty)...[")
end=body.find("          if(buildings.isNotEmpty)...[",start)
if start<0 or end<0:
    raise SystemExit('v264 pattern block anchors missing')
body=body[:start]+"""          if(patterns.isNotEmpty)...[
            const SizedBox(height:15),
            const Row(children:[Icon(Icons.hub_rounded,color:AppTheme.blue,size:18),SizedBox(width:7),Text('Patterns',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))]),
            const SizedBox(height:8),
            Wrap(spacing:7,runSpacing:7,children:patterns.take(6).map((p)=>_patternCardV264(p)).toList()),
          ],

"""+body[end:]

start=body.find("          if(!topicAccess || upgrades.isNotEmpty)...[")
end=body.find("          if(actions.isNotEmpty)...[",start)
if start<0 or end<0:
    raise SystemExit('v264 upgrade block anchors missing')
body=body[:start]+"""          if(!topicAccess || upgrades.isNotEmpty)...[
            const SizedBox(height:16),
            Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.amber.withOpacity(.11),AppTheme.blue.withOpacity(.05)]),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.amber.withOpacity(.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Row(children:[Icon(Icons.lock_open_rounded,color:AppTheme.amber,size:18),SizedBox(width:7),Text('Unlock more intelligence',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))]),
              const SizedBox(height:5),
              Text(topicAccess?'BridgePoint found intelligence beyond the current package. Nothing locked is exposed until the matching package is active.':'That topic is outside the current package. BridgePoint kept the locked intelligence private and matched the closest packages below.',style:const TextStyle(color:Colors.white60,fontSize:8.5,height:1.4)),
              if(upgrades.isNotEmpty)...[
                const SizedBox(height:10),
                ...upgrades.map((u)=>_upgradeCardV264(u,data)),
              ],
            ])),
          ],

"""+body[end:]

body += "\nconst String _bridgePointPackageAwareAiCompileV264='bridgepoint-v264-package-aware-ai-compile';\n"
path.write_text(body,encoding='utf-8')
print('Repaired package-aware BridgePoint AI card builder syntax v264.')
