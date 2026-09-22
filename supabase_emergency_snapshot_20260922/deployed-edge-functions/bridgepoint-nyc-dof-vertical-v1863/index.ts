import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1863,PAGE=1000,PAGES=6;
const county=(b:any)=>({"1":"New York County","2":"Bronx County","3":"Kings County","4":"Queens County","5":"Richmond County"}[String(b)]||null);
const esc=(s:string)=>s.replace(/'/g,"''");
async function jf(url:string){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,240)}`);try{return JSON.parse(t)}catch{throw new Error(`UNPARSEABLE_JSON:${t.slice(0,160)}`)}}
async function fail(task:string,msg:string){await db.rpc('bridgepoint_expansion_worker_fail_task_v90',{p_source_task_id:task,p_error:msg,p_detail:{nyc_dof_vertical_version:V,truth_rule:'FY2027_RECTYPE1_PARID_ONLY'}})}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST_REQUIRED'}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); const tok=String(b.task_token||req.headers.get('x-bridgepoint-worker-token')||'');
 const auth=await db.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:tok}); if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:'UNAUTHORIZED'}),{status:401,headers:H});
 const cl=await db.rpc('bridgepoint_claim_nyc_dof_vertical_v1863'); if(cl.error)throw cl.error; const t=cl.data?.task; if(!t)return new Response(JSON.stringify({complete:true,version:V,claimed:0,records:0}),{headers:H});
 const task=String(t.source_task_id); let last=String(t.cursor?.last_parid||'').trim(); let seen=Math.max(0,Number(t.cursor?.records_seen||0)||0); let total=0,done=false; const stats:any[]=[];
 const fields=['parid','boro','block','lot','easement','rectype','year','bldg_class','housenum_lo','housenum_hi','street_name','zip_code','stcode','appt_block','appt_lot','appt_ease','condo_number','condo_sfx1','condo_sfx2','condo_sfx3'];
 for(let p=0;p<PAGES&&!done;p++){
   const where=`year='2027' AND rectype=1${last?` AND parid > '${esc(last)}'`:''}`;
   const url=`https://data.cityofnewyork.us/resource/8y4t-faws.json?$select=${encodeURIComponent(fields.join(','))}&$where=${encodeURIComponent(where)}&$order=${encodeURIComponent('parid')}&$limit=${PAGE}`;
   const raw=await jf(url); if(!Array.isArray(raw))throw new Error('SOCRATA_ROWS_EXPECTED');
   const mapped=raw.map((x:any)=>{const parid=String(x?.parid||'').trim();const hn=String(x?.housenum_lo||'').trim();const st=String(x?.street_name||'').trim();return {...x,parcel_id:parid,address:[hn,st].filter(Boolean).join(' ')||null,property_address:[hn,st].filter(Boolean).join(' ')||null,postal_code:String(x?.zip_code||'').trim()||null,municipality:'New York City',county_name:county(x?.boro),state_code:'NY',_bridgepoint_source_record_id:parid,_bridgepoint_nyc_dof_ore_v1863:true}}).filter((x:any)=>x.parcel_id);
   if(new Set(mapped.map((x:any)=>x._bridgepoint_source_record_id)).size!==mapped.length)throw new Error('PARID_COLLISION_IN_ORE_PAGE');
   if(mapped.length){last=String(mapped[mapped.length-1].parcel_id);seen+=mapped.length;total+=mapped.length}
   done=raw.length<PAGE;
   const stg=await db.rpc('bridgepoint_expansion_worker_stage_records_v90',{p_source_task_id:task,p_records:mapped,p_next_cursor:{pagination_mode:'NYC_DOF_PARID_KEYSET_V1863',last_parid:last,records_seen:seen,foundation_where:"year='2027' AND rectype=1",canonical_key_fields:['parid']},p_done:done,p_result:{nyc_dof_vertical_version:V,truth_rule:'FY2027_RECTYPE1_PARID_ONLY',last_parid:last,records_seen:seen,last_batch_records:mapped.length,last_batch_at:new Date().toISOString(),api:url,privacy_minimized:true,owner_fields_excluded:true}}); if(stg.error)throw stg.error;
   stats.push({page:p+1,records:mapped.length,last_parid:last}); if(!mapped.length)done=true;
 }
 return new Response(JSON.stringify({complete:true,version:V,claimed:1,records:total,done,last_parid:last,records_seen:seen,pages:stats}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);try{const cl:any=await db.rpc('bridgepoint_claim_nyc_dof_vertical_v1863');const task=cl.data?.task?.source_task_id;if(task)await fail(String(task),msg)}catch{}return new Response(JSON.stringify({complete:false,version:V,error:msg}),{status:500,headers:H})}
});