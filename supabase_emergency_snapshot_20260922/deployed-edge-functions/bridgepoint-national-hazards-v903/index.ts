import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(U, S, { auth: { persistSession: false, autoRefreshToken: false } });
const H = { "content-type": "application/json", "cache-control": "no-store" };
const UA = "BridgePoint Intelligence / bridgepointintelligence.online";
const nowIso = () => new Date().toISOString();
const safeDate = (v: unknown) => { const d = v ? new Date(String(v)) : null; return d && !Number.isNaN(d.getTime()) ? d.toISOString() : null; };
const num = (v: unknown) => { const n = Number(v); return Number.isFinite(n) ? n : null; };

async function authorized(req: Request) {
  const supplied = req.headers.get("x-bridgepoint-prestorm-token") ?? "";
  const { data, error } = await db.schema("automation").from("prestorm_worker_secret_v516").select("token").eq("singleton", true).maybeSingle();
  return !error && !!data?.token && supplied === data.token;
}

async function getJson(url: string) {
  const r = await fetch(url, { headers: { Accept: "application/geo+json, application/json", "User-Agent": UA }, signal: AbortSignal.timeout(25000) });
  const text = await r.text();
  let body: any;
  try { body = JSON.parse(text); } catch { throw new Error(`Unparseable response from ${new URL(url).hostname}`); }
  if (!r.ok) throw new Error(`${new URL(url).hostname} HTTP ${r.status}: ${text.slice(0, 180)}`);
  return body;
}

function bboxOfGeometry(g: any): { minX:number,minY:number,maxX:number,maxY:number } | null {
  if (!g || !Array.isArray(g.coordinates)) return null;
  let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
  const walk=(x:any)=>{
    if(Array.isArray(x) && x.length>=2 && typeof x[0]==="number" && typeof x[1]==="number"){
      minX=Math.min(minX,x[0]); maxX=Math.max(maxX,x[0]); minY=Math.min(minY,x[1]); maxY=Math.max(maxY,x[1]); return;
    }
    if(Array.isArray(x)) for(const y of x) walk(y);
  };
  walk(g.coordinates);
  return Number.isFinite(minX) ? {minX,minY,maxX,maxY} : null;
}
function centroid(g:any){ const b=bboxOfGeometry(g); return b ? { longitude:(b.minX+b.maxX)/2, latitude:(b.minY+b.maxY)/2 } : {longitude:null,latitude:null}; }

function classifyAlert(eventRaw: string, textRaw: string): string[] {
  const event=eventRaw.toLowerCase(), text=textRaw.toLowerCase();
  const out = new Set<string>();
  if(event.includes("tornado")) out.add("TORNADO");
  if(event.includes("hurricane") || event.includes("tropical storm") || event.includes("storm surge") || event.includes("typhoon")) out.add("HURRICANE");
  if(event.includes("ice storm") || event.includes("freezing rain") || event.includes("freezing drizzle") || event.includes("freezing spray")) out.add("ICE");
  if(event.includes("blizzard") || event.includes("snow") || event.includes("winter storm") || event.includes("winter weather") || event.includes("lake effect")) out.add("SNOW");
  if(event.includes("flash flood") || event.includes("flood") || event.includes("heavy rain") || event.includes("excessive rainfall")) out.add("FLOOD");
  if(event.includes("red flag") || event.includes("fire weather")) out.add("FIRE_WEATHER");
  if(event.includes("high wind") || event.includes("wind advisory") || event.includes("severe thunderstorm")) out.add("WIND");
  if(text.includes("hail") && /\b(?:0?\.\d+|[1-6](?:\.\d+)?)\s*(?:inch|inches|in\b)|quarter|golf ball|baseball|softball|tennis ball/i.test(textRaw)) out.add("HAIL");
  if(out.size===0 && (event.includes("rain") || text.includes("heavy rain"))) out.add("RAIN");
  return [...out];
}

async function upsertEvents(rows:any[]) {
  if(!rows.length) return 0;
  let written=0;
  for(let i=0;i<rows.length;i+=250){
    const batch=rows.slice(i,i+250);
    const { data, error } = await db.schema("automation").rpc("upsert_hazard_events_v904", { p_rows: batch });
    if(error) throw error;
    written += Number((data as any)?.rows ?? batch.length);
  }
  return written;
}

async function updateSource(sourceKey:string, ok:boolean, count:number, error:string|null=null){
  const patch:any={last_attempt_at:nowIso(),record_count:Math.max(0,count),status:ok?"HEALTHY":"DEGRADED",last_error:ok?null:error,updated_at:nowIso()};
  if(ok) patch.last_success_at=nowIso();
  await db.schema("automation").from("hazard_source_state_v903").update(patch).eq("source_key",sourceKey);
  const codeMap:any={NWS_ALERTS:"NWS_ACTIVE_ALERTS_V903",SPC_DAY1_HAIL:"SPC_DAY1_HAIL_V903",SPC_DAY1_TORNADO:"SPC_DAY1_TORNADO_V903",WFIGS_CURRENT:"WFIGS_CURRENT_V903",NHC_CURRENT:"NHC_CURRENT_STORMS_V903"};
  if(codeMap[sourceKey]) await db.schema("automation").from("source_registry").update({last_checked_at:nowIso(),health_status:ok?"HEALTHY":"DEGRADED",last_error:ok?null:error,last_run_records_found:Math.max(0,count),consecutive_failures:ok?0:1,updated_at:nowIso(),...(ok?{last_successful_import_at:nowIso()}: {})}).eq("source_code",codeMap[sourceKey]);
}

