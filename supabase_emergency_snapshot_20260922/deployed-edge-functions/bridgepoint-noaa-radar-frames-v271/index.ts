import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"content-type":"application/json","cache-control":"no-store"}});
const queryUrl="https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/query?where=1%3D1&outFields=idp_validtime%2Cidp_validendtime%2Cname&returnGeometry=false&orderByFields=idp_validtime%20asc&resultRecordCount=200&f=json";
const wmsUrl="https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?";
const serviceUrl="https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer";
const officialRadar="https://radar.weather.gov/";
const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
const anonKey=Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceRole=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin=createClient(supabaseUrl,serviceRole,{auth:{persistSession:false}});

const reflectivityLegend=[
  {min_dbz:null,max_dbz:19,color_family:"light blue / pale green",meaning:"very light echo / trace precipitation",rain_rate_note:"often trace or very light precipitation"},
  {min_dbz:20,max_dbz:29,color_family:"green",meaning:"light precipitation",rain_rate_note:"20 dBZ is around trace precipitation"},
  {min_dbz:30,max_dbz:39,color_family:"green to yellow",meaning:"light to moderate rain",rain_rate_note:"30 dBZ is about 0.10 in/hr; 36 dBZ about 0.25 in/hr"},
  {min_dbz:40,max_dbz:49,color_family:"yellow to orange",meaning:"moderate to heavy rain",rain_rate_note:"41 dBZ is about 0.50 in/hr; 47 dBZ about 1.25 in/hr"},
  {min_dbz:50,max_dbz:59,color_family:"red",meaning:"very heavy rain / strong convective return",rain_rate_note:"52 dBZ about 2.5 in/hr; 55 dBZ about 4 in/hr"},
  {min_dbz:60,max_dbz:null,color_family:"magenta / pink / very bright return",meaning:"extreme reflectivity; hail is possible and rain-rate estimates can be inflated by hail",rain_rate_note:"60 dBZ is roughly 8 in/hr equivalent reflectivity; 65 dBZ can exceed 16 in/hr equivalent"}
];

async function requireWeather(req:Request){
  const auth=req.headers.get("Authorization")??req.headers.get("authorization")??"";
  if(!auth)return {ok:false,status:401,error:"Authentication required"};
  const user=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data,error}=await user.rpc("bridgepoint_customer_access_contract_v318");
  const flags=(data&&typeof data==="object")?(data as any).feature_flags??{}:{};
  if(error||flags.weather_intelligence!==true)return {ok:false,status:403,error:"Weather Intelligence is not included in this account's active package"};
  return {ok:true,status:200,error:null};
}

async function recordHealth(ok:boolean,found:number,error:string|null){
  try{
    const now=new Date().toISOString();
    const patch:Record<string,unknown>={last_checked_at:now,health_status:ok?"HEALTHY":"DEGRADED",last_error:ok?null:error,last_run_records_found:Math.max(0,found),updated_at:now};
    if(ok) patch.consecutive_failures=0;
    await admin.schema("automation").from("source_registry").update(patch).eq("source_code","NOAA_NWS_LIVE_RADAR_V80");
  }catch(_){/* Health telemetry must never block radar delivery. */}
}

function degraded(reason:string,checkedAt:string,providerHttpStatus:number|null=null){
  return json({
    complete:true,
    degraded:true,
    live_available:false,
    animation_available:false,
    provider:"NOAA/NWS MRMS radar_base_reflectivity_time",
    product:"Base reflectivity",
    units:"dBZ",
    frame_count:0,
    frames_epoch_ms:[],
    frames_iso:[],
    latest_epoch_ms:null,
    checked_at:checkedAt,
    provider_http_status:providerHttpStatus,
    message:"Live NOAA frame timestamps are temporarily unavailable. BridgePoint is returning an explicit degraded state instead of a blank radar experience.",
    error_context:reason,
    render_fallback:{
      wms_endpoint:wmsUrl,
      service_rest_url:serviceUrl,
      official_radar_url:officialRadar,
      sequence:["NOAA_MRMS_WMS_LATEST","NOAA_MRMS_REST_SERVICE","OFFICIAL_NWS_RADAR","EXPLICIT_DEGRADED_STATE"],
      latest_image_rule:"The WMS service can render the newest live image when TIME is omitted."
    },
    reflectivity_legend:reflectivityLegend,
    legend_disclaimer:"Reflectivity is radar echo intensity, not proof of hail, loss, or property damage. Very high reflectivity can be caused by hail and can inflate rain-rate estimates.",
    entitlement_contract_version:318,
    failure_contract_version:860
  },200);
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return json({complete:false,error:"POST required"},405);
  const access=await requireWeather(req);
  if(!access.ok)return json({complete:false,error:access.error,required_feature:"weather_intelligence",entitlement_contract_version:318},access.status);
  const checkedAt=new Date().toISOString();
  try{
    const response=await fetch(queryUrl,{headers:{"User-Agent":"BridgePoint Intelligence / bridgepointintelligence.online","Accept":"application/json"},signal:AbortSignal.timeout(9000)});
    if(!response.ok){
      const message=`NOAA radar frame query HTTP ${response.status}`;
      await recordHealth(false,0,message);
      return degraded(message,checkedAt,response.status);
    }
    const payload=await response.json();
    const raw=Array.isArray(payload?.features)?payload.features:[];
    const times=[...new Set(raw.map((f:any)=>Number(f?.attributes?.idp_validtime)).filter((v:number)=>Number.isFinite(v)&&v>0))].sort((a:number,b:number)=>a-b);
    const latest=times.slice(-25);
    await recordHealth(true,latest.length,null);
    return json({
      complete:true,
      degraded:false,
      live_available:true,
      animation_available:latest.length>0,
      provider:"NOAA/NWS MRMS radar_base_reflectivity_time",
      product:"Base reflectivity",
      units:"dBZ",
      movement:"Successive NOAA scan timestamps are returned in chronological order so BridgePoint can animate real precipitation movement.",
      frame_count:latest.length,
      frames_epoch_ms:latest,
      frames_iso:latest.map((v:number)=>new Date(v).toISOString()),
      latest_epoch_ms:latest.length?latest[latest.length-1]:null,
      checked_at:checkedAt,
      latest_request_rule:"Omit TIME for the newest live image; use an exact NOAA frame timestamp for historical animation.",
      render_fallback:{wms_endpoint:wmsUrl,service_rest_url:serviceUrl,official_radar_url:officialRadar,never_blank:true},
      reflectivity_legend:reflectivityLegend,
      legend_disclaimer:"Reflectivity is radar echo intensity, not proof of hail, loss, or property damage. Very high reflectivity can be caused by hail and can inflate rain-rate estimates.",
      health_feedback:"BridgePoint source health updated from this successful NOAA frame fetch.",
      entitlement_contract_version:318,
      failure_contract_version:860
    });
  }catch(e){
    const message=`${e}`;
    await recordHealth(false,0,message);
    return degraded(message,checkedAt,null);
  }
});