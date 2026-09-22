import { createClient } from "npm:@supabase/supabase-js@2.57.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json"}; const V=2742;
async function fj(url:string){
  const r=await fetch(url,{signal:AbortSignal.timeout(50000),headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"}});
  const t=await r.text(); if(!r.ok) throw new Error(`HTTP ${r.status}: ${t.slice(0,300)}`);
  try{return JSON.parse(t)}catch{throw new Error(`UNPARSEABLE_JSON ${url}`)}
}
Deno.serve(async(req:Request)=>{
 try{
  const body=await req.json().catch(()=>({}));
  const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
  const ok=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(body.task_token||"")});
  if(ok.error||ok.data!==true)return new Response(JSON.stringify({complete:false,error:"INVALID_TASK_TOKEN"}),{status:401,headers:H});
  const st=await s.rpc("bridgepoint_nyc_bes_state_v2742");
  if(st.error)throw st.error;
  let state=st.data||{}, offset=Number(state.row_offset||0), total=Number(state.expected_rows||0);
  if(state.status==="COMPLETE"&&total>0&&offset>=total)return new Response(JSON.stringify({complete:true,version:V,status:"COMPLETE",offset,total}),{headers:H});
  if(!total){
    const c=await fj("https://data.cityofnewyork.us/resource/bsin-59hv.json?$select=count(*)%20as%20count");
    total=Number(c?.[0]?.count||0); if(!total)throw new Error("BES_COUNT_ZERO");
  }
  const lim=Math.max(500,Math.min(3000,Number(body.page_limit||2000)));
  const burst=Math.max(1,Math.min(4,Number(body.burst||3)));
  let persisted=0,pages=0;
  for(let i=0;i<burst&&offset<total;i++){
    const url=`https://data.cityofnewyork.us/resource/bsin-59hv.json?$limit=${lim}&$offset=${offset}&$order=bin`;
    const rows=await fj(url);
    if(!Array.isArray(rows))throw new Error("BES_ROWS_NOT_ARRAY");
    if(rows.length===0&&offset<total)throw new Error(`BES_PREMATURE_EOF offset=${offset} total=${total}`);
    const next=offset+rows.length,done=next>=total;
    const p=await s.rpc("bridgepoint_nyc_bes_persist_v2742",{p_rows:rows,p_next_offset:next,p_expected_rows:total,p_done:done,p_metadata:{page_limit:lim,burst_page:i+1,burst_limit:burst,worker_version:V}});
    if(p.error)throw new Error(`BES_PERSIST: ${p.error.message}`);
    persisted+=Number(p.data?.written||0);pages++;offset=next;
    if(done||rows.length<lim)break;
  }
  return new Response(JSON.stringify({complete:true,version:V,offset,total,pages,persisted,status:offset>=total?"COMPLETE":"RUNNING"}),{headers:H});
 }catch(e){
  return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});
 }
});