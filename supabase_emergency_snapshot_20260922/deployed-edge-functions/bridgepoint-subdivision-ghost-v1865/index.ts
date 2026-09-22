import { createClient } from "npm:@supabase/supabase-js@2.55.0";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1865,PAGE=1000,PAGES=8;
async function jf(url:string){const r=await fetch(url,{headers:{accept:"application/geo+json,application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});const t=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${t.slice(0,240)}`);try{return JSON.parse(t)}catch{throw new Error(`UNPARSEABLE_JSON:${t.slice(0,160)}`)}}
Deno.serve(async(req:Request)=>{let cid="";try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const body=await req.json().catch(()=>({})); const tok=String(body.task_token||req.headers.get("x-bridgepoint-worker-token")||"");
 const auth=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok}); if(auth.error||auth.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const cl=await db.rpc("[REDACTED_LONG_LITERAL]"); if(cl.error)throw cl.error; const s=cl.data?.source;if(!s)return new Response(JSON.stringify({complete:true,version:V,claimed:0,features:0}),{headers:H});
 cid=String(s.candidate_id);let last=Math.max(0,Number(s.cursor_oid||0)||0),seen=Math.max(0,Number(s.records_seen||0)||0),total=0,done=false;const stats:any[]=[];const oid=String(s.object_id_field||"OBJECTID");const base=String(s.source_url).replace(/\/$/,"");
 for(let p=0;p<PAGES&&!done;p++){
   const where=`${oid}>${last}`;const url=`${base}/query?where=${encodeURIComponent(where)}&outFields=*&returnGeometry=true&outSR=4326&orderByFields=${encodeURIComponent(oid)}&resultRecordCount=${PAGE}&f=geojson`;
   const gj=await jf(url);const feats=Array.isArray(gj?.features)?gj.features:[];
   for(const f of feats){const v=Number(f?.properties?.[oid]??f?.properties?.OBJECTID??f?.properties?.objectid??0);if(v>last)last=v;}
   seen+=feats.length;total+=feats.length;done=feats.length<PAGE;
   const st=await db.rpc("[REDACTED_LONG_LITERAL]",{p_candidate_id:cid,p_features:feats,p_last_oid:last,p_records_seen:seen,p_done:done});if(st.error)throw st.error;
   stats.push({page:p+1,features:feats.length,last_oid:last,seen});if(!feats.length)done=true;
 }
 return new Response(JSON.stringify({complete:true,version:V,claimed:1,candidate_id:cid,features:total,done,last_oid:last,records_seen:seen,pages:stats}),{headers:H});
 }catch(e){const msg=String((e as any)?.message||e);if(cid){try{await db.rpc("[REDACTED_LONG_LITERAL]",{p_candidate_id:cid,p_error:msg})}catch{}}return new Response(JSON.stringify({complete:false,version:V,candidate_id:cid,error:msg}),{status:500,headers:H})}
});