import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE="https://services1.arcgis.com/fBc8EJBxQRMcHlei/arcgis/rest/services/NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer/1";
const CID="4ab7d7f4-cfc5-49b3-b497-8dd4a21bf478";
const WHERE="Interest='Federal Land (Fee)' AND ALPHA_TRACT IS NOT NULL AND ALPHA_TRACT<>''";
async function jf(url:string,ms=80000){
  const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text(); if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,300)}`);
  const j=JSON.parse(t); if(j?.error)throw new Error(`REMOTE_${j.error?.code??""}:${j.error?.message??""}`); return j;
}
Deno.serve(async(req:Request)=>{
  const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
  try{
    if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const pq=await db.schema("automation").from("nps_national_execution_v5452")
      .select("candidate_id,last_oid,rows_seen,estimated_total_rows,status,last_error").eq("candidate_id",CID).single();
    if(pq.error)throw pq.error; const p=pq.data;
    if(p.status==="DONE")return new Response(JSON.stringify({complete:true,done:true,progress:p}),{headers:H});

    const drain=await db.schema("automation").rpc("materialize_nps_fee_tracts_v5453",{p_candidate_id:CID,p_limit:1000});
    if(drain.error)throw drain.error;
    if(drain.data?.skipped==="LOCKED")return new Response(JSON.stringify({complete:true,version:5454,paused:"MATERIALIZER_LOCKED",materialized:drain.data}),{headers:H});
    if(Number(drain.data?.selected||0)>0)return new Response(JSON.stringify({complete:true,version:5454,drained:true,materialized:drain.data}),{headers:H});

    const meta=await jf(`${SOURCE}?f=json`,30000);
    if(String(meta.geometryType||"").toLowerCase()!=="esrigeometrypolygon")throw new Error("NPS_LAYER_NOT_POLYGON");
    const oid=String(meta.objectIdField||meta.objectIdFieldName||"OBJECTID");
    const countj=await jf(`${SOURCE}/query?where=${encodeURIComponent(WHERE)}&returnCountOnly=true&f=json`,45000);
    const total=Number(countj?.count||0);
    if(!Number.isFinite(total)||total<=0)throw new Error("NPS_FEE_COUNT_INVALID");

    const last=Number(p.last_oid||0),seen=Number(p.rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||1000),100),1500);
    const keyWhere=last>0?`(${WHERE}) AND ${oid}>${Math.trunc(last)}`:WHERE;
    const fields=[oid,"TRACT_ID","ALPHA","ALPHA_TRACT","STATENAME","DEED","ESTATE","STATUS","REGION","Interest","GlobalID","AreaID"].join(",");
    const q=`${SOURCE}/query?where=${encodeURIComponent(keyWhere)}&outFields=${encodeURIComponent(fields)}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,100000),fs=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;
    const rows=fs.map((f:any)=>{const props=f?.properties||{},id=Number(props?.[oid]??props?.OBJECTID??props?.objectid);if(Number.isFinite(id))maxOid=Math.max(maxOid,id);return {...props,geometry_geojson:f?.geometry??null,_bridgepoint_source_record_id:Number.isFinite(id)?String(id):String(props?.[oid]??crypto.randomUUID())};});
    const nextSeen=seen+rows.length,done=rows.length===0||nextSeen>=total||rows.length<page;

    const stage=await db.schema("automation").rpc("stage_nps_national_v5452",{p_records:rows});
    if(stage.error)throw stage.error;
    const up=await db.schema("automation").from("nps_national_execution_v5452").update({
      last_oid:maxOid,rows_seen:nextSeen,estimated_total_rows:total,status:done?"DONE":"QUEUED",last_error:null,updated_at:new Date().toISOString()
    }).eq("candidate_id",CID);
    if(up.error)throw up.error;

    const mat=await db.schema("automation").rpc("materialize_nps_fee_tracts_v5453",{p_candidate_id:CID,p_limit:Math.max(100,rows.length)});
    if(mat.error)throw mat.error;

    return new Response(JSON.stringify({complete:true,version:5454,total,remote_features:rows.length,last_oid:maxOid,rows_seen:nextSeen,done,staged:stage.data,materialized:mat.data}),{headers:H});
  }catch(e){
    await db.schema("automation").from("nps_national_execution_v5452").update({status:"ERROR",last_error:String((e as any)?.message||e),updated_at:new Date().toISOString()}).eq("candidate_id",CID).catch(()=>{});
    return new Response(JSON.stringify({complete:false,version:5454,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});