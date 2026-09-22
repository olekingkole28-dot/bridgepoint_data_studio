import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE="https://services3.arcgis.com/Jdnp1TjADvSDxMAX/ArcGIS/rest/services/DNRLOTSParcelsOPENDATA/FeatureServer/0";
async function jf(url:string,ms=50000){
  const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text(); if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,300)}`);
  const j=JSON.parse(t); if(j?.error)throw new Error(`REMOTE_${j.error?.code??""}:${j.error?.message??""}`); return j;
}
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const cq=await db.schema("automation").from("geographic_source_candidates_v86")
      .select("candidate_id,run_id,state_code,source_url,decision_status")
      .eq("source_url",SOURCE).eq("state_code","MI").eq("decision_status","ACCEPTED").limit(1);
    if(cq.error)throw cq.error; const c=cq.data?.[0]; if(!c)throw new Error("MI_DNR_LOTS_CANDIDATE_NOT_FOUND");

    const tq=await db.schema("automation").from("geographic_source_tasks_v90")
      .select("source_task_id,task_status,cursor,result")
      .eq("candidate_id",c.candidate_id).eq("task_type","ACQUIRE_PROPERTY_FOUNDATION").limit(1);
    if(tq.error)throw tq.error; const t=tq.data?.[0]; if(!t)throw new Error("MI_DNR_LOTS_TASK_NOT_FOUND");
    if(t.task_status==="SUCCEEDED")return new Response(JSON.stringify({complete:true,done:true,candidate_id:c.candidate_id,task:t}),{headers:H});

    // Drain any staged backlog before fetching another remote page. If another
    // materializer holds the lane lock, do not advance the acquisition cursor.
    const drain=await db.schema("automation").rpc("materialize_mi_dnr_lots_v5400",{p_candidate_id:c.candidate_id,p_limit:500});
    if(drain.error)throw drain.error;
    const dr=drain.data||{};
    if(dr.skipped==="LOCKED"){
      return new Response(JSON.stringify({complete:true,version:5406,candidate_id:c.candidate_id,paused:"MATERIALIZER_LOCKED",materialized:dr}),{headers:H});
    }
    if(Number(dr.selected||0)>0){
      return new Response(JSON.stringify({complete:true,version:5406,candidate_id:c.candidate_id,drained:true,materialized:dr}),{headers:H});
    }

    const meta=await jf(`${SOURCE}?f=json`,25000);
    const oid=String(meta.objectIdField||meta.objectIdFieldName||meta.fields?.find((x:any)=>String(x?.type||"").toLowerCase()==="esrifieldtypeoid")?.name||"ObjectID");
    const countj=await jf(`${SOURCE}/query?where=1%3D1&returnCountOnly=true&f=json`,30000);
    const total=Number(countj?.count||0); if(!Number.isFinite(total)||total<=0)throw new Error("REMOTE_COUNT_INVALID");

    const last=Number(t.cursor?.last_oid||0),seen=Number(t.cursor?.keyset_rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||250),25),500);
    const where=last>0?`${oid}>${Math.trunc(last)}`:"1=1";
    const outFields=[oid,"ParID","County","LegalDescription","ParcelTypeCode","ParcelType","ParcelStatus","Acreage","Flag"].join(",");
    const q=`${SOURCE}/query?where=${encodeURIComponent(where)}&outFields=${encodeURIComponent(outFields)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,60000); const fs=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;
    const rows=fs.map((f:any)=>{
      const p=f?.properties||{}; const id=Number(p?.[oid]??p?.ObjectID??p?.objectid);
      if(Number.isFinite(id))maxOid=Math.max(maxOid,id);
      return {...p,
        parcel_id:p?.ParID==null?null:String(p.ParID),
        county_name:p?.County??null,
        acreage:p?.Acreage??null,
        geometry_geojson:f?.geometry??null,
        _bridgepoint_source_record_id:Number.isFinite(id)?String(id):String(p?.[oid]??crypto.randomUUID())
      };
    });
    const nextSeen=seen+rows.length;
    const done=rows.length===0||nextSeen>=total||rows.length<page;
    const staged=await db.rpc("bridgepoint_expansion_worker_stage_records_v90",{
      p_source_task_id:t.source_task_id,p_records:rows,
      p_next_cursor:{pagination_mode:"OID_KEYSET_MI_DNR_LOTS_V5400",last_oid:maxOid,keyset_rows_seen:nextSeen,estimated_total_rows:total},
      p_done:done,
      p_result:{source:"MI_DNR_LOTS",batch_size:rows.length,estimated_total_rows:total,last_oid:maxOid,worker_version:5406}
    });
    if(staged.error)throw staged.error;

    const mat=await db.schema("automation").rpc("materialize_mi_dnr_lots_v5400",{p_candidate_id:c.candidate_id,p_limit:Math.max(100,rows.length)});
    if(mat.error)throw mat.error;
    return new Response(JSON.stringify({complete:true,version:5406,candidate_id:c.candidate_id,total,remote_features:fs.length,last_oid:maxOid,keyset_rows_seen:nextSeen,done,staged:staged.data,materialized:mat.data}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5406,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});