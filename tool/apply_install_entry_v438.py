from pathlib import Path

main_path=Path('lib/main.dart')
text=main_path.read_text(encoding='utf-8')
marker='bridgepoint-v438-install-entry'
if marker not in text:
    # Enrich the unauthenticated entry without touching account/avatar identity code.
    auth_anchor="""      const SizedBox(height:8),Text(create?'Create your 7-day trial':'Sign in to live property intelligence',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted)),
      const SizedBox(height:24),"""
    auth_insert="""      const SizedBox(height:8),Text(create?'Create your 7-day trial':'Sign in to live property intelligence',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted)),
      const SizedBox(height:12),
      Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.07),AppTheme.blue.withOpacity(.035)]),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('LIVE PROPERTY INTELLIGENCE',style:TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.7)),SizedBox(height:5),Text('See explainable opportunities, property evidence, live map context, timelines and field tools in one workspace.',style:TextStyle(color:Colors.white70,fontSize:9.5,height:1.45)),SizedBox(height:8),Wrap(spacing:6,runSpacing:6,children:[Chip(label:Text('Explainable opportunities',style:TextStyle(fontSize:8))),Chip(label:Text('Live map + weather',style:TextStyle(fontSize:8))),Chip(label:Text('Property timelines',style:TextStyle(fontSize:8)))])])),
      const SizedBox(height:18),"""
    if text.count(auth_anchor)==1:
        text=text.replace(auth_anchor,auth_insert,1)

    toggle_anchor="""      TextButton(onPressed:loading?null:()=>setState(()=>create=!create),child:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial')),"""
    toggle_replacement="""      OutlinedButton.icon(onPressed:loading?null:()=>setState(()=>create=!create),icon:Icon(create?Icons.login_rounded:Icons.person_add_alt_1_rounded),label:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial'),style:OutlinedButton.styleFrom(minimumSize:const Size(double.infinity,44))),"""
    if text.count(toggle_anchor)==1:
        text=text.replace(toggle_anchor,toggle_replacement,1)

    # Keep the canonical Ask BridgePoint A.I. search wording broad and clear.
    for old in [
        "hintText: 'Ask BridgePoint AI about any property, place, event or opportunity'",
        "hintText: 'Ask about a property, place, event, opportunity or BridgePoint tool'",
    ]:
        if old in text:
            text=text.replace(old,"hintText: 'Ask BridgePoint A.I. — property, place, event, opportunity, package or system'",1)

    text += "\nconst String _bridgePointInstallEntryV438='bridgepoint-v438-install-entry | gold install CTA | richer auth entry | BridgePoint A.I.';\n"
    main_path.write_text(text,encoding='utf-8')
    print('Applied richer auth entry and BridgePoint A.I. wording V438.')
else:
    print('V438 Flutter entry already applied.')

