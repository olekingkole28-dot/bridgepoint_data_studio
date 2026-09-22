import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const VERSION=3132;
const H={"content-type":"application/json"};
const STATES:Record<string,string>={AL:"Alabama",AK:"Alaska",AZ:"Arizona",AR:"Arkansas",CA:"California",CO:"Colorado",CT:"Connecticut",DE:"Delaware",FL:"Florida",GA:"Georgia",HI:"Hawaii",ID:"Idaho",IL:"Illinois",IN:"Indiana",IA:"Iowa",KS:"Kansas",KY:"Kentucky",LA:"Louisiana",ME:"Maine",MD:"Maryland",MA:"Massachusetts",MI:"Michigan",MN:"Minnesota",MS:"Mississippi",MO:"Missouri",MT:"Montana",NE:"Nebraska",NV:"Nevada",NH:"New Hampshire",NJ:"New Jersey",NM:"New Mexico",NY:"New York",NC:"North Carolina",ND:"North Dakota",OH:"Ohio",OK:"Oklahoma",OR:"Oregon",PA:"Pennsylvania",RI:"Rhode Island",SC:"South Carolina",SD:"South Dakota",TN:"Tennessee",TX:"Texas",UT:"Utah",VT:"Vermont",VA:"Virginia",WA:"Washington",WV:"West Virginia",WI:"Wisconsin",WY:"Wyoming",DC:"District of Columbia",PR:"Puerto Rico",VI:"U.S. Virgin Islands",GU:"Guam",AS:"American Samoa",MP:"Northern Mariana Islands"};
const TERMS:Record<string,string>={
  BUILDING_PERMITS:"building permits permit",
  CODE_ENFORCEMENT:"code enforcement violations complaints",
  INSPECTIONS_OCCUPANCY:"building inspections certificate occupancy",
  CONTRACTOR_LICENSING:"contractor licenses licensing disciplinary",
  SALES_DEEDS_LIENS:"property deeds recorder liens sales",
  CLAIMS_REGULATORY_RECOVERY:"insurance complaints claims regulatory recovery",
  LIGHTNING_DETECTION:"lightning detection lightning strikes",
  GRID_OUTAGES:"power outages electric utility outages"
};
const CATEGORY:Record<string,string>={BUILDING_PERMITS:"PERMITS",CODE_ENFORCEMENT:"CODE_ENFORCEMENT",INSPECTIONS_OCCUPANCY:"INSPECTIONS_OCCUPANCY",CONTRACTOR_LICENSING:"CONTRACTOR_TRUST",SALES_DEEDS_LIENS:"REAL_ESTATE_SALES",CLAIMS_REGULATORY_RECOVERY:"INSURANCE_REGULATORY",LIGHTNING_DETECTION:"LIGHTNING_DETECTION",GRID_OUTAGES:"GRID_OUTAGES"};
const PRIVACY_REVIEW=new Set(["BUILDING_PERMITS","CODE_ENFORCEMENT","INSPECTIONS_OCCUPANCY","CONTRACTOR_LICENSING","SALES_DEEDS_LIENS","CLAIMS_REGULATORY_RECOVERY"]);
const LOW_PERSONAL=new Set(["LIGHTNING_DETECTION","GRID_OUTAGES"]);
function resp(x:any,s=200){return new Response(JSON.stringify(x),{status:s,headers:H})}
const lc=(v:any)=>String(v??"").toLowerCase();
function govHost(u:string){try{const h=new URL(u).hostname.toLowerCase();return h.endsWith(".gov")||h.endsWith(".mil")||h==="govinfo.gov"}catch{return false}}
function stateSpecific(blob:string,st:string){const name=lc(STATES[st]||st),s=lc(blob),code=st.toLowerCase();const territory=new Set(["AS","GU","MP","PR","VI"]).has(st);return s.includes(name)||s.includes(`state of ${name}`)||(!territory&&new RegExp(`\\b${code}\\b`).test(s))}
function explicitOpen(text:string){const s=lc(text);return (s.includes("public domain")||s.includes("cc0")||s.includes("creative commons zero")||s.includes("cc by")||s.includes("cc-by")||s.includes("creative commons attribution")||s.includes("u.s. government work")||s.includes("us government work"))&&!s.includes("noncommercial")&&!s.includes("cc-by-nc")&&!s.includes("no commercial")}
function familyRelevant(blob:string,fam:string){const s=lc(blob);const words=(TERMS[fam]||fam).toLowerCase().split(/\s+/).filter(x=>x.length>3);return words.some(w=>s.includes(w))}
async function jf(url:string,ms=14000){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePoint-Intelligence/2604"},signal:AbortSignal.timeout(ms)});if(!r.ok)throw new Error(`HTTP ${r.status}`);return await r.json()}
async function portalInfo(orgId:string){if(!orgId)return null;try{return await jf(`https://www.arcgis.com/sharing/rest/portals/${encodeURIComponent(orgId)}?f=json`,9000)}catch{return null}}
function arcResourceMode(u:string,type:string){if(/FeatureServer/i.test(u))return "ARCGIS_FEATURESERVER";if(/MapServer/i.test(u))return "ARCGIS_MAPSERVER";return type||"ARCGIS_SERVICE"}
async function arcCandidates(t:any){
  const st=String(t.state_code),name=STATES[st]||st,term=TERMS[t.family_key]||t.family_key;
  const queries=[`${name} ${term}`,`${st} ${term} government`,`${name} open data ${term}`];
  const seen=new Set<string>(),out:any[]=[];
  for(const q0 of queries){
    let js:any;try{js=await jf(`https://www.arcgis.com/sharing/rest/search?f=json&num=25&sortField=modified&sortOrder=desc&q=${encodeURIComponent(q0)}`,12000)}catch{continue}
    for(const raw of js?.results||[]){
      const id=String(raw?.id||""); if(!id||seen.has(id))continue;seen.add(id);
      if(!["Feature Service","Map Service"].includes(String(raw?.type||"")))continue;
      let item:any=raw; try{item={...raw,...await jf(`https://www.arcgis.com/sharing/rest/content/items/${id}?f=json`,9000)}}catch{}
      const url=String(item?.url||raw?.url||""); if(!url)continue;
      const blob=`${item?.title||""} ${item?.snippet||""} ${item?.description||""} ${(item?.tags||[]).join(" ")} ${item?.owner||""} ${url}`;
      if(!stateSpecific(blob,st)||!familyRelevant(blob,t.family_key))continue;
      const portal=await portalInfo(String(item?.orgId||raw?.orgId||""));
      const pblob=`${portal?.name||""} ${portal?.portalName||""} ${portal?.description||""} ${portal?.url||""} ${portal?.customBaseUrl||""}`;
      const official=govHost(url)||govHost(String(portal?.url||""))||govHost(String(item?.homepage||""))||(stateSpecific(pblob,st)&&/(government|county|city|state|territory|department|agency|authority|commission|office)/i.test(pblob));
      const lic=`${item?.licenseInfo||""} ${item?.accessInformation||""} ${item?.termsOfUse||""}`;
      const open=explicitOpen(lic);
      const privacy=PRIVACY_REVIEW.has(t.family_key);
      const auto=official&&open&&LOW_PERSONAL.has(t.family_key)&&govHost(url);
      out.push({state_code:st,family_key:t.family_key,lifecycle_stage:t.lifecycle_stage,dataset_title:String(item?.title||t.family_key).slice(0,500),provider:String(portal?.name||item?.owner||"ArcGIS publisher").slice(0,500),dataset_page_url:`https://www.arcgis.com/home/item.html?id=${id}`,resource_url:url,resource_format:arcResourceMode(url,String(item?.type||"")),license_id:open?"EXPLICIT_OPEN_TEXT":"UNRESOLVED",license_title:String(lic||"").slice(0,1000),official_domain:official,discovery_score:auto?100:official?82:62,candidate_status:auto?"AUTO_ELIGIBLE":"DISCOVERED_REVIEW_REQUIRED",legal_status:auto?"AUTO_PASS_EXPLICIT_OPEN_OFFICIAL_GOV":open?"OPEN_LICENSE__AUTHORITY_REVIEW":"UNREVIEWED",privacy_status:privacy?"REVIEW_REQUIRED":LOW_PERSONAL.has(t.family_key)?"LOW_PERSONAL_DATA_CONTEXT":"UNREVIEWED",adapter_status:"ARCGIS_METADATA_VERIFIED",ingest_status:auto?"READY_FOR_GOVERNED_FIRST_PASS":"BLOCKED_PENDING_LEGAL_AND_ADAPTER",metadata:{discovery_version:VERSION,search_provider:"ARCGIS_SHARING",arcgis_item_id:id,arcgis_org_id:item?.orgId||null,portal_name:portal?.name||null,portal_url:portal?.url||null,access:item?.access||null,explicit_open_license:open,official_publisher_evidence:official,privacy_review_required:privacy,technical_control_rule:"never bypass authentication, paywalls, CAPTCHAs, robots restrictions, or access controls"},updated_at:new Date().toISOString()});
      if(out.length>=10)return out;
    }
  }
  return out;
}
function socLicense(r:any){const md=r?.metadata||{},cf=md?.custom_fields||{},res=r?.resource||{};return `${md?.license||""} ${md?.attribution||""} ${res?.attribution||""} ${JSON.stringify(cf).slice(0,5000)}`}
async function socrataCandidates(t:any){
  const st=String(t.state_code),name=STATES[st]||st,term=TERMS[t.family_key]||t.family_key;
  let js:any;try{js=await jf(`https://api.us.socrata.com/api/catalog/v1?q=${encodeURIComponent(`${name} ${term}`)}&limit=25`,15000)}catch{return []}
  const out:any[]=[];
  for(const x of js?.results||[]){
    const r=x?.resource||{},md=x?.metadata||{},domain=String(md?.domain||""); const rid=String(r?.id||"");
    if(!domain||!rid)continue;
    const blob=`${r?.name||""} ${r?.description||""} ${(r?.tags||[]).join(" ")} ${domain} ${md?.source||""}`;
    if(!stateSpecific(blob,st)||!familyRelevant(blob,t.family_key))continue;
    const page=String(x?.permalink||x?.link||`https://${domain}/d/${rid}`);
    const dataUrl=`https://${domain}/resource/${rid}.json?$limit=250`;
    const official=govHost(`https://${domain}`)||govHost(page)||govHost(String(md?.source||""));
    const lic=socLicense(x),open=explicitOpen(lic),privacy=PRIVACY_REVIEW.has(t.family_key);
    const auto=official&&open&&LOW_PERSONAL.has(t.family_key);
    out.push({state_code:st,family_key:t.family_key,lifecycle_stage:t.lifecycle_stage,dataset_title:String(r?.name||t.family_key).slice(0,500),provider:String(md?.domain||md?.source||"Socrata publisher").slice(0,500),dataset_page_url:page,resource_url:dataUrl,resource_format:"SOCRATA_JSON",license_id:open?"EXPLICIT_OPEN_TEXT":"UNRESOLVED",license_title:String(lic||"").slice(0,1000),official_domain:official,discovery_score:auto?100:official?84:60,candidate_status:auto?"AUTO_ELIGIBLE":"DISCOVERED_REVIEW_REQUIRED",legal_status:auto?"AUTO_PASS_EXPLICIT_OPEN_OFFICIAL_GOV":open?"OPEN_LICENSE__AUTHORITY_REVIEW":"UNREVIEWED",privacy_status:privacy?"REVIEW_REQUIRED":LOW_PERSONAL.has(t.family_key)?"LOW_PERSONAL_DATA_CONTEXT":"UNREVIEWED",adapter_status:"SOCRATA_METADATA_VERIFIED",ingest_status:auto?"READY_FOR_GOVERNED_FIRST_PASS":"BLOCKED_PENDING_LEGAL_AND_ADAPTER",metadata:{discovery_version:VERSION,search_provider:"SOCRATA_CATALOG",socrata_domain:domain,socrata_resource_id:rid,explicit_open_license:open,official_publisher_evidence:official,privacy_review_required:privacy,technical_control_rule:"never bypass authentication, paywalls, CAPTCHAs, robots restrictions, or access controls"},updated_at:new Date().toISOString()});
    if(out.length>=10)break;
  }
  return out;
}
async function storeCandidates(rows:any[]){let n=0;for(const c of rows){const {error}=await db.schema("automation").from("claims_lifecycle_source_candidates_v2034").upsert(c,{onConflict:"state_code,family_key,resource_url"});if(!error)n++;}return n}

Deno.serve(async(req:Request)=>{
  const started=Date.now(); if(req.method!=="POST")return resp({complete:false,error:"method_not_allowed"},405);
  try{
    const body=await req.json().catch(()=>({}));
    const token=String(body?.task_token||"");
    const {data:ok,error:authErr}=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:token});
    if(authErr||ok!==true)return resp({complete:false,error:"invalid_worker_token",version:VERSION},401);
    const limit=Math.max(1,Math.min(Number(body?.limit||4),6));
    const {data:claim,error:claimErr}=await db.schema("automation").rpc("claim_claims_lifecycle_research_v2604",{p_limit:limit});
    if(claimErr)throw claimErr;
    const tasks=claim?.tasks||[]; if(!tasks.length)return resp({complete:true,version:VERSION,status:"IDLE",claim});
    const details:any[]=[]; let discovered=0;
    for(const t of tasks){
      try{
        const [arc,soc]=await Promise.all([arcCandidates(t),socrataCandidates(t)]);
        const byUrl=new Map<string,any>(); for(const c of [...arc,...soc]){const old=byUrl.get(c.resource_url);if(!old||Number(c.discovery_score)>Number(old.discovery_score))byUrl.set(c.resource_url,c)}
        const candidates=[...byUrl.values()].sort((a,b)=>Number(b.discovery_score)-Number(a.discovery_score)).slice(0,12);
        const stored=await storeCandidates(candidates); discovered+=stored;
        const best=candidates[0];
        await db.schema("automation").from("claims_lifecycle_discovery_queue_v2032").update({status:best?"CANDIDATE_FOUND_REVIEW_REQUIRED":"QUEUED_OFFICIAL_SOURCE_RESEARCH",discovered_source_url:best?.resource_url||null,legal_status:best?.legal_status||"UNREVIEWED",privacy_status:best?.privacy_status||"UNREVIEWED",ingest_status:"NOT_STARTED",last_error:best?null:"No matching official/open ArcGIS or Socrata candidate found in v2604 pass",next_attempt_at:new Date(Date.now()+(best?6*3600_000:45*60_000)).toISOString(),metadata:{research_version:VERSION,searches:["ARCGIS_SHARING","SOCRATA_CATALOG"],candidates_found:candidates.length,truth_rule:"Discovery is not approval. Every source must pass BridgePoint rights/privacy/local-law/technical-control gates before ingestion."},updated_at:new Date().toISOString()}).eq("queue_id",t.queue_id);
        details.push({state:t.state_code,family:t.family_key,candidates:candidates.length,top:best?{url:best.resource_url,score:best.discovery_score,official:best.official_domain,legal:best.legal_status}:null});
      }catch(e){await db.schema("automation").from("claims_lifecycle_discovery_queue_v2032").update({status:"QUEUED_OFFICIAL_SOURCE_RESEARCH",last_error:`v2604 research: ${String((e as any)?.message||e).slice(0,700)}`,next_attempt_at:new Date(Date.now()+30*60_000).toISOString(),updated_at:new Date().toISOString()}).eq("queue_id",t.queue_id);details.push({state:t.state_code,family:t.family_key,error:String((e as any)?.message||e).slice(0,180)})}
    }
    return resp({complete:true,version:VERSION,tasks:tasks.length,candidates_stored:discovered,details,elapsed_ms:Date.now()-started,truth_boundary:"Discovery never equals legal approval. High-personal-data lifecycle families remain review-gated even when a dataset is publicly accessible."});
  }catch(e){return resp({complete:false,version:VERSION,error:String((e as any)?.message||e),elapsed_ms:Date.now()-started},500)}
});