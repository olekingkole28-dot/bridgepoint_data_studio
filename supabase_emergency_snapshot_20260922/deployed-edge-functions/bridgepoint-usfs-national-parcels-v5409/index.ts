import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const SOURCE_ID="c14d692f-aa33-4223-8f5d-1e86777e02bc";
async function jf(url:string,ms=60000){
  const r=await fetch(url,{headers:{accept:"application/json,application/geo+json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text(); if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,350)}`);
  const j=JSON.parse(t); if(j?.error)throw new Error(`REMOTE_${j.error?.code??""}:${j.error?.message??""}`); return j;
}
function field(meta:any,names:string[]){
  const m=new Map((meta?.fields||[]).map((f:any)=>[String(f?.name||"").toLowerCase(),String(f?.name||"")]));
  for(const n of names){const hit=m.get(n.toLowerCase());if(hit)return hit} return "";
}
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const {data:src,error:se}=await db.schema("automation").from("source_registry")
      .select("source_id,source_code,source_name,source_url,enabled,metadata").eq("source_id",SOURCE_ID).maybeSingle();
    if(se||!src?.enabled)throw se||new Error("USFS_SOURCE_DISABLED_OR_MISSING");
    const {data:comp,error:ce}=await db.schema("automation").from("national_parcel_source_compliance_v5407")
      .select("*").eq("source_id",SOURCE_ID).maybeSingle();
    if(ce||comp?.activation_status!=="APPROVED"||comp?.rights_status!=="PASS"||comp?.authority_status!=="PASS"||comp?.provenance_status!=="PASS"||!["PASS","NOT_APPLICABLE"].includes(comp?.privacy_status)||comp?.local_law_status!=="PASS")throw ce||new Error("USFS_COMPLIANCE_GATE_FAILED");
    const {data:st,error:ste}=await db.schema("automation").from("national_parcel_acquisition_state_v5409")
      .select("*").eq("source_id",SOURCE_ID).maybeSingle();
    if(ste||!st)throw ste||new Error("USFS_STATE_MISSING");
    if(st.status==="COMPLETE")return new Response(JSON.stringify({complete:true,version:5409,done:true,state:st}),{headers:H});

    // Drain previously staged rows first. Do not run acquisition ahead of canonicalization.
    const drain=await db.schema("automation").rpc("[REDACTED_LONG_LITERAL]",{p_source_id:SOURCE_ID,p_limit:100});
    if(drain.error)throw drain.error;
    if(drain.data?.skipped==="LOCKED")return new Response(JSON.stringify({complete:true,version:5409,paused:"MATERIALIZER_LOCKED",materialized:drain.data}),{headers:H});
    if(Number(drain.data?.selected||0)>0)return new Response(JSON.stringify({complete:true,version:5409,drained:true,materialized:drain.data}),{headers:H});

    const base=String(src.source_url).replace(/\/$/,"");
    const meta=await jf(`${base}?f=json`,30000);
    const oid=String(meta.objectIdField||meta.objectIdFieldName||meta.fields?.find((x:any)=>String(x?.type||"").toLowerCase()==="esrifieldtypeoid")?.name||"").trim();
    const identity=field(meta,["SURFACEOWNERSHIPID","SurfaceOwnershipID","surfaceownershipid"]);
    if(!oid)throw new Error("USFS_OBJECT_ID_FIELD_MISSING");
    if(!identity)throw new Error("USFS_SURFACEOWNERSHIPID_MISSING");
    if(!/polygon/i.test(String(meta.geometryType||"")))throw new Error("USFS_POLYGON_GEOMETRY_REQUIRED");

    const countj=await jf(`${base}/query?where=1%3D1&returnCountOnly=true&f=json`,30000);
    const total=Number(countj?.count||0); if(!Number.isFinite(total)||total<=0)throw new Error("USFS_REMOTE_COUNT_INVALID");

    const safeCandidates=[
      ["casename","CASE_NAME","CaseName"],
      ["localcaseid","LOCALCASEID","LocalCaseID"],
      ["ownerclassification","OWNERCLASSIFICATION","OwnerClassification"],
      ["statusmethod","STATUSMETHOD","StatusMethod"],
      ["status","STATUS","Status"],
      ["recordedacres","RECORDEDACRES","RecordedAcres"],
      ["gis_acres","GIS_ACRES","GISAcres"],
      ["actiondate","ACTIONDATE","ActionDate"],
      ["region","REGION","Region"],
      ["landstatuscaseid","LANDSTATUSCASEID","LandStatusCaseID"],
      ["nfslandunitname","NFSLANDUNITNAME","NFSLandUnitName"]
    ];
    const safe=[oid,identity];
    for(const choices of safeCandidates){const f=field(meta,choices);if(f&&!safe.includes(f))safe.push(f)}
    const last=Number(st.last_oid||0),seen=Number(st.rows_seen||0);
    const page=Math.min(Math.max(Number(b.page||50),10),100);
    const where=last>0?`${oid}>${Math.trunc(last)}`:"1=1";
    const q=`${base}/query?where=${encodeURIComponent(where)}&outFields=${encodeURIComponent(safe.join(","))}&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid+" ASC")}&resultRecordCount=${page}&f=geojson`;
    const gj=await jf(q,75000),features=Array.isArray(gj?.features)?gj.features:[];
    let maxOid=last;
    const records=features.flatMap((f:any)=>{
      const p=f?.properties||{};
      const id=Number(p?.[oid]);
      const aid=p?.[identity]==null?"":String(p[identity]).trim();
      if(Number.isFinite(id))maxOid=Math.max(maxOid,id);
      if(!Number.isFinite(id)||!aid||!f?.geometry)return [];
      const payload:any={};
      for(const k of safe)if(k!==oid&&k!==identity&&p[k]!=null)payload[String(k).toLowerCase()]=p[k];
      return [{source_record_id:String(id),authoritative_id:aid,geometry:f.geometry,payload}];
    });
    const staged=await db.schema("automation").rpc("[REDACTED_LONG_LITERAL]",{p_source_id:SOURCE_ID,p_records:records});
    if(staged.error)throw staged.error;
    const nextSeen=seen+features.length;
    const done=features.length===0||nextSeen>=total||features.length<page;
    const statePatch={last_oid:maxOid,rows_seen:nextSeen,remote_count:total,object_id_field:oid,identity_field:identity,status:done?"COMPLETE":"READY",last_error:null,last_success_at:new Date().toISOString(),updated_at:new Date().toISOString(),metadata:{...(st.metadata||{}),last_page:page,last_remote_features:features.length,last_staged:Number(staged.data?.routed_staged||0),worker_version:5409}};
    const up=await db.schema("automation").from("national_parcel_acquisition_state_v5409").update(statePatch).eq("source_id",SOURCE_ID);
    if(up.error)throw up.error;
    const reg=await db.schema("automation").from("source_registry").update({
      last_checked_at:new Date().toISOString(),health_status:"HEALTHY",last_run_records_found:features.length,
      total_records_ingested:Math.max(Number(src?.total_records_ingested||0),nextSeen),last_error:null,consecutive_failures:0,updated_at:new Date().toISOString()
    }).eq("source_id",SOURCE_ID);
    if(reg.error)throw reg.error;

    const mat=await db.schema("automation").rpc("[REDACTED_LONG_LITERAL]",{p_source_id:SOURCE_ID,p_limit:Math.max(25,records.length)});
    if(mat.error)throw mat.error;
    return new Response(JSON.stringify({complete:true,version:5409,source_id:SOURCE_ID,remote_count:total,object_id_field:oid,identity_field:identity,remote_features:features.length,staged:staged.data,materialized:mat.data,last_oid:maxOid,rows_seen:nextSeen,done}),{headers:H});
  }catch(e){
    const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    try{
      await db.schema("automation").from("national_parcel_acquisition_state_v5409").update({status:"RETRY",last_error:String((e as any)?.message||e).slice(0,1000),updated_at:new Date().toISOString()}).eq("source_id",SOURCE_ID);
      await db.schema("automation").from("source_registry").update({health_status:"DEGRADED",last_error:String((e as any)?.message||e).slice(0,1000),updated_at:new Date().toISOString()}).eq("source_id",SOURCE_ID);
    }catch(_){}
    return new Response(JSON.stringify({complete:false,version:5409,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});