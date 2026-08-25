from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text


def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)

# Never expose formula / SQL-like internals as a customer-facing property description.
_compact_marker = "Future<void> _saveOpportunity(BuildContext context,Map<String,dynamic> opportunity) async {"
_formatted_marker = "Future<void> _saveOpportunity(\n    BuildContext context, Map<String, dynamic> opportunity) async {"
if text.count(_compact_marker) == 1:
    marker = _compact_marker
elif text.count(_formatted_marker) == 1:
    marker = _formatted_marker
else:
    raise SystemExit('crm-helper-marker not found exactly once in compact or formatted source')

helpers = r'''
String _customerSafeScalar(Object? value,{String fallback='BridgePoint internal calculation hidden — use the reasoning and evidence sections for the customer-safe explanation.'}){
  final raw='${value??''}'.trim();
  if(raw.isEmpty)return '—';
  final lower=raw.toLowerCase();
  const codeTokens=<String>[
    'case when','coalesce(','select ',' from ',' where ','jsonb_','pg_catalog','regexp_','::json','::numeric','=>','score_components','component_weights','weighted_score','formula:',
  ];
  final looksLikeFormula=codeTokens.any(lower.contains)||
      (raw.contains('{')&&raw.contains('}')&&raw.contains(':'))||
      (raw.contains('[')&&raw.contains(']')&&lower.contains('weight'));
  return looksLikeFormula?fallback:raw;
}

String _crmHandoffText(Map<String,dynamic> payload){
  final lines=<String>[
    'BridgePoint CRM Handoff',
    'Property: ${payload['address']??'Address unavailable'}',
    if(payload['parcel_number']!=null)'Parcel: ${payload['parcel_number']}',
    if(payload['property_type']!=null)'Property type: ${payload['property_type']}',
    if(payload['year_built']!=null)'Year built: ${payload['year_built']}',
    if(payload['opportunity_score']!=null)'Opportunity score: ${payload['opportunity_score']}',
    if(payload['opportunity_tier']!=null)'Priority: ${payload['opportunity_tier']}',
    if(payload['confidence_percent']!=null)'Confidence: ${payload['confidence_percent']}%',
    if(payload['why_this_property']!=null)'Why this property: ${_customerSafeScalar(payload['why_this_property'])}',
    if(payload['why_now']!=null)'Why now: ${_customerSafeScalar(payload['why_now'])}',
    if(payload['recommended_action']!=null)'Recommended action: ${payload['recommended_action']}',
    'BridgePoint reference: property ${payload['property_id']??'—'}',
    '',
    'BridgePoint Intelligence • $_bridgePointLiveUrl',
  ];
  return lines.join('\n');
}

Future<void> _sendToCrm(BuildContext context,Map<String,dynamic> opportunity) async{
  final propertyId='${opportunity['property_id']??''}'.trim();
  if(propertyId.isEmpty){_showInfoDialog(context,'CRM handoff unavailable','This record does not include a property ID yet.');return;}
  var destination='GENERIC_CRM';
  final selected=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:const Row(children:[Icon(Icons.sync_alt_rounded,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Text('Send to CRM'))]),
    content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('BridgePoint will prepare a customer-safe handoff with the property, score, Why This Property, Why Now, named evidence, and recommended next action. Direct CRM connections can use this same handoff later.',style:TextStyle(color:AppTheme.textMuted,height:1.5)),
      const SizedBox(height:14),
      DropdownButtonFormField<String>(
        value:destination,dropdownColor:AppTheme.panelSoft,
        decoration:const InputDecoration(labelText:'CRM / destination',border:OutlineInputBorder()),
        items:const [
          DropdownMenuItem(value:'GENERIC_CRM',child:Text('Generic CRM / copy & share')),
          DropdownMenuItem(value:'ACCULYNX',child:Text('AccuLynx')),
          DropdownMenuItem(value:'ROOFR',child:Text('Roofr')),
          DropdownMenuItem(value:'JOBNIMBUS',child:Text('JobNimbus')),
          DropdownMenuItem(value:'HUBSPOT',child:Text('HubSpot')),
          DropdownMenuItem(value:'SALESFORCE',child:Text('Salesforce')),
          DropdownMenuItem(value:'OTHER',child:Text('Other CRM')),
        ],
        onChanged:(v)=>setLocal(()=>destination=v??destination),
      ),
      const SizedBox(height:10),
      const Text('Until a direct connector is enabled, BridgePoint prepares the record for copy/share instead of pretending it was pushed into that CRM.',style:TextStyle(color:AppTheme.amber,fontSize:9,height:1.45)),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(dialogContext,destination),icon:const Icon(Icons.arrow_forward_rounded),label:const Text('Prepare handoff'))],
  )));
  if(selected==null||!context.mounted)return;
  try{
    final result=await _callRpc('bridgepoint_prepare_crm_export_v87',{
      'p_property_id':propertyId,
      'p_opportunity_id':opportunity['opportunity_id'],
      'p_destination':selected,
    });
    final payload=result['payload'] is Map?Map<String,dynamic>.from(result['payload'] as Map):<String,dynamic>{};
    final text=_crmHandoffText(payload);
    if(!context.mounted)return;
    await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
      backgroundColor:AppTheme.panel,
      title:Row(children:[const Icon(Icons.check_circle_outline_rounded,color:AppTheme.green),const SizedBox(width:9),Expanded(child:Text('CRM handoff ready • ${result['destination']??selected}'))]),
      content:SizedBox(width:680,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Review the customer-safe record below. Copy it into your CRM or use the device share menu. BridgePoint keeps the export in your company history.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
        const SizedBox(height:12),Container(constraints:const BoxConstraints(maxHeight:330),width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(11)),child:SingleChildScrollView(child:SelectableText(text,style:const TextStyle(color:Colors.white,fontSize:10,height:1.5)))),
      ])),
      actions:[
        TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:text));if(dialogContext.mounted)ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content:Text('CRM handoff copied.')));},icon:const Icon(Icons.copy_rounded),label:const Text('Copy')),
        FilledButton.icon(onPressed:()async{try{await SharePlus.instance.share(ShareParams(title:'BridgePoint CRM Handoff',subject:'BridgePoint property opportunity',text:text));}catch(e){if(dialogContext.mounted)_showInfoDialog(dialogContext,'Share unavailable',e.toString());}},icon:const Icon(Icons.ios_share_rounded),label:const Text('Share')),
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Done')),
      ],
    ));
  }catch(e){if(context.mounted)_showInfoDialog(context,'CRM handoff unavailable',e.toString());}
}

'''
text = text.replace(marker, helpers + marker, 1)

