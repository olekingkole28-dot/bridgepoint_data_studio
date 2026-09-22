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
    if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<14||z>22){
      return new Response("Invalid tile",{status:400,headers:{...H,"cache-control":"no-store"}});
    }
    const requested=Number(q.get("limit")||12000);
    const limit=Math.min(Math.max(Number.isFinite(requested)?requested:12000,500),12000);
    const {data,error}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_z:z,p_x:x,p_y:y,p_limit:limit});
    if(error)throw new Error(error.message);
    if(typeof data!=="string"||!data.length)throw new Error("EMPTY_BASE64_TILE");
    const bytes=base64ToBytes(data);
    if(q.get("diag")==="1"){
      return new Response(JSON.stringify({ok:bytes.length>0,encoding:"base64",layers:["buildings","roofs"],z,x,y,limit,base64Length:data.length,byteLength:bytes.length,firstBytes:Array.from(bytes.slice(0,8)),version:5368}),{headers:{...H,"content-type":"application/json","cache-control":"no-store"}});
    }
    return new Response(bytes,{headers:{
      ...H,
      "content-type":"application/vnd.mapbox-vector-tile",
      "cache-control":"public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800",
      "x-bridgepoint-layer":"structural-buildings-and-roofs",
      "x-bridgepoint-version":"5368",
      "x-bridgepoint-encoding":"base64-decoded",
      "x-bridgepoint-bytes":String(bytes.length),
      "x-bridgepoint-count-cap":"12000"
    }});
  }catch(e){
    console.error("building tile v5368",String(e));
    return new Response(JSON.stringify({complete:false,error:"PUBLIC_TILE_UNAVAILABLE",detail:String(e?.message||e),version:5368}),{
      status:500,headers:{...H,"content-type":"application/json","cache-control":"no-store"}
    });
  }
});