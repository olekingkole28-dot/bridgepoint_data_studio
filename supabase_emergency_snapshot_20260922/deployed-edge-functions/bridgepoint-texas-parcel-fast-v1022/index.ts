import { createClient } from "npm:@supabase/supabase-js@2";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H = { "content-type": "application/json" };
const V = 1647;

async function fetchJson(url: string, ms = 26000) {
  const started = Date.now();
  const r = await fetch(url, { signal: AbortSignal.timeout(ms), headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0" } });
  const txt = await r.text();
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${txt.slice(0, 220)}`);
  let j: any; try { j = JSON.parse(txt); } catch { throw new Error("Unparseable ArcGIS JSON"); }
  if (j?.error) throw new Error(`ArcGIS ${j.error.code ?? "error"}: ${j.error.message ?? JSON.stringify(j.error).slice(0,220)}`);
  return { j, ms: Date.now() - started, bytes: txt.length };
}

function rows(fs: any[], objectIdField: string, allowedFields: string[]) {
  const allowed = new Set(allowedFields.map((x) => x.toLowerCase())); allowed.add(objectIdField.toLowerCase());
  return fs.map((f: any) => { const a=f.attributes||f.properties||f||{},o:Record<string,unknown>={}; for(const [k,v] of Object.entries(a)) if(allowed.has(k.toLowerCase())) o[k]=v; const id=a[objectIdField]??a.OBJECTID??a.objectid??a.GlobalID??a.globalid??a.id??null; if(id!=null)o._bridgepoint_source_record_id=String(id); return o; });
}

Deno.serve(async(req:Request)=>{
  const s=createClient(U,S,{auth:{persistSession:false}}); let task:any=null;
  try{
    const b=await req.json().catch(()=>({}));
    const ok=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(ok.error||ok.data!==true)return new Response(JSON.stringify({complete:false,version:V,error:"Invalid task token"}),{status:401,headers:H});

    const tq=await s.schema("automation").from("geographic_source_tasks_v90").select("source_task_id,run_id,candidate_id,state_code,task_type,task_status,cursor,result,updated_at").eq("state_code","TX").eq("task_type","ACQUIRE_PROPERTY_FOUNDATION").eq("task_status","QUEUED").order("priority",{ascending:true}).order("updated_at",{ascending:true}).limit(1);
    if(tq.error)throw tq.error; const live:any=tq.data?.[0]; if(!live)return new Response(JSON.stringify({complete:true,version:V,claimed:0,reason:"NO_READY_TX_TASK"}),{headers:H});

    const cq=await s.schema("automation").from("geographic_source_candidates_v86").select("candidate_id,source_url,decision_status,metadata").eq("candidate_id",live.candidate_id).maybeSingle(); if(cq.error)throw cq.error; const candidate:any=cq.data; if(!candidate||candidate.decision_status!=="ACCEPTED")throw new Error("TX candidate missing or not ACCEPTED");
    const allowedFields=Array.isArray(candidate.metadata?.foundation_out_fields)?candidate.metadata.foundation_out_fields.map((x:unknown)=>String(x)).filter(Boolean):[]; if(!allowedFields.length)throw new Error("TX foundation_out_fields missing; privacy projection required");

    const cur=live.cursor||{},prev=live.result||{}; const base=String(cur.layer||prev.layer||candidate.source_url||"").replace(/\/$/,""); if(!base)throw new Error("TX candidate source_url missing");
    const meta=(await fetchJson(`${base}?f=json`,18000)).j; const of=String(cur.object_id_field||prev.object_id_field||meta.objectIdField||"objectid"); const last=Number(cur.last_oid||prev.last_oid||0)||0,seen=Number(cur.keyset_rows_seen||prev.keyset_rows_seen||0)||0,total=Number(cur.estimated_total_rows||prev.estimated_total_rows||0)||0; const noGeom=Number(meta.standardMaxRecordCountNoGeometry||meta.maxRecordCount||2000)||2000; const page=Math.max(250,Math.min(Math.min(16000,noGeom),Number(b.page||8000))); const where=last>0?`${of}>${last}`:"1=1"; const outFields=Array.from(new Set([of,...allowedFields])).join(",");
    const q=`${base}/query?where=${encodeURIComponent(where)}&outFields=${encodeURIComponent(outFields)}&returnGeometry=false&orderByFields=${encodeURIComponent(of+" ASC")}&resultRecordCount=${page}&f=json`;

    if(b.probe_only===true){const got=await fetchJson(q),raw=got.j.features||[];return new Response(JSON.stringify({complete:true,version:V,probe:true,state:"TX",source_url:base,requested:Number(b.page||8000),effective_request:page,returned:raw.length,elapsed_ms:got.ms,response_bytes:got.bytes,exceeded_transfer_limit:!!got.j.exceededTransferLimit,max_record_count:Number(meta.maxRecordCount||0),standard_max_no_geometry:Number(meta.standardMaxRecordCountNoGeometry||0),object_id_field:of,last_oid:last,seen,total,projected_field_count:allowedFields.length,query_mode:"ORDERED_KEYSET_NO_RESULTTYPE_V1647"}),{headers:H});}

    const cl=await s.rpc("[REDACTED_LONG_LITERAL]",{p_run_id:live.run_id,p_source_task_id:live.source_task_id}); if(cl.error)throw cl.error; task=cl.data?.task||null; if(!task)return new Response(JSON.stringify({complete:true,version:V,claimed:0,state:"TX",reason:"NO_READY_TX_TASK_AFTER_DEDICATED_CLAIM"}),{headers:H});
    const got=await fetchJson(q),raw=got.j.features||[],rr=rows(raw,of,allowedFields); const oids=raw.map((f:any)=>Number((f.attributes||{})[of])).filter((x:number)=>Number.isFinite(x)); const next=oids.length?Math.max(...oids):last,nextSeen=seen+rr.length; const done=rr.length===0||(total>0&&nextSeen>=total)||(!got.j.exceededTransferLimit&&rr.length<page&&total<=0);
    const st=await s.rpc("[REDACTED_LONG_LITERAL]",{p_source_task_id:task.source_task_id,p_records:rr,p_next_cursor:{pagination_mode:"OID_KEYSET_TX_2025_PROJECTED_V1647",last_oid:next,keyset_rows_seen:nextSeen,layer:base,estimated_total_rows:total,object_id_field:of,foundation_out_fields:allowedFields,privacy_minimized:true},p_done:done,p_result:{layer:base,batch_size:rr.length,last_batch_records:rr.length,requested_batch_size:Number(b.page||8000),effective_page_size:page,estimated_total_rows:total,pagination_mode:"OID_KEYSET_TX_2025_PROJECTED_V1647",object_id_field:of,keyset_rows_seen:nextSeen,last_oid:next,texas_2025_candidate_bound_v1647:true,privacy_minimized:true,projected_fields:allowedFields,geometry_deferred:true,return_geometry_mode:"ATTRIBUTES_ONLY_ORDERED_KEYSET",provider_no_geometry_record_limit:noGeom,response_bytes:got.bytes,fetch_ms:got.ms,worker_version:V}}); if(st.error)throw st.error;
    return new Response(JSON.stringify({complete:true,version:V,claimed:1,state:"TX",records:rr.length,seen:nextSeen,total,last_oid:next,done,fetch_ms:got.ms,response_bytes:got.bytes,source_url:base,projected_field_count:allowedFields.length,pagination:"OID_KEYSET_TX_2025_PROJECTED_V1647",geometry_deferred:true,privacy_minimized:true}),{headers:H});
  }catch(e){if(task?.source_task_id){try{await s.rpc("[REDACTED_LONG_LITERAL]",{p_source_task_id:task.source_task_id,p_error:String((e as any)?.message||e),p_detail:{worker_version:V,state:"TX",mode:"TX_2025_PROJECTED_ORDERED_KEYSET"}})}catch{}}return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:400,headers:H});}
});
