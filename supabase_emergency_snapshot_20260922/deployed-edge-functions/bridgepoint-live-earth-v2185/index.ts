import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const JSON_HEADERS={"content-type":"application/json; charset=utf-8","cache-control":"no-store","access-control-allow-origin":"*","access-control-allow-headers":"authorization,apikey,content-type","access-control-allow-methods":"POST,OPTIONS"};
let currentStationsCache:{at:number,stations:any[]}|null=null;
let waterStationsCache:{at:number,stations:any[]}|null=null;

const clamp=(v:number,a:number,b:number)=>Math.max(a,Math.min(b,v));
const num=(v:any)=>{const n=Number(v);return Number.isFinite(n)?n:null};

async function getJson(url:string,timeout=9000){
  const ctl=new AbortController(); const t=setTimeout(()=>ctl.abort(),timeout);
  try{const r=await fetch(url,{headers:{"user-agent":"BridgePoint Intelligence live-earth/2185 (public NOAA data)","accept":"application/json, application/geo+json;q=0.9,*/*;q=0.2"},signal:ctl.signal});if(!r.ok)throw new Error(`HTTP ${r.status}`);return await r.json();}
  finally{clearTimeout(t)}
}

function bboxHit(lng:number,lat:number,w:number,s:number,e:number,n:number){return lng>=w&&lng<=e&&lat>=s&&lat<=n}
function cloudFraction(v:any){const x=String(v??'').toUpperCase();if(!x)return 0;if(/OVC/.test(x))return 1;if(/BKN/.test(x))return .78;if(/SCT/.test(x))return .5;if(/FEW/.test(x))return .25;if(/CLR|SKC|CAVOK/.test(x))return .03;const q=Number(x);return Number.isFinite(q)?clamp(q>1?q/8:q,0,1):.18}

async function surfaceObs(w:number,s:number,e:number,n:number,limit:number){
  const fields="timeobs,stationname,locationname,winddir,windspeed,windgust,cloudcover,cloudbase,sst,waveheight,visibility,temperature,dewpoint,sealevelpress";
  const p=new URLSearchParams({where:"1=1",geometry:`${w},${s},${e},${n}`,geometryType:"esriGeometryEnvelope",inSR:"4326",spatialRel:"esriSpatialRelIntersects",outFields:fields,returnGeometry:"true",outSR:"4326",f:"geojson",resultRecordCount:String(limit)});
  const url=`https://mapservices.weather.noaa.gov/vector/rest/services/obs/surface_obs/MapServer/10/query?${p}`;
  const d=await getJson(url,10000);
  return (d.features||[]).map((f:any)=>{const c=f?.geometry?.coordinates||[],p=f?.properties||{};return {lng:num(c[0]),lat:num(c[1]),station:p.stationname||p.locationname||null,observed_at:p.timeobs?new Date(Number(p.timeobs)).toISOString():null,wind_dir_deg:num(p.winddir),wind_speed_kt:num(p.windspeed),wind_gust_kt:num(p.windgust),cloud_cover_raw:p.cloudcover??null,cloud_fraction:cloudFraction(p.cloudcover),cloud_base:p.cloudbase??null,sea_surface_temp:p.sst??null,wave_height_ft:num(p.waveheight),visibility_mi:num(p.visibility),temperature_f:num(p.temperature),dewpoint_f:num(p.dewpoint),sea_level_pressure_mb:num(p.sealevelpress)}}).filter((x:any)=>x.lng!=null&&x.lat!=null);
}

async function stations(type:"currents"|"waterlevels"){
  const ref=type==="currents"?currentStationsCache:waterStationsCache;
  if(ref&&Date.now()-ref.at<60*60*1000)return ref.stations;
  const url=`https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=${type}&units=metric`;
  const d=await getJson(url,10000);const a=Array.isArray(d?.stations)?d.stations:[];
  const out=a.map((x:any)=>({id:String(x.id||""),name:x.name||null,lat:num(x.lat),lng:num(x.lng)})).filter((x:any)=>x.id&&x.lat!=null&&x.lng!=null);
  if(type==="currents")currentStationsCache={at:Date.now(),stations:out};else waterStationsCache={at:Date.now(),stations:out};
  return out;
}

async function currentVectors(w:number,s:number,e:number,n:number,maxStations:number){
  const ss=(await stations("currents")).filter((x:any)=>bboxHit(x.lng,x.lat,w,s,e,n)).slice(0,maxStations);
  const rows=await Promise.all(ss.map(async(st:any)=>{
    const q=new URLSearchParams({date:"latest",station:st.id,product:"currents",time_zone:"gmt",units:"metric",application:"BridgePoint",format:"json"});
    try{const d=await getJson(`https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?${q}`,6500);const a=Array.isArray(d?.data)?d.data:[];const x=a[a.length-1]||null;if(!x)return null;return {...st,speed_mps:num(x.s),direction_deg:num(x.d),observed_at:x.t||null,bin:x.b||null,source:"NOAA CO-OPS"};}catch{return null}
  }));
  return rows.filter(Boolean);
}

