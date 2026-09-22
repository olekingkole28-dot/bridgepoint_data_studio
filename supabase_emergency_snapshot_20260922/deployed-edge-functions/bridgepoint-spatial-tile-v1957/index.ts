import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U = Deno.env.get("SUPABASE_URL")!;
const A = Deno.env.get("SUPABASE_ANON_KEY")!;

function hexToBytes(hex:string){
  const clean=hex.startsWith("\\x")?hex.slice(2):hex.startsWith("0x")?hex.slice(2):hex;
  const out=new Uint8Array(Math.floor(clean.length/2));
  for(let i=0;i<out.length;i++) out[i]=parseInt(clean.slice(i*2,i*2+2),16);
  return out;
}
function base64ToBytes(s:string){
  const b=atob(s); const out=new Uint8Array(b.length); for(let i=0;i<b.length;i++)out[i]=b.charCodeAt(i); return out;
}
function decodeBytea(v:any){
  if(v instanceof Uint8Array)return v;
  if(typeof v!=="string")throw new Error("RPC_TILE_PAYLOAD_NOT_STRING");
  if(v.startsWith("\\x")||v.startsWith("0x"))return hexToBytes(v);
  try{return base64ToBytes(v)}catch{throw new Error("RPC_TILE_PAYLOAD_ENCODING_UNKNOWN")}
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="GET") return new Response("GET required",{status:405});
    const auth=req.headers.get("authorization")||"";
    if(!auth.toLowerCase().startsWith("bearer ")) return new Response("Unauthorized",{status:401});
    const q=new URL(req.url).searchParams;
    const layer=(q.get("layer")||"parcels").toLowerCase();
    const z=Number(q.get("z")),x=Number(q.get("x")),y=Number(q.get("y"));
    const limit=Math.min(Math.max(Number(q.get("limit")||0)|| (layer==="buildings"?5000:6000),100),layer==="buildings"?10000:12000);
    if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<0||z>22) return new Response("Invalid tile",{status:400});
    if(!["parcels","buildings"].includes(layer)) return new Response("Invalid layer",{status:400});
    const db=createClient(U,A,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:auth}}});
    const fn=layer==="buildings"?"bridgepoint_building_mvt_v1957":"bridgepoint_parcel_mvt_v1957";
    const {data,error}=await db.rpc(fn,{p_z:z,p_x:x,p_y:y,p_limit:limit});
    if(error) return new Response(JSON.stringify({complete:false,error:error.message}),{status:error.message.toLowerCase().includes("access")?403:500,headers:{"content-type":"application/json","cache-control":"no-store"}});
    const bytes=decodeBytea(data??"");
    return new Response(bytes,{headers:{"content-type":"application/vnd.mapbox-vector-tile","cache-control":"private, max-age=60","x-bridgepoint-layer":layer,"x-bridgepoint-version":"1957"}});
  }catch(e){return new Response(JSON.stringify({complete:false,error:String((e as any)?.message||e)}),{status:500,headers:{"content-type":"application/json","cache-control":"no-store"}})}
});