from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

state='  bool _ownerCustomerPreview=false;\n'
if state not in text:raise SystemExit('owner preview state marker missing')
text=text.replace(state,'''  bool _ownerCustomerPreview=false;
  bool _walkthroughActive=false;
  bool _walkthroughBusy=false;
  List<Map<String,dynamic>> _walkthroughSteps=<Map<String,dynamic>>[];
  int _walkthroughIndex=0;
''',1)

start=text.find('  Future<void> _openWalkthrough({bool replay=false,bool automatic=false})async{')
end=text.find('  Future<void> _maybeOfferWalkthrough()async{',start)
if start<0 or end<0:raise SystemExit('walkthrough method block missing')
methods=r'''  String _coachLabel(Map<String,dynamic> step){
    final raw='${step['nav_label']??''}';
    return switch(raw){
      'Dashboard'=>'Daily Brief','Map'=>'Intelligence Map','Plans'=>'Packages',
      'Analytics'=>'Models','Calendar'=>'My Work',_=>raw,
    };
  }

  List<Map<String,dynamic>> _condenseWalkthrough(List<Map<String,dynamic>> steps){
    final core=<String>[
      'Daily Brief','Opportunities','Intelligence Map','Properties','Weather Center',
      'Field Mode','My Work','Community','My Home','Packages','Settings',
      if(widget.ownerMode)'Owner Center',
    ];
    final out=<Map<String,dynamic>>[];
    for(final label in core){
      final match=steps.where((s)=>_coachLabel(s)==label);
      if(match.isNotEmpty)out.add(match.first);
    }
    if(out.length>=6)return out;
    final seen=<String>{};
    for(final step in steps){
      final label=_coachLabel(step);
      final key=label.isEmpty?'${step['step_number']}':label;
      if(seen.add(key))out.add(step);
      if(out.length>=12)break;
    }
    return out;
  }

  Future<void> _openWalkthrough({bool replay=false,bool automatic=false})async{
    try{
      var data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':replay});
      final initialState=_bpMap(data['state']);
      final status='${initialState['status']??'NOT_STARTED'}';
      if(automatic&&!['NOT_STARTED','IN_PROGRESS'].contains(status))return;
      if(!automatic&&!replay&&status=='COMPLETED'){
        data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':true});
      }else if(!automatic&&!replay&&status=='SKIPPED'){
        await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'RESUME','p_step':initialState['current_step']});
        data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':false});
      }
      final steps=_condenseWalkthrough(_bpRows(data['steps']));
      if(steps.isEmpty)throw Exception('Training steps are not available yet.');
      var index=0;
      final current=(initialState['current_step'] as num?)?.toInt();
      if(current!=null){
        final found=steps.indexWhere((s)=>(s['step_number'] as num?)?.toInt()==current);
        if(found>=0)index=found;
      }
      if(!mounted)return;
      setState((){
        _walkthroughSteps=steps;_walkthroughIndex=index.clamp(0,steps.length-1);_walkthroughActive=true;
      });
      final step=steps[_walkthroughIndex];
      final label=_coachLabel(step);
      if(label.isNotEmpty)_navigateTrainingLabel(label);
      await _callRpc('bridgepoint_walkthrough_progress_v155',{
        'p_action':status=='IN_PROGRESS'?'STEP':'START','p_step':step['step_number'],
      });
    }catch(e){if(mounted&&!automatic)_showInfoDialog(context,'Walkthrough unavailable','$e');}
  }

  Future<void> _walkthroughMove(int next)async{
    if(_walkthroughSteps.isEmpty||_walkthroughBusy)return;
    final index=next.clamp(0,_walkthroughSteps.length-1);
    setState(()=>_walkthroughBusy=true);
    try{
      final step=_walkthroughSteps[index];
      await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'STEP','p_step':step['step_number']});
      if(!mounted)return;
      setState(()=>_walkthroughIndex=index);
      final label=_coachLabel(step);if(label.isNotEmpty)_navigateTrainingLabel(label);
    }finally{if(mounted)setState(()=>_walkthroughBusy=false);}
  }

  Future<void> _walkthroughNext()async{
    if(_walkthroughSteps.isEmpty||_walkthroughBusy)return;
    if(_walkthroughIndex>=_walkthroughSteps.length-1){
      setState(()=>_walkthroughBusy=true);
      try{
        final step=_walkthroughSteps[_walkthroughIndex];
        await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'COMPLETE','p_step':step['step_number']});
        if(mounted){
          setState(()=>_walkthroughActive=false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Molly walkthrough complete. Replay it anytime with the training button.')));
        }
      }finally{if(mounted)setState(()=>_walkthroughBusy=false);}
      return;
    }
    await _walkthroughMove(_walkthroughIndex+1);
  }

  Future<void> _walkthroughSkip()async{
    if(_walkthroughSteps.isEmpty)return;
    final step=_walkthroughSteps[_walkthroughIndex];
    try{await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'SKIP','p_step':step['step_number']});}
    finally{if(mounted)setState(()=>_walkthroughActive=false);}
  }

'''
text=text[:start]+methods+text[end:]

