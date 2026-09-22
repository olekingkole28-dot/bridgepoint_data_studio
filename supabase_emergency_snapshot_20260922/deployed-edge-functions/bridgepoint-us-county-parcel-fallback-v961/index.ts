import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json"}; const V=961;
const lc=(x:any)=>String(x??'').toLowerCase();
const clean=(x:string)=>lc(x).replace(/[^a-z0-9 ]+/g,' ').replace(/\s+/g,' ').trim();
const countyBase=(x:string)=>clean(x).replace(/\b(county|parish|borough|census area|municipality|municipio|city and borough)\b/g,'').replace(/\s+/g,' ').trim();
async function jf(url:string){const r=await fetch(url,{signal:AbortSignal.timeout(25000),headers:{accept:'application/json','user-agent':'BridgePointIntelligence/1.0'}});const t=await r.text();if(!r.ok)throw new Error(`HTTP ${r.status}: ${t.slice(0,220)}`);try{return JSON.parse(t)}catch{throw new Error(`Unparseable JSON: ${url}: ${t.slice(0,160)}`)}}
function govish(...v:any[]){const s=lc(v.join(' '));return /(^|[./])([a-z0-9-]+\.)*gov([/:]|$)/.test(s)||s.includes('.gov/')||s.includes('.gov ')}
function orgToken(url:string){const m=lc(url).match(/services[0-9]*\.arcgis\.com\/([^/]+)/);return m?.[1]||''}
function stateEvidence(blob:string,stateName:string,stateCode:string){const s=clean(blob),n=clean(stateName),c=String(stateCode||'').toUpperCase();if(n&&s.includes(n))return true;return new RegExp(`(^|[^A-Z])${c}([^A-Z]|$)`).test(String(blob||'').toUpperCase())}
function countyEvidence(blob:string,countyName:string){const b=countyBase(countyName),s=clean(blob);if(!b)return false;const toks=b.split(' ').filter(x=>x.length>2);return toks.length?toks.every(x=>s.includes(x)):s.includes(b)}
function parcelEvidence(blob:string){return /\b(parcel|parcels|cadastral|assessor|assessment|tax parcel|tax map|property parcel|parcel map|appraisal|real property|property map)\b/.test(clean(blob))}
function score(authority:number,coverage:number){const freshness=80,quality=Math.round(authority*.45+coverage*.35+freshness*.20);return{authority_score:authority,coverage_score:coverage,freshness_score:freshness,quality_score:quality}}
function sets(tr:any){return{orgs:new Set((tr?.arcgis_org_tokens||[]).map((x:any)=>lc(x))),providers:new Set((tr?.providers||[]).map((x:any)=>lc(x)))}}
async function countyOrgEvidence(orgId:string,countyName:string,stateName:string,stateCode:string){if(!orgId)return{county:false,state:false,name:'',blob:''};try{const p=await jf(`https://www.arcgis.com/sharing/rest/portals/${encodeURIComponent(orgId)}?f=json`);const name=String(p?.name||p?.portalName||''),blob=`${name} ${p?.description||''} ${p?.url||''} ${p?.urlKey||''} ${p?.customBaseUrl||''}`;return{county:countyEvidence(blob,countyName),state:stateEvidence(blob,stateName,stateCode),name,blob}}catch{return{county:false,state:false,name:'',blob:''}}}
async function discover(t:any,tr:any){
  const b=countyBase(t.county_name);
  const qs=[
    `${t.county_name} ${t.state_name} parcels`,
    `${b} ${t.state_name} assessor parcels`,
    `${b} ${t.state_name} tax parcels`,
    `${b} ${t.state_code} cadastral`,
    `${b} ${t.state_name} parcel map GIS`,
    `${b} ${t.state_name} real property GIS`,
    `${b} ${t.state_name} appraisal parcels`,
    `${b} ${t.state_code} FeatureServer parcels`
  ];
  const js=await Promise.all(qs.map(q=>jf(`https://www.arcgis.com/sharing/rest/search?f=json&num=100&sortField=modified&sortOrder=desc&q=${encodeURIComponent(q)}`).catch(()=>({results:[]}))));
  const all:any[]=[]; const seen=new Set<string>();
  for(const j of js) for(const x of (j.results||[])){const k=String(x.id||x.url||'');if(k&&!seen.has(k)){seen.add(k);all.push(x)}}
  const ts=sets(tr);
  const raw=all.filter((x:any)=>['Feature Service','Map Service'].includes(String(x.type||''))).filter((x:any)=>parcelEvidence(`${x.title||''} ${x.snippet||''} ${x.description||''} ${(x.tags||[]).join(' ')} ${x.url||''}`)).slice(0,40);
  const orgCache=new Map<string,any>();
  const enriched=[] as any[];
  for(const x of raw){
    const oid=String(x.orgId||'');
    if(oid&&!orgCache.has(oid)) orgCache.set(oid,await countyOrgEvidence(oid,t.county_name,t.state_name,t.state_code));
    const org=orgCache.get(oid)||{county:false,state:false,name:'',blob:''};
    const u=String(x.url||''),p=String(x.owner||x.orgId||'ArcGIS');
    const blob=`${x.title||''} ${x.snippet||''} ${x.description||''} ${p} ${u} ${(x.tags||[]).join(' ')}`;
    const tok=orgToken(u),trusted=!!tok&&ts.orgs.has(tok),providerTrusted=ts.providers.has(lc(p));
    const countyText=countyEvidence(blob,t.county_name), countyMatch=countyText||org.county;
    const stateText=stateEvidence(blob,t.state_name,t.state_code), stateMatch=stateText||org.state||trusted||providerTrusted;
    const local=/\b(city|town|township|village|school district|fire district)\b/.test(clean(`${x.title||''} ${x.snippet||''}`));
    if(!countyMatch||!stateMatch||local) continue;
    const official=trusted||providerTrusted||(org.county&&org.state)||govish(u,p,blob,org.blob);
    const authority=official?97:84,coverage=94,qv=score(authority,coverage);
    enriched.push({source_category:'PROPERTY_PARCEL',candidate_name:String(x.title||`${t.county_name} parcels`).slice(0,300),provider:p,source_url:u,access_method:u.includes('FeatureServer')?'ARCGIS_FEATURESERVER':u.includes('MapServer')?'ARCGIS_MAPSERVER':'ARCGIS_SERVICE',official,...qv,metadata:{portal:'ArcGIS Online',item_id:x.id,owner:x.owner,org_id:x.orgId,org_name:org.name,county_fips:t.county_fips,county_name:t.county_name,countywide_candidate:true,target_geo_evidence:true,state_text_evidence:stateText,county_text_evidence:countyText,county_org_evidence:org.county,state_org_evidence:org.state,official_basis:trusted?'TRUSTED_STATE_ORG':providerTrusted?'TRUSTED_PROVIDER':org.county&&org.state?'COUNTY_STATE_ARCGIS_ORG':govish(u,p,blob,org.blob)?'GOV_ORG_OR_SERVICE':null,requirement_key:'PROPERTY_PARCEL',county_discovery_version:V,search_strategy:'HARD_COUNTY_BROAD_ORG_PROOF'}})
  }
  return enriched;
}
Deno.serve(async(req:Request)=>{try{
  const b=await req.json().catch(()=>({})),s=createClient(U,S,{auth:{persistSession:false}});
  const ok=await s.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:String(b.task_token||'')});
  if(ok.error||ok.data!==true)return new Response(JSON.stringify({complete:false,error:'Invalid task token'}),{status:401,headers:H});
  const cl=await s.rpc('[REDACTED_LONG_LITERAL]',{p_limit:Math.min(Math.max(Number(b.limit||5),1),10)}); if(cl.error)throw cl.error;
  const out=[];
  for(const t of cl.data?.targets||[]){try{
    const tr=await s.rpc('[REDACTED_LONG_LITERAL]',{p_state_code:t.state_code}); if(tr.error)throw tr.error;
    const cand=await discover(t,tr.data); const uniq=new Set<string>(); const dedup=cand.filter((x:any)=>{const k=`${x.candidate_name}|${x.source_url}`.toLowerCase();if(!x.source_url||uniq.has(k))return false;uniq.add(k);return true});
    const st=await s.rpc('[REDACTED_LONG_LITERAL]',{p_state_code:t.state_code,p_county_fips:t.county_fips,p_county_name:t.county_name,p_candidates:dedup}); if(st.error)throw st.error;
    out.push({state:t.state_code,county:t.county_name,candidates:dedup.length,result:st.data});
  }catch(e){out.push({state:t.state_code,county:t.county_name,error:String((e as any)?.message||e)})}}
  return new Response(JSON.stringify({complete:true,version:V,claimed:cl.data?.claimed||0,results:out}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:400,headers:H})}});