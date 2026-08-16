from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""  final technology='${package['package_key']??''}'.startsWith('technology_');

  showDialog<void>(
""",
"""  final technology='${package['package_key']??''}'.startsWith('technology_');
  final configuration=package['configuration'] is Map?Map<String,dynamic>.from(package['configuration'] as Map):<String,dynamic>{};
  final bestFor='${configuration['best_for']??''}'.trim();
  final problemSolved='${configuration['problem_solved']??''}'.trim();
  final delivers='${configuration['delivers']??''}'.trim();
  final maturity='${configuration['maturity']??''}'.trim();
  final deliveryModes=(configuration['delivery_modes'] is List?(configuration['delivery_modes'] as List):const []).map((e)=>'$e'.replaceAll('_',' ')).toList();

  showDialog<void>(
""",
'technology-detail-config')

replace_once(
"""                const SizedBox(height: 12),
                if(technology)SizedBox(width:double.infinity,child:FilledButton.icon(
""",
"""                if(technology)...[
                  const SizedBox(height:12),
                  Container(
                    width:double.infinity,
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.amber.withOpacity(.16))),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      const Row(children:[Icon(Icons.apartment_rounded,color:AppTheme.amber,size:18),SizedBox(width:8),Text('Who this technology is for',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11))]),
                      const SizedBox(height:5),Text(bestFor.isEmpty?'Enterprise teams that need this BridgePoint capability inside their own workflow or product.':bestFor,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5)),
                      if(problemSolved.isNotEmpty)...[const SizedBox(height:11),const Text('PROBLEM IT SOLVES',style:TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:3),Text(problemSolved,style:const TextStyle(color:Colors.white,fontSize:10,height:1.45))],
                      if(delivers.isNotEmpty)...[const SizedBox(height:11),const Text('WHAT YOU GET',style:TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:3),Text(delivers,style:const TextStyle(color:Colors.white,fontSize:10,height:1.45))],
                      const SizedBox(height:11),Wrap(spacing:7,runSpacing:7,children:[
                        if(maturity.isNotEmpty)_OpportunityChip(label:maturity.replaceAll('_',' '),color:maturity=='ROADMAP'?AppTheme.amber:AppTheme.green),
                        ...deliveryModes.take(4).map((mode)=>_OpportunityChip(label:mode,color:AppTheme.cyan)),
                      ]),
                      const SizedBox(height:9),const Text('BridgePoint can provide managed service, API/OEM, white-label or private deployment where the package supports it. Protected scoring weights, proprietary learning logic and core implementation IP are not transferred by default.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.45)),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                if(technology)SizedBox(width:double.infinity,child:FilledButton.icon(
""",
'technology-explainer-panel')

if text==original:
    raise SystemExit('No technology clarity changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint technology clarity patch v100')
