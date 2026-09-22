import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1599;
const td=new TextDecoder();
function u16(b:Uint8Array,o:number){return b[o]|(b[o+1]<<8)}
function u32(b:Uint8Array,o:number){return (b[o]|(b[o+1]<<8)|(b[o+2]<<16)|(b[o+3]<<24))>>>0}
async function range(url:string,start:number,end:number){
 const r=await fetch(url,{headers:{Range:`bytes=${start}-${end}`,Accept:"application/octet-stream","Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(30000)});
 if(!(r.status===206||r.status===200)) throw new Error(`RANGE_HTTP_${r.status}`);
 const ab=await r.arrayBuffer(); return {status:r.status,bytes:new Uint8Array(ab),headers:Object.fromEntries(r.headers.entries()),finalUrl:r.url};
}
async function sizeOf(url:string){
 try{const r=await fetch(url,{method:"HEAD",headers:{"Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(15000)});const n=Number(r.headers.get("content-length")||0);if(r.ok&&n>0)return {size:n,finalUrl:r.url,acceptRanges:r.headers.get("accept-ranges"),contentType:r.headers.get("content-type")};}catch{}
 const r=await fetch(url,{headers:{Range:"bytes=0-0","Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(15000)});const cr=r.headers.get("content-range")||"";const m=cr.match(/\/(\d+)$/);if(!m)throw new Error(`SIZE_UNKNOWN_HTTP_${r.status}`);await r.body?.cancel();return {size:Number(m[1]),finalUrl:r.url,acceptRanges:r.headers.get("accept-ranges"),contentType:r.headers.get("content-type")};
}
function findEOCD(b:Uint8Array){for(let i=b.length-22;i>=0;i--){if(b[i]===0x50&&b[i+1]===0x4b&&b[i+2]===0x05&&b[i+3]===0x06)return i;}return -1}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const body=await req.json().catch(()=>({}));const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(body.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const target=String(body.target_url||"").trim();if(!/^https?:\/\//i.test(target))throw new Error("TARGET_URL_REQUIRED");
 const meta=await sizeOf(target);const size=meta.size;if(!Number.isFinite(size)||size<22)throw new Error("INVALID_ARCHIVE_SIZE");
 const tailLen=Math.min(size,70000);const tailStart=size-tailLen;const tail=await range(meta.finalUrl,tailStart,size-1);const e=findEOCD(tail.bytes);if(e<0)throw new Error("ZIP_EOCD_NOT_FOUND");
 const entries=u16(tail.bytes,e+10),cdSize=u32(tail.bytes,e+12),cdOffset=u32(tail.bytes,e+16),commentLen=u16(tail.bytes,e+20);
 if(entries===0xffff||cdSize===0xffffffff||cdOffset===0xffffffff)return new Response(JSON.stringify({complete:true,version:V,target_url:target,final_url:meta.finalUrl,size,zip64:true,entries,cdSize,cdOffset,commentLen}),{headers:H});
 if(cdSize>8_000_000)return new Response(JSON.stringify({complete:true,version:V,target_url:target,final_url:meta.finalUrl,size,zip64:false,entries,cdSize,cdOffset,commentLen,central_directory_too_large:true}),{headers:H});
 const cd=await range(meta.finalUrl,cdOffset,cdOffset+cdSize-1);let p=0;const files:any[]=[];
 while(p+46<=cd.bytes.length&&files.length<200){if(!(cd.bytes[p]===0x50&&cd.bytes[p+1]===0x4b&&cd.bytes[p+2]===0x01&&cd.bytes[p+3]===0x02))break;const method=u16(cd.bytes,p+10),compressed=u32(cd.bytes,p+20),uncompressed=u32(cd.bytes,p+24),fn=u16(cd.bytes,p+28),ex=u16(cd.bytes,p+30),cm=u16(cd.bytes,p+32),localOffset=u32(cd.bytes,p+42);const name=td.decode(cd.bytes.slice(p+46,p+46+fn));files.push({name,method,compressed_size:compressed,uncompressed_size:uncompressed,local_header_offset:localOffset});p+=46+fn+ex+cm;}
 return new Response(JSON.stringify({complete:true,version:V,target_url:target,final_url:meta.finalUrl,size,content_type:meta.contentType,accept_ranges:meta.acceptRanges,zip64:false,entry_count:entries,central_directory_size:cdSize,central_directory_offset:cdOffset,comment_length:commentLen,files}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});
