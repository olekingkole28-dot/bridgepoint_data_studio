import { createClient } from "npm:@supabase/supabase-js@2";
import { Inflate } from "npm:fflate@0.8.2";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"},V=1925,td=new TextDecoder("utf-8",{fatal:false});
const URL="https://download.hcad.org/data/CAMA/2026/Real_acct_owner.zip";
const META:any={
 "real_acct.txt":{cs:138718339,us:888843098,lo:72936106},
 "real_mnrl.txt":{cs:51996,us:405354,lo:211759522},
 "parcel_tieback.txt":{cs:1351579,us:20742498,lo:47569745},
 "deeds.txt":{cs:24511205,us:112874272,lo:0}
};
function u16(b:Uint8Array,o:number){return b[o]|(b[o+1]<<8)}
async function rf(a:number,z:number){const r=await fetch(URL,{headers:{Range:`bytes=${a}-${z}`,"User-Agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});if(!(r.status===206||r.status===200))throw new Error(`RANGE_HTTP_${r.status}`);return new Uint8Array(await r.arrayBuffer())}
async function dataStart(lo:number){const h=await rf(lo,lo+512);if(!(h[0]===80&&h[1]===75&&h[2]===3&&h[3]===4))throw new Error("LOCAL_HEADER_BAD");return lo+30+u16(h,26)+u16(h,28)}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const en=String(b.entry_name||"").toLowerCase(),m=META[en];if(!m)throw new Error("ENTRY_NOT_ALLOWLISTED");
 const ds=await dataStart(m.lo);const take=Math.min(m.cs,en==="real_acct.txt"?4_000_000:m.cs);
 const compressed=await rf(ds,ds+take-1);let chunks:Uint8Array[]=[],n=0;
 const inf=new Inflate((data:Uint8Array,final:boolean)=>{if(n<120000&&data?.length){const x=data.slice(0,Math.min(data.length,120000-n));chunks.push(x);n+=x.length}});
 inf.push(compressed,take===m.cs);
 const out=new Uint8Array(n);let p=0;for(const c of chunks){out.set(c,p);p+=c.length}
 return new Response(JSON.stringify({complete:true,version:V,entry_name:en,compressed_total:m.cs,uncompressed_total:m.us,compressed_read:take,sample_bytes:n,sample:td.decode(out)}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H})}});