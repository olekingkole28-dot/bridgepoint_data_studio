import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL=Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
async function rpc(name:string,body:any){const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{method:"POST",headers:{"Content-Type":"application/json","apikey":SERVICE_KEY,"Authorization":`Bearer ${SERVICE_KEY}`},body:JSON.stringify(body??{})});const t=await r.text();if(!r.ok)throw new Error(`${name} ${r.status}: ${t.slice(0,1200)}`);return t?JSON.parse(t):null;}
const n=(v:any)=>{const s=v==null?"":String(v).trim();return s||null};
const num=(v:any)=>{const x=Number(v);return Number.isFinite(x)?x:null};
function normalize(a:any,sourceCode:string){
  return {
    id:n(a.pgm_sys_id)||n(a.registry_id)||n(a.site_id)||n(a.OBJECTID),
    state:n(a.state_code),
    address:n(a.location_address),
    city:n(a.city_name), county:n(a.county_name), postal_code:n(a.postal_code),
    latitude:num(a.latitude), longitude:num(a.longitude),
    facility_name:n(a.primary_name), registry_id:n(a.registry_id), program_system:n(a.pgm_sys_acrnm), program_system_id:n(a.pgm_sys_id),
    epa_region:n(a.epa_region), fips_code:n(a.fips_code), huc_code:n(a.huc_code), facility_url:n(a.facility_url), profile_url:n(a.profile_url),
    source_code:sourceCode, source_record_oid:num(a.OBJECTID), source_provider:"U.S. Environmental Protection Agency / Envirofacts"
  };
}
Deno.serve(async(_req:Request)=>{const started=Date.now();let sourceCode:string|null=null;try{
 const claim=await rpc("bridgepoint_claim_manual_arcgis_v2023",{}); if(!claim?.claimed)return new Response(JSON.stringify({...claim,version:2023}),{headers:{"content-type":"application/json"}});
 sourceCode=claim.source_code; let cursor=Number(claim.cursor_oid||0),seen=0,inserted=0,pages=0,hasMore=true;
 const pageSize=Math.min(10000,Math.max(100,Number(claim.page_size||5000))),maxPages=Math.min(4,Math.max(1,Number(claim.max_pages||4)));
 const oidField=String(claim.oid_field||"OBJECTID");
 for(let i=0;i<maxPages;i++){
  const q=new URL(`${claim.layer_url}/query`);q.searchParams.set("where",`${oidField} > ${Math.max(0,Math.floor(cursor))}`);q.searchParams.set("outFields","*");q.searchParams.set("returnGeometry","false");q.searchParams.set("orderByFields",`${oidField} ASC`);q.searchParams.set("resultRecordCount",String(pageSize));q.searchParams.set("f","json");
  const rr=await fetch(q.toString(),{headers:{"Accept":"application/json","User-Agent":"BridgePoint-Intelligence/2023"}});const txt=await rr.text();if(!rr.ok)throw new Error(`ArcGIS ${rr.status}: ${txt.slice(0,1000)}`);const js=JSON.parse(txt);if(js?.error)throw new Error(`ArcGIS error: ${JSON.stringify(js.error).slice(0,1000)}`);
  const feats=Array.isArray(js.features)?js.features:[];const attrs=feats.map((f:any)=>f?.attributes??{});const rows=attrs.map((a:any)=>normalize(a,sourceCode!)).filter((x:any)=>x.id&&x.state);
  const maxOid=attrs.reduce((m:number,a:any)=>Math.max(m,Number(a?.[oidField])||0),cursor);hasMore=feats.length===pageSize||Boolean(js.exceededTransferLimit);
  const ing=await rpc("ingest_public_lifecycle_context_v1100",{p_source_code:sourceCode,p_rows:rows,p_next_offset:maxOid,p_has_more:hasMore});
  seen+=feats.length;inserted+=Number(ing?.inserted||0);pages++;cursor=maxOid;
  if(!hasMore||feats.length===0)break;
 }
 await rpc("bridgepoint_complete_manual_arcgis_v2023",{p_source_code:sourceCode,p_cursor_oid:cursor,p_has_more:hasMore});
 return new Response(JSON.stringify({complete:true,source_code:sourceCode,pages,records_seen:seen,records_inserted:inserted,cursor_oid:cursor,has_more:hasMore,elapsed_ms:Date.now()-started,version:2023}),{headers:{"content-type":"application/json"}});
}catch(e){if(sourceCode){try{await rpc("bridgepoint_fail_manual_arcgis_v2023",{p_source_code:sourceCode,p_error:String(e)})}catch{}}return new Response(JSON.stringify({complete:false,source_code:sourceCode,error:String(e),elapsed_ms:Date.now()-started,version:2023}),{status:500,headers:{"content-type":"application/json"}})}});
