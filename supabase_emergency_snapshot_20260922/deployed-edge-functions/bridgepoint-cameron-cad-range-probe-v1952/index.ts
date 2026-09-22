import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")}); if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(b.target_url||""); if(!/^https?:\/\//i.test(url))throw new Error("TARGET_URL_REQUIRED");
 const r=await fetch(url,{headers:{Range:"bytes=0-65535","Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(30000)});
 const ab=new Uint8Array(await r.arrayBuffer());
 return new Response(JSON.stringify({complete:true,version:1952,status:r.status,final_url:r.url,content_type:r.headers.get("content-type"),content_length:r.headers.get("content-length"),content_range:r.headers.get("content-range"),accept_ranges:r.headers.get("accept-ranges"),bytes:ab.length,magic:Array.from(ab.slice(0,8))}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,version:1952,error:String((e as any)?.message||e)}),{status:500,headers:H});}});
