import { createClient } from "npm:@supabase/supabase-js@2";

type Obj=Record<string,unknown>;
const H={"content-type":"application/json","cache-control":"no-store"};
const FIELDS=["OBJECTID","REGISTRY_ID","FAC_NAME","FAC_STREET","FAC_CITY","FAC_STATE","FAC_ZIP","FAC_COUNTY","FAC_LAT","FAC_LONG","TRI_IDS","TRI_RELEASES_TRANSFERS","TRI_ON_SITE_RELEASES","TRI_OFF_SITE_TRANSFERS","TRI_REPORTER","RCRA_FLAG","RCRA_IDS","RCRA_CURR_COMPLIANCE_STATUS","RCRA_CURR_SNC_FLAG","FAC_CURR_COMPLIANCE_STATUS","FAC_CURR_SNC_FLG","FAC_QTRS_IN_NC","FAC_TOTAL_PENALTIES","FAC_PENALTY_COUNT","FAC_LAST_PENALTY_AMT","FAC_DATE_LAST_PENALTY","DFR_URL"];
function resp(x:unknown,s=200){return new Response(JSON.stringify(x),{status:s,headers:H});}
function bounded(v:unknown,d:number,min:number,max:number){const n=Number(v);return Number.isFinite(n)?Math.min(max,Math.max(min,Math.trunc(n))):d;}
async function body(req:Request):Promise<Obj>{const t=await req.text();if(!t.trim())return{};const x=JSON.parse(t);if(!x||typeof x!=="object"||Array.isArray(x))throw new Error("JSON object required");return x as Obj;}
async function fetchPage(state:string,offset:number,count:number){
 const q=new URLSearchParams({where:`FAC_STATE='${state}' AND TRI_FLAG='Y'`,outFields:FIELDS.join(','),returnGeometry:'true',outSR:'4326',f:'json',orderByFields:'OBJECTID ASC',resultOffset:String(offset),resultRecordCount:String(count)});
 const url=`https://echogeo.epa.gov/arcgis/rest/services/ECHO/Facilities/MapServer/0/query?${q}`;
 let last:unknown;
 for(let i=0;i<3;i++)try{
   const r=await fetch(url,{headers:{accept:'application/json','user-agent':'BridgePoint Intelligence / bridgepointintelligence.online'},signal:AbortSignal.timeout(35000)});
   const text=await r.text();if(!r.ok)throw new Error(`EPA ECHO HTTP ${r.status}: ${text.slice(0,800)}`);
   const j=JSON.parse(text);if(j?.error)throw new Error(`EPA ECHO ArcGIS error ${JSON.stringify(j.error).slice(0,800)}`);return j;
 }catch(e){last=e;if(i<2)await new Promise(res=>setTimeout(res,750*(i+1)));}
 throw last instanceof Error?last:new Error(String(last));
}
function norm(f:any):Obj{const a={...(f?.attributes??{})};if(f?.geometry&&Number.isFinite(Number(f.geometry.x))&&Number.isFinite(Number(f.geometry.y))){a.FAC_LONG=Number(f.geometry.x);a.FAC_LAT=Number(f.geometry.y);}return a;}
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return resp({complete:false,error:"POST required"},405);
 const started=Date.now();let worker:string|null=null,state:string|null=null;
 try{
  const b=await body(req),url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");if(!url||!key)throw new Error("Supabase credentials unavailable");
  const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const auth=await db.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:String(b.task_token??'')});if(auth.error||auth.data!==true)return resp({complete:false,error:'Invalid task token'},401);
  worker=crypto.randomUUID();const cl=await db.rpc('claim_epa_echo_tri_state_v1077',{p_worker_id:worker});if(cl.error)throw new Error(`claim failed: ${cl.error.message}`);if(!cl.data||cl.data.complete===true)return resp({complete:true,status:'nothing_due',duration_ms:Date.now()-started});
  state=String(cl.data.state_code);let offset=Number(cl.data.offset??0);const batch=bounded(b.batch_size,1000,100,1000),maxPages=bounded(b.max_pages,3,1,5);const pages:Obj[]=[];
  for(let page=1;page<=maxPages;page++){
    const j=await fetchPage(state,offset,batch);const fs=Array.isArray(j?.features)?j.features:[];const rows=fs.map(norm);
    let written=0;if(rows.length){const ing=await db.rpc('ingest_epa_echo_tri_batch_v1077',{p_state_code:state,p_rows:rows});if(ing.error)throw new Error(`ingest failed: ${ing.error.message}`);written=Number(ing.data?.written??0);}
    const received=fs.length,next=offset+received,done=received<batch;
    const ck=await db.rpc('complete_epa_echo_tri_page_v1077',{p_worker_id:worker,p_state_code:state,p_next_offset:next,p_page_received:received,p_rows_written:written,p_complete:done,p_error:null});if(ck.error)throw new Error(`checkpoint failed: ${ck.error.message}`);
    pages.push({page,offset,received,written,complete:done});offset=next;
    if(done){await db.rpc('reconcile_epa_echo_tri_truth_v1077');return resp({complete:true,status:'state_cycle_completed',state_code:state,pages,checkpoint:ck.data,duration_ms:Date.now()-started,version:1077});}
  }
  const rel=await db.rpc('release_epa_echo_tri_state_v1077',{p_worker_id:worker,p_state_code:state});if(rel.error)throw new Error(`release failed: ${rel.error.message}`);
  return resp({complete:false,status:'state_checkpointed',state_code:state,next_offset:offset,pages,release:rel.data,duration_ms:Date.now()-started,version:1077});
 }catch(e){const msg=e instanceof Error?e.message:String(e);try{if(worker&&state){const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");if(url&&key){const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});await db.rpc('complete_epa_echo_tri_page_v1077',{p_worker_id:worker,p_state_code:state,p_next_offset:0,p_page_received:0,p_rows_written:0,p_complete:false,p_error:msg.slice(0,4000)});}}}catch{}return resp({complete:false,status:'failed',state_code:state,error:msg,duration_ms:Date.now()-started,version:1077},500);}
});