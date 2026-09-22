import { createClient } from "npm:@supabase/supabase-js@2";
import { unzipSync } from "npm:fflate@0.8.2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1597;
function textSample(b:Uint8Array,max=12000){try{return new TextDecoder("utf-8",{fatal:false}).decode(b.slice(0,max));}catch{return "";}}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(b.url||"").trim(); if(!/^https:\/\//i.test(url))throw new Error("HTTPS_URL_REQUIRED");
 const r=await fetch(url,{headers:{accept:"application/zip,application/octet-stream,*/*","user-agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(45000)});
 if(!r.ok)throw new Error(`HTTP_${r.status}`);
 const ct=r.headers.get("content-type")||""; const ab=new Uint8Array(await r.arrayBuffer());
 if(ab.byteLength>120_000_000)throw new Error("ARCHIVE_TOO_LARGE_FOR_PROBE");
 const magic=Array.from(ab.slice(0,4));
 let entries:any[]=[];
 if(ab[0]===0x50&&ab[1]===0x4b){const z=unzipSync(ab);entries=Object.entries(z).map(([name,data]:any)=>{const lower=name.toLowerCase();const isText=/\.(txt|csv|tsv|dat|asc)$/i.test(lower);const sample=isText?textSample(data):"";return {name,size:data.length,is_text:isText,sample:sample.slice(0,12000)};});}
 return new Response(JSON.stringify({complete:true,version:V,url,final_url:r.url,status:r.status,content_type:ct,bytes:ab.byteLength,magic,entries}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});