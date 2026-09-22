import { createClient } from "npm:@supabase/supabase-js@2";
import { unzipSync } from "npm:fflate@0.8.2";
import * as XLSX from "npm:xlsx@0.18.5";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(b.target_url||"");if(!/^https?:\/\//i.test(url))throw new Error("TARGET_URL_REQUIRED");
 const r=await fetch(url,{headers:{"Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(30000)});if(!r.ok)throw new Error(`HTTP_${r.status}`);const outer=new Uint8Array(await r.arrayBuffer());if(outer.length>5_000_000)throw new Error("ARCHIVE_TOO_LARGE");
 const z=unzipSync(outer);const xname=Object.keys(z).find(x=>x.toLowerCase().endsWith('.xlsx'));if(!xname)throw new Error("XLSX_NOT_FOUND");const wb=XLSX.read(z[xname],{type:'array'});const out:any[]=[];const terms=(Array.isArray(b.terms)?b.terms:['PROP.TXT','PROP','pID','geoID','situs','condo']).map((x:any)=>String(x).toLowerCase());
 for(const sn of wb.SheetNames){const rows=XLSX.utils.sheet_to_json(wb.Sheets[sn],{header:1,defval:null,raw:false}) as any[][];for(let i=0;i<rows.length;i++){const line=rows[i].map(v=>v==null?'':String(v)).join(' | ').toLowerCase();if(terms.some(t=>line.includes(t)))out.push({sheet:sn,row:i+1,values:rows[i].slice(0,30)});if(out.length>=300)break;}if(out.length>=300)break;}
 return new Response(JSON.stringify({complete:true,version:1934,xlsx:xname,sheets:wb.SheetNames,matches:out}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,version:1934,error:String((e as any)?.message||e)}),{status:500,headers:H});}});
