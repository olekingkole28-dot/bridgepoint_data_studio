import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const C={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS","content-type":"application/json","cache-control":"public,max-age=45,stale-while-revalidate=120"};
const json=(x:unknown,s=200)=>new Response(JSON.stringify(x),{status:s,headers:C});
const Q="https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/query?where=1%3D1&outFields=idp_validtime%2Cidp_validendtime%2Cname&returnGeometry=false&orderByFields=idp_validtime%20asc&resultRecordCount=200&f=json";
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:C});
 if(req.method!=="POST")return json({complete:false,error:"POST_REQUIRED"},405);
 try{
  const r=await fetch(Q,{headers:{"User-Agent":"BridgePoint Intelligence public NOAA renderer","Accept":"application/json"},signal:AbortSignal.timeout(9000)});
  if(!r.ok)return json({complete:true,degraded:true,frames_epoch_ms:[],latest_epoch_ms:null,provider_status:r.status},200);
  const d=await r.json(),raw=Array.isArray(d?.features)?d.features:[],times=[...new Set(raw.map((f:any)=>Number(f?.attributes?.idp_validtime)).filter((v:number)=>Number.isFinite(v)&&v>0))].sort((a:number,b:number)=>a-b).slice(-25);
  return json({complete:true,degraded:false,provider:"NOAA/NWS MRMS",product:"Base reflectivity",units:"dBZ",frames_epoch_ms:times,frames_iso:times.map((v:number)=>new Date(v).toISOString()),latest_epoch_ms:times.at(-1)??null,generated_at:new Date().toISOString(),source_service:"NOAA radar_base_reflectivity_time"});
 }catch(e){return json({complete:true,degraded:true,frames_epoch_ms:[],latest_epoch_ms:null,error:String((e as any)?.message||e)},200)}
});