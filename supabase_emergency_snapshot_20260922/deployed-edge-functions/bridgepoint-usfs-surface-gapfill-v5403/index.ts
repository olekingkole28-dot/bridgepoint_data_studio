import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const PRIMARY="https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_SurfaceOwnership_01/MapServer/0";
const FALLBACK="https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_ALPStatusAndEncumbrance_01/MapServer/80";
const STATUS_WHERE="status IN ('Acquired','Reserved Public Domain','Unpartitioned Riparian Interest')";
async function jf(url:string,ms=60000){
  const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text(); if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,350)}`);
  const j=JSON.parse(t); if(j?.error)throw new Error(`REMOTE_${j.error?.code??""}:${j.error?.message??""}`); return j;
}
async function chooseSource(){
  let last:any=null;
  for(const u of [PRIMARY,FALLBACK]){
    try{
      const m=await jf(`${u}?f=json`,30000);
      const gt=String(m?.geometryType||"");
      const fields=(Array.isArray(m?.fields)?m.fields:[]).map((x:any)=>String(x?.name||"").toLowerCase());
      if(/polygon/i.test(gt)&&fields.includes("surfaceownershipid"))return {url:u,meta:m};
      last=new Error(`INVALID_USFS_LAYER:${u}`);
    }catch(e){last=e;}
  }
  throw last??new Error("USFS_SOURCE_UNAVAILABLE");
}
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const state=String(b.state_code||"").toUpperCase();
    if(!/^[A-Z]{2}$/.test(state))throw new Error("STATE_REQUIRED");
    const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const cq=await db.schema("automation").from("geographic_source_candidates_v86")
      .select("candidate_id,run_id,state_code,source_url,decision_status,metadata")
      .eq("source_url",PRIMARY).eq("state_code",state).eq("decision_status","ACCEPTED").limit(1);
    if(cq.error)throw cq.error; const c=cq.data?.[0]; if(!c)throw new Error("USFS_STATE_CANDIDATE_NOT_FOUND");
    const bbox=Array.isArray(c.metadata?.state_bbox)?c.metadata.state_bbox.map(Number):[];
    if(bbox.length!==4||bbox.some((x:number)=>!Number.isFinite(x)))throw new Error("STATE_BBOX_MISSING");

    const tq=await db.schema("automation").from("geographic_source_tasks_v90")
      .select("source_task_id,task_status,cursor,result")
      .eq("candidate_id",c.candidate_id).eq("task_type","ACQUIRE_PROPERTY_FOUNDATION").limit(1);
    if(tq.error)throw tq.error; const t=tq.data?.[0]; if(!t)throw new Error("USFS_STATE_TASK_NOT_FOUND");
    if(t.task_status==="SUCCEEDED")return new Response(JSON.stringify({complete:true,done:true,state_code:state,candidate_id:c.candidate_id,task:t}),{headers:H});

    const picked=await chooseSource(),source=picked.url,meta=picked.meta;
    const oid=String(meta.objectIdField||meta.objectIdFieldName||meta.fields?.find((x:any)=>String(x?.type||"").toLowerCase()==="esrifieldtypeoid")?.name||"objectid");
    const geom=encodeURIComponent(bbox.join(","));
    const spatial=`geometry=${geom}&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects`;
    const countj=await jf(`${source}/query?where=${encodeURIComponent(STATUS_WHERE)}&${spatial}&returnCountOnly=true&f=json`,45000);
    const total=Number(countj?.count||0); if(!Number.isFinite(total)||total<0)throw new Error("REMOTE_COUNT_INVALID");

    const last=Number(t.cursor?.last_oid||0),seen=Number(t.cursor?.keyset_rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||100),10),500);
    const where=`(${STATUS_WHERE}) AND ${oid}>${Math.trunc(last)}`;
    const outFields=[
      oid,"surfaceownershipid","casename","localcaseid","ownerclassification","status",
      "recordedacres","gis_acres","pilt_ind","actiondate","region","nfs_landunit_fk",
      "landstatuscaseid","fiscallandtype","nfslandunitname"
    ].join(",");
    const q=`${source}/query?where=${encodeURIComponent(where)}&${spatial}&outFields=${encodeURIComponent(outFields)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,70000); const fs=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;
    const rows=fs.map((f:any)=>{
      const p=f?.properties||{}; const id=Number(p?.[oid]??p?.objectid??p?.OBJECTID);
      if(Number.isFinite(id))maxOid=Math.max(maxOid,id);
      return {...p,
        surfaceownershipid:p?.surfaceownershipid??p?.SURFACEOWNERSHIPID??null,
        geometry_geojson:f?.geometry??null,
        _bridgepoint_fetch_source_url:source,
        _bridgepoint_source_record_id:Number.isFinite(id)?String(id):String(p?.[oid]??crypto.randomUUID())
      };
    });
    const nextSeen=seen+rows.length;
    const done=rows.length===0||nextSeen>=total||rows.length<page;
    const staged=await db.rpc("[REDACTED_LONG_LITERAL]",{
      p_source_task_id:t.source_task_id,p_records:rows,
      p_next_cursor:{pagination_mode:"OID_KEYSET_USFS_SURFACE_V5403",last_oid:maxOid,keyset_rows_seen:nextSeen,estimated_total_rows:total,state_code:state,source_used:source},
      p_done:done,
      p_result:{source:"USFS_SURFACE_OWNERSHIP",source_used:source,state_code:state,batch_size:rows.length,estimated_total_rows:total,last_oid:maxOid,worker_version:5404}
    });
    if(staged.error)throw staged.error;
    const mat=await db.schema("automation").rpc("materialize_usfs_surface_gap_v5403",{p_candidate_id:c.candidate_id,p_limit:Math.min(2000,Math.max(200,rows.length*2))});
    if(mat.error)throw mat.error;
    return new Response(JSON.stringify({complete:true,version:5404,state_code:state,candidate_id:c.candidate_id,source_used:source,total,remote_features:fs.length,last_oid:maxOid,keyset_rows_seen:nextSeen,done,staged:staged.data,materialized:mat.data}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5404,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});