async function ingestNws(){
  const source="NWS_ALERTS";
  try{
    const body=await getJson("https://api.weather.gov/alerts/active?status=actual");
    const features=Array.isArray(body?.features)?body.features:[];
    const rows:any[]=[];
    for(const f of features){
      const p=f?.properties??{}; const event=String(p.event??"");
      const fullText=[p.headline,p.description,p.instruction,JSON.stringify(p.parameters??{})].filter(Boolean).join("\n");
      const types=classifyAlert(event,fullText); if(!types.length) continue;
      const c=centroid(f?.geometry); const sourceRef=String(p.id??f.id??`${event}:${p.sent??p.effective??"unknown"}`).slice(0,900);
      for(const hazardType of types){
        rows.push({provider:"NOAA/NWS",source_ref:sourceRef,hazard_type:hazardType,event_name:event||hazardType,observation_kind:"ALERT",severity:p.severity??null,certainty:p.certainty??null,urgency:p.urgency??null,starts_at:safeDate(p.onset??p.effective??p.sent),ends_at:safeDate(p.ends??p.expires),observed_at:safeDate(p.sent),latitude:c.latitude,longitude:c.longitude,geometry_geojson:f?.geometry??null,area_description:p.areaDesc??null,headline:p.headline??null,source_url:p["@id"]??f.id??"https://api.weather.gov/alerts/active",source_updated_at:safeDate(p.sent),properties:{senderName:p.senderName??null,response:p.response??null,messageType:p.messageType??null,parameters:p.parameters??{}},active:true,last_seen_at:nowIso(),updated_at:nowIso()});
      }
    }
    const n=await upsertEvents(rows); await updateSource(source,true,n); return {source,ok:true,rows:n};
  }catch(e){const msg=String((e as any)?.message??e);await updateSource(source,false,0,msg);return {source,ok:false,error:msg};}
}

async function ingestSpc(layer:number,hazardType:string,source:string){
  try{
    const url=`https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/FeatureServer/${layer}/query?where=1%3D1&outFields=*&returnGeometry=true&outSR=4326&f=geojson`;
    const body=await getJson(url); const fs=Array.isArray(body?.features)?body.features:[]; const rows:any[]=[];
    for(let i=0;i<fs.length;i++){
      const f=fs[i],p=f?.properties??{},c=centroid(f?.geometry);
      const oid=p.OBJECTID??p.objectid??p.OID??p.id??i;
      const label=String(p.LABEL??p.label??p.dn??p.DN??p.PROB??p.probability??p.RISK??"Forecast area");
      rows.push({provider:"NOAA/NWS/SPC",source_ref:`day1:${layer}:${oid}:${label}`,hazard_type:hazardType,event_name:`Day 1 ${hazardType.toLowerCase()} outlook — ${label}`,observation_kind:"FORECAST_OUTLOOK",severity:null,certainty:"Possible",urgency:"Future",starts_at:nowIso(),ends_at:new Date(Date.now()+30*3600_000).toISOString(),observed_at:null,latitude:c.latitude,longitude:c.longitude,geometry_geojson:f?.geometry??null,area_description:null,headline:`SPC Day 1 probabilistic ${hazardType.toLowerCase()} outlook`,source_url:url.split("/query?")[0],source_updated_at:nowIso(),properties:p,active:true,last_seen_at:nowIso(),updated_at:nowIso()});
    }
    const n=await upsertEvents(rows);await updateSource(source,true,n);return {source,ok:true,rows:n};
  }catch(e){const msg=String((e as any)?.message??e);await updateSource(source,false,0,msg);return {source,ok:false,error:msg};}
}

