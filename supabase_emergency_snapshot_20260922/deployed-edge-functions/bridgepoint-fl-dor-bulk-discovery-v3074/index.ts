import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=3074;
const FOLDER="/property/dataportal/Documents/PTO Data Portal/Map Data/2026F";
const BASE="https://floridarevenue.com/property/dataportal";
async function sp(path:string){
  const r=await fetch(path,{headers:{accept:"application/json;odata=nometadata","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(30000)});
  const t=await r.text();
  if(!r.ok) throw new Error(`HTTP_${r.status}:${t.slice(0,600)}`);
  let j:any; try{j=JSON.parse(t)}catch{throw new Error(`JSON_PARSE:${t.slice(0,600)}`)}
  return {status:r.status,data:j};
}
Deno.serve(async(req:Request)=>{
  const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,version:V,error:"POST_REQUIRED"}),{status:405,headers:H});
    const b=await req.json().catch(()=>({}));
    const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
    if(a.error||a.data!==true) return new Response(JSON.stringify({complete:false,version:V,error:"UNAUTHORIZED"}),{status:401,headers:H});
    const esc=FOLDER.replaceAll("'","''");
    const root=`${BASE}/_api/web/GetFolderByServerRelativeUrl('${esc}')`;
    let files:any[]=[];
    let folders:any[]=[];
    let status=200;
    try{
      const fr=await sp(`${root}/Files?$select=Name,ServerRelativeUrl,Length,TimeLastModified`);
      status=fr.status;
      files=Array.isArray(fr.data?.value)?fr.data.value:[];
      const dr=await sp(`${root}/Folders?$select=Name,ServerRelativeUrl,TimeLastModified`);
      folders=Array.isArray(dr.data?.value)?dr.data.value:[];
    }catch(e){
      const msg=String((e as any)?.message||e);
      const m=msg.match(/^HTTP_(\d+)/);
      await s.schema("automation").from("fl_dor_bulk_discovery_state_v3074").update({
        status:"ERROR",last_error:msg,last_http_status:m?Number(m[1]):null,last_run_at:new Date().toISOString(),
        metadata:{version:V,folder:FOLDER,source:"FL_DOR_PTO_2026F"},updated_at:new Date().toISOString()
      }).eq("singleton",true);
      return new Response(JSON.stringify({complete:false,version:V,error:msg}),{status:502,headers:H});
    }
    const rows=[
      ...files.map((x:any)=>({
        server_relative_url:String(x.ServerRelativeUrl||""),
        kind:"FILE",name:String(x.Name||""),byte_length:Number(x.Length||0)||null,
        modified_at:x.TimeLastModified||null,raw:x,updated_at:new Date().toISOString()
      })),
      ...folders.filter((x:any)=>String(x.Name||"").toLowerCase()!=="forms").map((x:any)=>({
        server_relative_url:String(x.ServerRelativeUrl||""),
        kind:"FOLDER",name:String(x.Name||""),byte_length:null,
        modified_at:x.TimeLastModified||null,raw:x,updated_at:new Date().toISOString()
      }))
    ].filter((x:any)=>x.server_relative_url&&x.name);
    if(rows.length){
      const u=await s.schema("automation").from("fl_dor_bulk_files_v3074").upsert(rows,{onConflict:"server_relative_url"});
      if(u.error) throw u.error;
    }
    await s.schema("automation").from("fl_dor_bulk_discovery_state_v3074").update({
      status:"SUCCESS",files_found:files.length,folders_found:folders.filter((x:any)=>String(x.Name||"").toLowerCase()!=="forms").length,
      last_error:null,last_http_status:status,last_run_at:new Date().toISOString(),
      metadata:{version:V,folder:FOLDER,source:"FL_DOR_PTO_2026F",official:true,read_only_discovery:true},
      updated_at:new Date().toISOString()
    }).eq("singleton",true);
    return new Response(JSON.stringify({complete:true,version:V,files:files.length,folders:folders.length,sample:rows.slice(0,20)}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});