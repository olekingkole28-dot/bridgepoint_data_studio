import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1810;
async function jf(url:string,timeoutMs=70000){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(timeoutMs)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,180)}`);const j=JSON.parse(t);if(j?.error)throw new Error(`REMOTE_API_ERROR:${j.error?.code??''}:${j.error?.message??''}`);return j;}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const cl=await s.rpc("bridgepoint_claim_iowa_foundation_v1540"); if(cl.error)throw cl.error;
 const t=cl.data?.task; if(!t)return new Response(JSON.stringify({complete:true,version:V,claimed:0}),{headers:H});
 try{
   const meta=t.candidate_metadata||{}, cur=t.cursor||{}, prev=t.result||{};
   const url=String(meta?.exact_layer_url||t.source_url||"").replace(/\/$/,"");
   const oid=String(cur.object_id_field||meta.object_id_field||"OBJECTID");
   const fields=(Array.isArray(cur.foundation_out_fields)?cur.foundation_out_fields:Array.isArray(meta.foundation_out_fields)?meta.foundation_out_fields:[]).map((x:any)=>String(x)).filter(Boolean);
   if(!fields.length)throw new Error("FOUNDATION_OUT_FIELDS_REQUIRED"); if(!fields.includes(oid))fields.unshift(oid);
   const total=Number(cur.estimated_total_rows||prev.estimated_total_rows||meta?.shard_expected_rows||meta?.endpoint_revalidation?.count||0);
   const ceiling=Number(cur.shard_window_ceiling||meta.shard_window_ceiling||0)||0;
   const last=Number(cur.last_oid||prev.last_oid||0)||0, seen=Number(cur.keyset_rows_seen||prev.keyset_rows_seen||0)||0;
   const failures=Number(prev.failure_count||0)||0; const page=failures>=2?200:failures===1?300:1000;
   let where=last>0?`${oid}>${last}`:"1=1"; if(ceiling>0)where=`(${where}) AND ${oid}<=${ceiling}`;
   const q=`${url}/query?where=${encodeURIComponent(where)}&outFields=${encodeURIComponent(fields.join(','))}&returnGeometry=false&orderByFields=${encodeURIComponent(oid+' ASC')}&resultRecordCount=${page}&f=json`;
   const j=await jf(q,70000); const raw=Array.isArray(j?.features)?j.features:[];
   const rows=raw.map((f:any)=>{const a={...(f?.attributes||{})};const id=a[oid]??a.OBJECTID??a.objectid;if(id==null)throw new Error("SOURCE_ID_MISSING");a._bridgepoint_source_record_id=String(id);return a;});
   const ids=rows.map((x:any)=>String(x._bridgepoint_source_record_id)); if(new Set(ids).size!==ids.length)throw new Error("SOURCE_ID_COLLISION");
   const oids=raw.map((f:any)=>Number((f?.attributes||{})[oid])).filter((x:number)=>Number.isFinite(x)); const nextLast=oids.length?Math.max(...oids):last; const nextSeen=seen+rows.length;
   const done=rows.length===0||(total>0&&nextSeen>=total)||(ceiling>0&&nextLast>=ceiling)||(!j?.exceededTransferLimit&&rows.length<page);
   const st=await s.rpc("bridgepoint_expansion_worker_stage_records_v90",{p_source_task_id:t.source_task_id,p_records:rows,p_next_cursor:{pagination_mode:"OID_BOUNDED_IOWA_V1810",last_oid:nextLast,keyset_rows_seen:nextSeen,estimated_total_rows:total,object_id_field:oid,foundation_out_fields:fields,privacy_minimized:true,shard_window_ceiling:ceiling||null},p_done:done,p_result:{batch_size:rows.length,last_batch_records:rows.length,progress_from:seen,progress_to:nextSeen,last_batch_at:new Date().toISOString(),last_oid:nextLast,keyset_rows_seen:nextSeen,estimated_total_rows:total,object_id_field:oid,projected_fields:fields,effective_page_size:page,iowa_foundation_version:V,privacy_minimized:true,metadata_roundtrip_skipped:true,source_url_resolved_v1540:url,shard_window_ceiling:ceiling||null}}); if(st.error)throw st.error;
   return new Response(JSON.stringify({complete:true,version:V,claimed:1,records:rows.length,done,last_oid:nextLast,seen:nextSeen,total,page,ceiling:ceiling||null}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);await s.rpc("bridgepoint_expansion_worker_fail_task_v90",{p_source_task_id:t.source_task_id,p_error:msg,p_detail:{iowa_foundation_version:V,source_url:t.source_url,privacy_minimized:true,metadata_roundtrip_skipped:true}});return new Response(JSON.stringify({complete:false,version:V,claimed:1,error:msg}),{status:500,headers:H});}
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});