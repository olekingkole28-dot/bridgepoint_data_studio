import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"}; const V=1949;
const ALLOWED=new Set(["https://www.tad.org/content/data-download/PropertyData(Delimited).ZIP"]);
const td=new TextDecoder("utf-8",{fatal:false});
function u16(b:Uint8Array,o:number){return b[o]|(b[o+1]<<8)}
function u32(b:Uint8Array,o:number){return (b[o]|(b[o+1]<<8)|(b[o+2]<<16)|(b[o+3]<<24))>>>0}
async function rf(url:string,a:number,z:number){const r=await fetch(url,{headers:{Range:`bytes=${a}-${z}`,"Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(30000)});if(!(r.status===206||r.status===200))throw new Error(`RANGE_HTTP_${r.status}`);return new Uint8Array(await r.arrayBuffer());}
async function sizeOf(url:string){const r=await fetch(url,{method:"HEAD",headers:{"User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(15000)});const n=Number(r.headers.get("content-length")||0);if(!r.ok||!n)throw new Error("CONTENT_LENGTH_REQUIRED");return {n,final_url:r.url,last_modified:r.headers.get("last-modified"),etag:r.headers.get("etag")};}
function eocd(b:Uint8Array){for(let i=b.length-22;i>=0;i--)if(b[i]===80&&b[i+1]===75&&b[i+2]===5&&b[i+3]===6)return i;return -1}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const body=await req.json().catch(()=>({}));const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const tok=String(body.task_token||req.headers.get("x-bridgepoint-worker-token")||"");const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(body.url||"").trim();if(!ALLOWED.has(url))throw new Error("ARCHIVE_NOT_ALLOWLISTED");
 const sm=await sizeOf(url),tailLen=Math.min(sm.n,131072),tail=await rf(sm.final_url,sm.n-tailLen,sm.n-1),e=eocd(tail);if(e<0)throw new Error("ZIP_EOCD_NOT_FOUND");
 const cdSize=u32(tail,e+12),cdOff=u32(tail,e+16);if(cdSize>16000000)throw new Error("CENTRAL_DIRECTORY_TOO_LARGE");const cd=await rf(sm.final_url,cdOff,cdOff+cdSize-1);
 const entries:any[]=[];let p=0;while(p+46<=cd.length){if(!(cd[p]===80&&cd[p+1]===75&&cd[p+2]===1&&cd[p+3]===2))break;const method=u16(cd,p+10),cs=u32(cd,p+20),us=u32(cd,p+24),fn=u16(cd,p+28),ex=u16(cd,p+30),cm=u16(cd,p+32),lo=u32(cd,p+42),name=td.decode(cd.slice(p+46,p+46+fn));entries.push({name,method,compressed_size:cs,uncompressed_size:us,local_header_offset:lo});p+=46+fn+ex+cm;}
 return new Response(JSON.stringify({complete:true,version:V,url:sm.final_url,content_length:sm.n,last_modified:sm.last_modified,etag:sm.etag,entry_count:entries.length,entries}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});