import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1831;
async function jf(url:string,ms=25000){const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,180)}`);const j=JSON.parse(t);if(j?.error)throw new Error(`REMOTE_API_ERROR:${j.error?.code??''}:${j.error?.message??''}`);return j;}
function exactLayer(u:string){return /\/(FeatureServer|MapServer)\/\d+\/?$/i.test(u.replace(/\/$/,''));}
function oidField(m:any){return String(m?.objectIdField||m?.objectIdFieldName||(Array.isArray(m?.fields)?m.fields.find((x:any)=>String(x?.type||'').toLowerCase()==='esrifieldtypeoid')?.name:'')||'').trim();}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST_REQUIRED'}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const auth=await s.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:String(b.task_token||req.headers.get('x-bridgepoint-worker-token')||'')});
 if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:'UNAUTHORIZED'}),{status:401,headers:H});
 const candidateId=String(b.candidate_id||''); if(!candidateId)throw new Error('CANDIDATE_REQUIRED');
 const limit=Math.min(250,Math.max(1,Number(b.limit||100)));
 const tr=await s.rpc('parcel_boundary_target_v1831',{p_candidate_id:candidateId}); if(tr.error)throw tr.error;
 const t=tr.data||{}, url=String(t.source_url||'').replace(/\/$/,''); if(!exactLayer(url))throw new Error('EXACT_ARCGIS_LAYER_REQUIRED');
 const lm=await jf(`${url}?f=json`); const oid=oidField(lm); if(!oid)throw new Error('OBJECT_ID_FIELD_MISSING');
 const formats=String(lm?.supportedQueryFormats||'').toLowerCase(); if(formats&&!formats.includes('geojson'))throw new Error('GEOJSON_QUERY_NOT_SUPPORTED');
 const last=Number(t.last_oid||0)||0;
 const q=`${url}/query?where=${encodeURIComponent(`${oid}>${Math.trunc(last)}`)}&outFields=${encodeURIComponent(oid)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+' ASC')}&resultRecordCount=${limit}&f=geojson`;
 const g=await jf(q,35000); const fs=Array.isArray(g?.features)?g.features:[];
 const records:any[]=[]; let maxOid=last;
 for(const f of fs){const id=Number(f?.properties?.[oid]);if(!Number.isFinite(id)||!f?.geometry)continue;maxOid=Math.max(maxOid,id);records.push({source_record_id:String(id),geometry:f.geometry});}
 const done=fs.length<limit;
 const ap=await s.rpc('apply_parcel_boundary_batch_v1831',{p_candidate_id:candidateId,p_records:records,p_last_oid:maxOid,p_done:done}); if(ap.error)throw ap.error;
 return new Response(JSON.stringify({complete:true,version:V,candidate_id:candidateId,state_code:t.state_code,source_url:url,object_id_field:oid,requested:limit,remote_features:fs.length,geometry_records:records.length,last_oid:maxOid,done,apply:ap.data}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:400,headers:H});}});
