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
    if((u.hostname==="localhost"||u.hostname==="127.0.0.1") && (u.protocol==="http:"||u.protocol==="https:"))return origin;
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

function hexToBytes(hex:string){
  const clean=hex.startsWith("\\x")?hex.slice(2):hex.startsWith("0x")?hex.slice(2):hex;
  const out=new Uint8Array(Math.floor(clean.length/2));
  for(let i=0;i<out.length;i++)out[i]=parseInt(clean.slice(i*2,i*2+2),16);
  return out;
}
function base64ToBytes(s:string){
  const b=atob(s),out=new Uint8Array(b.length);
  for(let i=0;i<b.length;i++)out[i]=b.charCodeAt(i);
  return out;
}
function decodeBytea(v:unknown){
  if(v instanceof Uint8Array)return v;
  if(typeof v!=="string")throw new Error("PUBLIC_BUILDING_TILE_PAYLOAD_NOT_STRING");
  if(v.startsWith("\\x")||v.startsWith("0x"))return hexToBytes(v);
  return base64ToBytes(v);
}
async function sha256(s:string){
  const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
function firstIp(req:Request){
  const raw=req.headers.get("x-forwarded-for")||req.headers.get("cf-connecting-ip")||req.headers.get("x-real-ip")||"unknown";
  return raw.split(",")[0].trim().slice(0,80);
}

Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin")||"";
  const H=cors(origin);

  if(req.method==="OPTIONS"){
    if(origin && !allowedOrigin(origin))return new Response(null,{status:403,headers:H});
    return new Response(null,{status:204,headers:H});
  }
  if(req.method!=="GET")return new Response("GET required",{status:405,headers:H});
  if(origin && !allowedOrigin(origin))return new Response("Origin not allowed",{status:403,headers:{...H,"cache-control":"no-store"}});

  try{
    const q=new URL(req.url).searchParams;
    const z=Number(q.get("z")),x=Number(q.get("x")),y=Number(q.get("y"));
    if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<10||z>22){
      return new Response("Invalid tile",{status:400,headers:{...H,"cache-control":"no-store"}});
    }

    const ip=firstIp(req);
    const ua=(req.headers.get("user-agent")||"").slice(0,220);
    const day=new Date().toISOString().slice(0,10);
    const subject=(await sha256(ip+"|"+ua+"|"+day+"|bridgepoint-v5370-city")).slice(0,48);
    let originHost="";
    try{originHost=origin?new URL(origin).host:""}catch{}

    const gate=await db.rpc("bridgepoint_public_tile_gate_v5300",{
      p_subject_hash:subject,
      p_asset_key:"PUBLIC_BUILDING_CITY_TILE_V5370",
      p_origin_host:originHost
    });
    if(gate.error)throw new Error("RATE_GATE:"+gate.error.message);
    if(gate.data?.allowed!==true){
      return new Response(JSON.stringify({complete:false,error:"RATE_LIMITED",retry_after_seconds:60}),{
        status:429,
        headers:{...H,"content-type":"application/json","cache-control":"no-store","retry-after":"60"}
      });
    }

    const requested=Number(q.get("limit")||0);
    const zoomCap=z<=12?500:z<=13?700:z<=14?900:1200;
    const limit=Math.min(Math.max(Number.isFinite(requested)&&requested>0?requested:zoomCap,100),zoomCap);

    const {data,error}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_z:z,p_x:x,p_y:y,p_limit:limit});
    if(error)throw new Error(error.message);
    const bytes=decodeBytea(data??"");

    return new Response(bytes,{headers:{
      ...H,
      "content-type":"application/vnd.mapbox-vector-tile",
      "cache-control":"public, max-age=90, s-maxage=90, stale-while-revalidate=180",
      "x-bridgepoint-layer":"public-buildings-city-lod-v5370",
      "x-bridgepoint-version":"5370"
    }});
  }catch(e){
    return new Response(JSON.stringify({complete:false,error:"PUBLIC_TILE_UNAVAILABLE"}),{
      status:500,
      headers:{...H,"content-type":"application/json","cache-control":"no-store"}
    });
  }
});