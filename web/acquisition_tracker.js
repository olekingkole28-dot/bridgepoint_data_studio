(()=>{
  const supabaseUrl='https://xdfsjztwgsbmabshzsjw.supabase.co';
  const apikey='sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
  const endpoint=`${supabaseUrl}/rest/v1/rpc/track_acquisition_event_v400`;
  const safeId=()=>globalThis.crypto?.randomUUID?.()||`${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  const getStored=(storage,key)=>{try{return storage.getItem(key)}catch(_){return null}};
  const setStored=(storage,key,value)=>{try{storage.setItem(key,value)}catch(_){}};
  let visitorId=getStored(localStorage,'bp_visitor_id_v421');
  if(!visitorId){visitorId=safeId();setStored(localStorage,'bp_visitor_id_v421',visitorId)}
  let sessionId=getStored(sessionStorage,'bp_session_id_v421');
  if(!sessionId){sessionId=safeId();setStored(sessionStorage,'bp_session_id_v421',sessionId)}
  const params=new URLSearchParams(location.search);
  const campaign={p_utm_source:params.get('utm_source'),p_utm_medium:params.get('utm_medium'),p_utm_campaign:params.get('utm_campaign'),p_utm_content:params.get('utm_content'),p_referral_code:params.get('ref')||params.get('referral_code')};
  const sent=new Map();
  const send=(eventType,metadata={},dedupeMs=750)=>{
    const key=`${eventType}:${metadata.control||metadata.route||''}`;
    const now=Date.now(); if(now-(sent.get(key)||0)<dedupeMs)return; sent.set(key,now);
    const payload={p_event_type:eventType,p_visitor_id:visitorId,p_session_id:sessionId,p_page_path:`${location.pathname}${location.search}`.slice(0,1000),p_platform:'WEB',p_referrer_host:(()=>{try{return document.referrer?new URL(document.referrer).host:null}catch(_){return null}})(),...campaign,p_auth_error_code:null,p_metadata:{capture_version:423,href_hash:location.hash||null,...metadata}};
    fetch(endpoint,{method:'POST',headers:{apikey,'Content-Type':'application/json','Accept':'application/json'},body:JSON.stringify(payload),keepalive:true}).catch(()=>{});
  };
  const classify=(raw)=>{
    const s=(raw||'').replace(/\s+/g,' ').trim().toLowerCase();
    if(!s)return null;
    if(/create account|sign up|signup|start 7-day trial|start free trial|free trial|try bridgepoint/.test(s))return 'SIGNUP_VIEW';
    if(/pricing|plans?|packages?|subscription/.test(s))return 'PRICING_VIEW';
    if(/sample|demo|preview|see it work|how it works|why bridgepoint|explore|intelligence/.test(s))return 'VALUE_VIEW';
    if(/checkout|buy now|subscribe|upgrade|purchase/.test(s))return 'CHECKOUT_START';
    return null;
  };
  const inspectRoute=()=>{
    const route=`${location.pathname}${location.hash}`.toLowerCase();
    if(/pricing|plans|packages/.test(route))send('PRICING_VIEW',{route},3000);
    if(/signup|sign-up|register|create-account|trial/.test(route))send('SIGNUP_VIEW',{route},3000);
    if(/sample|demo|preview|how-it-works|why-bridgepoint/.test(route))send('VALUE_VIEW',{route},3000);
    if(/checkout|subscribe|purchase/.test(route))send('CHECKOUT_START',{route},3000);
  };
  send('LANDING_VIEW',{visibility:document.visibilityState},3000); inspectRoute();
  document.addEventListener('click',(event)=>{
    const el=event.target instanceof Element?event.target.closest('button,a,[role="button"],input[type="submit"]'):null;if(!el)return;
    const label=(el.textContent||el.getAttribute('aria-label')||el.getAttribute('title')||el.getAttribute('value')||'').replace(/\s+/g,' ').trim().slice(0,160);
    const href=el instanceof HTMLAnchorElement?el.href:'';
    const type=classify(`${label} ${href}`); if(type)send(type,{control:label||null,href:href||null});
  },true);
  document.addEventListener('submit',(event)=>{
    const form=event.target instanceof HTMLFormElement?event.target:null;if(!form)return;
    const text=(form.innerText||form.getAttribute('aria-label')||'').toLowerCase();
    send(/signup|account|trial|register/.test(text)?'SIGNUP_SUBMIT':'FORM_SUBMIT',{form_action:form.action||null},1500);
  },true);
  const originalPush=history.pushState.bind(history),originalReplace=history.replaceState.bind(history);
  history.pushState=(...args)=>{originalPush(...args);queueMicrotask(inspectRoute)};
  history.replaceState=(...args)=>{originalReplace(...args);queueMicrotask(inspectRoute)};
  addEventListener('popstate',inspectRoute);addEventListener('hashchange',inspectRoute);
})();