sync='''                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
'''
if sync not in text:raise SystemExit('live sync marker missing')
coach=r'''                      if(_walkthroughActive&&_walkthroughSteps.isNotEmpty)
                        _WalkthroughCoachBanner(
                          step:_walkthroughSteps[_walkthroughIndex],index:_walkthroughIndex,total:_walkthroughSteps.length,busy:_walkthroughBusy,
                          onBack:_walkthroughIndex==0?null:()=>_walkthroughMove(_walkthroughIndex-1),
                          onNext:_walkthroughNext,onSkip:_walkthroughSkip,
                        ),
'''
text=text.replace(sync,sync+coach,1)

class_marker='class _CustomerPreviewBanner extends StatelessWidget{'
if class_marker not in text:raise SystemExit('customer preview class marker missing')
widget=r'''
class _WalkthroughCoachBanner extends StatelessWidget{
  const _WalkthroughCoachBanner({required this.step,required this.index,required this.total,required this.busy,required this.onBack,required this.onNext,required this.onSkip});
  final Map<String,dynamic> step;final int index,total;final bool busy;
  final VoidCallback? onBack;final VoidCallback onNext,onSkip;
  @override Widget build(BuildContext context){
    final tip='${step['tip']??''}'.trim();
    final tryThis='${step['try_this']??''}'.trim();
    final why='${step['why_it_matters']??''}'.trim();
    final target='${step['nav_label']??step['title']??'this page'}';
    return Container(
      margin:const EdgeInsets.fromLTRB(16,6,16,8),padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[const Color(0xFFD6A06A).withOpacity(.12),AppTheme.cyan.withOpacity(.055)]),
        borderRadius:BorderRadius.circular(13),border:Border.all(color:const Color(0xFFE8B77F).withOpacity(.34),width:1.2),
        boxShadow:[BoxShadow(color:const Color(0xFFE8B77F).withOpacity(.08),blurRadius:16)],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFFD6A06A).withOpacity(.18),shape:BoxShape.circle),child:const Icon(Icons.pets_rounded,color:Color(0xFFE8B77F),size:21)),
          const SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('MOLLY LIVE WALKTHROUGH • ${index+1}/$total',style:const TextStyle(color:Color(0xFFE8B77F),fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6)),
            const SizedBox(height:2),Text('${step['headline']??step['title']??'Learn BridgePoint on the real screen'}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),
          ])),
          TextButton(onPressed:busy?null:onSkip,child:const Text('Skip for now')),
        ]),
        const SizedBox(height:7),
        Text('${step['body']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
        if(tryThis.isNotEmpty)...[
          const SizedBox(height:8),
          Container(width:double.infinity,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.green.withOpacity(.16))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Icon(Icons.touch_app_rounded,color:AppTheme.green,size:17),const SizedBox(width:7),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('ON THE LIVE $target SCREEN, LOOK FOR / TAP:',style:const TextStyle(color:AppTheme.green,fontSize:7.5,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),Text(tryThis,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800,height:1.4)),
            ])),
          ])),
        ],
        if(tip.isNotEmpty||why.isNotEmpty)...[
          const SizedBox(height:7),Text(tip.isNotEmpty?'Molly: $tip':why,style:const TextStyle(color:Color(0xFFE8B77F),fontSize:8.5,fontStyle:FontStyle.italic,height:1.4)),
        ],
        const SizedBox(height:8),
        Row(children:[
          TextButton.icon(onPressed:busy?null:onBack,icon:const Icon(Icons.arrow_back_rounded,size:16),label:const Text('Back')),
          const Spacer(),
          const Text('Use the real page underneath — this is not a slide deck.',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5)),
          const SizedBox(width:8),
          FilledButton.icon(onPressed:busy?null:onNext,icon:Icon(index==total-1?Icons.check_rounded:Icons.arrow_forward_rounded,size:16),label:Text(index==total-1?'Finish':'Next live step')),
        ]),
      ]),
    );
  }
}

'''
text=text.replace(class_marker,widget+class_marker,1)

for needle in ['MOLLY LIVE WALKTHROUGH','Use the real page underneath — this is not a slide deck.','_condenseWalkthrough']:
    if needle not in text:raise SystemExit(f'missing live walkthrough marker: {needle}')
if text==original:raise SystemExit('no Molly live walkthrough changes applied')
path.write_text(text,encoding='utf-8')
print('Applied Molly live walkthrough v176')
