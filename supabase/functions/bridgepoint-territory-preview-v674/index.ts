import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ORIGINS=new Set(["https://bridgepointintelligence.online","https://www.bridgepointintelligence.online"]);
const cors=(origin:string|null)=>({"Access-Control-Allow-Origin":origin&&ORIGINS.has(origin)?origin:"https://bridgepointintelligence.online","Access-Control-Allow-Headers":"content-type, apikey","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin","Cache-Control":"no-store"});
const reply=(body:unknown,status=200,origin:string|null=null)=>new Response(JSON.stringify(body),{status,headers:{...cors(origin),"Content-Type":"application/json; charset=utf-8"}});
const clean=(v:unknown,n:number)=>String(v??"").replace(/\s+/g," ").trim().slice(0,n);
async function rpc(name:string,payload:Record<string,unknown>){
  const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res=await fetch(`${url}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify(payload)});
  const text=await res.text(); let data:unknown; try{data=JSON.parse(text)}catch{data={complete:false,error:"INVALID_BACKEND_RESPONSE"}};
  return {ok:res.ok,data};
}
function decoratePreview(data:any){
  if(!data||typeof data!=="object") return data;
  const opportunities=Array.isArray(data.opportunities)?data.opportunities.map((o:any)=>{
    if(!o||typeof o!=="object") return o;
    const fallback=o.territory_match===false;
    const area=clean(o.area||"Connecticut",180);
    return {...o,area:fallback?`Connecticut fallback · ${area}`:area,scope_label:fallback?"Connecticut fallback":"Your territory"};
  }):data.opportunities;
  return {...data,opportunities};
}
Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin");
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors(origin)});
  if(req.method!=="POST") return reply({complete:false,error:"METHOD_NOT_ALLOWED"},405,origin);
  if(origin && !ORIGINS.has(origin)) return reply({complete:false,error:"ORIGIN_NOT_ALLOWED"},403,origin);
  try{
    const body=await req.json().catch(()=>({}));
    const state=clean(body?.state_code??"CT",2).toUpperCase();
    const territory=clean(body?.territory,120);
    const vertical=clean(body?.vertical??"ROOFING",40).toUpperCase();
    if(territory.length<2) return reply({complete:false,error:"TERRITORY_REQUIRED"},400,origin);
    const result=await rpc("bridgepoint_public_territory_preview_v935",{p_state_code:state,p_territory:territory,p_vertical:vertical});
    if(!result.ok) return reply({complete:false,error:"PREVIEW_UNAVAILABLE"},502,origin);
    const visitor=clean(body?.visitor_id,128),session=clean(body?.session_id,128);
    if(visitor.length>=8&&session.length>=8){
      void rpc("track_acquisition_event_v400",{p_event_type:"SAMPLE_VIEW",p_visitor_id:visitor,p_session_id:session,p_page_path:"/sample/",p_platform:"WEB",p_referrer_host:null,p_utm_source:null,p_utm_medium:null,p_utm_campaign:null,p_utm_content:"territory_preview_v935",p_referral_code:clean(body?.referral_code,64)||null,p_auth_error_code:null,p_metadata:{capture_version:935,surface:"territory_preview",state_code:state,territory_kind:/^\d{5}$/.test(territory)?"ZIP":"NAMED_AREA",vertical}});
    }
    return reply(decoratePreview(result.data),200,origin);
  }catch{return reply({complete:false,error:"PREVIEW_UNAVAILABLE"},500,origin)}
});
