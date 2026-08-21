from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v420-owner-cross-filters'
if marker in text:
    print('Owner Cross Filters V420 already applied')
    raise SystemExit(0)
if 'bridgepoint-v419-owner-human-details' not in text:
    raise SystemExit('V420 requires V419 owner human details')

fields_old="""  String range='24H';
  String status='ALL';
  String search='';
"""
fields_new="""  String range='24H';
  String status='ALL';
  String search='';
  String stateFilter='ALL';
  String verticalFilter='ALL';
  String packageFilter='ALL';
  String channelFilter='ALL';
  String workerFilter='ALL';
"""
if text.count(fields_old)!=1:
    raise SystemExit(f'V420 fields anchor count {text.count(fields_old)}')
text=text.replace(fields_old,fields_new,1)

helper_old="""  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v415',{'p_since':_since().toUtc().toIso8601String()});
  void refresh()=>setState(()=>request=_load());
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
"""
helper_new=r'''  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v415',{'p_since':_since().toUtc().toIso8601String()});
  void refresh()=>setState(()=>request=_load());
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  String _normKey(String value)=>value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');
  Set<String> _collectDimensionValues(dynamic node,Set<String> keys,[int depth=0]){
    final found=<String>{};
    if(depth>8||node==null)return found;
    if(node is Map){
      for(final entry in node.entries){
        final key=_normKey('${entry.key}');
        final value=entry.value;
        if(keys.contains(key)){
          if(value is String&&value.trim().isNotEmpty&&value.trim().length<=90)found.add(value.trim());
          if(value is num)found.add('$value');
        }
        found.addAll(_collectDimensionValues(value,keys,depth+1));
      }
    }else if(node is List){
      for(final value in node.take(2000))found.addAll(_collectDimensionValues(value,keys,depth+1));
    }
    return found;
  }
  bool _hasDimension(dynamic node,Set<String> keys,[int depth=0]){
    if(depth>8||node==null)return false;
    if(node is Map){
      for(final entry in node.entries){
        if(keys.contains(_normKey('${entry.key}')))return true;
        if(_hasDimension(entry.value,keys,depth+1))return true;
      }
    }else if(node is List){
      for(final value in node.take(2000)){if(_hasDimension(value,keys,depth+1))return true;}
    }
    return false;
  }
  bool _containsDimensionValue(dynamic node,Set<String> keys,String wanted,[int depth=0]){
    if(wanted=='ALL')return true;
    if(depth>8||node==null)return false;
    final target=wanted.toLowerCase();
    if(node is Map){
      for(final entry in node.entries){
        final key=_normKey('${entry.key}'),value=entry.value;
        if(keys.contains(key)&&'${value??''}'.toLowerCase()==target)return true;
        if(_containsDimensionValue(value,keys,wanted,depth+1))return true;
      }
    }else if(node is List){
      for(final value in node.take(2000)){if(_containsDimensionValue(value,keys,wanted,depth+1))return true;}
    }
    return false;
  }
  bool _dimensionAllows(Map<String,dynamic> section,Map<String,dynamic> live,Set<String> keys,String wanted){
    if(wanted=='ALL')return true;
    final payloadKey=section['payload_key']?.toString();
    final payload=payloadKey==null?null:live[payloadKey];
    if(!_hasDimension(payload,keys))return true;
    return _containsDimensionValue(payload,keys,wanted);
  }
  List<String> _dimensionOptions(Map<String,dynamic> live,Set<String> keys,{int limit=60}){
    final values=_collectDimensionValues(live,keys).where((v)=>v.trim().isNotEmpty).toList()..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>['ALL',...values.take(limit)];
  }
'''
if text.count(helper_old)!=1:
    raise SystemExit(f'V420 helper anchor count {text.count(helper_old)}')
text=text.replace(helper_old,helper_new,1)

visible_old="""    final visible=all.where((section){final state='${section['status']??''}';if(status!='ALL'&&state!=status)return false;if(needle.isEmpty)return true;final hay='${section['title']} ${section['what_is']} ${section['why_matters']} ${section['auto_next']}'.toLowerCase();return hay.contains(needle);}).toList();
"""
visible_new="""    const stateKeys={'state','statecode','statename','geography','geographycode'};
    const verticalKeys={'vertical','verticalkey','verticalcode','buyertype','buyervertical'};
    const packageKeys={'package','packagekey','packagecode','packagename','plan','plancode'};
    const channelKeys={'channel','channelkey','sourcechannel','acquisitionchannel','provider','platform'};
    const workerKeys={'worker','workername','workerkey','assignment','workerassignment'};
    final stateOptions=_dimensionOptions(live,stateKeys),verticalOptions=_dimensionOptions(live,verticalKeys,limit:30),packageOptions=_dimensionOptions(live,packageKeys,limit:30),channelOptions=_dimensionOptions(live,channelKeys,limit:30),workerOptions=_dimensionOptions(live,workerKeys,limit:30);
    if(!stateOptions.contains(stateFilter))stateFilter='ALL';
    if(!verticalOptions.contains(verticalFilter))verticalFilter='ALL';
    if(!packageOptions.contains(packageFilter))packageFilter='ALL';
    if(!channelOptions.contains(channelFilter))channelFilter='ALL';
    if(!workerOptions.contains(workerFilter))workerFilter='ALL';
    final visible=all.where((section){
      final state='${section['status']??''}';
      if(status!='ALL'&&state!=status)return false;
      if(!_dimensionAllows(section,live,stateKeys,stateFilter))return false;
      if(!_dimensionAllows(section,live,verticalKeys,verticalFilter))return false;
      if(!_dimensionAllows(section,live,packageKeys,packageFilter))return false;
      if(!_dimensionAllows(section,live,channelKeys,channelFilter))return false;
      if(!_dimensionAllows(section,live,workerKeys,workerFilter))return false;
      if(needle.isEmpty)return true;
      final hay='${section['title']} ${section['what_is']} ${section['why_matters']} ${section['auto_next']}'.toLowerCase();
      final payloadKey=section['payload_key']?.toString();
      final payload=payloadKey==null?null:live[payloadKey];
      return hay.contains(needle)||(payload!=null&&'$payload'.toLowerCase().contains(needle));
    }).toList();
"""
if text.count(visible_old)!=1:
    raise SystemExit(f'V420 visible anchor count {text.count(visible_old)}')
