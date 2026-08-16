from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
old="""    try{await _callRpc('bridgepoint_accept_legal_v82',{'p_document_keys':['TERMS','PRIVACY','ACCEPTABLE_USE','DATA_DISCLAIMER'],'p_acceptance_source':'APP_REQUIRED_GATE'});widget.onComplete();}"""
new="""    try{
      final docs=widget.state['documents'];
      final requiredKeys=<String>[];
      if(docs is List){
        for(final item in docs){
          if(item is Map&&item['required']==true&&item['accepted']!=true&&item['document_key']!=null){
            requiredKeys.add('${item['document_key']}');
          }
        }
      }
      if(requiredKeys.isEmpty){
        widget.onComplete();
        return;
      }
      final result=await _callRpc('bridgepoint_accept_legal_v82',{
        'p_document_keys':requiredKeys,
        'p_acceptance_source':'APP_REQUIRED_GATE',
      });
      if(result['required_acceptance_missing']==true){
        throw Exception('BridgePoint still shows ${result['missing_count']??1} required legal document(s) as unaccepted. Please retry.');
      }
      widget.onComplete();
    }"""
count=text.count(old)
if count!=1:
    raise SystemExit(f'Expected one legal gate submit block, found {count}')
text=text.replace(old,new,1)
path.write_text(text,encoding='utf-8')
print('Legal acceptance gate now submits every currently required unaccepted document.')
