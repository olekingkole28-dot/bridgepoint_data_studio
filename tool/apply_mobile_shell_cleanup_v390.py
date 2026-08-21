from pathlib import Path
main=Path('lib/main.dart'); web=Path('web/index.html')
text=main.read_text(encoding='utf-8')
marker='bridgepoint-v390-mobile-shell-cleanup'
if marker in text: print('v390 shell already applied'); raise SystemExit(0)
if 'bridgepoint-v380-owner-national-cockpit' not in text: raise SystemExit('v390 requires v380')
ai="""                    Positioned(\n                      right:desktop?22:14,bottom:desktop?22:14,\n                      child:SafeArea(child:Material(color:Colors.transparent,child:InkWell(\n                        borderRadius:BorderRadius.circular(99),onTap:()=>_showBridgePointAiPromptV248(context,_openBridgePointAiV248),\n"""
if text.count(ai)!=1: raise SystemExit(f'AI float anchor {text.count(ai)}')
text=text.replace(ai,ai.replace('                    Positioned(','                    if(desktop)Positioned('),1)
raw="""      const SizedBox(height:10),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Raw live backend details',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),subtitle:const Text('For owner troubleshooting and deep inspection',style:TextStyle(color:AppTheme.textMuted,fontSize:8)),children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:SelectableText(pretty,style:const TextStyle(fontFamily:'monospace',color:Colors.white70,fontSize:8.5,height:1.45)))])\n"""
raw2="""      if(MediaQuery.sizeOf(context).width>=800)...[const SizedBox(height:10),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Advanced technical details',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),subtitle:const Text('Desktop owner troubleshooting only',style:TextStyle(color:AppTheme.textMuted,fontSize:8)),children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:SelectableText(pretty,style:const TextStyle(fontFamily:'monospace',color:Colors.white70,fontSize:8.5,height:1.45)))])],\n"""
if text.count(raw)!=1: raise SystemExit(f'raw detail anchor {text.count(raw)}')
text=text.replace(raw,raw2,1)
text += "\nconst String _bridgePointMobileShellCleanupV390='bridgepoint-v390-mobile-shell-cleanup | desktop-only floating AI | no mobile raw JSON';\n"
main.write_text(text,encoding='utf-8')
html=web.read_text(encoding='utf-8')
for x in ['bp-expansion-launcher','bp-expansion-panel','>Expansion Engine<']:
    if x in html: raise SystemExit(f'legacy expansion DOM remains: {x}')
html=html.replace("const releaseKey='bridgepoint_release_v162';","const releaseKey='bridgepoint_release_v390';",1)
boot='<script src="flutter_bootstrap.js" async></script>'
if boot not in html: raise SystemExit('flutter bootstrap anchor missing')
gate='''<script>\n  /* bridgepoint-v390-bootstrap-cache-gate */\n  (async()=>{\n    const epoch='bridgepoint_bootstrap_epoch_v390';\n    try{if(localStorage.getItem(epoch)!=='1'){\n      if('serviceWorker' in navigator){const regs=await navigator.serviceWorker.getRegistrations();await Promise.all(regs.map(r=>r.unregister()));}\n      if('caches' in window){const keys=await caches.keys();await Promise.all(keys.filter(k=>k.startsWith('flutter')||k.includes('bridgepoint')).map(k=>caches.delete(k)));}\n      localStorage.setItem(epoch,'1');\n    }}catch(_){ }\n    const s=document.createElement('script');s.src='flutter_bootstrap.js?bpv=390';s.async=true;document.body.appendChild(s);\n  })();\n  </script>'''
html=html.replace(boot,gate,1)
web.write_text(html,encoding='utf-8')
print('Applied v390 mobile shell + stale PWA cleanup')
