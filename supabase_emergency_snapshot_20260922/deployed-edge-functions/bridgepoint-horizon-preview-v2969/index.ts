import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const VERSION=2969;
const U=Deno.env.get("SUPABASE_URL")!;
const SERVICE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}});
const B={west:-72.680,south:41.535,east:-72.635,north:41.570};
const CENTER={lon:(B.west+B.east)/2,lat:(B.south+B.north)/2};
const TERRAIN="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const TIGER="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Transportation/MapServer";
const HYDRO="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Hydro/MapServer";
const H={
  "content-type":"application/json; charset=utf-8",
  "cache-control":"public, max-age=900, stale-while-revalidate=1800",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"content-type,apikey,authorization,x-client-info",
  "access-control-allow-methods":"GET,POST,OPTIONS"
};
let memory:{at:number,payload:any}|null=null;

function makePoints(width:number,height:number){
  const out:number[][]=[];
  for(let y=0;y<height;y++){
    const fy=height<=1?0:y/(height-1),lat=B.north+(B.south-B.north)*fy;
    for(let x=0;x<width;x++){
      const fx=width<=1?0:x/(width-1);
      out.push([B.west+(B.east-B.west)*fx,lat]);
    }
  }
  return out;
}
async function terrain(){
  const width=19,height=19,points=makePoints(width,height);
  const p=new URLSearchParams();
  p.set("geometryType","esriGeometryMultipoint");
  p.set("geometry",JSON.stringify({points,spatialReference:{wkid:4326}}));
  p.set("returnFirstValueOnly","true");
  p.set("interpolation","RSP_BilinearInterpolation");
  p.set("outFields","Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Resolution_X,Resolution_Y");
  p.set("f","json");
  const r=await fetch(TERRAIN,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded;charset=UTF-8",accept:"application/json","user-agent":"BridgePointHorizon/2969"},body:p.toString(),signal:AbortSignal.timeout(18000)});
  const txt=await r.text(); if(!r.ok) throw new Error("TERRAIN_"+r.status+":"+txt.slice(0,160));
  const j=JSON.parse(txt); if(j?.error) throw new Error("TERRAIN_API:"+JSON.stringify(j.error).slice(0,180));
  const rows=Array.isArray(j?.samples)?j.samples:[];
  const values=new Array(width*height).fill(0),valid=new Array(width*height).fill(false);
  const ids=rows.map((s:any)=>Number(s?.locationId)).filter(Number.isInteger);
  const oneBased=ids.length>0&&Math.min(...ids)>=1&&Math.max(...ids)<=values.length&&!ids.includes(0);
  let meta:any={};
  for(let i=0;i<rows.length;i++){
    const row=rows[i]||{},raw=Number(row.locationId);let idx=Number.isInteger(raw)?raw-(oneBased?1:0):i;if(idx<0||idx>=values.length)idx=i<values.length?i:-1;if(idx<0)continue;
    const v=Number(row.value??row.Elevation??row.elevation);if(Number.isFinite(v)&&v>-12000&&v<10000){values[idx]=v;valid[idx]=true}
    const a=row.attributes||{};if(!meta.dataset_id&&a.Dataset_ID)meta.dataset_id=String(a.Dataset_ID);if(!meta.product_name&&a.ProductName)meta.product_name=String(a.ProductName);if(!meta.vertical_datum&&a.VerticalDatum)meta.vertical_datum=String(a.VerticalDatum);
  }
  if(!valid.some(Boolean)) throw new Error("TERRAIN_NO_DATA");
  let last:number|null=null;for(let i=0;i<values.length;i++){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  last=null;for(let i=values.length-1;i>=0;i--){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  return {width,height,heights_m:values,valid_mask:valid,truth:"SOURCE_SAMPLED_USGS_3DEP",source:"USGS 3DEP",meta};
}
async function arcLayer(base:string,layer:number,kind:string,fields:string){
  const q=new URL(base+"/"+layer+"/query");
  q.searchParams.set("where","1=1");
  q.searchParams.set("geometry",JSON.stringify({xmin:B.west,ymin:B.south,xmax:B.east,ymax:B.north,spatialReference:{wkid:4326}}));
  q.searchParams.set("geometryType","esriGeometryEnvelope");
  q.searchParams.set("inSR","4326");
  q.searchParams.set("spatialRel","esriSpatialRelIntersects");
  q.searchParams.set("outFields",fields);
  q.searchParams.set("returnGeometry","true");
  q.searchParams.set("outSR","4326");
  q.searchParams.set("f","geojson");
  const r=await fetch(q,{headers:{accept:"application/geo+json,application/json","user-agent":"BridgePointHorizon/2969"},signal:AbortSignal.timeout(16000)});
  const txt=await r.text(); if(!r.ok) throw new Error(kind+"_"+r.status+":"+txt.slice(0,140));
  const j=JSON.parse(txt); if(j?.error) throw new Error(kind+"_API:"+JSON.stringify(j.error).slice(0,160));
  return (Array.isArray(j?.features)?j.features:[]).map((f:any)=>({kind,geometry:f.geometry,props:{name:f?.properties?.NAME??f?.properties?.FULLNAME??null,mtfcc:f?.properties?.MTFCC??null}})).filter((x:any)=>x.geometry);
}
async function safe<T>(p:Promise<T>,fallback:T){try{return await p}catch(e){console.warn(String((e as any)?.message||e));return fallback}}

async function build(){
  const sceneResp=await db.rpc("bridgepoint_horizon_preview_scene_v2969");
  if(sceneResp.error) throw sceneResp.error;
  const scene=sceneResp.data;
  const [terrainData,primary,secondary,local,rail,waterLine,waterArea]=await Promise.all([
    safe(terrain(),null as any),
    safe(arcLayer(TIGER,2,"ROAD_PRIMARY","NAME,MTFCC"),[]),
    safe(arcLayer(TIGER,6,"ROAD_SECONDARY","NAME,MTFCC"),[]),
    safe(arcLayer(TIGER,8,"ROAD_LOCAL","NAME,MTFCC"),[]),
    safe(arcLayer(TIGER,9,"RAIL","NAME,MTFCC"),[]),
    safe(arcLayer(HYDRO,0,"WATER_LINE","FULLNAME,MTFCC"),[]),
    safe(arcLayer(HYDRO,1,"WATER_AREA","FULLNAME,MTFCC"),[])
  ]);
  return {
    ...scene,
    version:VERSION,
    center:CENTER,
    terrain:terrainData,
    transport:[...primary,...secondary,...local,...rail],
    water:[...waterLine,...waterArea],
    game_art:{
      mode:"DERIVED_DECORATIVE_ONLY",
      notice:"Weathering, grass, debris, barricades, barrels, crates, fog and survival dressing are game art, not claims about real-world object locations."
    },
    attribution:[
      ...(Array.isArray(scene?.attribution)?scene.attribution:[]),
      "Terrain: U.S. Geological Survey 3DEP",
      "Roads / rail / hydrography: U.S. Census Bureau TIGERweb (public domain)"
    ],
    public_contract:{
      fixed_preview_cell:true,
      arbitrary_bbox_export:false,
      b2b_intelligence:false,
      raw_property_attributes:false
    }
  };
}
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:H});
  if(req.method!=="GET"&&req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"GET_OR_POST_REQUIRED"}),{status:405,headers:H});
  try{
    if(memory&&Date.now()-memory.at<15*60*1000)return new Response(JSON.stringify({...memory.payload,cache:"edge-memory"}),{headers:H});
    const payload=await build();memory={at:Date.now(),payload};
    return new Response(JSON.stringify({...payload,cache:"fresh"}),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e).slice(0,500)}),{status:500,headers:{...H,"cache-control":"no-store"}});
  }
});