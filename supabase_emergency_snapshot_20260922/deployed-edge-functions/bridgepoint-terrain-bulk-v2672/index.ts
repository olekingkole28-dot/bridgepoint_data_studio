import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";
import UTIF from "npm:utif@3.1.0";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const USGS="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer";
const NOAA="https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_global_mosaic/ImageServer";
const H={"content-type":"application/json","cache-control":"no-store"};
const W=385,HGT=385,STEP=96;

type Raster={values:number[], valid:boolean[], width:number, height:number, href:string, bytes:number, elapsed_ms:number};

async function exportRaster(base:string,west:number,south:number,east:number,north:number,label:string):Promise<Raster>{
  const p=new URLSearchParams({bbox:`${west},${south},${east},${north}`,bboxSR:"4326",imageSR:"4326",size:`${W},${HGT}`,format:"tiff",pixelType:"F32",interpolation:"RSP_BilinearInterpolation",f:"json"});
  const t0=Date.now();
  const m=await fetch(`${base}/exportImage?${p}`,{headers:{accept:"application/json","user-agent":`BridgePointIntelligence/2672 terrain-bulk-${label}`},signal:AbortSignal.timeout(30000)});
  const mt=await m.text();
  if(!m.ok) throw new Error(`${label}_EXPORT_${m.status}:${mt.slice(0,260)}`);
  const j=JSON.parse(mt);
  if(!j?.href) throw new Error(`${label}_NO_HREF:${mt.slice(0,260)}`);
  const r=await fetch(j.href,{signal:AbortSignal.timeout(30000)});
  if(!r.ok) throw new Error(`${label}_TIFF_HTTP_${r.status}`);
  const ab=await r.arrayBuffer();
  const ifds:any[]=UTIF.decode(ab);
  if(!ifds?.length) throw new Error(`${label}_NO_IFD`);
  const ifd:any=ifds[0];
  UTIF.decodeImage(ab,ifd);
  const width=Number(ifd.width||ifd.t256?.[0]),height=Number(ifd.height||ifd.t257?.[0]);
  const bits=ifd.t258||[], sampleFormat=ifd.t339||[];
  const raw:Uint8Array=ifd.data;
  if(width!==W||height!==HGT) throw new Error(`${label}_BAD_SIZE:${width}x${height}`);
  if(bits[0]!==32 || !(sampleFormat[0]===3||sampleFormat.length===0)) throw new Error(`${label}_BAD_TIFF:bits=${JSON.stringify(bits)} fmt=${JSON.stringify(sampleFormat)}`);
  const dv=new DataView(raw.buffer,raw.byteOffset,raw.byteLength);
  const values=new Array<number>(width*height);
  const valid=new Array<boolean>(width*height);
  for(let i=0;i<values.length;i++){
    const v=dv.getFloat32(i*4,true);
    values[i]=v;
    valid[i]=Number.isFinite(v)&&v>=-12000&&v<=10000;
  }
  return {values,valid,width,height,href:j.href,bytes:ab.byteLength,elapsed_ms:Date.now()-t0};
}

function splitTile(block:any,tile:any,values:number[],valid:boolean[]){
  const x0=Math.round((Number(tile.west)-Number(block.west))*STEP);
  const y0=Math.round((Number(block.north)-Number(tile.north))*STEP);
  if(x0<0||y0<0||x0+24>=W||y0+24>=HGT) throw new Error(`TILE_OFFSET:${tile.tile_key}:${x0},${y0}`);
  const h:number[]=[];
  for(let y=0;y<25;y++) for(let x=0;x<25;x++){
    const i=(y0+y)*W+(x0+x);
    if(!valid[i]) throw new Error(`MISSING_SOURCE_SAMPLE:${tile.tile_key}:${x},${y}`);
    h.push(values[i]);
  }
  if(h.length!==625) throw new Error(`BAD_TILE_SAMPLE_COUNT:${tile.tile_key}:${h.length}`);
  return {tile_key:String(tile.tile_key),heights_m:h};
}

