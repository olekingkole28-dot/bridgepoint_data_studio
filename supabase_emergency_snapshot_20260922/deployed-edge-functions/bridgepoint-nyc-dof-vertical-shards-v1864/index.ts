import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1864,PAGE=1000,PAGES=10;
const county=(b:number)=>({1:"New York County",2:"Bronx County",3:"Kings County",4:"Queens County",5:"Richmond County"} as Record<number,string>)[b]||null;
const esc=(s:string)=>s.replace(/'/g,"''");
async function jf(url:string){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,240)}`);try{return JSON.parse(t)}catch{throw new Error(`UNPARSEABLE_JSON:${t.slice(0,160)}`)}}
Deno.serve(async(req:Request)=>{let boro=0;try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const body=await req.json().catch(()=>({})); const tok=String(body.task_token||req.headers.get("x-bridgepoint-worker-token")||"");
 const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok}); if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED",token_length:tok.length,auth_data:auth.data,auth_error:auth.error?String(auth.error.message||auth.error):null}),{status:401,headers:H});
 const cl=await db.rpc("bridgepoint_claim_nyc_dof_vertical_shard_v1864"); if(cl.error)throw cl.error; const sh=cl.data?.shard; if(!sh)return new Response(JSON.stringify({complete:true,version:V,claimed:0,records:0}),{headers:H});
 boro=Number(sh.boro); let last=String(sh.last_parid||"").trim(); let seen=Math.max(0,Number(sh.records_seen||0)||0); let total=0,done=false; const stats:any[]=[];
 const fields=["parid","boro","block","lot","easement","rectype","year","bldg_class","housenum_lo","housenum_hi","street_name","zip_code","stcode","appt_block","appt_lot","appt_ease","condo_number","condo_sfx1","condo_sfx2","condo_sfx3"];
 for(let p=0;p<PAGES&&!done;p++){
   const where=`year='2027' AND rectype=1 AND boro=${boro}${last?` AND parid > '${esc(last)}'`:''}`;
   const url=`https://data.cityofnewyork.us/resource/8y4t-faws.json?$select=${encodeURIComponent(fields.join(','))}&$where=${encodeURIComponent(where)}&$order=${encodeURIComponent('parid')}&$limit=${PAGE}`;
   const raw=await jf(url); if(!Array.isArray(raw))throw new Error("SOCRATA_ROWS_EXPECTED");
   const mapped=raw.map((x:any)=>{const parid=String(x?.parid||"").trim();const hn=String(x?.housenum_lo||"").trim();const st=String(x?.street_name||"").trim();return {...x,parcel_id:parid,address:[hn,st].filter(Boolean).join(" ")||null,property_address:[hn,st].filter(Boolean).join(" ")||null,postal_code:String(x?.zip_code||"").trim()||null,municipality:"New York City",county_name:county(boro),state_code:"NY",_bridgepoint_source_record_id:parid,_bridgepoint_nyc_dof_borough_shard_v1864:boro}}).filter((x:any)=>x.parcel_id);
   if(new Set(mapped.map((x:any)=>x.parcel_id)).size!==mapped.length)throw new Error("PARID_COLLISION_IN_BOROUGH_PAGE");
   if(mapped.length){last=String(mapped[mapped.length-1].parcel_id);seen+=mapped.length;total+=mapped.length}
   done=raw.length<PAGE;
   const stg=await db.rpc("bridgepoint_stage_nyc_dof_vertical_shard_v1864",{p_boro:boro,p_records:mapped,p_last_parid:last,p_records_seen:seen,p_done:done}); if(stg.error)throw stg.error;
   stats.push({page:p+1,records:mapped.length,last_parid:last,seen}); if(!mapped.length)done=true;
 }
 return new Response(JSON.stringify({complete:true,version:V,claimed:1,boro,records:total,done,last_parid:last,records_seen:seen,pages:stats}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);if(boro){try{await db.rpc("bridgepoint_fail_nyc_dof_vertical_shard_v1864",{p_boro:boro,p_error:msg})}catch{}}return new Response(JSON.stringify({complete:false,version:V,boro,error:msg}),{status:500,headers:H})}
});