async function tideLevels(w:number,s:number,e:number,n:number,maxStations:number){
  const ss=(await stations("waterlevels")).filter((x:any)=>bboxHit(x.lng,x.lat,w,s,e,n)).slice(0,maxStations);
  const rows=await Promise.all(ss.map(async(st:any)=>{
    const q=new URLSearchParams({date:"latest",station:st.id,product:"water_level",datum:"MLLW",time_zone:"gmt",units:"metric",application:"BridgePoint",format:"json"});
    try{const d=await getJson(`https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?${q}`,6000);const a=Array.isArray(d?.data)?d.data:[];const x=a[a.length-1]||null;if(!x)return null;return {...st,water_level_m:num(x.v),observed_at:x.t||null,quality:x.q||null,source:"NOAA CO-OPS"};}catch{return null}
  }));
  return rows.filter(Boolean);
}

function stormCandidates(v:any,out:any[]=[]){if(!v||out.length>60)return out;if(Array.isArray(v)){for(const x of v)stormCandidates(x,out);return out}if(typeof v!=="object")return out;const lat=num(v.latitude??v.lat??v.Latitude??v.LAT),lng=num(v.longitude??v.lon??v.lng??v.Longitude??v.LON);if(lat!=null&&lng!=null){out.push({id:v.id||v.stormId||v.atcf||v.name||null,name:v.name||v.stormName||v.storm_name||null,classification:v.classification||v.type||v.status||null,lat,lng,wind_mph:num(v.windSpeedMph??v.wind_mph??v.maxWindMph??v.wind),pressure_mb:num(v.pressure??v.pressureMb??v.mslp),movement_dir:v.movementDir||v.movement_dir||null,movement_mph:num(v.movementSpeedMph??v.movement_mph),raw:v})}for(const x of Object.values(v))if(x&&typeof x==="object")stormCandidates(x,out);return out}
async function nhcStorms(w:number,s:number,e:number,n:number){try{const d=await getJson("https://www.nhc.noaa.gov/maps/currentStorms/currentStorms.json",8500);const seen=new Set<string>();return stormCandidates(d).filter((x:any)=>bboxHit(x.lng,x.lat,w,s,e,n)).filter((x:any)=>{const k=`${x.id||x.name||""}|${x.lat}|${x.lng}`;if(seen.has(k))return false;seen.add(k);return true}).slice(0,20)}catch{return []}}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{headers:JSON_HEADERS});
  if(req.method!=="POST")return new Response(JSON.stringify({error:"POST required"}),{status:405,headers:JSON_HEADERS});
  try{
    const body=await req.json().catch(()=>({}));
    let w=clamp(Number(body.west??-130),-180,180),s=clamp(Number(body.south??20),-90,90),e=clamp(Number(body.east??-60),-180,180),n=clamp(Number(body.north??55),-90,90);
    if(!(w<e&&s<n))throw new Error("invalid bbox");
    const zoom=clamp(Number(body.zoom??5),0,24),modes=Array.isArray(body.modes)?body.modes.map((x:any)=>String(x)):[];
    const obsLimit=clamp(Number(body.observation_limit??(zoom<5?250:zoom<9?420:650)),40,900);
    const wantOcean=modes.includes("ocean"),wantTides=modes.includes("tides"),wantStorms=modes.includes("hurricanes")||modes.includes("all");
    const [obs,currents,tides,storms]=await Promise.all([
      surfaceObs(w,s,e,n,obsLimit).catch(()=>[]),
      wantOcean?currentVectors(w,s,e,n,zoom<6?10:18):Promise.resolve([]),
      wantTides?tideLevels(w,s,e,n,zoom<6?8:14):Promise.resolve([]),
      wantStorms?nhcStorms(w,s,e,n):Promise.resolve([])
    ]);
    return new Response(JSON.stringify({complete:true,version:2185,generated_at:new Date().toISOString(),bbox:[w,s,e,n],zoom,observations:obs,currents,tides,storms,sources:[
      {key:"NOAA_SURFACE_OBS",provider:"NOAA/NWS MADIS",url:"https://mapservices.weather.noaa.gov/vector/rest/services/obs/surface_obs/MapServer",refresh_seconds:600,role:"wind/cloud/wave/surface observations"},
      {key:"NOAA_COOPS_CURRENTS",provider:"NOAA CO-OPS",url:"https://api.tidesandcurrents.noaa.gov/api/prod/",refresh_seconds:360,role:"real-time coastal current vectors"},
      {key:"NOAA_COOPS_WATER_LEVEL",provider:"NOAA CO-OPS",url:"https://api.tidesandcurrents.noaa.gov/api/prod/",refresh_seconds:360,role:"observed coastal water levels"},
      {key:"NHC_CURRENT_STORMS",provider:"NOAA/NHC",url:"https://www.nhc.noaa.gov/maps/currentStorms/currentStorms.json",refresh_seconds:120,role:"current tropical cyclone position/intensity"}
    ],truth_notice:"Live Earth uses current NOAA observations where available. Surface station vectors are observations, not a continuous atmospheric analysis. BridgePoint visually interpolates between samples for motion; it does not invent measured values. Ocean currents and water levels render only where CO-OPS returns current station data. Tropical cyclone positions/intensity come from NHC."}),{headers:JSON_HEADERS});
  }catch(e){return new Response(JSON.stringify({complete:false,version:2185,error:String(e?.message||e)}),{status:400,headers:JSON_HEADERS})}
});