async function runBlock(block:any,tok:string){
  const {data:tm,error:te}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token});
  if(te) throw te;
  const tiles=Array.isArray(tm?.tiles)?tm.tiles:[];
  if(tiles.length!==Number(block.required_tiles)) throw new Error(`TILE_MAPPING_COUNT:${tiles.length}/${block.required_tiles}`);
  const usgs=await exportRaster(USGS,Number(block.west),Number(block.south),Number(block.east),Number(block.north),"USGS");
  const requiredIdx=new Set<number>();
  for(const t of tiles){
    const x0=Math.round((Number(t.west)-Number(block.west))*STEP);
    const y0=Math.round((Number(block.north)-Number(t.north))*STEP);
    for(let y=0;y<25;y++) for(let x=0;x<25;x++) requiredIdx.add((y0+y)*W+(x0+x));
  }
  let missing=0;
  for(const i of requiredIdx) if(!usgs.valid[i]) missing++;
  let noaa:any=null;
  if(missing>0){
    noaa=await exportRaster(NOAA,Number(block.west),Number(block.south),Number(block.east),Number(block.north),"NOAA");
    for(const i of requiredIdx){
      if(!usgs.valid[i]&&noaa.valid[i]){usgs.values[i]=noaa.values[i];usgs.valid[i]=true;}
    }
  }
  let unresolved=0;
  for(const i of requiredIdx) if(!usgs.valid[i]) unresolved++;
  if(unresolved>0) throw new Error(`INCOMPLETE_BLOCK_SOURCE_COVERAGE:${unresolved}/${requiredIdx.size}`);
  const out=tiles.map((t:any)=>splitTile(block,t,usgs.values,usgs.valid));
  const source={provider:missing>0?"USGS 3DEP + NOAA NCEI":"USGS 3DEP",endpoint:`${USGS}/exportImage`,product_name:"3DEP ImageServer F32 4-degree bulk raster",bulk_block:block.block_key,bulk_width:W,bulk_height:HGT,grid_spacing_deg:1/96,usgs_href:usgs.href,usgs_bytes:usgs.bytes,usgs_elapsed_ms:usgs.elapsed_ms,noaa_fallback_required:missing>0,noaa_href:noaa?.href||null,noaa_bytes:noaa?.bytes||0,noaa_elapsed_ms:noaa?.elapsed_ms||0,truth:"SOURCE_SAMPLED_TERRAIN"};
  const {data:persisted,error:pe}=await db.rpc("[REDACTED_LONG_LITERAL]",{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token,p_tiles:out,p_source:source,p_error:null});
  if(pe) throw pe;
  if(persisted?.stored!==true) throw new Error(`PERSIST_REJECTED:${JSON.stringify(persisted).slice(0,500)}`);
  return {block_key:block.block_key,tiles:out.length,required_source_samples:requiredIdx.size,usgs_ms:usgs.elapsed_ms,usgs_bytes:usgs.bytes,noaa_fallback:missing>0,persisted};
}

Deno.serve(async(req:Request)=>{
  if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST required"}),{status:405,headers:H});
  const started=Date.now();
  try{
    const b=await req.json().catch(()=>({}));
    const tok=String(b?.task_token||"");
    const {data:ok,error:ae}=await db.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok});
    if(ae||ok!==true) return new Response(JSON.stringify({complete:false,error:"invalid worker token"}),{status:401,headers:H});
    const {data:claim,error:ce}=await db.schema("automation").rpc("claim_world_terrain_bulk_block_v2672",{p_limit:1});
    if(ce) throw ce;
    const blocks=Array.isArray(claim?.blocks)?claim.blocks:[];
    if(!blocks.length) return new Response(JSON.stringify({complete:true,version:2672,claimed:0,elapsed_ms:Date.now()-started}),{headers:H});
    const block=blocks[0];
    try{
      const result=await runBlock(block,tok);
      return new Response(JSON.stringify({complete:true,version:2672,claimed:1,completed:1,failed:0,elapsed_ms:Date.now()-started,result}),{headers:H});
    }catch(e){
      const msg=String((e as any)?.message||e).slice(0,1000);
      await db.rpc("[REDACTED_LONG_LITERAL]",{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token,p_tiles:[],p_source:{},p_error:msg});
      return new Response(JSON.stringify({complete:true,version:2672,claimed:1,completed:0,failed:1,elapsed_ms:Date.now()-started,block_key:block.block_key,error:msg}),{headers:H});
    }
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:2672,elapsed_ms:Date.now()-started,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});