async function ingestWildfire(){
  const source="WFIGS_CURRENT";
  try{
    const url="https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Incident_Locations_Current/FeatureServer/0/query?where=IncidentTypeCategory%3D%27WF%27&outFields=OBJECTID%2CGlobalID%2CIncidentName%2CIncidentTypeCategory%2CIncidentSize%2CPercentContained%2CFireDiscoveryDateTime%2CCreatedOnDateTime_dt%2CModifiedOnDateTime_dt%2CPooState%2CPooCounty%2CPOOJurisdictionalAgency&returnGeometry=true&outSR=4326&f=geojson";
    const body=await getJson(url);const fs=Array.isArray(body?.features)?body.features:[];const rows:any[]=[];
    for(const f of fs){const p=f?.properties??{},c=centroid(f?.geometry);const ref=String(p.GlobalID??p.OBJECTID??`${p.IncidentName??"fire"}:${p.FireDiscoveryDateTime??""}`);rows.push({provider:"NIFC/WFIGS",source_ref:ref,hazard_type:"WILDFIRE",event_name:String(p.IncidentName??"Wildfire"),observation_kind:"OBSERVED_INCIDENT",severity:null,certainty:"Observed",urgency:"Immediate",starts_at:safeDate(p.FireDiscoveryDateTime),ends_at:null,observed_at:safeDate(p.ModifiedOnDateTime_dt??p.CreatedOnDateTime_dt),latitude:c.latitude,longitude:c.longitude,geometry_geojson:f?.geometry??null,area_description:[p.PooCounty,p.PooState].filter(Boolean).join(", ")||null,headline:`${p.IncidentName??"Wildfire"}${p.IncidentSize!=null?` • ${p.IncidentSize} acres`:""}${p.PercentContained!=null?` • ${p.PercentContained}% contained`:""}`,source_url:"https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Incident_Locations_Current/FeatureServer/0",source_updated_at:safeDate(p.ModifiedOnDateTime_dt),properties:p,active:true,last_seen_at:nowIso(),updated_at:nowIso()});}
    const n=await upsertEvents(rows);await updateSource(source,true,n);return {source,ok:true,rows:n};
  }catch(e){const msg=String((e as any)?.message??e);await updateSource(source,false,0,msg);return {source,ok:false,error:msg};}
}

async function ingestNhc(){
  const source="NHC_CURRENT";
  try{
    const body=await getJson("https://www.nhc.noaa.gov/CurrentStorms.json");const storms=Array.isArray(body?.activeStorms)?body.activeStorms:[];const rows:any[]=[];
    for(const s of storms){const lat=num(s.latitudeNumeric),lon=num(s.longitudeNumeric);const ref=String(s.id??`${s.name??"storm"}:${s.lastUpdate??""}`);const classification=String(s.classification??"");const intensity=num(s.intensity);rows.push({provider:"NOAA/NHC",source_ref:ref,hazard_type:"HURRICANE",event_name:`${s.name??"Tropical cyclone"} (${classification||"active"})`,observation_kind:"CURRENT_STORM",severity:intensity!=null&&intensity>=64?"Severe":intensity!=null&&intensity>=34?"Moderate":null,certainty:"Observed",urgency:"Expected",starts_at:safeDate(s.lastUpdate),ends_at:null,observed_at:safeDate(s.lastUpdate),latitude:lat,longitude:lon,geometry_geojson:(lat!=null&&lon!=null)?{type:"Point",coordinates:[lon,lat]}:null,area_description:null,headline:`${s.name??"Storm"} • ${classification||"active cyclone"}${intensity!=null?` • ${intensity} kt`:""}`,source_url:s.forecastGraphics?.url??s.publicAdvisory?.url??"https://www.nhc.noaa.gov/",source_updated_at:safeDate(s.lastUpdate),properties:{classification:s.classification??null,intensity:s.intensity??null,pressure:s.pressure??null,movementDir:s.movementDir??null,movementSpeed:s.movementSpeed??null,trackCone:s.trackCone??null,forecastTrack:s.forecastTrack??null,windSpeedProbabilitiesGIS:s.windSpeedProbabilitiesGIS??null,stormSurgeWatchWarningGIS:s.stormSurgeWatchWarningGIS??null,potentialStormSurgeFloodingGIS:s.potentialStormSurgeFloodingGIS??null},active:true,last_seen_at:nowIso(),updated_at:nowIso()});}
    const n=await upsertEvents(rows);await updateSource(source,true,n);return {source,ok:true,rows:n};
  }catch(e){const msg=String((e as any)?.message??e);await updateSource(source,false,0,msg);return {source,ok:false,error:msg};}
}

async function deactivateStale(){
  const { error } = await db.schema("automation").rpc("deactivate_stale_hazards_v904");
  if(error) throw error;
}

Deno.serve(async(req:Request)=>{
  if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST required"}),{status:405,headers:H});
  if(!(await authorized(req))) return new Response(JSON.stringify({complete:false,error:"unauthorized"}),{status:401,headers:H});
  const started=Date.now();
  const results=await Promise.all([ingestNws(),ingestSpc(5,"HAIL","SPC_DAY1_HAIL"),ingestSpc(3,"TORNADO","SPC_DAY1_TORNADO"),ingestWildfire(),ingestNhc()]);
  let stale:any=null;
  try{await deactivateStale(); stale={ok:true};}catch(e){stale={ok:false,error:String((e as any)?.message??e)};}
  let truth:any=null;
  try{const r=await db.schema("automation").rpc("sync_v903_hazard_truth");truth=r.error?{ok:false,error:r.error.message}:{ok:true,data:r.data};}catch(e){truth={ok:false,error:String((e as any)?.message??e)};}
  const ok=results.filter((x:any)=>x.ok).length;
  return new Response(JSON.stringify({complete:true,version:904,sources_ok:ok,sources_total:results.length,results,stale,truth,duration_ms:Date.now()-started,truth_rule:"Alert, outlook, observed incident and property impact remain separate evidence types. Power-outage coverage is adapter-based and is not claimed nationally complete."}),{headers:H});
});