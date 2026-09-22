import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL=Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const service=createClient(SUPABASE_URL,SERVICE_ROLE,{auth:{persistSession:false}});
const H={'content-type':'application/json','cache-control':'no-store'};
const clean=(s:string)=>s.replace(/<script[\s\S]*?<\/script>/gi,' ').replace(/<style[\s\S]*?<\/style>/gi,' ').replace(/<[^>]+>/g,' ').replace(/&amp;/g,'&').replace(/&nbsp;|&#160;/gi,' ').replace(/\s+/g,' ').trim();
const slug=(s:string)=>s.toLowerCase().replace(/[^a-z0-9]+/g,'');
async function fetchText(url:string,ms=5000){try{const r=await fetch(url,{redirect:'follow',signal:AbortSignal.timeout(ms),headers:{accept:'text/html,application/xhtml+xml','user-agent':'BridgePointIntelligence/1.0 (+https://bridgepointintelligence.online)'}});return {ok:r.ok,status:r.status,url:r.url,text:(await r.text()).slice(0,220000)};}catch(e){return {ok:false,status:0,url,text:String((e as any)?.message||e)};}}
function guestCandidates(municipality:string){const s=slug(municipality);const slugs=[s,`${s}ct`];const hosts=['https://www.permitlinkonline.com','https://permitlinkusa-online.com','https://permitlinkusaonline.com'];const out:string[]=[];for(const h of hosts)for(const k of slugs)out.push(`${h}/csp/${k}/DocumentLink.GuestPermitListCenter.cls`);return out;}
async function openGuest(municipality:string){const probes:any[]=[];for(const url of guestCandidates(municipality)){const r=await fetchText(url);const text=clean(r.text).toLowerCase();const usable=r.ok&&text.includes('guest permit list')&&text.includes('permit type')&&text.includes('work description');probes.push({url,status:r.status,final_url:r.url,usable});if(usable)return {ok:true,url:r.url,status:r.status,probes};}return {ok:false,url:null,status:0,probes};}

Deno.serve(async(req:Request)=>{try{
  if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST required'}),{status:405,headers:H});
  const token=req.headers.get('x-bridgepoint-discovery-token')||'';
  const sec=await service.schema('automation').from('municipal_discovery_secret_v238').select('token').eq('singleton',true).single();
  if(sec.error||!sec.data||token!==sec.data.token)return new Response(JSON.stringify({complete:false,error:'Unauthorized scheduler'}),{status:401,headers:H});
  const body=await req.json().catch(()=>({}));const limit=Math.min(8,Math.max(1,Number(body.limit||4)));
  const q=await service.schema('automation').from('municipal_property_sources_v232')
    .select('municipal_source_id,municipality,discovery_status,provider,metadata,discovery_attempts,last_error,last_checked_at')
    .eq('state_code','CT').eq('source_family','BUILDING_PERMITS').neq('discovery_status','READY')
    .order('last_checked_at',{ascending:true,nullsFirst:true}).order('municipality',{ascending:true}).limit(limit*5);
  if(q.error)throw q.error;
  const rows=(q.data||[]).filter((x:any)=>String(x.provider||'').toLowerCase()!=='permitlink').slice(0,limit);
  const results:any[]=[];
  for(const row of rows){
    const municipality=String(row.municipality);const opened=await openGuest(municipality);const now=new Date().toISOString();const prior=(row.metadata||{});
    if(!opened.ok){
      const miss=await service.schema('automation').from('municipal_property_sources_v232').update({last_checked_at:now,metadata:{...prior,permitlink_probe_at:now,permitlink_probe_version:324,permitlink_probe_result:'NOT_FOUND',permitlink_probe:opened.probes}}).eq('municipal_source_id',row.municipal_source_id);
      if(miss.error)throw miss.error;
      results.push({municipality,found:false,probes:opened.probes});continue;
    }
    const upd=await service.schema('automation').from('municipal_property_sources_v232').update({
      discovery_status:'DISCOVERED',provider:'PermitLink',source_name:`${municipality} building permits`,source_url:opened.url,
      access_method:'VENDOR_PORTAL',official:true,legal_access_status:'UNREVIEWED',quality_score:96,
      discovered_at:now,last_checked_at:now,last_error:null,discovery_attempts:Number(row.discovery_attempts||0)+1,
      next_discovery_at:new Date(Date.now()+30*86400000).toISOString(),metadata:{...prior,discovered_by:'permitlink-guest-probe-v324',discovery_version:324,guest_url:opened.url,guest_probe:opened.probes,adapter_status:'DISCOVERED_PUBLIC_GUEST_LIST',automatic_refresh_status:'WAITING_FOR_V319_INGEST'}
    }).eq('municipal_source_id',row.municipal_source_id);
    if(upd.error)throw upd.error;
    results.push({municipality,found:true,provider:'PermitLink',source_url:opened.url});
  }
  return new Response(JSON.stringify({complete:true,worker:'permitlink-guest-discovery-v324.3',processed:rows.length,found:results.filter(x=>x.found).length,results,checked_at:new Date().toISOString()}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,error:String((e as any)?.message||e)}),{status:500,headers:H});}});
