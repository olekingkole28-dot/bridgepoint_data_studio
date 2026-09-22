import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE="https://gis.cobbcounty.gov/gisserver/rest/services/tax/taxassessorsdaily/MapServer/0";
const TASK_ID="01ab9bfb-daa1-4cca-b826-a03d85dc7bfc";
const CANDIDATE_ID="4a79a756-349f-49ad-8237-ab08bb8bfb36";
const EXPECTED=279446;
const OUT_FIELDS=["OBJECTID","PIN","PARID","SITUS_ADDR","CLASS","ACRES","LOTNUM","NBHOOD_NUM","SUBDIVNUM","TAXDIST"].join(",");
async function jf(url:string){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,200)}`);const j=JSON.parse(t);if(j?.error)throw new Error(`REMOTE_API_ERROR:${j.error?.code??''}:${j.error?.message??''}`);return j;}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const {data:tasks,error:te}=await s.schema("automation").from("geographic_source_tasks_v90").select("source_task_id,task_status,cursor,result,next_retry_at").eq("source_task_id",TASK_ID).limit(1); if(te)throw te;
 const task=tasks?.[0]; if(!task)return new Response(JSON.stringify({complete:true,skipped:"NO_TASK"}),{headers:H});
 if(!["QUEUED","RETRY"].includes(task.task_status))return new Response(JSON.stringify({complete:true,skipped:`TASK_${task.task_status}`}),{headers:H});
 if(task.next_retry_at&&new Date(task.next_retry_at).getTime()>Date.now())return new Response(JSON.stringify({complete:true,skipped:"NOT_DUE"}),{headers:H});
 const {data:claimed,error:ce}=await s.schema("automation").from("geographic_source_tasks_v90").update({task_status:"RUNNING",updated_at:new Date().toISOString(),result:{...(task.result||{}),cobb_dedicated_v1670:true,claimed_at_v1670:new Date().toISOString()}}).eq("source_task_id",TASK_ID).in("task_status",["QUEUED","RETRY"]).select("source_task_id"); if(ce)throw ce; if(!claimed?.length)return new Response(JSON.stringify({complete:true,skipped:"CLAIM_RACE"}),{headers:H});
 let last=Number(task.cursor?.last_oid||0)||0, seen=Number(task.cursor?.keyset_rows_seen||0)||0; const records:any[]=[]; let eof=false; const pageSize=2000; const waves=3;
 for(let i=0;i<waves;i++){const q=new URLSearchParams({where:last>0?`OBJECTID > ${last}`:"1=1",outFields:OUT_FIELDS,returnGeometry:"false",orderByFields:"OBJECTID ASC",resultRecordCount:String(pageSize),f:"json"}); const j=await jf(`${SOURCE}/query?${q}`); const fs=Array.isArray(j?.features)?j.features:[]; if(!fs.length){eof=true;break;} for(const f of fs){const x=f?.attributes||{}; const oid=Number(x.OBJECTID); if(!Number.isFinite(oid))continue; if(oid>last)last=oid; records.push({...x,_bridgepoint_source_record_id:String(oid),parcel_id:x.PIN??x.PARID??null,address:x.SITUS_ADDR??null,county_name:"Cobb County",property_subtype:x.CLASS??null,acreage:x.ACRES??null,cobb_free_tabular_alias_v1670:true});} if(fs.length<pageSize){eof=true;break;}}
 seen+=records.length; const done=eof||records.length===0||seen>=EXPECTED; const nextCursor={last_oid:last,object_id_field:"OBJECTID",pagination_mode:"OID_KEYSET_COBB_TABULAR_V1670",keyset_rows_seen:seen,estimated_total_rows:EXPECTED,foundation_out_fields:OUT_FIELDS.split(",")};
 const st=await s.rpc("bridgepoint_expansion_worker_stage_records_v90",{p_source_task_id:TASK_ID,p_records:records,p_next_cursor:nextCursor,p_done:done,p_result:{worker:"bridgepoint-cobb-parcel-v1670",worker_ok:true,candidate_id:CANDIDATE_ID,last_batch_records:records.length,last_batch_at:new Date().toISOString(),privacy_minimized:true,return_geometry:false,paid_polygon_product_excluded:true,free_tabular_product:true}}); if(st.error)throw st.error;
 return new Response(JSON.stringify({complete:true,candidate_id:CANDIDATE_ID,source_task_id:TASK_ID,records:records.length,seen,last_oid:last,done,stage:st.data}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,error:String((e as any)?.message||e)}),{status:500,headers:H});}});