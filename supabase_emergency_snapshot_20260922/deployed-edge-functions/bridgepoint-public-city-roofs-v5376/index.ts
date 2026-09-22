import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});

const ALLOWED_ORIGINS=new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online",
  "https://olekingkole28-dot.github.io"
]);

function allowedOrigin(origin:string){
  if(!origin)return "";
  if(ALLOWED_ORIGINS.has(origin))return origin;
  try{
    const u=new URL(origin);
    if((u.hostname==="localhost"||u.hostname==="127.0.0.1")&&(u.protocol==="http:"||u.protocol==="https:"))return origin;
  }catch{}
  return "";
}
function cors(origin:string){
  const ok=allowedOrigin(origin);
  return {
    "access-control-allow-origin":ok||"https://bridgepointintelligence.online",
    "vary":"Origin",
    "access-control-allow-headers":"apikey,authorization,x-client-info,content-type",
    "access-control-allow-methods":"GET,OPTIONS",
    "x-content-type-options":"nosniff",
    "referrer-policy":"strict-origin-when-cross-origin"
  };
}
function base64ToBytes(s:string){
  const compact=s.replace(/\s+/g,"");
  const bin=atob(compact),out=new Uint8Array(bin.length);
  for(let i=0;i<bin.length;i++)out[i]=bin.charCodeAt(i);
  return out;
}

Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin")||"";
  const H=cors(origin);
  if(req.method==="OPTIONS"){
    if(origin&&!allowedOrigin(origin))return new Response(null,{status:403,headers:H});
    return new Response(null,{status:204,headers:H});
  }
  if(req.method!=="GET")return new Response("GET required",{status:405,headers:H});
  if(origin&&!allowedOrigin(origin))return new Response("Origin not allowed",{status:403,headers:{...H,"cache-control":"no-store"}});
  try{
    const q=new URL(req.url).searchParams;
    const z=Number(q.get("z")),x=Number(q.get("x")),y=Number(q.get("y"));
    if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<15||z>22){
      return new Response("Invalid tile",{status:400,headers:{...H,"cache-control":"no-store"}});
    }
    const requested=Number(q.get("limit")||500);
    const cap=z<=16?650:900;
    const limit=Math.min(Math.max(Number.isFinite(requested)?requested:500,100),cap);
    const {data,error}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_z:z,p_x:x,p_y:y,p_limit:limit});
    if(error)throw new Error(error.message);
    if(typeof data!=="string")throw new Error("EMPTY_TILE");
    const bytes=base64ToBytes(data);
    return new Response(bytes,{headers:{
      ...H,
      "content-type":"application/vnd.mapbox-vector-tile",
      "cache-control":"public, max-age=600, s-maxage=3600, stale-while-revalidate=86400",
      "x-bridgepoint-layer":"city-real-roofs",
      "x-bridgepoint-version":"5376",
      "x-bridgepoint-count-cap":String(cap)
    }});
  }catch(e){
    console.error("city roofs v5376",String(e));
    return new Response(JSON.stringify({complete:false,error:"PUBLIC_TILE_UNAVAILABLE"}),{
      status:500,headers:{...H,"content-type":"application/json","cache-control":"no-store"}
    });
  }
});