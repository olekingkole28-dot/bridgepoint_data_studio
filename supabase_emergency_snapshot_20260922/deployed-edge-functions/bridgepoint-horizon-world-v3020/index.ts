import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const VERSION=3020;
const U=Deno.env.get("SUPABASE_URL")!;
const SERVICE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}});

type Anchor={name:string;lat:number;lon:number};
const ANCHORS:Record<string,Anchor>={
  AL:{name:"Birmingham",lat:33.5186,lon:-86.8104},AK:{name:"Anchorage",lat:61.2181,lon:-149.9003},
  AZ:{name:"Phoenix",lat:33.4484,lon:-112.0740},AR:{name:"Little Rock",lat:34.7465,lon:-92.2896},
  CA:{name:"Los Angeles",lat:34.0522,lon:-118.2437},CO:{name:"Denver",lat:39.7392,lon:-104.9903},
  CT:{name:"Middletown",lat:41.5623,lon:-72.6506},DE:{name:"Wilmington",lat:39.7391,lon:-75.5398},
  FL:{name:"Miami",lat:25.7617,lon:-80.1918},GA:{name:"Atlanta",lat:33.7490,lon:-84.3880},
  HI:{name:"Honolulu",lat:21.3069,lon:-157.8583},ID:{name:"Boise",lat:43.6150,lon:-116.2023},
  IL:{name:"Chicago",lat:41.8781,lon:-87.6298},IN:{name:"Indianapolis",lat:39.7684,lon:-86.1581},
  IA:{name:"Des Moines",lat:41.5868,lon:-93.6250},KS:{name:"Wichita",lat:37.6872,lon:-97.3301},
  KY:{name:"Louisville",lat:38.2527,lon:-85.7585},LA:{name:"New Orleans",lat:29.9511,lon:-90.0715},
  ME:{name:"Portland",lat:43.6591,lon:-70.2568},MD:{name:"Baltimore",lat:39.2904,lon:-76.6122},
  MA:{name:"Boston",lat:42.3601,lon:-71.0589},MI:{name:"Detroit",lat:42.3314,lon:-83.0458},
  MN:{name:"Minneapolis",lat:44.9778,lon:-93.2650},MS:{name:"Jackson",lat:32.2988,lon:-90.1848},
  MO:{name:"St. Louis",lat:38.6270,lon:-90.1994},MT:{name:"Billings",lat:45.7833,lon:-108.5007},
  NE:{name:"Omaha",lat:41.2565,lon:-95.9345},NV:{name:"Las Vegas",lat:36.1699,lon:-115.1398},
  NH:{name:"Manchester",lat:42.9956,lon:-71.4548},NJ:{name:"Newark",lat:40.7357,lon:-74.1724},
  NM:{name:"Albuquerque",lat:35.0844,lon:-106.6504},NY:{name:"Lower Manhattan",lat:40.7100,lon:-74.0035},
  NC:{name:"Charlotte",lat:35.2271,lon:-80.8431},ND:{name:"Fargo",lat:46.8772,lon:-96.7898},
  OH:{name:"Columbus",lat:39.9612,lon:-82.9988},OK:{name:"Oklahoma City",lat:35.4676,lon:-97.5164},
  OR:{name:"Portland",lat:45.5152,lon:-122.6784},PA:{name:"Philadelphia",lat:39.9526,lon:-75.1652},
  RI:{name:"Providence",lat:41.8240,lon:-71.4128},SC:{name:"Charleston",lat:32.7765,lon:-79.9311},
  SD:{name:"Sioux Falls",lat:43.5446,lon:-96.7311},TN:{name:"Nashville",lat:36.1627,lon:-86.7816},
  TX:{name:"Austin",lat:30.2672,lon:-97.7431},UT:{name:"Salt Lake City",lat:40.7608,lon:-111.8910},
  VT:{name:"Burlington",lat:44.4759,lon:-73.2121},VA:{name:"Richmond",lat:37.5407,lon:-77.4360},
  WA:{name:"Seattle",lat:47.6062,lon:-122.3321},WV:{name:"Charleston",lat:38.3498,lon:-81.6326},
  WI:{name:"Milwaukee",lat:43.0389,lon:-87.9065},WY:{name:"Cheyenne",lat:41.1400,lon:-104.8202},
  DC:{name:"Washington",lat:38.9072,lon:-77.0369},PR:{name:"San Juan",lat:18.4655,lon:-66.1057},
  VI:{name:"Charlotte Amalie",lat:18.3419,lon:-64.9307},GU:{name:"Hagåtña",lat:13.4443,lon:144.7937},
  AS:{name:"Pago Pago",lat:-14.2756,lon:-170.7020},MP:{name:"Saipan",lat:15.1778,lon:145.7500}
};

