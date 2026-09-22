import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const VERSION=5608;
const ORIGIN="https://bridgepointintelligence.online";

async function rpc(name:string,body:any){
  const {data,error}=await db.schema("automation").rpc(name,body);
  if(error) throw new Error(`${name}: ${error.message}`);
  return data;
}
async function get(path:string){
  const u=`${ORIGIN}${path}${path.includes("?")?"&":"?"}watchdog=${Date.now()}`;
  try{
    const r=await fetch(u,{headers:{"cache-control":"no-cache","user-agent":"BridgePoint-Map-Contract/5608"},signal:AbortSignal.timeout(18000)});
    const text=await r.text();
    return {status:r.status,text,url:u,error:null};
  }catch(e){
    return {status:0,text:"",url:u,error:String((e as any)?.message||e)};
  }
}
function hasAll(s:string, xs:string[]){return xs.every(x=>s.includes(x))}
Deno.serve(async(req:Request)=>{
  if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
  try{
    const body=await req.json().catch(()=>({}));
    const tok=String(body.task_token||"");
    const auth=await rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok});
    if(auth!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});

    const [world,app,parcel,root,appHtml]=await Promise.all([
      get("/world-v2300-map.js?v=5560"),
      get("/app.js?v=5562"),
      get("/parcel-boundary-viewer-v5403.js?v=5575"),
      get("/"),
      get("/app/")
    ]);

    const worldOk=world.status===200
      && hasAll(world.text,["__BP_WORLD_PERFORMANCE_V5560__","single-maplibre-click","const PARCEL_MIN=MOBILE?6.45","function startWaterMotion","if(MOBILE||LOW)return"])
      && !world.text.includes("canvas.addEventListener('click'");
    const appOk=app.status===200 && app.text.includes("destructiveStop:false");
    const parcelVersion=Number((parcel.text.match(/const VERSION=(\d+)/)||[])[1]||0);
    const parcelMinzoom=Number((parcel.text.match(/minzoom:([0-9.]+)/)||[])[1]||999);
    const parcelOk=parcel.status===200
      && parcelVersion>=5585
      && parcelMinzoom<=1
      && parcel.text.includes("bridgepoint-parcel-boundary-tile-v5403")
      && !/fresh sign.?in need/i.test(parcel.text);
    const rootOk=root.status===200 && root.text.includes("parcel-boundary-viewer-v5403.js?v=");
    const appHtmlOk=appHtml.status===200 && hasAll(appHtml.text,["app.js?v=","parcel-boundary-viewer-v5403.js?v="]);

    const failures:string[]=[];
    if(!worldOk) failures.push("WORLD_CONTRACT");
    if(!appOk) failures.push("APP_INTERACTION_CONTRACT");
    if(!parcelOk) failures.push("PARCEL_VIEWER_CONTRACT");
    if(!rootOk) failures.push("ROOT_CACHE_CONTRACT");
    if(!appHtmlOk) failures.push("APP_HTML_CACHE_CONTRACT");

    const details={
      version:VERSION,
      origin:ORIGIN,
      world:{status:world.status,bytes:world.text.length,error:world.error},
      app:{status:app.status,bytes:app.text.length,error:app.error},
      parcel:{status:parcel.status,bytes:parcel.text.length,error:parcel.error,parsed_version:parcelVersion,parsed_minzoom:parcelMinzoom,tile_endpoint:parcel.text.includes("bridgepoint-parcel-boundary-tile-v5403"),fresh_signin_loop_text:/fresh sign.?in need/i.test(parcel.text),head:parcel.text.slice(0,180)},
      root:{status:root.status,bytes:root.text.length,error:root.error},
      app_html:{status:appHtml.status,bytes:appHtml.text.length,error:appHtml.error}
    };
    const ok=failures.length===0;
    await rpc("record_production_map_contract_v5568",{
      p_ok:ok,p_world_ok:worldOk,p_app_ok:appOk,p_parcel_ok:parcelOk,p_root_ok:rootOk,p_app_html_ok:appHtmlOk,
      p_world_status:world.status,p_app_status:app.status,p_parcel_status:parcel.status,p_root_status:root.status,p_app_html_status:appHtml.status,
      p_failures:failures,p_details:details
    });
    return new Response(JSON.stringify({complete:true,version:VERSION,ok,failures,details}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});