from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v322-whole-system-ai-ui'
if marker in body:
    print('BridgePoint whole-system AI v322 already applied.')
    runpy.run_path('tool/apply_bridgepoint_network_v323.py',run_name='__main__')
    runpy.run_path('tool/fix_bridgepoint_network_v323.py',run_name='__main__')
    raise SystemExit(0)

if 'bridgepoint-v321-expansion-eta-radar-resilience' not in body:
    raise SystemExit('v322 requires the verified v321 generated source')

# Route the existing mature BridgePoint AI dialog through the governed v322 system-wide
# answer contract. Property questions remain compatible because v322 delegates them to the
# proven property engine and adds system-wide answers for expansion, packages, billing,
# founder/Molly, permits, automation, customers and investor truth based on caller scope.
count=body.count("'bridgepoint_ai_answer_v262'")
if count<1:
    if "'bridgepoint_ai_answer_v322'" not in body:
        raise SystemExit('v322 AI RPC anchor missing')
else:
    body=body.replace("'bridgepoint_ai_answer_v262'","'bridgepoint_ai_answer_v322'")

replacements={
"Ask naturally • package-aware • grounded in BridgePoint evidence":"Ask naturally • system-aware • grounded in live BridgePoint truth",
"Ask anything — “What is happening at 394 High St Middletown, CT?”":"Ask anything — property, expansion, permits, packages, Molly, billing, system health…",
"BridgePoint AI is resolving the property and checking the intelligence your package can see…":"BridgePoint AI is checking the live BridgePoint information your account is allowed to see…",
"Search BridgePoint intelligence across properties, places, events, opportunities, maps and the information your account can access.":"Ask BridgePoint about properties, expansion, packages, your access, founder/Molly, system status and any operating truth your account is allowed to see.",
"Try “best roofing opportunities near Hartford”":"Try “How is New York expansion going?” or ask about a property",
}
for old,new in replacements.items():
    if old in body:
        body=body.replace(old,new)

# Use the v322 topic for system-wide answers while preserving the older property topic label.
old="final topicAccess=packageContext['topic_access']!=false;final address='${property['full_address']??''}';final headline='${data['headline']??'BridgePoint AI answer'}';final summary='${data['summary']??''}';"
new="final topicAccess=packageContext['topic_access']!=false;final address='${property['full_address']??''}';final headline='${data['headline']??'BridgePoint AI answer'}';final summary='${data['summary']??''}';final topicLabel='${data['topic']??data['topic_label']??'BridgePoint intelligence'}'.replaceAll('_',' ');final aiScope='${data['scope']??''}';final answerStatus='${data['answer_status']??''}';"
if old in body:
    body=body.replace(old,new,1)
elif "final topicLabel='${data['topic']??data['topic_label']??'BridgePoint intelligence'}'" not in body:
    raise SystemExit('v322 topic label anchor missing')

old="'${data['topic_label']??'Property intelligence'}'.toUpperCase()"
if old in body:
    body=body.replace(old,"topicLabel.toUpperCase()",1)

# Expand quick-action routing so whole-system answers open the correct BridgePoint surface
# instead of falling back to Daily Brief.
old="""      'PROPERTIES'=>'Properties','OPPORTUNITIES'=>'Opportunities','INTELLIGENCE_MAP'=>'Intelligence Map','COMMUNITY'=>'Community',
      'PROPERTY_MEMORY'=>'My Home','ADVANCED_EVIDENCE'=>'Properties','PACKAGES'=>'Packages',_=>'Daily Brief'};"""
new="""      'PROPERTIES'=>'Properties','OPPORTUNITIES'=>'Opportunities','INTELLIGENCE_MAP'=>'Intelligence Map','COMMUNITY'=>'Community',
      'PROPERTY_MEMORY'=>'My Home','ADVANCED_EVIDENCE'=>'Properties','PACKAGES'=>'Packages','BILLING'=>'Packages','COVERAGE'=>'Coverage',
      'SOURCES'=>'Sources','PERMIT_CONTEXT'=>'Permit Context','ABOUT'=>'About BridgePoint','SETTINGS'=>'Settings',
      'OWNER_CENTER'=>'Owner Center','FOUNDER_COMMAND'=>'Founder Command','INVESTOR_ROOM'=>'Founder Command',_=>'Daily Brief'};"""
if old in body:
    body=body.replace(old,new,1)
elif "'COVERAGE'=>'Coverage'" not in body:
    raise SystemExit('v322 quick-action route anchor missing')

# Give system-wide answers a clear governed-scope badge without exposing private data.
needle="""              const SizedBox(height:9),Text(headline,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,height:1.18)),
              if(summary.isNotEmpty)...[const SizedBox(height:8),Text(summary,style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.55))],"""
insert="""              const SizedBox(height:9),Text(headline,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,height:1.18)),
              if(aiScope.isNotEmpty||answerStatus.isNotEmpty)...[const SizedBox(height:7),Wrap(spacing:6,runSpacing:6,children:[
                if(aiScope.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:(aiScope=='OWNER_GOVERNED'?AppTheme.amber:AppTheme.cyan).withOpacity(.09),borderRadius:BorderRadius.circular(99),border:Border.all(color:(aiScope=='OWNER_GOVERNED'?AppTheme.amber:AppTheme.cyan).withOpacity(.20))),child:Text(aiScope=='OWNER_GOVERNED'?'OWNER TRUTH':'CUSTOMER SAFE',style:TextStyle(color:aiScope=='OWNER_GOVERNED'?AppTheme.amber:AppTheme.cyan,fontSize:7,fontWeight:FontWeight.w900))),
                if(answerStatus.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:(answerStatus=='FOUND'?AppTheme.green:AppTheme.textMuted).withOpacity(.08),borderRadius:BorderRadius.circular(99),border:Border.all(color:(answerStatus=='FOUND'?AppTheme.green:AppTheme.textMuted).withOpacity(.16))),child:Text(answerStatus.replaceAll('_',' '),style:TextStyle(color:answerStatus=='FOUND'?AppTheme.green:AppTheme.textMuted,fontSize:7,fontWeight:FontWeight.w900))),
              ])],
              if(summary.isNotEmpty)...[const SizedBox(height:8),Text(summary,style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.55))],"""
if needle in body:
    body=body.replace(needle,insert,1)
elif 'OWNER TRUTH' not in body:
    raise SystemExit('v322 governed-scope badge anchor missing')

# Add an explicit grounding note near the answer content. This makes a missing answer useful
# and tells customers why BridgePoint will not invent unsupported backend facts.
quick_anchor="""          if(actions.isNotEmpty)...["""
if quick_anchor in body:
    grounding="""          if('${data['grounding_notice']??''}'.isNotEmpty)...[
            const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.66),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.verified_user_outlined,color:AppTheme.cyan,size:16),const SizedBox(width:8),Expanded(child:Text('${data['grounding_notice']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.45)))])),
          ],
"""
    body=body.replace(quick_anchor,grounding+quick_anchor,1)
elif "data['grounding_notice']" not in body:
    raise SystemExit('v322 grounding anchor missing')

body += "\n// bridgepoint-v322-whole-system-ai-ui\n"
path.write_text(body,encoding='utf-8')
print(f'BridgePoint whole-system AI v322 UI applied; upgraded {count} legacy AI RPC call(s).')
runpy.run_path('tool/apply_bridgepoint_network_v323.py',run_name='__main__')
runpy.run_path('tool/fix_bridgepoint_network_v323.py',run_name='__main__')