const TERRAIN="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const TIGER="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Transportation/MapServer";
const HYDRO="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Hydro/MapServer";
const H={
  "content-type":"application/json; charset=utf-8",
  "cache-control":"public, max-age=300, stale-while-revalidate=900",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"content-type,apikey,authorization,x-client-info",
  "access-control-allow-methods":"GET,POST,OPTIONS"
};
const memory=new Map<string,{at:number,payload:any}>();

type Bounds={state:string;cell:string;west:number;south:number;east:number;north:number;lat:number;lon:number;span:number};

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
async function terrain(B:Bounds){
  const width=17,height=17,points=makePoints(B,width,height);
  const p=new URLSearchParams();
  p.set("geometryType","esriGeometryMultipoint");
  p.set("geometry",JSON.stringify({points,spatialReference:{wkid:4326}}));
  p.set("returnFirstValueOnly","true");
  p.set("interpolation","RSP_BilinearInterpolation");
  p.set("outFields","Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Resolution_X,Resolution_Y");
  p.set("f","json");
  const r=await fetch(TERRAIN,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded;charset=UTF-8",accept:"application/json","user-agent":"BridgePointHorizon/3020"},body:p.toString(),signal:AbortSignal.timeout(18000)});
  const txt=await r.text();
  if(!r.ok)throw new Error("TERRAIN_"+r.status+":"+txt.slice(0,140));
  const j=JSON.parse(txt);if(j?.error)throw new Error("TERRAIN_API");
  const rows=Array.isArray(j?.samples)?j.samples:[];
  const values=new Array(width*height).fill(0),valid=new Array(width*height).fill(false);
  const ids=rows.map((s:any)=>Number(s?.locationId)).filter(Number.isInteger);
  const oneBased=ids.length>0&&Math.min(...ids)>=1&&Math.max(...ids)<=values.length&&!ids.includes(0);
  let meta:any={};
  for(let i=0;i<rows.length;i++){
    const row=rows[i]||{},raw=Number(row.locationId);
    let idx=Number.isInteger(raw)?raw-(oneBased?1:0):i;if(idx<0||idx>=values.length)idx=i<values.length?i:-1;if(idx<0)continue;
    const v=Number(row.value??row.Elevation??row.elevation);
    if(Number.isFinite(v)&&v>-12000&&v<10000){values[idx]=v;valid[idx]=true}
    const a=row.attributes||{};
    if(!meta.dataset_id&&a.Dataset_ID)meta.dataset_id=String(a.Dataset_ID);
    if(!meta.product_name&&a.ProductName)meta.product_name=String(a.ProductName);
  }
  if(!valid.some(Boolean))return null;
  let last:number|null=null;
  for(let i=0;i<values.length;i++){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  last=null;for(let i=values.length-1;i>=0;i--){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  return{width,height,heights_m:values,valid_mask:valid,truth:"SOURCE_SAMPLED_USGS_3DEP",source:"USGS 3DEP",meta};
}
async function arcLayer(B:Bounds,base:string,layer:number,kind:string,fields:string){
  const q=new URL(base+"/"+layer+"/query");
  q.searchParams.set("where","1=1");
  q.searchParams.set("geometry",JSON.stringify({xmin:B.west,ymin:B.south,xmax:B.east,ymax:B.north,spatialReference:{wkid:4326}}));
  q.searchParams.set("geometryType","esriGeometryEnvelope");q.searchParams.set("inSR","4326");q.searchParams.set("spatialRel","esriSpatialRelIntersects");
  q.searchParams.set("outFields",fields);q.searchParams.set("returnGeometry","true");q.searchParams.set("outSR","4326");q.searchParams.set("f","geojson");
  const r=await fetch(q,{headers:{accept:"application/geo+json,application/json","user-agent":"BridgePointHorizon/3020"},signal:AbortSignal.timeout(16000)});
  const txt=await r.text();if(!r.ok)throw new Error(kind+"_"+r.status);
  const j=JSON.parse(txt);if(j?.error)throw new Error(kind+"_API");
  return(Array.isArray(j?.features)?j.features:[]).map((f:any)=>({kind,geometry:f.geometry,props:{name:f?.properties?.NAME??f?.properties?.FULLNAME??null,mtfcc:f?.properties?.MTFCC??null}})).filter((x:any)=>x.geometry);
}
async function safe<T>(p:Promise<T>,fallback:T){try{return await p}catch(e){console.warn(String((e as any)?.message||e));return fallback}}

function parseBounds(url:URL,body:any):Bounds{
  const state=String(body?.state??url.searchParams.get("state")??"NY").toUpperCase();
  const anchor=ANCHORS[state];if(!anchor)throw new Error("HORIZON_JURISDICTION_NOT_ALLOWED");
  let lat=Number(body?.lat??url.searchParams.get("lat")??anchor.lat);
  let lon=Number(body?.lon??url.searchParams.get("lon")??anchor.lon);
  let span=Number(body?.span??url.searchParams.get("span")??0.028);
  if(!Number.isFinite(lat)||!Number.isFinite(lon)){lat=anchor.lat;lon=anchor.lon}
  span=Math.max(0.012,Math.min(0.055,Number.isFinite(span)?span:0.028));
  const latHalf=span/2,lonHalf=span/(2*Math.max(.25,Math.cos(lat*Math.PI/180)));
  const west=lon-lonHalf,east=lon+lonHalf,south=lat-latHalf,north=lat+latHalf;
  return{state,cell:`${state}_${lat.toFixed(4)}_${lon.toFixed(4)}`,west,south,east,north,lat,lon,span};
}
async function build(B:Bounds){
  const sceneResp=await db.rpc("bridgepoint_horizon_scene_v3020",{p_state:B.state,p_w:B.west,p_s:B.south,p_e:B.east,p_n:B.north,p_cell:B.cell});
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
  const a=ANCHORS[B.state];
  return{
    ...scene,version:VERSION,jurisdiction:B.state,place_name:a?.name||B.state,
    center:{lon:B.lon,lat:B.lat},terrain:terrainData,transport:[...primary,...secondary,...local,...rail],water:[...waterLine,...waterArea],
    national_stream:{enabled:true,jurisdictions:Object.keys(ANCHORS).length,cell_span_degrees:B.span,arbitrary_center:true},
    game_art:{mode:"CC0_SURVIVAL_DRESSING",notice:"Game art is procedural/CC0 dressing and is not a claim about exact real-world object locations."},
    attribution:[
      ...(Array.isArray(scene?.attribution)?scene.attribution:[]),
      "Terrain: U.S. Geological Survey 3DEP where available",
      "Roads / rail / hydrography: U.S. Census Bureau TIGERweb (public domain)",
      "Survival art: CC0/open game art, streamed separately"
    ],
    public_contract:{us_jurisdiction_stream:true,b2b_intelligence:false,raw_property_attributes:false,owner_data:false}
  };
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:H});
  if(req.method!=="GET"&&req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"GET_OR_POST_REQUIRED"}),{status:405,headers:H});
  try{
    const url=new URL(req.url);let body:any={};
    if(req.method==="POST"){try{body=await req.clone().json()}catch(_){}}
    const B=parseBounds(url,body);
    const key=`${B.state}:${B.lat.toFixed(4)}:${B.lon.toFixed(4)}:${B.span.toFixed(3)}`;
    const cached=memory.get(key);
    if(cached&&Date.now()-cached.at<5*60*1000)return new Response(JSON.stringify({...cached.payload,cache:"edge-memory"}),{headers:H});
    const payload=await build(B);memory.set(key,{at:Date.now(),payload});
    return new Response(JSON.stringify({...payload,cache:"fresh"}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e).slice(0,500)}),{status:500,headers:{...H,"cache-control":"no-store"}});
  }
});