import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const ALLOWED=new Set(["https://bridgepointintelligence.online","https://www.bridgepointintelligence.online","https://olekingkole28-dot.github.io"]);
function originOk(o:string){if(!o)return"";if(ALLOWED.has(o))return o;try{const u=new URL(o);if((u.hostname==="localhost"||u.hostname==="127.0.0.1")&&(u.protocol==="http:"||u.protocol==="https:"))return o}catch{}return""}
function cors(o:string){const ok=originOk(o);return{"access-control-allow-origin":ok||"https://bridgepointintelligence.online","vary":"Origin","access-control-allow-headers":"apikey,authorization,x-client-info,content-type","access-control-allow-methods":"GET,OPTIONS","x-content-type-options":"nosniff"}}
function b64(s:string){const bin=atob(s.replace(/\s+/g,"")),out=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)out[i]=bin.charCodeAt(i);return out}
Deno.serve(async(req:Request)=>{
 const origin=req.headers.get("origin")||"",H=cors(origin);
 if(req.method==="OPTIONS"){if(origin&&!originOk(origin))return new Response(null,{status:403,headers:H});return new Response(null,{status:204,headers:H})}
 if(req.method!=="GET")return new Response("GET required",{status:405,headers:H});
 if(origin&&!originOk(origin))return new Response("Origin not allowed",{status:403,headers:{...H,"cache-control":"no-store"}});
 try{
  const q=new URL(req.url).searchParams,z=Number(q.get("z")),x=Number(q.get("x")),y=Number(q.get("y"));
  if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<14||z>22)return new Response("Invalid tile",{status:400,headers:{...H,"cache-control":"no-store"}});
  const requested=Number(q.get("limit")||8000),limit=Math.min(Math.max(Number.isFinite(requested)?requested:8000,200),8000);
  const {data,error}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_z:z,p_x:x,p_y:y,p_limit:limit});
  if(error)throw new Error(error.message);
  if(typeof data!=="string"||!data.length)throw new Error("EMPTY_ROOF_TILE");
  const bytes=b64(data);
  if(q.get("diag")==="1")return new Response(JSON.stringify({ok:bytes.length>0,layer:"roofs",z,x,y,byteLength:bytes.length,version:5369}),{headers:{...H,"content-type":"application/json","cache-control":"no-store"}});
  return new Response(bytes,{headers:{...H,"content-type":"application/vnd.mapbox-vector-tile","cache-control":"public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800","x-bridgepoint-layer":"roof-truth","x-bridgepoint-version":"5369","x-bridgepoint-bytes":String(bytes.length)}});
 }catch(e){return new Response(JSON.stringify({complete:false,error:"ROOF_TILE_UNAVAILABLE",detail:String(e?.message||e),version:5369}),{status:500,headers:{...H,"content-type":"application/json","cache-control":"no-store"}})}
});