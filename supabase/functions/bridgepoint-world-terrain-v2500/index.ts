import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const VERSION=2500;
const IMAGE_SAMPLES="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const H={"content-type":"application/json; charset=utf-8","cache-control":"private, max-age=86400","access-control-allow-origin":"*","access-control-allow-headers":"authorization,apikey,x-client-info,content-type","access-control-allow-methods":"POST,OPTIONS"};
const clamp=(v:number,a:number,b:number)=>Math.max(a,Math.min(b,v));
const finite=(v:any)=>{const n=Number(v);return Number.isFinite(n)?n:null};
const cache=new Map<string,{at:number,payload:any}>();

function tileKey(w:number,s:number,e:number,n:number,width:number,height:number){return [w,s,e,n,width,height].map(v=>Number(v).toFixed(7)).join(":")}
function makePoints(w:number,s:number,e:number,n:number,width:number,height:number){
  const points:number[][]=[];
  for(let y=0;y<height;y++){
    const fy=height<=1?0:y/(height-1);
    const lat=n+(s-n)*fy;
    for(let x=0;x<width;x++){
      const fx=width<=1?0:x/(width-1);
      points.push([w+(e-w)*fx,lat]);
    }
  }
  return points;
}
async function sample(points:number[][]){
  const params=new URLSearchParams();
  params.set("geometryType","esriGeometryMultipoint");
  params.set("geometry",JSON.stringify({points,spatialReference:{wkid:4326}}));
  params.set("returnFirstValueOnly","true");
  params.set("interpolation","RSP_BilinearInterpolation");
  params.set("outFields","Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Resolution_X,Resolution_Y,pubdate,title");
  params.set("f","json");
  const response=await fetch(IMAGE_SAMPLES,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded;charset=UTF-8",accept:"application/json","user-agent":"BridgePointIntelligence/2500 terrain"},body:params.toString(),signal:AbortSignal.timeout(16000)});
  const text=await response.text();
  if(!response.ok)throw new Error(`USGS_3DEP_HTTP_${response.status}:${text.slice(0,240)}`);
  const payload=JSON.parse(text);
  if(payload?.error)throw new Error(`USGS_3DEP:${JSON.stringify(payload.error).slice(0,300)}`);
  return Array.isArray(payload?.samples)?payload.samples:[];
}
function ordered(samples:any[],count:number){
  const values=new Array<number>(count).fill(0),valid=new Array<boolean>(count).fill(false),meta:any={};
  const ids=samples.map(s=>Number(s?.locationId)).filter(Number.isInteger);
  const oneBased=ids.length>0&&Math.min(...ids)>=1&&Math.max(...ids)<=count&&!ids.includes(0);
  for(let i=0;i<samples.length;i++){
    const row=samples[i]||{};const raw=Number(row.locationId);let idx=Number.isInteger(raw)?raw-(oneBased?1:0):i;if(idx<0||idx>=count)idx=i<count?i:-1;if(idx<0)continue;
    const v=finite(row.value??row.Elevation??row.elevation);if(v!==null&&v>=-12000&&v<=10000){values[idx]=v;valid[idx]=true}
    const a=row.attributes||{};if(!meta.dataset_id&&a.Dataset_ID)meta.dataset_id=String(a.Dataset_ID);if(!meta.product_name&&a.ProductName)meta.product_name=String(a.ProductName);if(!meta.vertical_datum&&a.VerticalDatum)meta.vertical_datum=String(a.VerticalDatum);if(!meta.resolution_m)meta.resolution_m=finite(row.resolution??a.Resolution_X);
  }
  // HeightmapTerrainProvider cannot carry holes. Fill sparse no-data cells from nearest previous/next valid source sample; if the tile has no source data, reject it.
  if(!valid.some(Boolean))throw new Error("USGS_3DEP_NO_DATA");
  let last:number|null=null;for(let i=0;i<count;i++){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  last=null;for(let i=count-1;i>=0;i--){if(valid[i])last=values[i];else if(last!==null)values[i]=last}
  return {values,valid_count:valid.filter(Boolean).length,meta};
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:H});
  if(req.method!=="POST")return new Response(JSON.stringify({complete:false,version:VERSION,error:"POST required"}),{status:405,headers:H});
  try{
    const b=await req.json().catch(()=>({}));
    const west=clamp(Number(b.west),-180,180),south=clamp(Number(b.south),-90,90),east=clamp(Number(b.east),-180,180),north=clamp(Number(b.north),-90,90);
    const width=clamp(Math.round(Number(b.width||17)),5,25),height=clamp(Math.round(Number(b.height||17)),5,25);
    if(!(west<east&&south<north))throw new Error("invalid bbox");
    if(width*height>625)throw new Error("sample grid too large");
    // The world currently unlocks U.S. property depth only; terrain sampler is correspondingly bounded to U.S./territory longitudes and latitudes plus Alaska/Aleutian coverage.
    if(north<17||south>72)throw new Error("outside BridgePoint U.S. terrain latitude gate");
    const key=tileKey(west,south,east,north,width,height),hit=cache.get(key);
    if(hit&&Date.now()-hit.at<24*60*60*1000)return new Response(JSON.stringify({...hit.payload,cache:"memory-hit"}),{headers:H});
    const points=makePoints(west,south,east,north,width,height),rows=await sample(points),orderedRows=ordered(rows,points.length);
    const payload={complete:true,version:VERSION,width,height,west,south,east,north,heights_m:orderedRows.values,valid_samples:orderedRows.valid_count,source:{provider:"USGS 3DEP",endpoint:IMAGE_SAMPLES,interpolation:"RSP_BilinearInterpolation",...orderedRows.meta},truth_notice:"Heights are sampled from the public USGS 3DEP bare-earth DEM. BridgePoint does not synthesize terrain where the source tile has no 3DEP sample."};
    cache.set(key,{at:Date.now(),payload});if(cache.size>900){const first=cache.keys().next().value;if(first)cache.delete(first)}
    return new Response(JSON.stringify(payload),{headers:H});
  }catch(e){return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e)}),{status:400,headers:{...H,"cache-control":"no-store"}})}
});
