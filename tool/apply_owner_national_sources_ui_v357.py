from __future__ import annotations

from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v357-owner-national-sources-ui'

if marker in text:
    print('Owner national Sources UI v357 already applied')
    raise SystemExit(0)

start = text.find('class _SourcesPage extends StatelessWidget {')
end = text.find('\nclass _LiveSourceCard extends StatelessWidget {', start)
if start < 0 or end < 0:
    raise SystemExit('v357 SourcesPage structural anchors missing')

replacement = r'''// bridgepoint-v357-owner-national-sources-ui
class _SourcesPage extends StatefulWidget {
  const _SourcesPage({required this.sourcesRequest,required this.onRefresh});
  final Future<Map<String,dynamic>> sourcesRequest;
  final VoidCallback onRefresh;
  @override State<_SourcesPage> createState()=>_SourcesPageState();
}

class _SourcesPageState extends State<_SourcesPage>{
  String selectedState='ALL';

  List<Map<String,dynamic>> _rows(dynamic raw)=>raw is List
      ? raw.whereType<Map>().map((item)=>Map<String,dynamic>.from(item)).toList()
      : <Map<String,dynamic>>[];

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:widget.sourcesRequest,
    builder:(context,snapshot){
      final data=snapshot.data;
      final owner=data?['owner_only']==true;
      final sources=_rows(data?['sources']);
      final national=_rows(data?['national_accepted_sources']);
      final states=national.map((row)=>'${row['state_code']??''}'.toUpperCase()).where((code)=>code.length==2).toSet().toList()..sort();
      if(selectedState!='ALL'&&!states.contains(selectedState))selectedState='ALL';
      final filtered=selectedState=='ALL'?national:national.where((row)=>'${row['state_code']??''}'.toUpperCase()==selectedState).toList();
      final loading=snapshot.connectionState==ConnectionState.waiting;
      final connected=data?['connected_source_count'];
      final registered=data?['registered_source_count'];
      final accepted=data?['accepted_national_source_count'];
      final stateCount=data?['states_with_accepted_sources'];
      final recordTotal=sources.fold<num>(0,(sum,row)=>sum+((row['total_records_ingested'] as num?)??0));

      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(
          title:'Intelligence Sources',
          subtitle:owner
            ?'Owner national source truth • registry health • classifications • coverage • provenance'
            :'BridgePoint source infrastructure is protected and entitlement-safe',
          onRefresh:widget.onRefresh,loading:loading,
        ),
        const SizedBox(height:18),
        if(snapshot.hasError)_DashboardError(message:snapshot.error.toString(),onRetry:widget.onRefresh)
        else if(!owner&&!loading)Card(child:Padding(
          padding:const EdgeInsets.all(22),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(width:44,height:44,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.verified_user_outlined,color:AppTheme.cyan)),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Source infrastructure is owner-protected',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
              const SizedBox(height:5),Text('${data?['message']??'Your workspace shows the evidence, signals and opportunities your package is entitled to without exposing BridgePoint internal source operations.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.5)),
            ])),
          ]),
        ))
        else ...[
          LayoutBuilder(builder:(context,constraints){
            final columns=constraints.maxWidth>=1050?4:constraints.maxWidth>=680?2:1;
            const gap=12.0;final width=(constraints.maxWidth-gap*(columns-1))/columns;
            return Wrap(spacing:gap,runSpacing:gap,children:[
              _MetricCard(width:width,label:'ENABLED REGISTRY',value:loading?'—':_formatInteger(connected),detail:'Operational registry sources',icon:Icons.hub_rounded,accent:AppTheme.green),
              _MetricCard(width:width,label:'REGISTERED',value:loading?'—':_formatInteger(registered),detail:'Tracked source definitions',icon:Icons.inventory_2_outlined,accent:AppTheme.cyan),
              _MetricCard(width:width,label:'NATIONAL ACCEPTED',value:loading?'—':_formatInteger(accepted),detail:'Accepted classified candidates',icon:Icons.public_rounded,accent:AppTheme.blue),
              _MetricCard(width:width,label:'STATES COVERED',value:loading?'—':_formatInteger(stateCount),detail:'States with accepted sources',icon:Icons.map_outlined,accent:AppTheme.amber),
            ]);
          }),
          const SizedBox(height:16),
          Container(
            width:double.infinity,padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.055),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Icon(Icons.admin_panel_settings_outlined,color:AppTheme.cyan,size:20),const SizedBox(width:10),
              Expanded(child:Text('OWNER VIEW • National accepted candidates are classified before they can influence intelligence. FOUNDATION_ONLY builds canonical property coverage; CONTEXT_ONLY adds supporting context; INTELLIGENCE_ELIGIBLE may feed direct intelligence only when matching and evidence rules also pass. Customer accounts never receive this infrastructure payload.',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))),
            ]),
          ),
          const SizedBox(height:18),
          Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _PanelHeader(title:'National Accepted Sources',subtitle:'State-aware owner review • source class • quality • coverage • health',action:selectedState=='ALL'?'${national.length} sources':'${filtered.length} in $selectedState'),
            const SizedBox(height:14),
            Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
              const Text('STATE',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),
              Container(
                constraints:const BoxConstraints(maxWidth:230),padding:const EdgeInsets.symmetric(horizontal:10),
                decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white.withOpacity(.08))),
                child:DropdownButtonHideUnderline(child:DropdownButton<String>(
                  value:selectedState,dropdownColor:AppTheme.panel,isDense:true,
                  items:<String>['ALL',...states].map((code)=>DropdownMenuItem(value:code,child:Text(code=='ALL'?'ALL STATES':'$code • ${_bridgePointUsStatesV352[code]??code}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)))).toList(),
                  onChanged:loading?null:(value){if(value!=null)setState(()=>selectedState=value);},
                )),
              ),
              if(selectedState!='ALL')TextButton.icon(onPressed:()=>setState(()=>selectedState='ALL'),icon:const Icon(Icons.clear_rounded,size:15),label:const Text('Clear')),
            ]),
            const SizedBox(height:16),
            if(loading)const SizedBox(height:180,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:2.5)))
            else if(filtered.isEmpty)const SizedBox(height:140,child:Center(child:Text('No accepted national sources match this state.',style:TextStyle(color:AppTheme.textMuted))))
            else LayoutBuilder(builder:(context,constraints){
              final columns=constraints.maxWidth>=1120?3:constraints.maxWidth>=720?2:1;
              const gap=12.0;final width=(constraints.maxWidth-gap*(columns-1))/columns;
              return Wrap(spacing:gap,runSpacing:gap,children:filtered.map((source)=>_NationalAcceptedSourceCardV357(width:width,source:source)).toList());
            }),
          ]))),
          const SizedBox(height:18),
          Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _PanelHeader(title:'Operational Source Registry',subtitle:'Enabled adapters • refresh state • ingestion volume • source health',action:'${_formatCompact(recordTotal)} records tracked'),
            const SizedBox(height:16),
            if(loading)const SizedBox(height:160,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:2.5)))
            else LayoutBuilder(builder:(context,constraints){
              final columns=constraints.maxWidth>=1050?2:1;const gap=14.0;final width=(constraints.maxWidth-gap*(columns-1))/columns;
              return Wrap(spacing:gap,runSpacing:gap,children:sources.map((source)=>_DetailedSourceCard(width:width,source:source)).toList());
            }),
          ]))),
        ],
      ]);
    },
  );
}

class _NationalAcceptedSourceCardV357 extends StatelessWidget{
  const _NationalAcceptedSourceCardV357({required this.width,required this.source});
  final double width;final Map<String,dynamic> source;
  Color _classColor(String value)=>switch(value){
    'INTELLIGENCE_ELIGIBLE'=>AppTheme.green,'FOUNDATION_ONLY'=>AppTheme.cyan,'CONTEXT_ONLY'=>AppTheme.blue,'QUARANTINED_REVIEW'=>AppTheme.amber,_=>AppTheme.textMuted};
  @override Widget build(BuildContext context){
    final sourceClass='${source['source_class']??'UNCLASSIFIED'}'.toUpperCase();
    final color=_classColor(sourceClass);
    final quality=(source['overall_quality_score'] as num?)?.toDouble();
    final authority=(source['authority_score'] as num?)?.toDouble();
    final coverage=(source['coverage_score'] as num?)?.toDouble();
    final freshness=(source['freshness_score'] as num?)?.toDouble();
    final state='${source['state_code']??'—'}';
    final title='${source['candidate_name']??source['source_name']??'Accepted source'}';
    final provider='${source['provider']??'Provider unavailable'}';
    final coverageStatus='${source['coverage_status']??'REVIEW COVERAGE'}';
    final operational='${source['operational_status']??source['health_check_status']??'BUILDING'}';
    return InkWell(
      onTap:()=>_showInfoDialog(context,title,
        'State: $state\nProvider: $provider\nCategory: ${source['source_category']??'—'}\nSource class: $sourceClass\nCoverage: $coverageStatus\nOperational status: $operational\nQuality: ${quality?.toStringAsFixed(1)??'—'}\nAuthority: ${authority?.toStringAsFixed(1)??'—'}\nCoverage score: ${coverage?.toStringAsFixed(1)??'—'}\nFreshness: ${freshness?.toStringAsFixed(1)??'—'}\nAccess: ${source['access_method']??'—'}\n\nBridgePoint keeps source class separate from endpoint health. Working endpoints are not automatically intelligence-eligible, and foundation/context sources do not create opportunities by themselves.'),
      borderRadius:BorderRadius.circular(14),
      child:Container(width:width,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.50),borderRadius:BorderRadius.circular(14),border:Border.all(color:color.withOpacity(.22))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(10)),child:Icon(Icons.dataset_linked_outlined,color:color,size:20)),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('$state • $title',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900,height:1.25)),
            const SizedBox(height:4),Text(provider,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
          ])),
        ]),
        const SizedBox(height:11),
        Wrap(spacing:6,runSpacing:6,children:[
          _OpportunityChip(label:sourceClass.replaceAll('_',' '),color:color),
          _OpportunityChip(label:coverageStatus.replaceAll('_',' '),color:AppTheme.blue),
          if(quality!=null)_OpportunityChip(label:'Q ${quality.toStringAsFixed(0)}',color:quality>=90?AppTheme.green:quality>=75?AppTheme.cyan:AppTheme.amber),
        ]),
        const SizedBox(height:10),Text('${source['source_category']??'SOURCE'} • $operational',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,fontWeight:FontWeight.w700)),
      ])),
    );
  }
}
'''

text = text[:start] + replacement + text[end:]

for needle in (
    'bridgepoint-v357-owner-national-sources-ui',
    'National Accepted Sources',
    "data?['national_accepted_sources']",
    'OWNER VIEW • National accepted candidates are classified before they can influence intelligence.',
    'Customer accounts never receive this infrastructure payload.',
):
    if needle not in text:
        raise SystemExit(f'v357 required marker missing: {needle}')

path.write_text(text,encoding='utf-8')
print('Owner national Sources UI v357 applied')
