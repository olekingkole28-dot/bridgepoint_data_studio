import { createClient } from "npm:@supabase/supabase-js@2";
import shp from "npm:shpjs@6.2.0";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const ZIP="https://www.humboldtgov.org/DocumentCenter/View/562";
Deno.serve(async(req:Request)=>{
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
  const b=await req.json().catch(()=>({}));
  const ok=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
  if(ok.error||ok.data!==true) return new Response(JSON.stringify({complete:false,error:"INVALID_TASK_TOKEN"}),{status:401,headers:H});
  const r=await fetch(ZIP,{redirect:"follow",signal:AbortSignal.timeout(40000),headers:{"user-agent":"BridgePointIntelligence/1.0","accept":"application/zip,application/octet-stream,*/*"}});
  if(!r.ok) throw new Error(`ZIP_HTTP_${r.status}`);
  const ab=await r.arrayBuffer();
  const parsed:any=await shp(ab);
  const collections=Array.isArray(parsed)?parsed:[parsed];
  let count=0; const keys=new Set<string>(); const samples:any[]=[];
  for(const fc of collections){for(const f of (fc?.features||[])){count++;for(const k of Object.keys(f?.properties||{}))keys.add(k);if(samples.length<3)samples.push({properties:f?.properties||{},geometry_type:f?.geometry?.type||null});}}
  const payload={probe_status:"COMPLETE",feature_count:count,zip_bytes:ab.byteLength,property_keys:[...keys].slice(0,100),samples};
  const st=await s.rpc("bridgepoint_store_humboldt_probe_v1567",{p_payload:payload}); if(st.error) throw st.error;
  return new Response(JSON.stringify({complete:true,version:1567,...payload}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);await s.rpc("bridgepoint_store_humboldt_probe_v1567",{p_payload:{probe_status:"ERROR",error:msg}}).catch(()=>{});return new Response(JSON.stringify({complete:false,version:1567,error:msg}),{status:400,headers:H});}
});