# Customer-safe score explanation even if an older backend record contains a formula.
replace_once(
"""      subtitle: '${score['explanation'] ?? 'Current intelligence score'}',
""",
"""      subtitle: _customerSafeScalar(
        score['explanation'],
        fallback:'BridgePoint selected this property because its verified signals, evidence timing, confidence, and model fit produced a qualified score. Open the evidence and opportunity sections for the named reasons.',
      ),
""",
'safe-score-explanation')

# Block formula-looking scalar values anywhere in the generic property intelligence facts.
replace_once(
"""          Text(
            '${value ?? '—'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
""",
"""          Text(
            _customerSafeScalar(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
""",
'safe-detail-fact')

# Add Send to CRM beside Save and Add note in opportunity details.
replace_once(
"""                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity'))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note'))),
                  ]),
""",
"""                  Wrap(spacing:10,runSpacing:10,children:[
                    FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity')),
                    OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note')),
                    OutlinedButton.icon(onPressed:(){_sendToCrm(context,opportunity);},icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM')),
                  ]),
""",
'opportunity-crm-button')

# Add CRM handoff on map opportunity details too.
replace_once(
"""                const SizedBox(height: 18),
                Text(
                  'Model: ${point['model_name'] ?? point['model_key'] ?? '—'}\\n'
""",
"""                const SizedBox(height: 18),
                SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>_sendToCrm(context,point),icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM'))),
                const SizedBox(height: 18),
                Text(
                  'Model: ${point['model_name'] ?? point['model_key'] ?? '—'}\\n'
""",
'map-crm-button')

# Make active opportunities opened from Properties explicitly actionable with CRM handoff.
old = """    return _DetailRowShell(
      icon: Icons.bolt_rounded,
      title: '${opportunity['title'] ?? 'Opportunity'}',
      subtitle:_opportunityWhyThisProperty(opportunity),
      chips: [
        if (score != null)
          _OpportunityChip(
            label: 'SCORE ${score.toStringAsFixed(1)}',
            color: AppTheme.cyan,
          ),
        _OpportunityChip(
          label: priority.toUpperCase(),
          color: _opportunityPriorityColor(priority),
        ),
        if (opportunity['model_name'] != null)
          _OpportunityChip(
            label: '${opportunity['model_name']}',
            color: AppTheme.blue,
          ),
      ],
    );
"""
new = """    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _DetailRowShell(
        icon: Icons.bolt_rounded,
        title: '${opportunity['title'] ?? 'Opportunity'}',
        subtitle:_opportunityWhyThisProperty(opportunity),
        chips: [
          if (score != null)
            _OpportunityChip(
              label: 'SCORE ${score.toStringAsFixed(1)}',
              color: AppTheme.cyan,
            ),
          _OpportunityChip(
            label: priority.toUpperCase(),
            color: _opportunityPriorityColor(priority),
          ),
          if (opportunity['model_name'] != null)
            _OpportunityChip(
              label: '${opportunity['model_name']}',
              color: AppTheme.blue,
            ),
        ],
      ),
      Padding(padding:const EdgeInsets.only(bottom:8),child:TextButton.icon(onPressed:()=>_sendToCrm(context,opportunity),icon:const Icon(Icons.sync_alt_rounded,size:17),label:const Text('Send to CRM'))),
    ]);
"""
replace_once(old,new,'property-detail-crm-button')

if text == original:
    raise SystemExit('No changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint launch patch v95')
