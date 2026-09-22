import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const T=(x:any,n=5000)=>String(x??"").trim().slice(0,n);
const j=(b:any,s=200)=>new Response(JSON.stringify(b),{status:s,headers:H});
async function sha(s:string){const b=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));return Array.from(new Uint8Array(b)).map(x=>x.toString(16).padStart(2,"0")).join("");}
async function nodeAuth(req:Request,body:any){const token=req.headers.get("x-bridgepoint-node-token")||T(body?.node_token,256);const nodeId=T(body?.node_id,80);if(token.length<48||!nodeId)return null;const {data,error}=await db.schema("automation").from("local_reasoning_nodes_v584").select("node_id,token_hash,enabled,status,primary_model,reviewer_model,capabilities").eq("node_id",nodeId).maybeSingle();if(error||!data||!data.enabled||data.status==="REVOKED")return null;return (await sha(token))===data.token_hash?data:null;}
async function rpc(name:string,args:any={}){const {data,error}=await db.rpc(name,args);if(error)throw new Error(`${name}: ${error.message}`);return data;}
Deno.serve(async(req:Request)=>{if(req.method!=="POST")return j({ok:false,error:"POST_REQUIRED"},405);const body=await req.json().catch(()=>({}));const action=T(body.action||"",40).toLowerCase();try{
 if(action==="enroll"){const code=T(body.enrollment_code,128),name=T(body.node_name||"BridgePoint Local AI",120);if(code.length<24)return j({ok:false,error:"ENROLLMENT_CODE_REQUIRED"},400);const r=await rpc("bridgepoint_internal_local_reasoning_enroll_v5607",{p_code:code,p_node_name:name,p_capabilities:body.capabilities||{},p_hardware:body.hardware||{}});return j({...r,version:5618});}
 const node=await nodeAuth(req,body);if(!node)return j({ok:false,error:"UNAUTHORIZED_NODE",version:5618},401);const nodeId=String(node.node_id);
 if(action==="heartbeat"){const r=await rpc("bridgepoint_internal_local_reasoning_heartbeat_v584",{p_node_id:nodeId,p_capabilities:body.capabilities||{},p_hardware:body.hardware||{}});return j({...r,version:5618,provider_mode:"LOCAL_FIRST"});}
 if(action==="claim"){const r=await rpc("bridgepoint_internal_local_reasoning_claim_v584",{p_node_id:nodeId,p_limit:Math.max(1,Math.min(Number(body.limit||2),4))});return j({...r,version:5618});}
 if(action==="submit"){if(!body.task_id||!body.primary)return j({ok:false,error:"TASK_AND_PRIMARY_REQUIRED"},400);const r=await rpc("bridgepoint_internal_local_reasoning_submit_v584",{p_node_id:nodeId,p_task_id:body.task_id,p_primary:body.primary,p_reviewer:body.reviewer||{},p_models:body.models||{}});return j({...r,version:5618});}
 if(action==="fail"){const r=await rpc("bridgepoint_internal_local_reasoning_fail_v584",{p_node_id:nodeId,p_task_id:body.task_id,p_error:T(body.error||"LOCAL_REASONING_FAILED",1800)});return j({...r,version:5618});}
 if(action==="backup_claim"){const r=await rpc("bridgepoint_internal_local_backup_claim_v717",{p_node_id:nodeId});return j({...r,version:5618});}
 if(action==="backup_complete"){if(!body.job_id)return j({ok:false,error:"BACKUP_JOB_REQUIRED"},400);const r=await rpc("bridgepoint_internal_local_backup_complete_v717",{p_node_id:nodeId,p_job_id:body.job_id,p_result:body.result||{}});return j({...r,version:5618});}
 if(action==="backup_fail"){if(!body.job_id)return j({ok:false,error:"BACKUP_JOB_REQUIRED"},400);const r=await rpc("bridgepoint_internal_local_backup_fail_v717",{p_node_id:nodeId,p_job_id:body.job_id,p_error:T(body.error||"LOCAL_BACKUP_FAILED",1800),p_result:body.result||{}});return j({...r,version:5618});}
 if(action==="backup_report"){const typ=T(body.report_type,40).toUpperCase(),status=T(body.status,40).toUpperCase();const r=await rpc("bridgepoint_internal_local_backup_report_v616",{p_node_id:nodeId,p_report_type:typ,p_status:status,p_payload:body.payload||{}});return j({...r,version:5618});}
 if(action==="export_claim"){const r=await rpc("bridgepoint_internal_portable_export_claim_v5605",{p_node_id:nodeId});return j({...r,version:5618});}
 if(action==="export_page"){if(!body.request_id||!body.dataset)return j({ok:false,error:"EXPORT_REQUEST_AND_DATASET_REQUIRED"},400);const r=await rpc("bridgepoint_internal_portable_export_page_v1845",{p_node_id:nodeId,p_request_id:body.request_id,p_dataset:T(body.dataset,40).toUpperCase(),p_cursor:body.cursor?T(body.cursor,120):null,p_limit:Math.max(1,Math.min(Number(body.limit||500),1000))});return j({...r,version:5618});}
 if(action==="export_complete"){if(!body.request_id)return j({ok:false,error:"EXPORT_REQUEST_REQUIRED"},400);const r=await rpc("bridgepoint_internal_portable_export_complete_v936",{p_node_id:nodeId,p_request_id:body.request_id,p_result:body.result||{}});return j({...r,version:5618});}
 if(action==="export_fail"){if(!body.request_id)return j({ok:false,error:"EXPORT_REQUEST_REQUIRED"},400);const r=await rpc("bridgepoint_internal_portable_export_fail_v936",{p_node_id:nodeId,p_request_id:body.request_id,p_error:T(body.error||"PORTABLE_EXPORT_FAILED",1800),p_result:body.result||{}});return j({...r,version:5618});}
 if(action==="archive_list"){
   const caps=node.capabilities||{};
   const agent=Number(caps.agent_version||0);
   if(!Boolean(caps.portable_export_authority)||agent<718)return j({ok:false,error:"ARCHIVE_EXPORT_AUTHORITY_OR_AGENT_V718_REQUIRED",version:5618},403);
   const prefix=T(body.prefix||"",220).split("/").filter(Boolean).join("/");
   const allowed=new RegExp("^(?:buildings/v2710/[A-Z]{2}(?:/(?:building|building_part))?|transport/v2696/[A-Z]{2}(?:/(?:connector|segment))?|transport-runtime/v2716/[A-Z]{2})$");
   if(!allowed.test(prefix))return j({ok:false,error:"ARCHIVE_PREFIX_NOT_ALLOWED",version:5618},400);
   const limit=Math.max(1,Math.min(Number(body.limit||100),100));
   const offset=Math.max(0,Number(body.offset||0));
   const {data:list,error:listErr}=await db.storage.from("living-world-archives").list(prefix,{limit,offset,sortBy:{column:"name",order:"asc"}});
   if(listErr)throw listErr;
   const files=(list||[]).filter((x:any)=>x?.metadata?.size && x?.name);
   const paths=files.map((x:any)=>prefix+"/"+x.name);
   let signed:any[]=[];
   if(paths.length){
     const {data:sig,error:sigErr}=await db.storage.from("living-world-archives").createSignedUrls(paths,3600);
     if(sigErr)throw sigErr;
     signed=sig||[];
   }
   return j({ok:true,version:5618,bucket:"living-world-archives",prefix,limit,offset,count:files.length,has_more:(list||[]).length===limit,
     files:files.map((x:any,i:number)=>({path:paths[i],size:Number(x.metadata?.size||0),etag:x.metadata?.eTag||null,last_modified:x.metadata?.lastModified||null,signed_url:signed[i]?.signedUrl||null,expires_in_seconds:3600}))});
 }

 if(action==="bootstrap_catalog"){
   const r=await rpc("bridgepoint_internal_bootstrap_catalog_v941",{p_node_id:nodeId});
   return j({...r,version:941});
 }
 if(action==="bootstrap_table_page"){
   const schema=T(body.schema,80),table=T(body.table,120);
   if(!schema||!table)return j({ok:false,error:"SCHEMA_AND_TABLE_REQUIRED"},400);
   const r=await rpc("bridgepoint_internal_bootstrap_table_page_v941",{
     p_node_id:nodeId,p_schema:schema,p_table:table,
     p_offset:Math.max(0,Number(body.offset||0)),
     p_limit:Math.max(1,Math.min(Number(body.limit||500),1000))
   });
   return j({...r,version:941});
 }
 if(action==="bootstrap_schema_page"){
   const r=await rpc("bridgepoint_internal_bootstrap_schema_page_v941",{
     p_node_id:nodeId,p_offset:Math.max(0,Number(body.offset||0)),
     p_limit:Math.max(1,Math.min(Number(body.limit||250),500))
   });
   return j({...r,version:941});
 }
 if(action==="storage_rescue_page"){
   const r:any=await rpc("bridgepoint_internal_storage_object_page_v941",{
     p_node_id:nodeId,p_cursor:body.cursor?String(body.cursor):null,
     p_limit:Math.max(1,Math.min(Number(body.limit||100),100))
   });
   const rows:any[]=Array.isArray(r?.rows)?r.rows:[];
   const grouped=new Map<string,any[]>();
   for(const x of rows){const b=String(x.bucket_id||"");if(!grouped.has(b))grouped.set(b,[]);grouped.get(b)!.push(x);}
   for(const [bucket,items] of grouped){
     const paths=items.map((x:any)=>String(x.name));
     const {data:sig,error:sigErr}=await db.storage.from(bucket).createSignedUrls(paths,3600);
     if(sigErr)throw sigErr;
     for(let i=0;i<items.length;i++)items[i].signed_url=sig?.[i]?.signedUrl||null;
   }
   return j({...r,rows,version:941});
 }

 if(action==="bootstrap_plan_v942"){
   const r=await rpc("bridgepoint_internal_bootstrap_plan_v942",{p_node_id:nodeId});
   return j({...r,version:942});
 }
 if(action==="bootstrap_table_page_v942"){
   const schema=T(body.schema,80),table=T(body.table,120);
   if(!schema||!table)return j({ok:false,error:"SCHEMA_AND_TABLE_REQUIRED"},400);
   const r=await rpc("bridgepoint_internal_bootstrap_table_page_v942",{
     p_node_id:nodeId,p_schema:schema,p_table:table,
     p_cursor:body.cursor?String(body.cursor):null,
     p_limit:Math.max(1,Math.min(Number(body.limit||100),250))
   });
   return j({...r,version:942});
 }
 if(action==="status"){return j({ok:true,version:5618,node_id:nodeId,status:node.status,primary_model:node.primary_model,reviewer_model:node.reviewer_model,provider_mode:"LOCAL_FIRST",backup_reporting:true,backup_jobs:true,backup_authority:Boolean(node.capabilities?.backup_authority),portable_export_jobs:true,portable_export_authority:Boolean(node.capabilities?.portable_export_authority),minimum_export_free_disk_gb:600,minimum_global_agent_version:718,export_datasets:["PROPERTIES","ADDRESSES","PARCEL_GEOMETRY","BOUNDARY_PROVENANCE","LEGAL_MANIFEST","TERRAIN","SURFACE","BUILDING_VISUAL_MATERIAL","SIGNALS","PATTERNS","SCORES","OPPORTUNITIES","MEDIA","SOURCES","EVIDENCE","STATE_SUMMARY","PACKAGE_MAP"]});}
 return j({ok:false,error:"UNKNOWN_ACTION",version:5618},400);
}catch(e){return j({ok:false,error:T((e as any)?.message||e,1800),version:5618},500);}});