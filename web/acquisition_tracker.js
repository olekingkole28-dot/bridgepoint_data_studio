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
  const campaign={
    p_utm_source:params.get('utm_source'),p_utm_medium:params.get('utm_medium'),
    p_utm_campaign:params.get('utm_campaign'),p_utm_content:params.get('utm_content'),
    p_referral_code:params.get('ref')||params.get('referral_code')
  };
  const send=(eventType,metadata={})=>{
    const payload={
      p_event_type:eventType,p_visitor_id:visitorId,p_session_id:sessionId,
      p_page_path:`${location.pathname}${location.search}`.slice(0,1000),
      p_platform:'WEB',p_referrer_host:(()=>{try{return document.referrer?new URL(document.referrer).host:null}catch(_){return null}})(),
      ...campaign,p_auth_error_code:null,
      p_metadata:{capture_version:421,href_hash:location.hash||null,...metadata}
    };
    fetch(endpoint,{method:'POST',headers:{apikey,'Content-Type':'application/json','Accept':'application/json'},body:JSON.stringify(payload),keepalive:true}).catch(()=>{});
  };
  send('LANDING_VIEW',{visibility:document.visibilityState});
  let lastSignupView=0;
  document.addEventListener('click',(event)=>{
    const el=event.target instanceof Element?event.target.closest('button,a,[role="button"]'):null;
    if(!el)return;
    const label=(el.textContent||el.getAttribute('aria-label')||'').replace(/\s+/g,' ').trim().slice(0,120);
    const normalized=label.toLowerCase();
    if(normalized.includes('start 7-day trial')||normalized.includes('create account')){
      if(Date.now()-lastSignupView>1000){send('SIGNUP_VIEW',{control:label});lastSignupView=Date.now()}
      return;
    }
    if(normalized.includes('start free trial')){send('SIGNUP_SUBMIT',{control:label});return;}
    if(normalized.includes('pricing')||normalized.includes('plan')){send('PRICING_VIEW',{control:label});return;}
    if(normalized.includes('sample')){send('SAMPLE_REQUEST',{control:label});return;}
    if(normalized.includes('checkout')||normalized.includes('buy now')||normalized.includes('subscribe'))send('CHECKOUT_START',{control:label});
  },true);
})();