text=text.replace(visible_old,visible_new,1)

controls_old="""        DropdownButton<String>(value:range,items:const ['TODAY','24H','7D','30D','ALL'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v==null)return;setState((){range=v;request=_load();});}),
        DropdownButton<String>(value:status,items:const ['ALL','LIVE','BUILDING','BLOCKED'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>status=v??'ALL')),
      ]);}),
      const SizedBox(height:7),const Text('Global owner view • State, vertical, package, channel and worker drill-downs live inside the relevant Details payloads. Additional cross-section filters will only become active when their underlying metric supports them.',style:TextStyle(color:Colors.white38,fontSize:7.6,height:1.35)),
"""
controls_new="""        DropdownButton<String>(value:range,items:const ['TODAY','24H','7D','30D','ALL'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v==null)return;setState((){range=v;request=_load();});}),
        DropdownButton<String>(value:status,items:const ['ALL','LIVE','BUILDING','BLOCKED'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>status=v??'ALL')),
        _OwnerEverythingFilterV420(label:'State',value:stateFilter,options:stateOptions,onChanged:(v)=>setState(()=>stateFilter=v)),
        _OwnerEverythingFilterV420(label:'Vertical',value:verticalFilter,options:verticalOptions,onChanged:(v)=>setState(()=>verticalFilter=v)),
        _OwnerEverythingFilterV420(label:'Package',value:packageFilter,options:packageOptions,onChanged:(v)=>setState(()=>packageFilter=v)),
        _OwnerEverythingFilterV420(label:'Channel',value:channelFilter,options:channelOptions,onChanged:(v)=>setState(()=>channelFilter=v)),
        _OwnerEverythingFilterV420(label:'Worker',value:workerFilter,options:workerOptions,onChanged:(v)=>setState(()=>workerFilter=v)),
        if(stateFilter!='ALL'||verticalFilter!='ALL'||packageFilter!='ALL'||channelFilter!='ALL'||workerFilter!='ALL')TextButton.icon(onPressed:()=>setState((){stateFilter='ALL';verticalFilter='ALL';packageFilter='ALL';channelFilter='ALL';workerFilter='ALL';}),icon:const Icon(Icons.filter_alt_off_rounded,size:15),label:const Text('Clear scope filters')),
      ]);}),
      const SizedBox(height:7),const Text('Owner filters use the already-loaded reconciled payload. A section is filtered only when its source-of-truth payload actually supports that dimension; unavailable instrumentation stays visible instead of disappearing like a fake zero.',style:TextStyle(color:Colors.white38,fontSize:7.6,height:1.35)),
"""
if text.count(controls_old)!=1:
    raise SystemExit(f'V420 controls anchor count {text.count(controls_old)}')
text=text.replace(controls_old,controls_new,1)

class_anchor="""class _OwnerEverythingExplainV410 extends StatelessWidget{
"""
filter_class=r'''// bridgepoint-v420-owner-cross-filters
class _OwnerEverythingFilterV420 extends StatelessWidget{
  const _OwnerEverythingFilterV420({required this.label,required this.value,required this.options,required this.onChanged});
  final String label,value;final List<String> options;final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context){
    final safe=options.contains(value)?value:'ALL';
    return Tooltip(message:'Filter only sections whose live payload supports $label. Sections without that instrumentation remain visible.',child:Container(
      constraints:const BoxConstraints(maxWidth:190),padding:const EdgeInsets.symmetric(horizontal:9),
      decoration:BoxDecoration(color:Colors.white.withOpacity(.025),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.white10)),
      child:DropdownButtonHideUnderline(child:DropdownButton<String>(isDense:true,value:safe,items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v=='ALL'?'All $label':v,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8.5)))).toList(),onChanged:(v){if(v!=null)onChanged(v);})),
    ));
  }
}

'''
if text.count(class_anchor)!=1:
    raise SystemExit(f'V420 class anchor count {text.count(class_anchor)}')
text=text.replace(class_anchor,filter_class+class_anchor,1)

path.write_text(text,encoding='utf-8')
print('Applied Owner Cross Filters V420')
