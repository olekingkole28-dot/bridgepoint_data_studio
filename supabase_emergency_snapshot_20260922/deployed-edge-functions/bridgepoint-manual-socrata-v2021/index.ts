import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function rpc(name:string, body:any){
  const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{
    method:"POST",
    headers:{"Content-Type":"application/json","apikey":SERVICE_KEY,"Authorization":`Bearer ${SERVICE_KEY}`},
    body:JSON.stringify(body??{})
  });
  const text=await r.text();
  if(!r.ok) throw new Error(`${name} ${r.status}: ${text.slice(0,1000)}`);
  return text?JSON.parse(text):null;
}

function n(v:any){ const s=v==null?"":String(v).trim(); return s||null; }
function num(v:any){ const x=Number(v); return Number.isFinite(x)?x:null; }

function normalize(source:string, r:any){
  if(source==="TCEQ_TX_NOV_V2021") return {
    id:n(r.violation_id) ?? n(r.investigation_no),
    state:"TX", address:n(r.phys_loc), city:n(r.phys_city), county:n(r.county), postal_code:n(r.phys_zip),
    date_received:n(r.invest_approved_dt) ?? n(r.violation_status_date),
    regulated_entity_number:n(r.rn_number), regulated_entity_name:n(r.rn_name), investigation_number:n(r.investigation_no),
    violation_count:num(r.viol_cnt), violation_status_date:n(r.violation_status_date), region:n(r.region),
    category_a_tracking:n(r.a_viol_track_num), category_a_citations:n(r.a_viol_citations),
    category_b_tracking:n(r.b_viol_track_num), category_b_citations:n(r.b_viol_citations),
    category_c_tracking:n(r.c_viol_track_num), category_c_citations:n(r.c_viol_citations),
    source_dataset_id:"mwzi-gyw7", source_url:"https://data.texas.gov/d/mwzi-gyw7"
  };
  if(source==="TCEQ_TX_NOE_V2021") return {
    id:n(r.noe_id) ?? n(r.invstn_no),
    state:"TX", address:n(r.phys_loc_desc_txt), city:n(r.near_city_name), county:n(r.loc_cnty_name), postal_code:n(r.loc_zip_txt),
    latitude:num(r.lat_dec_coord_num), longitude:num(r.long_dec_coord_num), date_received:n(r.noe_dt),
    regulated_entity_number:n(r.rn), regulated_entity_name:n(r.reg_ent_name), regulated_entity_description:n(r.reg_ent_desc_txt),
    investigation_number:n(r.invstn_no), enforcement_docket:n(r.tnrcc_dkt_num_txt), violation_count:num(r.viol_cnt), region:n(r.region),
    category_a_tracking:n(r.a_viol_track_num), category_a_citations:n(r.a_viol_citations),
    category_b_tracking:n(r.b_viol_track_num), category_b_citations:n(r.b_viol_citations),
    category_c_tracking:n(r.c_viol_track_num), category_c_citations:n(r.c_viol_citations),
    source_dataset_id:"rua3-iswk", source_url:"https://data.texas.gov/d/rua3-iswk"
  };
  if(source==="TCEQ_TX_SPILLS_V2021") return {
    id:n(r.incid_track_num), state:"TX", city:n(r.near_city_name), county:n(r.loc_cnty_name), postal_code:n(r.loc_zip_txt),
    date_received:n(r.rcvd_dt), incident_nature:n(r.incident_nature), media:n(r.media_name), status:n(r.status_cd), status_date:n(r.status_dt),
    regulated_entity_number:n(r.rn), regulated_entity_name:n(r.reg_ent_name), description:n(r.description), region:n(r.tnrcc_region_name),
    source_dataset_id:"xagr-a3x2", source_url:"https://data.texas.gov/d/xagr-a3x2"
  };
  if(source==="TCEQ_TX_COMPLAINTS_V2021") return {
    id:n(r.incid_track_num), state:"TX", date_received:n(r.incid_rcvd_dt), status:n(r.inc_status), status_date:n(r.incid_status_dt),
    investigation_status:n(r.invest_status), media:n(r.media_cd), program:n(r.pgm_name), level:n(r.lvl_num), complainant_count:num(r.num_complaining_num),
    incident_description:n(r.incid_desc), description:n(r.desc_txt), source_dataset_id:"tdzs-qqjn", source_url:"https://data.texas.gov/d/tdzs-qqjn"
  };
  return null;
}

Deno.serve(async (_req:Request)=>{
  const started=Date.now();
  let sourceCode:string|null=null;
  try{
    const claim=await rpc("bridgepoint_claim_manual_socrata_v2021",{});
    if(!claim?.claimed) return new Response(JSON.stringify({...claim,version:2021}),{headers:{"content-type":"application/json"}});
    sourceCode=claim.source_code;
    let offset=Number(claim.cursor_offset||0), totalSeen=0,totalInserted=0,pages=0,hasMore=true;
    const pageSize=Math.min(5000,Math.max(100,Number(claim.page_size||5000)));
    const maxPages=Math.min(4,Math.max(1,Number(claim.max_pages||4)));
    for(let i=0;i<maxPages;i++){
      const url=`https://data.texas.gov/resource/${encodeURIComponent(claim.dataset_id)}.json?$limit=${pageSize}&$offset=${offset}`;
      const rr=await fetch(url,{headers:{"Accept":"application/json","User-Agent":"BridgePoint-Intelligence/2021"}});
      const txt=await rr.text();
      if(!rr.ok) throw new Error(`Socrata ${claim.dataset_id} ${rr.status}: ${txt.slice(0,1000)}`);
      const raw=JSON.parse(txt);
      if(!Array.isArray(raw)) throw new Error("Socrata response was not an array");
      const rows=raw.map((x:any)=>normalize(sourceCode!,x)).filter((x:any)=>x&&x.id);
      const nextOffset=offset+raw.length;
      hasMore=raw.length===pageSize;
      const ing=await rpc("ingest_public_lifecycle_context_v1100",{p_source_code:sourceCode,p_rows:rows,p_next_offset:hasMore?nextOffset:0,p_has_more:hasMore});
      totalSeen+=raw.length; totalInserted+=Number(ing?.inserted||0); pages++; offset=nextOffset;
      if(!hasMore||raw.length===0) break;
    }
    return new Response(JSON.stringify({complete:true,source_code:sourceCode,pages,records_seen:totalSeen,records_inserted:totalInserted,next_offset:hasMore?offset:0,has_more:hasMore,elapsed_ms:Date.now()-started,version:2021}),{headers:{"content-type":"application/json"}});
  }catch(e){
    if(sourceCode){ try{ await rpc("bridgepoint_fail_manual_socrata_v2021",{p_source_code:sourceCode,p_error:String(e)}); }catch{} }
    return new Response(JSON.stringify({complete:false,source_code:sourceCode,error:String(e),elapsed_ms:Date.now()-started,version:2021}),{status:500,headers:{"content-type":"application/json"}});
  }
});
