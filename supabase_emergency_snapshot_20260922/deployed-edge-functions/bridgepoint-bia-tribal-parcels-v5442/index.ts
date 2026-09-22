import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE="https://biamaps.geoplatform.gov/server/rest/services/BOGS/RTV_VIEWER/MapServer/0";
const CID="2ac05b64-0e49-437d-82ec-2b7776b83bc1";
const ACQUIRE_TASK="64885c44-7ad9-4681-a921-6c09e8617be4";

async function jf(url:string,ms=60000){
  const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${t.slice(0,300)}`);
  const j=JSON.parse(t);
  if(j?.error) throw new Error(`REMOTE_${j.error?.code??""}:${j.error?.message??""}`);
  return j;
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const cq=await db.schema("automation").from("geographic_source_candidates_v86")
      .select("candidate_id,run_id,state_code,source_url,decision_status,metadata")
      .eq("candidate_id",CID).eq("decision_status","ACCEPTED").limit(1);
    if(cq.error) throw cq.error;
    const c=cq.data?.[0];
    if(!c||c.source_url!==SOURCE) throw new Error("BIA_NATIONAL_CANDIDATE_NOT_FOUND");

    const tq=await db.schema("automation").from("geographic_source_tasks_v90")
      .select("source_task_id,task_status,cursor,result")
      .eq("source_task_id",ACQUIRE_TASK).limit(1);
    if(tq.error) throw tq.error;
    const t=tq.data?.[0];
    if(!t) throw new Error("BIA_ACQUIRE_TASK_NOT_FOUND");
    if(t.task_status==="SUCCEEDED") return new Response(JSON.stringify({complete:true,done:true,candidate_id:CID,task:t}),{headers:H});

    // Always drain staged rows before fetching another remote page.
    const drain=await db.schema("automation").rpc("materialize_bia_tribal_parcels_v5441",{p_candidate_id:CID,p_limit:1000});
    if(drain.error) throw drain.error;
    const dr=drain.data||{};
    if(dr.skipped==="LOCKED"){
      return new Response(JSON.stringify({complete:true,version:5442,candidate_id:CID,paused:"MATERIALIZER_LOCKED",materialized:dr}),{headers:H});
    }
    if(Number(dr.selected||0)>0){
      return new Response(JSON.stringify({complete:true,version:5442,candidate_id:CID,drained:true,materialized:dr}),{headers:H});
    }

    const meta=await jf(`${SOURCE}?f=json`,30000);
    const oid=String(meta.objectIdField||meta.objectIdFieldName||meta.fields?.find((x:any)=>String(x?.type||"").toLowerCase()==="esrifieldtypeoid")?.name||"OBJECTID");
    if(String(meta.geometryType||"").toLowerCase()!=="esrigeometrypolygon") throw new Error("BIA_LAYER_NOT_POLYGON");

    const countj=await jf(`${SOURCE}/query?where=1%3D1&returnCountOnly=true&f=json`,45000);
    const total=Number(countj?.count||0);
    if(!Number.isFinite(total)||total<=0) throw new Error("BIA_REMOTE_COUNT_INVALID");

    // Mark the already-verified schema/refresh tasks complete once the live service check passes.
    await db.schema("automation").from("geographic_source_tasks_v90")
      .update({
        task_status:"SUCCEEDED",
        result:{verified_live:true,worker_version:5442,geometry_type:meta.geometryType,object_id_field:oid,max_record_count:meta.maxRecordCount||2000,total_records:total,verified_at:new Date().toISOString()},
        updated_at:new Date().toISOString()
      })
      .eq("candidate_id",CID).in("task_type",["INSPECT_SCHEMA","CONFIGURE_REFRESH"]).neq("task_status","SUCCEEDED");

    const last=Number(t.cursor?.last_oid||0);
    const seen=Number(t.cursor?.keyset_rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||1000),100),1500);
    const where=last>0?`${oid}>${Math.trunc(last)}`:"1=1";
    const outFields=[oid,"LANDAREACODE","TRACTID","TRACTREFNUM","Label_Name","REGION"].join(",");
    const q=`${SOURCE}/query?where=${encodeURIComponent(where)}&outFields=${encodeURIComponent(outFields)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,90000);
    const fs=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;

    const rows=fs.map((f:any)=>{
      const p=f?.properties||{};
      const id=Number(p?.[oid]??p?.OBJECTID??p?.objectid);
      if(Number.isFinite(id)) maxOid=Math.max(maxOid,id);
      return {
        ...p,
        land_area_code:p?.LANDAREACODE??null,
        tract_id:p?.TRACTID??null,
        tract_ref_num:p?.TRACTREFNUM??null,
        label_name:p?.Label_Name??null,
        bia_region:p?.REGION??null,
        geometry_geojson:f?.geometry??null,
        _bridgepoint_source_record_id:Number.isFinite(id)?String(id):String(p?.[oid]??crypto.randomUUID())
      };
    });

    const nextSeen=seen+rows.length;
    const done=rows.length===0||nextSeen>=total||rows.length<page;
    const staged=await db.rpc("bridgepoint_expansion_worker_stage_records_v90",{
      p_source_task_id:ACQUIRE_TASK,
      p_records:rows,
      p_next_cursor:{pagination_mode:"OID_KEYSET_BIA_TAAMS_V5442",last_oid:maxOid,keyset_rows_seen:nextSeen,estimated_total_rows:total},
      p_done:done,
      p_result:{source:"BIA_TAAMS_TRIBAL_PARCELS",batch_size:rows.length,estimated_total_rows:total,last_oid:maxOid,worker_version:5442,spatial_state_assignment:true}
    });
    if(staged.error) throw staged.error;

    const mat=await db.schema("automation").rpc("materialize_bia_tribal_parcels_v5441",{p_candidate_id:CID,p_limit:Math.max(100,rows.length)});
    if(mat.error) throw mat.error;

    return new Response(JSON.stringify({
      complete:true,version:5442,candidate_id:CID,total,remote_features:fs.length,
      last_oid:maxOid,keyset_rows_seen:nextSeen,done,staged:staged.data,materialized:mat.data
    }),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5442,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});