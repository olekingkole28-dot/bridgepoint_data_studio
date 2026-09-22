import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const VERSION=5305;
const U=Deno.env.get("SUPABASE_URL")!;
const SERVICE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}});

const PRESETS={
  middletown:{state:"CT",cell:"MIDDLETOWN_CT",lat:41.5525,lon:-72.6575,span_km:4.1},
  manhattan:{state:"NY",cell:"DOWNTOWN_MANHATTAN_NY",lat:40.7100,lon:-74.0035,span_km:2.2}
} as const;

const STATES=new Set([
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
  "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
  "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC","PR","GU","VI","AS","MP","UM"
]);
const TERRAIN="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const TIGER="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Transportation/MapServer";
const HYDRO="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Hydro/MapServer";
const STATE_LAYER="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/0/query";
const H={
  "content-type":"application/json; charset=utf-8",
  "cache-control":"public, max-age=300, stale-while-revalidate=900",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"content-type,apikey,authorization,x-client-info",
  "access-control-allow-methods":"GET,POST,OPTIONS"
};
const memory=new Map<string,{at:number,payload:any}>();

const ALLOWED_ORIGINS=new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online",
  "https://olekingkole28-dot.github.io"
]);
function allowedOrigin(origin:string){
  if(!origin)return true;
  if(ALLOWED_ORIGINS.has(origin))return true;
  try{
    const u=new URL(origin);
    return (u.hostname==="localhost"||u.hostname==="127.0.0.1")&&(u.protocol==="http:"||u.protocol==="https:");
  }catch{return false}
}
async function sha256(s:string){
  const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
function firstIp(req:Request){
  const raw=req.headers.get("x-forwarded-for")||req.headers.get("cf-connecting-ip")||req.headers.get("x-real-ip")||"unknown";
  return raw.split(",")[0].trim().slice(0,80);
}

type Bounds={state:string;cell:string;west:number;south:number;east:number;north:number;lat:number;lon:number;span_km:number};

function clamp(n:number,a:number,b:number){return Math.max(a,Math.min(b,n))}
function boundsFromCenter(state:string,lat:number,lon:number,spanKm:number,cell:string):Bounds{
  spanKm=clamp(spanKm,1.0,5.5);
  lat=clamp(lat,-14.8,71.8); lon=clamp(lon,-179.9,179.9);
  const dLat=(spanKm/110.574)/2;
  const cos=Math.max(.12,Math.cos(lat*Math.PI/180));
  const dLon=(spanKm/(111.320*cos))/2;
  return {state,cell,west:lon-dLon,south:lat-dLat,east:lon+dLon,north:lat+dLat,lat,lon,span_km:spanKm};
}
function makePoints(B:Bounds,width:number,height:number){
  const out:number[][]=[];
  for(let y=0;y<height;y++){
    const fy=height<=1?0:y/(height-1),lat=B.north+(B.south-B.north)*fy;
    for(let x=0;x<width;x++){
      const fx=width<=1?0:x/(width-1);out.push([B.west+(B.east-B.west)*fx,lat]);
    }
  }
  return out;
}
async function resolveJurisdiction(lat:number,lon:number){
  const q=new URL(STATE_LAYER);
  q.searchParams.set("where","1=1");
  q.searchParams.set("geometry",lon+","+lat);
  q.searchParams.set("geometryType","esriGeometryPoint");
  q.searchParams.set("inSR","4326");
  q.searchParams.set("spatialRel","esriSpatialRelIntersects");
  q.searchParams.set("outFields","STUSAB,NAME,GEOID");
  q.searchParams.set("returnGeometry","false");
  q.searchParams.set("f","json");
  const r=await fetch(q,{headers:{accept:"application/json","user-agent":"BridgePointHorizon/3022"},signal:AbortSignal.timeout(12000)});
  const txt=await r.text();if(!r.ok)throw new Error("STATE_RESOLVE_"+r.status+":"+txt.slice(0,140));
  const j=JSON.parse(txt),f=Array.isArray(j?.features)?j.features[0]:null,a=f?.attributes||{};
  const state=String(a.STUSAB||"").toUpperCase();
  if(!state||!STATES.has(state))return null;
  return {state,name:String(a.NAME||state),geoid:String(a.GEOID||"")};
}

async function terrain(B:Bounds){
  const width=19,height=19,points=makePoints(B,width,height);
  const p=new URLSearchParams();
  p.set("geometryType","esriGeometryMultipoint");
  p.set("geometry",JSON.stringify({points,spatialReference:{wkid:4326}}));
  p.set("returnFirstValueOnly","true");
  p.set("interpolation","RSP_BilinearInterpolation");
  p.set("outFields","Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Resolution_X,Resolution_Y");
  p.set("f","json");
  const r=await fetch(TERRAIN,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded;charset=UTF-8",accept:"application/json","user-agent":"BridgePointHorizon/3022"},body:p.toString(),signal:AbortSignal.timeout(18000)});
  const txt=await r.text(); if(!r.ok)throw new Error("TERRAIN_"+r.status+":"+txt.slice(0,160));
  const j=JSON.parse(txt); if(j?.error)throw new Error("TERRAIN_API:"+JSON.stringify(j.error).slice(0,180));
  const rows=Array.isArray(j?.samples)?j.samples:[];
  const values=new Array(width*height).fill(0),valid=new Array(width*height).fill(false);
  const ids=rows.map((s:any)=>Number(s?.locationId)).filter(Number.isInteger);
  const oneBased=ids.length>0&&Math.min(...ids)>=1&&Math.max(...ids)<=values.length&&!ids.includes(0);
  let meta:any={};
  for(let i=0;i<rows.length;i++){
    const row=rows[i]||{},raw=Number(row.locationId);
    let idx=Number.isInteger(raw)?raw-(oneBased?1:0):i;
    if(idx<0||idx>=values.length)idx=i<values.length?i:-1;if(idx<0)continue;
    const v=Number(row.value??row.Elevation??row.elevation);
    if(Number.isFinite(v)&&v>-12000&&v<10000){values[idx]=v;valid[idx]=true}
    const a=row.attributes||{};
    if(!meta.dataset_id&&a.Dataset_ID)meta.dataset_id=String(a.Dataset_ID);
    if(!meta.product_name&&a.ProductName)meta.product_name=String(a.ProductName);
    if(!meta.vertical_datum&&a.VerticalDatum)meta.vertical_datum=String(a.VerticalDatum);
  }
  if(!valid.some(Boolean))throw new Error("TERRAIN_NO_DATA");
  let last:number|null=null;
  for(let i=0;i<values.length;i++){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  last=null;for(let i=values.length-1;i>=0;i--){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  return {width,height,heights_m:values,valid_mask:valid,truth:"SOURCE_SAMPLED_USGS_3DEP",source:"USGS 3DEP",meta};
}
async function arcLayer(B:Bounds,base:string,layer:number,kind:string,fields:string){
  const q=new URL(base+"/"+layer+"/query");
  q.searchParams.set("where","1=1");
  q.searchParams.set("geometry",JSON.stringify({xmin:B.west,ymin:B.south,xmax:B.east,ymax:B.north,spatialReference:{wkid:4326}}));
  q.searchParams.set("geometryType","esriGeometryEnvelope");q.searchParams.set("inSR","4326");
  q.searchParams.set("spatialRel","esriSpatialRelIntersects");q.searchParams.set("outFields",fields);
  q.searchParams.set("returnGeometry","true");q.searchParams.set("outSR","4326");q.searchParams.set("f","geojson");
  const r=await fetch(q,{headers:{accept:"application/geo+json,application/json","user-agent":"BridgePointHorizon/3022"},signal:AbortSignal.timeout(16000)});
  const txt=await r.text();if(!r.ok)throw new Error(kind+"_"+r.status+":"+txt.slice(0,140));
  const j=JSON.parse(txt);if(j?.error)throw new Error(kind+"_API:"+JSON.stringify(j.error).slice(0,160));
  return (Array.isArray(j?.features)?j.features:[]).map((f:any)=>({kind,geometry:f.geometry,props:{name:f?.properties?.NAME??f?.properties?.FULLNAME??null,mtfcc:f?.properties?.MTFCC??null}})).filter((x:any)=>x.geometry);
}
async function safe<T>(p:Promise<T>,fallback:T){try{return await p}catch(e){console.warn(String((e as any)?.message||e));return fallback}}

async function build(B:Bounds){
  const resolved=await safe(resolveJurisdiction(B.lat,B.lon),null as any);
  const effectiveJurisdiction=resolved||{state:B.state,name:B.state,geoid:"",fallback:true};
  if(resolved?.state)B.state=resolved.state;
  const sceneResp=await db.rpc("bridgepoint_horizon_stream_scene_v3020",{p_state:B.state,p_w:B.west,p_s:B.south,p_e:B.east,p_n:B.north,p_cell:B.cell});
  if(sceneResp.error)throw sceneResp.error;
  const scene=sceneResp.data;
  const [terrainData,primary,secondary,local,rail,waterLine,waterArea]=await Promise.all([
    safe(terrain(B),null as any),
    safe(arcLayer(B,TIGER,2,"ROAD_PRIMARY","NAME,MTFCC"),[]),
    safe(arcLayer(B,TIGER,6,"ROAD_SECONDARY","NAME,MTFCC"),[]),
    safe(arcLayer(B,TIGER,8,"ROAD_LOCAL","NAME,MTFCC"),[]),
    safe(arcLayer(B,TIGER,9,"RAIL","NAME,MTFCC"),[]),
    safe(arcLayer(B,HYDRO,0,"WATER_LINE","FULLNAME,MTFCC"),[]),
    safe(arcLayer(B,HYDRO,1,"WATER_AREA","FULLNAME,MTFCC"),[])
  ]);
  return {...scene,version:5305,streamed:true,span_km:B.span_km,resolved_jurisdiction:effectiveJurisdiction,terrain:terrainData,transport:[...primary,...secondary,...local,...rail],water:[...waterLine,...waterArea],
    game_art:{mode:"OPEN_SURVIVAL_DRESSING",notice:"Game-art props, enemies and loot are fictional dressing and do not assert real-world object locations."},
    attribution:[...(Array.isArray(scene?.attribution)?scene.attribution:[]),"Terrain: U.S. Geological Survey 3DEP where available","Roads / rail / hydrography: U.S. Census Bureau TIGERweb (public domain)","Survival art runtime: commercially-usable open game assets"],
    public_contract:{streamed_cells:true,max_span_km:5.5,arbitrary_bbox_export:false,b2b_intelligence:false,raw_property_attributes:false}
  };
}

Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin")||"";
  if(req.method==="OPTIONS"){
    if(!allowedOrigin(origin))return new Response(null,{status:403,headers:H});
    return new Response(null,{status:204,headers:H});
  }
  if(req.method!=="GET"&&req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"GET_OR_POST_REQUIRED"}),{status:405,headers:H});
  if(!allowedOrigin(origin))return new Response(JSON.stringify({complete:false,error:"ORIGIN_NOT_ALLOWED"}),{status:403,headers:{...H,"cache-control":"no-store"}});
  try{
    const ip=firstIp(req),day=new Date().toISOString().slice(0,10);
    const subject=(await sha256(ip+"|"+day+"|horizon-stream-v5305")).slice(0,48);
    let originHost="";try{originHost=origin?new URL(origin).host:""}catch{}
    const gate=await db.rpc("bridgepoint_public_tile_gate_v5300",{
      p_subject_hash:subject,p_asset_key:"HORIZON_WORLD_STREAM_V5305",p_origin_host:originHost
    });
    if(gate.error)throw new Error("HORIZON_RATE_GATE");
    if(gate.data?.allowed!==true)return new Response(JSON.stringify({complete:false,error:"RATE_LIMITED",retry_after_seconds:60}),{status:429,headers:{...H,"cache-control":"no-store","retry-after":"60"}});

    const url=new URL(req.url);let q:any=Object.fromEntries(url.searchParams.entries());
    if(req.method==="POST"){try{q={...q,...await req.clone().json()}}catch(_){}}
    const preset=String(q.cell||"").toLowerCase();
    if(String(q.mode||"").toLowerCase()==="resolve"){
      const lat=Number(q.lat),lon=Number(q.lon);
      if(!Number.isFinite(lat)||!Number.isFinite(lon))throw new Error("HORIZON_LAT_LON_REQUIRED");
      const resolved=await safe(resolveJurisdiction(lat,lon),null as any);
      return new Response(JSON.stringify({complete:true,version:5305,inside_us_universe:resolved?true:null,resolution_available:Boolean(resolved),resolved_jurisdiction:resolved}),{headers:{...H,"cache-control":"no-store"}});
    }
    let B:Bounds;
    if(preset==="middletown"||preset==="manhattan"){
      const p=PRESETS[preset as keyof typeof PRESETS];
      B=boundsFromCenter(p.state,p.lat,p.lon,p.span_km,p.cell);
    }else{
      const state=String(q.state||"CT").toUpperCase();
      if(!STATES.has(state))throw new Error("HORIZON_STATE_NOT_ALLOWED");
      const lat=Number(q.lat),lon=Number(q.lon),span=Number(q.span_km||q.span||3.2);
      if(!Number.isFinite(lat)||!Number.isFinite(lon))throw new Error("HORIZON_LAT_LON_REQUIRED");
      const cell=String(q.cell_id||("STREAM_"+state+"_"+lat.toFixed(4)+"_"+lon.toFixed(4))).slice(0,96);
      B=boundsFromCenter(state,lat,lon,span,cell);
    }
    const key=[B.state,B.lat.toFixed(4),B.lon.toFixed(4),B.span_km.toFixed(1)].join(":");
    const cached=memory.get(key);
    if(cached&&Date.now()-cached.at<5*60*1000)return new Response(JSON.stringify({...cached.payload,cache:"edge-memory"}),{headers:H});
    const payload=await build(B);memory.set(key,{at:Date.now(),payload});
    return new Response(JSON.stringify({...payload,cache:"fresh"}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e).slice(0,500)}),{status:500,headers:{...H,"cache-control":"no-store"}});
  }
});