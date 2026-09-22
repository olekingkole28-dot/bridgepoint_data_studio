import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NAD = "https://services.arcgis.com/xOi1kZaI0eWDREZv/ArcGIS/rest/services/Address_Points_from_National_Address_Database_view/FeatureServer/0";
const H = {"content-type":"application/json","cache-control":"no-store"};
const V = 1840;
const FIELDS = ["OBJECTID","AddNo_Full","StNam_Full","Building","Floor","Unit","Room","SubAddress","DeliverTyp","County","Inc_Muni","Post_City","State","Zip_Code","Longitude","Latitude","Parcel_ID","Placement","AddrClass","Lifecycle","DateUpdate","NAD_Source"];

async function fetchJson(url:string, timeoutMs=80000){
  const r = await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(timeoutMs)});
  const t = await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${t.slice(0,400)}`);
  let j:any; try{ j=JSON.parse(t); }catch{ throw new Error(`JSON_PARSE:${t.slice(0,400)}`); }
  if(j?.error) throw new Error(`ARCGIS_${j.error.code||"ERR"}:${j.error.message||"unknown"}:${j.error.details?.join(";")||""}`);
  return j;
}

async function processShard(s:any, target:any, page:number){
  const shardId=Number(target.shard_id);
  const start=Number(target.start_oid||0);
  const end=Number(target.end_oid||0);
  const last=Math.max(Number(target.last_oid||start)||start,start);
  try{
    const where=`OBJECTID>${Math.trunc(last)} AND OBJECTID<=${Math.trunc(end)}`;
    const qs=new URLSearchParams({where,outFields:FIELDS.join(","),returnGeometry:"false",orderByFields:"OBJECTID ASC",resultRecordCount:String(page),f:"json"});
    const j=await fetchJson(`${NAD}/query?${qs.toString()}`,80000);
    const attrs=(Array.isArray(j?.features)?j.features:[]).map((f:any)=>f?.attributes||{}).filter((x:any)=>x && x.OBJECTID!=null);
    const maxOid=attrs.reduce((m:number,x:any)=>Math.max(m,Number(x.OBJECTID)||0),last);
    const apply=await s.rpc("[REDACTED_LONG_LITERAL]",{p_rows:attrs});
    if(apply.error) throw apply.error;
    const a=apply.data||{};
    const hasMore=attrs.length>0 && maxOid<end && (j?.exceededTransferLimit===true || attrs.length>=page);
    const finish=await s.rpc("finish_nad_global_shard_v1839",{
      p_shard_id:shardId,p_last_oid:attrs.length?maxOid:end,p_seen:Number(a.seen||attrs.length),p_valid:Number(a.valid_source_rows||0),p_unique:Number(a.unique_identities||0),p_new:Number(a.address_rows_new||0),p_reused:Number(a.reused_existing_addresses||0),p_exact:Number(a.exact_matches||0),p_relations:Number(a.property_address_relations||0),p_subaddress:Number(a.subaddress_identities||0),p_primary:Number(a.primary_addresses_applied||0),p_has_more:hasMore,p_error:null
    });
    if(finish.error) throw finish.error;
    return {shard_id:shardId,source_rows:attrs.length,last_oid:maxOid,has_more:hasMore,...a};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,1000);
    await s.rpc("finish_nad_global_shard_v1839",{p_shard_id:shardId,p_last_oid:last,p_seen:0,p_valid:0,p_unique:0,p_new:0,p_reused:0,p_exact:0,p_relations:0,p_subaddress:0,p_primary:0,p_has_more:true,p_error:msg});
    return {shard_id:shardId,error:msg};
  }
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error || auth.data!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
    const shardLimit=Math.min(Math.max(Number(b.shard_limit||4),1),8);
    const page=Math.min(Math.max(Number(b.page||750),100),1500);
    const claim=await s.rpc("claim_nad_global_shards_v1838",{p_limit:shardLimit});
    if(claim.error) throw claim.error;
    const targets=Array.isArray(claim.data?.shards)?claim.data.shards:[];
    if(!targets.length) return new Response(JSON.stringify({complete:true,version:V,claimed:0,results:[]}),{headers:H});
    const results=await Promise.all(targets.map((t:any)=>processShard(s,t,page)));
    return new Response(JSON.stringify({
      complete:true,version:V,claimed:targets.length,page,
      seen:results.reduce((n:number,x:any)=>n+Number(x.seen||0),0),
      valid_source_rows:results.reduce((n:number,x:any)=>n+Number(x.valid_source_rows||0),0),
      unique_identities:results.reduce((n:number,x:any)=>n+Number(x.unique_identities||0),0),
      address_rows_new:results.reduce((n:number,x:any)=>n+Number(x.address_rows_new||0),0),
      reused_existing_addresses:results.reduce((n:number,x:any)=>n+Number(x.reused_existing_addresses||0),0),
      exact_matches:results.reduce((n:number,x:any)=>n+Number(x.exact_matches||0),0),
      property_address_relations:results.reduce((n:number,x:any)=>n+Number(x.property_address_relations||0),0),
      subaddress_identities:results.reduce((n:number,x:any)=>n+Number(x.subaddress_identities||0),0),
      primary_addresses_applied:results.reduce((n:number,x:any)=>n+Number(x.primary_addresses_applied||0),0),
      results
    }),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});
