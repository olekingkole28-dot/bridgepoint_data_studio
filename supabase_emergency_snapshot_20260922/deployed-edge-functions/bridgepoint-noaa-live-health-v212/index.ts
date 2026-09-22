import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"content-type":"application/json","cache-control":"no-store"}});
const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
const anonKey=Deno.env.get("SUPABASE_ANON_KEY")!;

async function requireWeather(req:Request){
  const auth=req.headers.get("Authorization")??req.headers.get("authorization")??"";
  if(!auth)return {ok:false,status:401,error:"Authentication required"};
  const user=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data,error}=await user.rpc("bridgepoint_customer_access_contract_v318");
  const flags=(data&&typeof data==="object")?(data as any).feature_flags??{}:{};
  if(error||flags.weather_intelligence!==true)return {ok:false,status:403,error:"Weather Intelligence is not included in this account's active package"};
  return {ok:true,status:200,error:null};
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return json({complete:false,error:"POST required"},405);
  const access=await requireWeather(req);
  if(!access.ok)return json({complete:false,error:access.error,required_feature:"weather_intelligence",entitlement_contract_version:318},access.status);
  const checkedAt=new Date().toISOString();
  let radarOk=false,alertsOk=false,activeAlertCount:number|null=null,radarStatus="UNAVAILABLE",alertsStatus="UNAVAILABLE";
  try{
    const radar=await fetch("https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?service=WMS&request=GetCapabilities",{headers:{"User-Agent":"BridgePoint Intelligence / bridgepointintelligence.online"},signal:AbortSignal.timeout(7000)});
    radarOk=radar.ok;radarStatus=radar.ok?"LIVE":`HTTP_${radar.status}`;
  }catch(_){radarStatus="CHECK_FAILED";}
  try{
    const alerts=await fetch("https://api.weather.gov/alerts/active?status=actual",{headers:{"User-Agent":"BridgePoint Intelligence contact: bridgepointintelligence.online","Accept":"application/geo+json"},signal:AbortSignal.timeout(9000)});
    alertsOk=alerts.ok;alertsStatus=alerts.ok?"LIVE":`HTTP_${alerts.status}`;
    if(alerts.ok){const body=await alerts.json();activeAlertCount=Array.isArray(body?.features)?body.features.length:0;}
  }catch(_){alertsStatus="CHECK_FAILED";}
  return json({complete:true,checked_at:checkedAt,radar:{ok:radarOk,status:radarStatus,provider:"NOAA/NWS radar_base_reflectivity_time"},alerts:{ok:alertsOk,status:alertsStatus,active_count:activeAlertCount,provider:"NWS active alerts"},historical_storm_events_note:"BridgePoint Storm Events history is separate from live NOAA radar and alerts.",official_urls:{radar:"https://radar.weather.gov/",alerts:"https://www.weather.gov/"},entitlement_contract_version:318});
});