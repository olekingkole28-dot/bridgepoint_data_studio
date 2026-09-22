import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { Inflate } from "npm:fflate@0.8.2";

const TARGET="ACCOUNT_APPRL_YEAR.CSV";
const URL="https://dallascad.org/ViewPDFs.aspx?id=%5C%5CDCAD.ORG%5CWEB%5CWEBDATA%5CWEBFORMS%5CDATA+PRODUCTS%5CDCAD2026_CURRENT.ZIP&type=3";

async function readPrefix(resp:Response,maxBytes:number){
  if(!resp.body) return new Uint8Array(await resp.arrayBuffer());
  const rd=resp.body.getReader(); const chunks:Uint8Array[]=[]; let total=0;
  try{
    while(total<maxBytes){ const {value,done}=await rd.read(); if(done) break; if(!value) continue; const take=value.subarray(0,Math.min(value.length,maxBytes-total)); chunks.push(take); total+=take.length; if(total>=maxBytes){try{await rd.cancel();}catch{} break;} }
  }finally{try{rd.releaseLock();}catch{}}
  const out=new Uint8Array(total); let p=0; for(const c of chunks){out.set(c,p);p+=c.length;} return out;
}
function inflateHead(data:Uint8Array,maxOut=262144){
  const chunks:Uint8Array[]=[]; let total=0; let error:string|null=null;
  try{ const infl=new Inflate((chunk)=>{if(total>=maxOut)return; const t=chunk.subarray(0,Math.min(chunk.length,maxOut-total)); if(t.length){chunks.push(t);total+=t.length;}}); for(let o=0;o<data.length&&total<maxOut;o+=131072) infl.push(data.subarray(o,Math.min(o+131072,data.length)),false); }catch(e){error=String(e)}
  const out=new Uint8Array(total); let p=0; for(const c of chunks){out.set(c,p);p+=c.length;} return {text:new TextDecoder().decode(out),error};
}
Deno.serve(async(req:Request)=>{
 try{
  if(req.method!=="POST") return new Response("Method Not Allowed",{status:405});
  const body=await req.json().catch(()=>({}));
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const {data:ok}=await sb.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:body.task_token??""});
  if(!ok) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:{"content-type":"application/json"}});
  const prefixBytes=Math.min(Math.max(Number(body.archive_prefix_bytes)||8388608,1048576),33554432);
  const r=await fetch(URL,{headers:{"User-Agent":"BridgePoint-Data-Acquisition/1937"},redirect:"follow"}); if(!r.ok) throw new Error(`HTTP_${r.status}`);
  const b=await readPrefix(r,prefixBytes);
  let off=0,found:any=null;
  while(off+30<=b.length){const dv=new DataView(b.buffer,b.byteOffset+off,b.byteLength-off); if(dv.getUint32(0,true)!==0x04034b50) break; const flags=dv.getUint16(6,true),method=dv.getUint16(8,true),csize=dv.getUint32(18,true),nlen=dv.getUint16(26,true),xlen=dv.getUint16(28,true); const name=new TextDecoder().decode(b.subarray(off+30,off+30+nlen)); const dataOffset=off+30+nlen+xlen; if(name===TARGET){found={name,flags,method,csize,dataOffset};break;} if(flags&0x08) break; off=dataOffset+csize;}
  if(!found) return new Response(JSON.stringify({complete:false,version:1937,error:"TARGET_NOT_FOUND_IN_PREFIX",archive_prefix_bytes:b.length,offset:off}),{headers:{"content-type":"application/json"}});
  const compressed=b.subarray(found.dataOffset); let text="",stream_error:null|string=null;
  if(found.method===0) text=new TextDecoder().decode(compressed.subarray(0,262144)); else if(found.method===8){const z=inflateHead(compressed);text=z.text;stream_error=z.error;} else throw new Error(`ZIP_METHOD_${found.method}`);
  return new Response(JSON.stringify({complete:true,version:1937,http_status:r.status,archive_prefix_bytes:b.length,entry:found,compressed_bytes_available:compressed.length,text_bytes:text.length,stream_error,text}),{headers:{"content-type":"application/json"}});
 }catch(e){return new Response(JSON.stringify({complete:false,version:1937,error:String(e)}),{status:500,headers:{"content-type":"application/json"}})}
});