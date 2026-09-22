import { withSupabase } from "npm:@supabase/server";

const ALLOWED=new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online",
  "https://olekingkole28-dot.github.io"
]);

function allowed(origin:string){
  if(!origin)return false;
  if(ALLOWED.has(origin))return true;
  try{
    const u=new URL(origin);
    return (u.hostname==="localhost"||u.hostname==="127.0.0.1")&&(u.protocol==="http:"||u.protocol==="https:");
  }catch{return false}
}
function cors(origin:string){
  const o=allowed(origin)?origin:"https://bridgepointintelligence.online";
  return {
    "access-control-allow-origin":o,
    "vary":"Origin",
    "access-control-allow-headers":"apikey,authorization,x-client-info,content-type",
    "access-control-allow-methods":"POST,OPTIONS",
    "content-type":"application/json",
    "cache-control":"no-store",
    "x-content-type-options":"nosniff"
  };
}
async function sha256(s:string){
  const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
function firstIp(req:Request){
  const raw=req.headers.get("x-forwarded-for")||req.headers.get("cf-connecting-ip")||req.headers.get("x-real-ip")||"unknown";
  return raw.split(",")[0].trim().slice(0,80);
}
function finite(v:unknown){const n=Number(v);return Number.isFinite(n)?n:null}

Deno.serve(withSupabase({auth:"none"},async(req:Request,ctx:any)=>{
  const db=ctx.supabaseAdmin;
  const origin=req.headers.get("origin")||"";
  const H=cors(origin);
  if(req.method==="OPTIONS")return new Response(null,{status:allowed(origin)?204:403,headers:H});
  if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
  if(origin&&!allowed(origin))return new Response(JSON.stringify({complete:false,error:"ORIGIN_NOT_ALLOWED"}),{status:403,headers:H});
  try{
    const b=await req.json().catch(()=>({}));
    const west=finite(b.west),south=finite(b.south),east=finite(b.east),north=finite(b.north);
    if(west==null||south==null||east==null||north==null||west>=east||south>=north||west< -180||east>180||south< -90||north>90){
      return new Response(JSON.stringify({complete:false,error:"VALID_VIEWPORT_REQUIRED"}),{status:400,headers:H});
    }
    const width=east-west,height=north-south;
    if(width>2.2||height>2.2){
      return new Response(JSON.stringify({complete:true,version:5319,type:"FeatureCollection",features:[],reason:"ZOOM_IN_FOR_FINE_DETAIL"}),{headers:{...H,"cache-control":"public, max-age=20"}});
    }

    const ip=firstIp(req),ua=(req.headers.get("user-agent")||"").slice(0,220),day=new Date().toISOString().slice(0,10);
    const subject=(await sha256(ip+"|"+ua+"|"+day+"|living-world-v5319")).slice(0,48);
    // Origin, viewport size and row limits already bound this public-safe endpoint.
    // Rate accounting is best-effort: a bookkeeping/RLS issue must never suppress map detail.
    try{
      const gate=await db.rpc("bridgepoint_public_tile_gate_v5300",{p_subject_hash:subject,p_asset_key:"PUBLIC_LIVING_WORLD_VIEWPORT_V5319",p_origin_host:origin?new URL(origin).host:""});
      if(!gate.error&&gate.data?.allowed===false){
        return new Response(JSON.stringify({complete:false,error:"RATE_LIMITED"}),{status:429,headers:{...H,"retry-after":"60"}});
      }
    }catch(_){}

    const limit=Math.min(Math.max(Number(b.limit||2200),100),4000);
    const {data,error}=await db.rpc("bridgepoint_living_world_viewport_v5319",{
      p_west:west,p_south:south,p_east:east,p_north:north,p_limit:limit
    });
    if(error)throw new Error(error.message);
    return new Response(JSON.stringify(data||{type:"FeatureCollection",features:[]}),{
      headers:{...H,"cache-control":"public, max-age=20, stale-while-revalidate=60","x-bridgepoint-version":"5319"}
    });
  }catch(e){
    return new Response(JSON.stringify({complete:false,error:"LIVING_WORLD_VIEWPORT_UNAVAILABLE",detail:String((e as any)?.message||e).slice(0,400)}),{status:500,headers:H});
  }
}));