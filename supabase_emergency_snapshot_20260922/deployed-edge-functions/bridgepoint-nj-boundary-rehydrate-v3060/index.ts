import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=3071;
const SOURCE="https://maps.nj.gov/arcgis/rest/services/Framework/Cadastral/MapServer/0";

function chunks<T>(a:T[],n:number){const o:T[][]=[];for(let i=0;i<a.length;i+=n)o.push(a.slice(i,i+n));return o}
async function jf(url:string,ms=30000){
  const r=await fetch(url,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(ms)});
  const t=await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${t.slice(0,400)}`);
  let j:any; try{j=JSON.parse(t)}catch{throw new Error(`JSON_PARSE:${t.slice(0,400)}`)}
  if(j?.error) throw new Error(`REMOTE_API_ERROR:${j.error?.code??""}:${j.error?.message??""}`);
  return j;
}
async function processLane(s:any,token:string,lane:number,limit:number){
  const cl=await s.rpc("bridgepoint_nj_boundary_rehydrate_claim_v3060",{p_task_token:token,p_lane:lane,p_limit:limit});
  if(cl.error) throw cl.error;
  const c=cl.data||{};
  if(c.done||c.skipped) return {lane,...c};
  const ids=(Array.isArray(c.ids)?c.ids:[]).map((x:any)=>String(x)).filter(Boolean);
  if(!ids.length) return {lane,...c};

  try{
    const found=new Map<string,any>();
    const parts=chunks(ids,350);
    for(const part of parts){
      const q=`${SOURCE}/query?objectIds=${encodeURIComponent(part.join(","))}&outFields=${encodeURIComponent("OBJECTID,PAMS_PIN,GIS_PIN,PIN_NODUP")}&returnGeometry=false&f=json`;
      const j=await jf(q,30000);
      for(const f of (Array.isArray(j?.features)?j.features:[])){
        const a=f?.attributes||{};
        const oid=String(a.OBJECTID??"");
        if(!oid) continue;
        found.set(oid,{
          source_record_id:oid,
          parcel_id:String(a.PAMS_PIN??a.GIS_PIN??a.PIN_NODUP??"").trim()||null,
          PAMS_PIN:a.PAMS_PIN??null,
          GIS_PIN:a.GIS_PIN??null,
          PIN_NODUP:a.PIN_NODUP??null
        });
      }
    }
    const rows=ids.map(id=>found.get(id)||{source_record_id:id,parcel_id:null});
    const ap=await s.rpc("bridgepoint_nj_boundary_rehydrate_apply_v3060",{p_task_token:token,p_lane:lane,p_rows:rows});
    if(ap.error) throw ap.error;
    return {lane,claimed:ids.length,remote_found:found.size,...(ap.data||{})};
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,1000);
    try{await s.rpc("bridgepoint_nj_boundary_rehydrate_fail_v3060",{p_task_token:token,p_lane:lane,p_error:msg})}catch{}
    return {lane,complete:false,error:msg};
  }
}
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,version:V,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const token=String(b.task_token||"");
    if(!token) return new Response(JSON.stringify({complete:false,version:V,error:"TASK_TOKEN_REQUIRED"}),{status:401,headers:H});
    const limit=Math.min(Math.max(Number(b.limit||2000),100),2000);
    const lanes=Array.isArray(b.lanes)?b.lanes.map(Number).filter((x:number)=>x>=0&&x<=5):[0,1,2,3,4,5];
    const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
    const results=await Promise.all(lanes.map((lane:number)=>processLane(s,token,lane,limit)));
    return new Response(JSON.stringify({
      complete:true,version:V,limit,lanes,
      claimed:results.reduce((n:number,x:any)=>n+Number(x.claimed||x.count||0),0),
      linked:results.reduce((n:number,x:any)=>n+Number(x.linked||0),0),
      unmatched:results.reduce((n:number,x:any)=>n+Number(x.unmatched||0),0),
      results
    }),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});