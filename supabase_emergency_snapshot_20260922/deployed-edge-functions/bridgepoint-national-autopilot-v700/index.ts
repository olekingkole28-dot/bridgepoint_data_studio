import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json"};
const V=700;
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST required",version:V}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const sb=createClient(U,S,{auth:{persistSession:false}});
    const token=String(b.task_token||req.headers.get("x-bridgepoint-token")||"");
    const auth=await sb.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:token});
    if(auth.error||auth.data!==true) return new Response(JSON.stringify({complete:false,error:"invalid task token",version:V}),{status:401,headers:H});
    const limit=Math.min(Math.max(Number(b.limit||1000),250),2500);
    const tick=await sb.rpc("bridgepoint_autopilot_tick_v700",{p_limit:limit});
    if(tick.error) throw tick.error;
    const health=await sb.rpc("bridgepoint_autopilot_health_v700");
    return new Response(JSON.stringify({complete:true,version:V,tick:tick.data,health:health.error?{error:String(health.error.message||health.error)}:health.data}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});