import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NAD = "https://services.arcgis.com/xOi1kZaI0eWDREZv/ArcGIS/rest/services/Address_Points_from_National_Address_Database_view/FeatureServer/0";
const H = {"content-type":"application/json","cache-control":"no-store"};
const V = 1836;
const FIELDS = ["OBJECTID","AddNo_Full","StNam_Full","Unit","County","Inc_Muni","Post_City","State","Zip_Code","Longitude","Latitude","Parcel_ID","Placement","AddrClass","Lifecycle","DateUpdate","NAD_Source"];

async function fetchJson(url:string, timeoutMs=45000){
  const r = await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(timeoutMs)});
  const t = await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${t.slice(0,500)}`);
  let j:any; try{ j=JSON.parse(t); }catch{ throw new Error(`JSON_PARSE:${t.slice(0,500)}`); }
  if(j?.error){const details=Array.isArray(j.error.details)?j.error.details.join(" | "):"";throw new Error(`ARCGIS_${j.error.code||"ERR"}:${j.error.message||""}${details?":"+details:""}`.slice(0,1000));}
  return j;
}
function esc(v:string){ return v.replace(/'/g,"''"); }

async function processState(s:any,target:any,page:number){
  const state=String(target.state_code||"").toUpperCase();
  const offset=Math.max(0,Number(target.last_oid||0)||0);
  try{
    const qs=new URLSearchParams({
      where:`State='${esc(state)}'`,
      outFields:FIELDS.join(","),
      returnGeometry:"false",
      orderByFields:"OBJECTID ASC",
      resultOffset:String(offset),
      resultRecordCount:String(page),
      f:"json"
    });
    const j=await fetchJson(`${NAD}/query?${qs.toString()}`,60000);
    const attrs=(Array.isArray(j?.features)?j.features:[]).map((f:any)=>f?.attributes||{}).filter((x:any)=>x&&x.OBJECTID!=null);
    const nextOffset=offset+attrs.length;
    const hasMore=attrs.length>0&&(j?.exceededTransferLimit===true||attrs.length>=page);
    const applied=await s.rpc("[REDACTED_LONG_LITERAL]",{
      p_state_code:state,p_rows:attrs,p_last_oid:nextOffset,p_has_more:hasMore
    });
    if(applied.error) throw applied.error;
    return {state_code:state,seen:attrs.length,cursor_offset:nextOffset,first_object_id:attrs[0]?.OBJECTID??null,last_object_id:attrs.at(-1)?.OBJECTID??null,has_more:hasMore,apply:applied.data};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,1000);
    await s.rpc("fail_nad_address_state_v1835",{p_state_code:state,p_error:msg,p_delay_seconds:180});
    return {state_code:state,error:msg};
  }
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const auth=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(auth.error||auth.data!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
    const stateLimit=Math.min(Math.max(Number(b.state_limit||4),1),6);
    const page=Math.min(Math.max(Number(b.page||600),100),1200);
    const claim=await s.rpc("claim_nad_address_states_v1835",{p_limit:stateLimit});
    if(claim.error) throw claim.error;
    if(claim.data?.skipped) return new Response(JSON.stringify({complete:true,version:V,claim:claim.data,results:[]}),{headers:H});
    const targets=Array.isArray(claim.data?.states)?claim.data.states:[];
    const results=await Promise.all(targets.map((t:any)=>processState(s,t,page)));
    return new Response(JSON.stringify({complete:true,version:V,claimed:targets.length,page,seen:results.reduce((n:number,x:any)=>n+Number(x.seen||0),0),addresses_applied:results.reduce((n:number,x:any)=>n+Number(x?.apply?.addresses_applied||0),0),exact_matches:results.reduce((n:number,x:any)=>n+Number(x?.apply?.exact_parcel_matches||0),0),polygon_matches:results.reduce((n:number,x:any)=>n+Number(x?.apply?.polygon_matches||0),0),results}),{headers:H});
  }catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}
});