web_path=Path('web/index.html')
web=web_path.read_text(encoding='utf-8')
web_marker='bridgepoint-v438-gold-install-cta'
if web_marker not in web:
    if 'bridgepoint-v310-install-onboarding' not in web:
        raise SystemExit('V438 requires V310 install onboarding in web/index.html')

    gate='if(shown||alreadyInstalled()||dismissedThisSession()||!hasAuthSession())return;'
    if gate in web:
        web=web.replace(gate,'if(shown||alreadyInstalled()||dismissedThisSession())return;',1)

    web=web.replace('.bp-install-icon{width:58px;height:58px;border-radius:16px;background:linear-gradient(135deg,#35d2e8,#4f7cff);', '.bp-install-icon{width:58px;height:58px;border-radius:16px;background:linear-gradient(135deg,#ffd84a,#f2a900);',1)
    web=web.replace('.bp-install-eyebrow{font-size:10px;letter-spacing:.9px;color:#35d2e8;', '.bp-install-eyebrow{font-size:10px;letter-spacing:.9px;color:#ffd84a;',1)
    web=web.replace('.bp-install-primary{background:#35d2e8;color:#07111f;', '.bp-install-primary{background:linear-gradient(135deg,#ffe36b,#f2ad13);color:#1b1402;box-shadow:0 10px 28px rgba(255,196,38,.28);',1)

    style_anchor='</style>'
    install_style=r'''    /* bridgepoint-v438-gold-install-cta */
    @keyframes bpInstallBounceV438{0%,78%,100%{transform:translateY(0) scale(1)}84%{transform:translateY(-8px) scale(1.025)}90%{transform:translateY(0) scale(1)}95%{transform:translateY(-3px) scale(1.01)}}
    @keyframes bpInstallGlowV438{0%,100%{box-shadow:0 10px 34px rgba(255,190,35,.28),0 0 0 0 rgba(255,216,74,.20)}50%{box-shadow:0 14px 42px rgba(255,190,35,.42),0 0 0 8px rgba(255,216,74,0)}}
    #bp-install-fab-v438{position:fixed;left:18px;bottom:calc(18px + env(safe-area-inset-bottom));z-index:2147483000;display:none;align-items:center;gap:10px;border:1px solid rgba(255,242,167,.78);border-radius:999px;padding:10px 15px 10px 11px;background:linear-gradient(135deg,#ffe879,#f2ad13);color:#211804;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;font-weight:950;cursor:pointer;animation:bpInstallBounceV438 3.2s ease-in-out infinite,bpInstallGlowV438 2.2s ease-in-out infinite;max-width:min(330px,calc(100vw - 36px));text-align:left}
    #bp-install-fab-v438.show{display:flex}#bp-install-fab-v438 .bp-dl-icon{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;background:rgba(33,24,4,.12);font-size:19px;flex:0 0 auto}#bp-install-fab-v438 strong{display:block;font-size:11px;line-height:1.05;letter-spacing:.4px}#bp-install-fab-v438 small{display:block;font-size:9px;line-height:1.15;font-weight:800;opacity:.72;margin-top:2px}
    #bp-install-primary{animation:bpInstallGlowV438 2.2s ease-in-out infinite}
    @media(max-width:620px){#bp-install-fab-v438{left:10px;bottom:calc(82px + env(safe-area-inset-bottom));padding:9px 12px 9px 9px;max-width:calc(100vw - 20px)}}
    @media(prefers-reduced-motion:reduce){#bp-install-fab-v438,#bp-install-primary{animation:none!important}}
'''
    if style_anchor not in web:
        raise SystemExit('V438 web style anchor missing')
    web=web.replace(style_anchor,install_style+style_anchor,1)

    body_anchor='  <div id="bp-install-backdrop"'
    install_button='''  <button id="bp-install-fab-v438" type="button" aria-label="Download or install the BridgePoint app"><span class="bp-dl-icon" aria-hidden="true">↓</span><span><strong>DOWNLOAD / INSTALL APP</strong><small>Put BridgePoint on this device</small></span></button>\n\n'''
    if body_anchor not in web:
        raise SystemExit('V438 install backdrop anchor missing')
    web=web.replace(body_anchor,install_button+body_anchor,1)

    bootstrap_anchor='  <script src="flutter_bootstrap.js" async></script>'
    install_script=r'''  <script>
  (()=>{
    const button=document.getElementById('bp-install-fab-v438');
    if(!button)return;
    const installedKey='bridgepoint_app_installed_v310';
    const standalone=()=>window.matchMedia?.('(display-mode: standalone)').matches===true||navigator.standalone===true||document.referrer.startsWith('android-app://');
    const installed=()=>{if(standalone())return true;try{return localStorage.getItem(installedKey)==='1'}catch(_){return false}};
    const sync=()=>button.classList.toggle('show',!installed());
    button.addEventListener('click',()=>{if(installed()){sync();return;}if(typeof window.bridgePointShowInstallGuide==='function')window.bridgePointShowInstallGuide();else document.getElementById('bp-install-backdrop')?.classList.add('show');});
    window.addEventListener('appinstalled',()=>{try{localStorage.setItem(installedKey,'1')}catch(_){ }sync();});
    window.matchMedia?.('(display-mode: standalone)').addEventListener?.('change',sync);
    window.addEventListener('load',()=>setTimeout(sync,250));
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)sync()});
    sync();
  })();
  </script>

'''
    if bootstrap_anchor not in web:
        raise SystemExit('V438 bootstrap anchor missing')
    web=web.replace(bootstrap_anchor,install_script+bootstrap_anchor,1)
    web_path.write_text(web,encoding='utf-8')
    print('Applied persistent gold install CTA V438.')
else:
    print('V438 gold install CTA already applied.')
