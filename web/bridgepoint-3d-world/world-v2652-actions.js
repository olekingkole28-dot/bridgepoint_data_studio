import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const supabase=createClient('https://xdfsjztwgsbmabshzsjw.supabase.co','sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25');
const button=document.getElementById('requestExpansionButton');
const status=document.getElementById('status');
if(button)button.addEventListener('click',async()=>{
  const base=window.BridgePointWorldV2500;
  const code=base&&base.state?base.state.lockedCountry:null;
  const title=document.getElementById('lockTitle')?.textContent||'';
  const name=title.split(' — ')[0]||null;
  if(!code){if(status)status.textContent='Move into a locked country first, then request expansion.';return}
  button.disabled=true;button.textContent='Sending request…';
  try{
    const {data,error}=await supabase.rpc('bridgepoint_request_world_expansion_v2652',{p_country_code:code,p_country_name:name,p_context:{world_version:2652,requested_from:'locked_country_card'}});
    if(error)throw error;
    if(data&&data.locked){button.textContent='Sign in to request expansion';if(status)status.textContent='Sign in to BridgePoint, then request this country again.'}
    else if(data&&data.complete){button.textContent='Expansion requested ✓';if(status)status.textContent=`${name||code} expansion request recorded for BridgePoint.`}
    else{button.textContent='Request BridgePoint expansion here';if(status)status.textContent=data&&data.reason?data.reason:'Expansion request was not recorded.'}
  }catch(e){button.textContent='Request BridgePoint expansion here';if(status)status.textContent=`Expansion request unavailable: ${e&&e.message?e.message:e}`}
  finally{button.disabled=false}
});
