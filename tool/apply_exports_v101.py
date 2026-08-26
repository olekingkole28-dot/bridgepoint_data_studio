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

# v797: newer BridgePoint builds add feature-module imports between package
# imports and constants. Add the download helper directly after url_launcher
# when it is not already present instead of depending on the old adjacency.
if "import 'bridgepoint_download.dart';" not in text:
    import_anchor="import 'package:url_launcher/url_launcher.dart';\n"
    if text.count(import_anchor)!=1:
        raise SystemExit(f'download-helper-import: expected exactly 1 url_launcher import, found {text.count(import_anchor)}')
    text=text.replace(import_anchor,import_anchor+"import 'bridgepoint_download.dart';\n",1)

# v798: accept the canonical formatted function and the historical compact
# generated function. Both represent the same stable insertion boundary.
_compact_marker="Future<void> _saveOpportunity(BuildContext context,Map<String,dynamic> opportunity) async {"
_formatted_marker="Future<void> _saveOpportunity(\n    BuildContext context, Map<String, dynamic> opportunity) async {"
if text.count(_compact_marker)==1:
    marker=_compact_marker
elif text.count(_formatted_marker)==1:
    marker=_formatted_marker
else:
    raise SystemExit('export-helper-marker not found exactly once in compact or formatted source')

helpers=r'''
String _csvCell(Object? value){
  final s='${value??''}'.replaceAll('"','""').replaceAll('\r',' ').replaceAll('\n',' ');
  return '"$s"';
}

String _safeFilename(String value){
  final cleaned=value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'),'_').replaceAll(RegExp(r'_+'),'_');
  return cleaned.isEmpty?'bridgepoint_export':cleaned.substring(0,cleaned.length.clamp(0,70));
}

String _opportunityCsv(Map<String,dynamic> o){
  final fields=<String,Object?>{
    'property_id':o['property_id'],
    'opportunity_id':o['opportunity_id'],
    'address':o['full_address']??o['address'],
    'municipality':o['municipality'],
    'county':o['county'],
    'state':o['state_code']??o['state'],
    'postal_code':o['postal_code'],
    'score':o['score']??o['opportunity_score']??o['quality_score'],
    'priority':o['priority']??o['quality_tier'],
    'confidence_percent':o['opportunity_confidence_percent']??o['confidence_score']??o['direct_confidence'],
    'urgency_score':o['urgency_score'],
    'why_this_property':_opportunityWhyThisProperty(o),
    'why_now':_opportunityWhyNow(o),
    'recommended_action':o['recommended_action'],
    'model':o['model_name']??o['model_key'],
    'direct_signals':o['direct_signal_count']??o['matched_signal_count']??o['distinct_signal_count'],
    'direct_sources':o['direct_source_count']??o['verified_event_count'],
    'latest_evidence_at':o['latest_direct_evidence_at']??o['latest_evidence_at'],
    'bridgepoint_url':_bridgePointLiveUrl,
  };
  return '${fields.keys.map(_csvCell).join(',')}\n${fields.values.map(_csvCell).join(',')}\n';
}

Future<void> _downloadOpportunityCsv(BuildContext context,Map<String,dynamic> opportunity)async{
  final address='${opportunity['full_address']??opportunity['address']??'property'}';
  final name='${_safeFilename(address)}_BridgePoint.csv';
  try{
    final ok=await bridgePointDownloadText(name,_opportunityCsv(opportunity),mimeType:'text/csv;charset=utf-8');
    if(!ok){
      final text=_opportunityCsv(opportunity);
      await Clipboard.setData(ClipboardData(text:text));
      if(context.mounted)_showInfoDialog(context,'CSV copied','This device does not support direct file download here, so BridgePoint copied the CSV content to your clipboard.');
    }else if(context.mounted){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Downloaded $name')));
    }
  }catch(e){if(context.mounted)_showInfoDialog(context,'CSV export unavailable',e.toString());}
}

Future<void> _printBridgePointPage(BuildContext context)async{
  try{
    final ok=await bridgePointPrintPage();
    if(!ok&&context.mounted)_showInfoDialog(context,'Print','Use your device or browser Share/Print command for this BridgePoint view.');
  }catch(e){if(context.mounted)_showInfoDialog(context,'Print unavailable',e.toString());}
}

'''
text=text.replace(marker,helpers+marker,1)

