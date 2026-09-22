import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HEADERS = {"content-type":"application/json","cache-control":"no-store"};
const VERSION = 2664;

function n(v:any, d:number){ const x=Number(v); return Number.isFinite(x)?x:d; }
function slimProps(p:any){
  if(!p || typeof p!=="object") return {};
  const out:any={};
  for(const k of ["OBJECTID","OID","NAME","BASENAME","MTFCC","RTTYP","FULLNAME","AREALAND","AREAWATER","FUNCSTAT","LSADC"]) if(p[k]!==undefined&&p[k]!==null) out[k]=p[k];
  return out;
}
async function fetchJson(url:string, ms=50000){
  const r=await fetch(url,{headers:{accept:"application/geo+json,application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const text=await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${text.slice(0,260)}`);
  let j:any; try{j=JSON.parse(text)}catch{throw new Error(`JSON_PARSE:${text.slice(0,260)}`)}
  if(j?.error) throw new Error(`ARCGIS_${j.error?.code??""}:${j.error?.message??"unknown"}`);
  return j;
}
async function runTile(s:any, token:string, tile:any){
  const srcResp=await s.rpc("bridgepoint_world_source_v2601",{p_task_token:token,p_source_key:tile.source_key});
  if(srcResp.error) throw srcResp.error;
  const src=srcResp.data;
  const page=Math.min(Math.max(n(tile.page_size,1000),250),2000);
  const offset=Math.max(0,n(tile.result_offset,0));
  const geom={xmin:n(tile.west,0),ymin:n(tile.south,0),xmax:n(tile.east,0),ymax:n(tile.north,0),spatialReference:{wkid:4326}};
  const q=new URL(`${src.service_url}/${src.layer_id}/query`);
  q.searchParams.set("where","1=1");
  q.searchParams.set("geometry",JSON.stringify(geom));
  q.searchParams.set("geometryType","esriGeometryEnvelope");
  q.searchParams.set("inSR","4326");
  q.searchParams.set("spatialRel","esriSpatialRelIntersects");
  q.searchParams.set("outFields","*");
  q.searchParams.set("returnGeometry","true");
  q.searchParams.set("returnZ","false");
  q.searchParams.set("returnM","false");
  q.searchParams.set("outSR","4326");
  q.searchParams.set("resultOffset",String(offset));
  q.searchParams.set("resultRecordCount",String(page));
  q.searchParams.set("f","geojson");
  const g=await fetchJson(q.toString());
  const features=Array.isArray(g?.features)?g.features:[];
  const rows=features.map((f:any)=>({
    source_feature_id:String(f?.properties?.OBJECTID ?? f?.properties?.OID ?? f?.id ?? ""),
    properties:slimProps(f?.properties),
    geometry:f?.geometry
  })).filter((x:any)=>x.source_feature_id && x.geometry);
  const exceeded=Boolean(g?.exceededTransferLimit);
  const next=offset+features.length;
  const done=features.length===0 || (!exceeded && features.length<page);
  const pr=await s.rpc("bridgepoint_world_persist_tile_v2600",{
    p_task_token:token,p_source_key:tile.source_key,p_state_code:tile.state_code,p_cell_id:tile.cell_id,p_lease_token:tile.lease_token,
    p_rows:rows,p_next_offset:next,p_done:done
  });
  if(pr.error) throw pr.error;
  return {source_key:tile.source_key,state_code:tile.state_code,cell_id:tile.cell_id,offset,features:features.length,persisted:Number(pr.data?.persisted||0),done,next_offset:next};
}
async function failTile(s:any,token:string,tile:any,e:any){
  try{await s.rpc("bridgepoint_world_fail_tile_v2600",{p_task_token:token,p_source_key:tile.source_key,p_state_code:tile.state_code,p_cell_id:tile.cell_id,p_lease_token:tile.lease_token,p_error:String(e?.message||e).slice(0,1000)});}catch(_){ }
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:HEADERS});
    const body=await req.json().catch(()=>({}));
    const token=String(body?.task_token||"");
    const s=createClient(SUPABASE_URL,SERVICE_ROLE,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:token});
    if(auth.error||auth.data!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:HEADERS});
    const limit=Math.min(Math.max(n(body?.tile_limit,6),1),12);
    const claim=await s.rpc("bridgepoint_world_claim_tiles_v2600",{p_task_token:token,p_limit:limit});
    if(claim.error) throw claim.error;
    if(claim.data?.skipped) return new Response(JSON.stringify({complete:true,version:VERSION,claim:claim.data,results:[]}),{headers:HEADERS});
    const tiles=Array.isArray(claim.data?.tiles)?claim.data.tiles:[];
    const results:any[]=[];
    for(let i=0;i<tiles.length;i+=3){
      const batch=tiles.slice(i,i+3);
      const settled=await Promise.allSettled(batch.map((t:any)=>runTile(s,token,t)));
      for(let j=0;j<settled.length;j++){
        const r=settled[j], tile=batch[j];
        if(r.status==="fulfilled") results.push(r.value);
        else { await failTile(s,token,tile,r.reason); results.push({source_key:tile.source_key,state_code:tile.state_code,cell_id:tile.cell_id,error:String(r.reason?.message||r.reason).slice(0,600)}); }
      }
    }
    return new Response(JSON.stringify({complete:true,version:VERSION,claimed:tiles.length,persisted:results.reduce((a,x)=>a+Number(x.persisted||0),0),parallelism:3,results}),{headers:HEADERS});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e)}),{status:500,headers:HEADERS});
  }
});