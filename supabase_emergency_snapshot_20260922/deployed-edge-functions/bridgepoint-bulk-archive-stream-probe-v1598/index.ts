import { createClient } from "npm:@supabase/supabase-js@2";
import { Unzip, UnzipInflate } from "npm:fflate@0.8.2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"}; const V=1598;
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(b.url||"").trim(); if(!/^https:\/\//i.test(url))throw new Error("HTTPS_URL_REQUIRED");
 const r=await fetch(url,{headers:{accept:"application/zip,application/octet-stream,*/*","user-agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(120000)}); if(!r.ok)throw new Error(`HTTP_${r.status}`); if(!r.body)throw new Error("NO_BODY");
 const entries:any[]=[]; let totalBytes=0; let textSamples=0; let streamError:any=null;
 const unzip=new Unzip(file=>{const name=file.name; const isText=/\.(txt|csv|tsv|dat|asc)$/i.test(name); const rec:any={name,size_compressed:file.size??null,is_text:isText,sample:"",sample_bytes:0}; entries.push(rec); if(!isText||textSamples>=8){file.terminate?.();return;} textSamples++; const chunks:Uint8Array[]=[]; let n=0; file.ondata=(err,data,final)=>{if(err){rec.error=String(err);return;} if(n<20000&&data?.length){const take=data.slice(0,Math.min(data.length,20000-n));chunks.push(take);n+=take.length;} if(final){const out=new Uint8Array(n);let p=0;for(const c of chunks){out.set(c,p);p+=c.length;} rec.sample=new TextDecoder("utf-8",{fatal:false}).decode(out);rec.sample_bytes=n;}}; file.start();});
 unzip.register(UnzipInflate);
 const reader=r.body.getReader(); try{while(true){const {done,value}=await reader.read(); if(done)break; if(value){totalBytes+=value.length; unzip.push(value,false);}} unzip.push(new Uint8Array(0),true);}catch(e){streamError=String((e as any)?.message||e);}
 return new Response(JSON.stringify({complete:!streamError,version:V,url,final_url:r.url,status:r.status,content_type:r.headers.get("content-type")||"",content_length:r.headers.get("content-length"),bytes_streamed:totalBytes,stream_error:streamError,entries:entries.slice(0,200)}),{status:streamError?500:200,headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});