from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v284-founder-reviews-customer-preview'
if marker in body:
    print('Founder/reviews/customer preview v284 already applied.')
    raise SystemExit(0)

old_stars="stars(((summary['average_rating'] as num?)?.round()??0),size:22)"
new_stars="stars((summary['average_rating'] as num?)?.round()??0,size:22)"
if body.count(old_stars)!=1:
    raise SystemExit(f'v284 review stars anchor {body.count(old_stars)}')
body=body.replace(old_stars,new_stars,1)

model_anchor="""  static const packageModelKeys = <String, String>{
    'All Intelligence': 'all',
    'BridgePoint Homeowner': 'bridgepoint_home',
    'BridgePoint Home': 'bridgepoint_home',
    'BridgePoint Commercial': 'bridgepoint_commercial',
    'Roofing Opportunity': 'roofing_opportunity',
    'BridgePoint General': 'bridgepoint_general_v1',
    'Property Investor': 'property_investor',
    'Development Opportunity': 'development_opportunity',
    'Solar Opportunity': 'solar_opportunity',
  };
"""
model_replace=model_anchor+"""
  static const packageProductKeysV284 = <String,String>{
    'All Intelligence':'all_intelligence',
    'BridgePoint Homeowner':'homeowner',
    'BridgePoint Home':'home',
    'BridgePoint Commercial':'commercial',
    'Roofing Opportunity':'home',
    'BridgePoint General':'all_intelligence',
    'Property Investor':'investor',
    'Development Opportunity':'commercial',
    'Solar Opportunity':'solar',
  };
"""
if body.count(model_anchor)!=1:
    raise SystemExit(f'v284 package mapping anchor {body.count(model_anchor)}')
body=body.replace(model_anchor,model_replace,1)

open_old="""    showDialog<void>(context:context,builder:(dialogContext)=>_BridgePointAiSearchDialogV248(
      initialQuery:q,onNavigateLabel:_navigateTrainingLabel,
      onPropertySelected:(property){Navigator.of(dialogContext).pop();_showPropertyInventoryDetail(context,property);},
    ));
"""
open_new="""    showDialog<void>(context:context,builder:(dialogContext)=>_BridgePointAiSearchDialogV248(
      initialQuery:q,onNavigateLabel:_navigateTrainingLabel,
      previewPackageKey:_ownerCustomerPreview?packageProductKeysV284[selectedPackage]:null,
      previewPackageName:_ownerCustomerPreview?selectedPackage:null,
      onPropertySelected:(property){Navigator.of(dialogContext).pop();_showPropertyInventoryDetail(context,property);},
    ));
"""
if body.count(open_old)!=1:
    raise SystemExit(f'v284 AI open anchor {body.count(open_old)}')
body=body.replace(open_old,open_new,1)

ctor_old="""class _BridgePointAiSearchDialogV248 extends StatefulWidget{
  const _BridgePointAiSearchDialogV248({required this.initialQuery,required this.onNavigateLabel,required this.onPropertySelected});
  final String initialQuery;final ValueChanged<String> onNavigateLabel;final ValueChanged<Map<String,dynamic>> onPropertySelected;
"""
ctor_new="""class _BridgePointAiSearchDialogV248 extends StatefulWidget{
  const _BridgePointAiSearchDialogV248({required this.initialQuery,required this.onNavigateLabel,required this.onPropertySelected,this.previewPackageKey,this.previewPackageName});
  final String initialQuery;final ValueChanged<String> onNavigateLabel;final ValueChanged<Map<String,dynamic>> onPropertySelected;final String? previewPackageKey;final String? previewPackageName;
"""
if body.count(ctor_old)!=1:
    raise SystemExit(f'v284 AI constructor anchor {body.count(ctor_old)}')
body=body.replace(ctor_old,ctor_new,1)

state_old="""class _BridgePointAiSearchDialogV248State extends State<_BridgePointAiSearchDialogV248>{
  late final TextEditingController controller;late Future<Map<String,dynamic>> request;String query='';
  @override void initState(){super.initState();controller=TextEditingController(text:widget.initialQuery);query=widget.initialQuery;request=_callRpc('bridgepoint_ai_answer_v262',{'p_query':query});}
  @override void dispose(){controller.dispose();super.dispose();}
  void _search(String value){final q=value.trim();if(q.length<2)return;setState((){query=q;request=_callRpc('bridgepoint_ai_answer_v262',{'p_query':q});});}
"""
state_new="""class _BridgePointAiSearchDialogV248State extends State<_BridgePointAiSearchDialogV248>{
  late final TextEditingController controller;late Future<Map<String,dynamic>> request;String query='';
  bool get previewing=>widget.previewPackageKey!=null&&widget.previewPackageKey!.isNotEmpty;
  Future<Map<String,dynamic>> _loadAi(String q)=>previewing
    ?_callRpc('bridgepoint_ai_answer_preview_v283',{'p_query':q,'p_package_key':widget.previewPackageKey})
    :_callRpc('bridgepoint_ai_answer_v262',{'p_query':q});
  @override void initState(){super.initState();controller=TextEditingController(text:widget.initialQuery);query=widget.initialQuery;request=_loadAi(query);}
  @override void dispose(){controller.dispose();super.dispose();}
  void _search(String value){final q=value.trim();if(q.length<2)return;setState((){query=q;request=_loadAi(q);});}
"""
if body.count(state_old)!=1:
    raise SystemExit(f'v284 AI state anchor {body.count(state_old)}')
body=body.replace(state_old,state_new,1)

title_old="""      const SizedBox(width:11),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('BridgePoint AI',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Ask naturally • package-aware • grounded in BridgePoint evidence',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w600))])),
      IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
"""
title_new="""      const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('BridgePoint AI',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(previewing?'Customer preview • ${widget.previewPackageName??widget.previewPackageKey}':'Ask naturally • package-aware • grounded in BridgePoint evidence',style:TextStyle(color:previewing?AppTheme.amber:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700))])),
      if(previewing)const Padding(padding:EdgeInsets.only(right:6),child:_OpportunityChip(label:'SERVER-FILTERED PREVIEW',color:AppTheme.amber)),
      IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
"""
if body.count(title_old)!=1:
    raise SystemExit(f'v284 AI title anchor {body.count(title_old)}')
body=body.replace(title_old,title_new,1)

banner_old="""class _CustomerPreviewBanner extends StatelessWidget{
"""
if body.count(banner_old)!=1:
    raise SystemExit(f'v284 customer preview banner class anchor {body.count(banner_old)}')

body += "\nconst String _bridgePointFounderReviewsCustomerPreviewV284='bridgepoint-v284-founder-reviews-customer-preview | review syntax repaired | server-filtered owner customer preview | preview package passed to AI';\n"
path.write_text(body,encoding='utf-8')
print('Repaired founder reviews and wired server-filtered customer preview v284.')
runpy.run_path('tool/apply_owner_system_explorer_v286.py', run_name='__main__')
