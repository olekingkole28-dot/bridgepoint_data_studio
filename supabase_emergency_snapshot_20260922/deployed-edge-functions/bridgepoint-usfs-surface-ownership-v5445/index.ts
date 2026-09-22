import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE="https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_SurfaceOwnership_01/MapServer/0";
const CID="36d68f54-c0b0-8cab-4c23-3801ce2d7e2f";
const ACQUIRE_TASK="80652547-b6f2-40c6-a80e-dddd0721b8a2";
const WHERE="status IN ('Acquired','Reserved Public Domain','Unpartitioned Riparian Interest')";

async function jf(url:string,ms=70000){
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

    const tq=await db.schema("automation").from("geographic_source_tasks_v90")
      .select("source_task_id,task_status,cursor,result").eq("source_task_id",ACQUIRE_TASK).limit(1);
    if(tq.error) throw tq.error;
    const t=tq.data?.[0];
    if(!t) throw new Error("USFS_ACQUIRE_TASK_NOT_FOUND");
    if(t.task_status==="SUCCEEDED") return new Response(JSON.stringify({complete:true,done:true,task:t}),{headers:H});

    const drain=await db.schema("automation").rpc("[REDACTED_LONG_LITERAL]",{p_candidate_id:CID,p_limit:1000});
    if(drain.error) throw drain.error;
    const dr=drain.data||{};
    if(dr.skipped==="LOCKED") return new Response(JSON.stringify({complete:true,version:5445,paused:"MATERIALIZER_LOCKED",materialized:dr}),{headers:H});
    if(Number(dr.selected||0)>0) return new Response(JSON.stringify({complete:true,version:5445,drained:true,materialized:dr}),{headers:H});

    const meta=await jf(`${SOURCE}?f=json`,30000);
    const oid=String(meta.objectIdField||meta.objectIdFieldName||meta.fields?.find((x:any)=>String(x?.type||"").toLowerCase()==="esrifieldtypeoid")?.name||"objectid");
    if(String(meta.geometryType||"").toLowerCase()!=="esrigeometrypolygon") throw new Error("USFS_LAYER_NOT_POLYGON");
    const countj=await jf(`${SOURCE}/query?where=${encodeURIComponent(WHERE)}&returnCountOnly=true&f=json`,45000);
    const total=Number(countj?.count||0);
    if(!Number.isFinite(total)||total<=0) throw new Error("USFS_REMOTE_COUNT_INVALID");

    await db.schema("automation").from("geographic_source_tasks_v90")
      .update({
        task_status:"SUCCEEDED",
        result:{verified_live:true,worker_version:5445,geometry_type:meta.geometryType,object_id_field:oid,max_record_count:meta.maxRecordCount||2000,total_records:total,status_filter:WHERE,verified_at:new Date().toISOString()},
        updated_at:new Date().toISOString()
      })
      .eq("candidate_id",CID).in("task_type",["INSPECT_SCHEMA","CONFIGURE_REFRESH"]).neq("task_status","SUCCEEDED");

    const last=Number(t.cursor?.last_oid||0),seen=Number(t.cursor?.keyset_rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||1000),100),1500);
    const keyWhere=last>0?`(${WHERE}) AND ${oid}>${Math.trunc(last)}`:WHERE;
    const outFields=[oid,"surfaceownershipid","casename","localcaseid","ownerclassification","statusmethod","status","recordedacres","gis_acres","pilt_ind","actiondate","region","nfs_landunit_fk","landstatuscaseid","fiscallandtype","nfslandunitname"].join(",");
    const q=`${SOURCE}/query?where=${encodeURIComponent(keyWhere)}&outFields=${encodeURIComponent(outFields)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,100000);
    const fs=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;
    const rows=fs.map((f:any)=>{
      const p=f?.properties||{};
      const id=Number(p?.[oid]??p?.objectid??p?.OBJECTID);
      if(Number.isFinite(id)) maxOid=Math.max(maxOid,id);
      return {...p,
        geometry_geojson:f?.geometry??null,
        _bridgepoint_source_record_id:Number.isFinite(id)?String(id):String(p?.[oid]??crypto.randomUUID())
      };
    });
    const nextSeen=seen+rows.length;
    const done=rows.length===0||nextSeen>=total||rows.length<page;
    const staged=await db.rpc("[REDACTED_LONG_LITERAL]",{
      p_source_task_id:ACQUIRE_TASK,
      p_records:rows,
      p_next_cursor:{pagination_mode:"OID_KEYSET_USFS_SURFACE_V5445",last_oid:maxOid,keyset_rows_seen:nextSeen,estimated_total_rows:total},
      p_done:done,
      p_result:{source:"USFS_SURFACE_OWNERSHIP",batch_size:rows.length,estimated_total_rows:total,last_oid:maxOid,worker_version:5445,status_filter:WHERE,spatial_state_assignment:true}
    });
    if(staged.error) throw staged.error;

    const mat=await db.schema("automation").rpc("[REDACTED_LONG_LITERAL]",{p_candidate_id:CID,p_limit:Math.max(100,rows.length)});
    if(mat.error) throw mat.error;

    return new Response(JSON.stringify({complete:true,version:5445,candidate_id:CID,total,remote_features:fs.length,last_oid:maxOid,keyset_rows_seen:nextSeen,done,staged:staged.data,materialized:mat.data}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5445,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});