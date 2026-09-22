import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1864,PAGE=1000,PAGES=4;
async function jf(url:string){const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(35000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,240)}`);try{return JSON.parse(t)}catch{throw new Error(`UNPARSEABLE_JSON:${t.slice(0,160)}`)}}
function qurl(base:string,args:Record<string,string>){const u=new URL(base.replace(/\/$/,"")+"/query");for(const [k,v] of Object.entries(args))u.searchParams.set(k,v);return u.toString()}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const cl=await s.rpc("[REDACTED_LONG_LITERAL]");if(cl.error)throw cl.error;
 const c=cl.data?.candidate;if(!c)return new Response(JSON.stringify({complete:true,version:V,claimed:0,records:0}),{headers:H});
 const base=String(c.source_url||"");let ofs=Math.max(0,Number(c.offset||0)||0);
 const cnt=await jf(qurl(base,{where:"1=1",returnCountOnly:"true",f:"json"}));const total=Math.max(0,Number(cnt?.count||0)||0);
 let written=0,done=false;const pages:any[]=[];
 for(let p=0;p<PAGES&&!done;p++){
   const url=qurl(base,{where:"1=1",outFields:"*",returnGeometry:"true",outSR:"4326",f:"geojson",resultOffset:String(ofs),resultRecordCount:String(PAGE),orderByFields:"OBJECTID ASC"});
   const g=await jf(url);const fs=Array.isArray(g?.features)?g.features:[];
   const records=fs.map((f:any,i:number)=>({source_record_id:String(f?.id??f?.properties?.OBJECTID??f?.properties?.objectid??`${ofs+i}`),geometry:f?.geometry,properties:f?.properties||{}})).filter((x:any)=>x.geometry&&x.source_record_id);
   const next=ofs+fs.length;done=fs.length<PAGE||(total>0&&next>=total);
   const st=await s.rpc("[REDACTED_LONG_LITERAL]",{p_candidate_id:c.candidate_id,p_records:records,p_next_offset:next,p_done:done});if(st.error)throw st.error;
   written+=Number(st.data?.written||0);pages.push({page:p+1,from:ofs,to:next,fetched:fs.length,written:Number(st.data?.written||0)});ofs=next;
 }
 return new Response(JSON.stringify({complete:true,version:V,claimed:1,candidate_id:c.candidate_id,source:c.candidate_name,records:written,offset:ofs,total,done,pages,canonicalized:0}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H})}});