replace_once(
"""                  Wrap(spacing:10,runSpacing:10,children:[
                    FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity')),
                    OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note')),
                    OutlinedButton.icon(onPressed:(){_sendToCrm(context,opportunity);},icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM')),
                  ]),
""",
"""                  Wrap(spacing:10,runSpacing:10,children:[
                    FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity')),
                    OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note')),
                    OutlinedButton.icon(onPressed:(){_sendToCrm(context,opportunity);},icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM')),
                    OutlinedButton.icon(onPressed:(){_downloadOpportunityCsv(context,opportunity);},icon:const Icon(Icons.download_rounded),label:const Text('Download CSV')),
                    OutlinedButton.icon(onPressed:(){_printBridgePointPage(context);},icon:const Icon(Icons.print_rounded),label:const Text('Print / Save PDF')),
                  ]),
""",
'opportunity-export-buttons')

replace_once(
"""      Padding(padding:const EdgeInsets.only(bottom:8),child:TextButton.icon(onPressed:()=>_sendToCrm(context,opportunity),icon:const Icon(Icons.sync_alt_rounded,size:17),label:const Text('Send to CRM'))),
""",
"""      Padding(padding:const EdgeInsets.only(bottom:8),child:Wrap(spacing:5,children:[
        TextButton.icon(onPressed:()=>_sendToCrm(context,opportunity),icon:const Icon(Icons.sync_alt_rounded,size:17),label:const Text('Send to CRM')),
        TextButton.icon(onPressed:()=>_downloadOpportunityCsv(context,opportunity),icon:const Icon(Icons.download_rounded,size:17),label:const Text('CSV')),
        TextButton.icon(onPressed:()=>_printBridgePointPage(context),icon:const Icon(Icons.print_rounded,size:17),label:const Text('Print')),
      ])),
""",
'property-opportunity-export-buttons')

replace_once(
"""                SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>_sendToCrm(context,point),icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM'))),
""",
"""                Wrap(spacing:8,runSpacing:8,children:[
                  OutlinedButton.icon(onPressed:()=>_sendToCrm(context,point),icon:const Icon(Icons.sync_alt_rounded),label:const Text('Send to CRM')),
                  OutlinedButton.icon(onPressed:()=>_downloadOpportunityCsv(context,point),icon:const Icon(Icons.download_rounded),label:const Text('CSV')),
                  OutlinedButton.icon(onPressed:()=>_printBridgePointPage(context),icon:const Icon(Icons.print_rounded),label:const Text('Print')),
                ]),
""",
'map-opportunity-export-buttons')

# v799 release-chain compatibility: v105 predates dart format and keys off
# these two boundaries. Normalize only formatting, not behavior, so its real
# Growth Center implementation can still apply unchanged.
_growth_compact="        const SizedBox(height:18),const _EmergencyAdminPanel(),\n"
_growth_formatted="                const SizedBox(height: 18),\n                const _EmergencyAdminPanel(),\n"
if _growth_compact not in text:
    if text.count(_growth_formatted)!=1:
        raise SystemExit(f'growth-boundary-normalize: expected exactly 1 formatted emergency panel boundary, found {text.count(_growth_formatted)}')
    text=text.replace(_growth_formatted,_growth_compact,1)

_growth_class_compact="class _EmergencyAdminPanel extends StatefulWidget{"
_growth_class_formatted="class _EmergencyAdminPanel extends StatefulWidget {"
if _growth_class_compact not in text:
    if text.count(_growth_class_formatted)!=1:
        raise SystemExit(f'growth-class-normalize: expected exactly 1 formatted emergency panel class, found {text.count(_growth_class_formatted)}')
    text=text.replace(_growth_class_formatted,_growth_class_compact,1)

if text==original:
    raise SystemExit('No export changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint export/print patch v101/v799 with growth compatibility')
