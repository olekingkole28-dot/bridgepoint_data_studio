import { createClient } from "npm:@supabase/supabase-js@2";
import { Unzip, UnzipInflate } from "npm:fflate@0.8.2";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const URL="https://dallascad.org/ViewPDFs.aspx?type=3&id=%5C%5CDCAD.ORG%5CWEB%5CWEBDATA%5CWEBFORMS%5CDATA%20PRODUCTS%5CDCAD2026_CURRENT.ZIP";
const td=new TextDecoder("utf-8",{fatal:false});
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const ac=new AbortController();
 const r=await fetch(URL,{headers:{"User-Agent":"BridgePointIntelligence/1.0"},signal:ac.signal});
 if(!r.ok||!r.body)throw new Error(`HTTP_${r.status}`);
 const files:any[]=[]; const samples:Record<string,string>={}; const sampleBytes:Record<string,number>={};
 const uz=new Unzip((f:any)=>{
   const name=String(f.name||""); const rec:any={name,compression:f.compression,size:f.size,originalSize:f.originalSize}; files.push(rec);
   let n=0; const chunks:Uint8Array[]=[]; const want=/\.(csv|txt|dat|tsv|md|xml|json)$/i.test(name)||files.length<=5;
   f.ondata=(err:any,data:Uint8Array,final:boolean)=>{if(err){rec.error=String(err);return;} if(want&&data?.length&&n<65536){const x=data.slice(0,Math.min(data.length,65536-n));chunks.push(x);n+=x.length;} if(final&&want){const out=new Uint8Array(n);let p=0;for(const c of chunks){out.set(c,p);p+=c.length}samples[name]=td.decode(out);sampleBytes[name]=n;}};
   f.start();
 });
 uz.register(UnzipInflate);
 const reader=r.body.getReader(); let compressedRead=0; let stopped=false;
 try{
   while(true){const x=await reader.read();if(x.done){uz.push(new Uint8Array(),true);break;} if(x.value){compressedRead+=x.value.length;uz.push(x.value,false);} if(compressedRead>=16000000&&files.length>=1){stopped=true;await reader.cancel();break;}}
 }catch(e){if(!stopped)throw e;}
 return new Response(JSON.stringify({complete:true,version:1928,http_status:r.status,content_length:r.headers.get("content-length"),compressed_read:compressedRead,stopped_early:stopped,files,samples,sample_bytes:sampleBytes}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1928,error:String((e as any)?.message||e)}),{status:500,headers:H});}});