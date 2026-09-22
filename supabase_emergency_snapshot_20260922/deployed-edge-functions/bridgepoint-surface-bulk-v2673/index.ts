import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";
import { PNG } from "npm:pngjs@7.0.0";
import { Buffer } from "node:buffer";
import { fromUrl } from "npm:geotiff@2.1.3";

const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const H={"content-type":"application/json","cache-control":"no-store"};
const W=385,HGT=385,STEP=96;
const WORLD_COVER_KEY='ESA_WORLDCOVER_2021_WMS_V2673';
const NLCD=[[11,0x46,0x6b,0x9f],[12,0xd1,0xde,0xf8],[21,0xde,0xc5,0xc5],[22,0xd9,0x92,0x82],[23,0xeb,0x00,0x00],[24,0xab,0x00,0x00],[31,0xb3,0xac,0x9f],[41,0x68,0xab,0x5f],[42,0x1c,0x5f,0x2c],[43,0xb5,0xc5,0x8f],[52,0xcc,0xb8,0x79],[71,0xdf,0xdf,0xc2],[81,0xdc,0xd9,0x39],[82,0xab,0x6c,0x28],[90,0xb8,0xd9,0xeb],[95,0x6c,0x9f,0xb8]] as const;
const WC_TO_MAT:Record<number,number>={10:43,20:52,30:71,40:82,50:23,60:31,70:12,80:11,90:95,95:90,100:71};
function nearest(r:number,g:number,b:number){let best=11,bd=Infinity;for(const p of NLCD){const d=(r-p[1])**2+(g-p[2])**2+(b-p[3])**2;if(d<bd){bd=d;best=p[0]}}return best;}
function hist(a:number[]){const h:Record<string,number>={};for(const v of a)h[String(v)]=(h[String(v)]||0)+1;return h;}

async function nlcdGrid(block:any){
 const url='https://dmsdata.cr.usgs.gov/geoserver/mrlc_Land-Cover-Native_conus_year_data/wms',layer='Land-Cover-Native_conus_year_data';
 const p=new URLSearchParams({service:'WMS',version:'1.1.1',request:'GetMap',layers:layer,styles:'',format:'image/png',transparent:'false',srs:'EPSG:4326',bbox:`${block.west},${block.south},${block.east},${block.north}`,width:String(W),height:String(HGT),time:'2025-01-01T00:00:00Z'});
 const t0=Date.now();const r=await fetch(`${url}?${p}`,{headers:{accept:'image/png','user-agent':'BridgePointIntelligence/2677 surface-nlcd-bulk'},signal:AbortSignal.timeout(30000)});const ab=await r.arrayBuffer();
 if(!r.ok)throw new Error(`NLCD_WMS_${r.status}:${new TextDecoder().decode(ab.slice(0,300))}`);
 const png=PNG.sync.read(Buffer.from(ab));if(png.width!==W||png.height!==HGT)throw new Error(`NLCD_BAD_SIZE:${png.width}x${png.height}`);
 const g=new Array<number>(W*HGT);for(let i=0;i<g.length;i++){const j=i*4;g[i]=nearest(png.data[j],png.data[j+1],png.data[j+2]);}
 return{grid:g,source_ms:Date.now()-t0,source_bytes:ab.byteLength,source_url:url,source_layer:layer};
}

function wcTileFor(west:number,south:number){const lo=Math.floor(west/3)*3,la=Math.floor(south/3)*3;const a=(la<0?'S':'N')+String(Math.abs(la)).padStart(2,'0');const o=(lo<0?'W':'E')+String(Math.abs(lo)).padStart(3,'0');return{name:`${a}${o}`,west:lo,south:la,east:lo+3,north:la+3};}
type WC={name:string,url:string,west:number,south:number,east:number,north:number,width:number,height:number,data:number[],elapsed_ms:number};
async function loadWC(ref:any):Promise<WC>{
 const url=`https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_${ref.name}_Map.tif`;const t0=Date.now();const gt=await fromUrl(url);const base=await gt.getImage(0);const bb=base.getBoundingBox();const count=await gt.getImageCount();let oi=count-1;
 for(let i=count-1;i>=0;i--){const im=await gt.getImage(i);if(im.getWidth()>=1000&&im.getHeight()>=1000){oi=i;break;}}
 const im=await gt.getImage(oi),w=im.getWidth(),h=im.getHeight();const arr:any=await im.readRasters({interleave:true});const data=Array.from(arr as any).map(Number);
 return{name:ref.name,url,west:bb[0],south:bb[1],east:bb[2],north:bb[3],width:w,height:h,data,elapsed_ms:Date.now()-t0};
}
function wcPixel(src:WC,lon:number,lat:number){const fx=(lon-src.west)/(src.east-src.west)*(src.width-1),fy=(src.north-lat)/(src.north-src.south)*(src.height-1);const x=Math.max(1,Math.min(src.width-2,Math.round(fx))),y=Math.max(1,Math.min(src.height-2,Math.round(fy)));return Number(src.data[y*src.width+x]);}

function splitNLCD(block:any,t:any,grid:number[]){const x0=Math.round((Number(t.west)-Number(block.west))*STEP),y0=Math.round((Number(block.north)-Number(t.north))*STEP);const raw:number[]=[],mat:number[]=[];for(let y=0;y<25;y++)for(let x=0;x<25;x++){const c=grid[(y0+y)*W+(x0+x)];if(!Number.isFinite(c))throw new Error(`NLCD_MISSING:${t.tile_key}`);raw.push(c);mat.push(c);}return{tile_key:String(t.tile_key),state_code:String(t.state_code),raw_classes:raw,material_classes:mat,raw_histogram:hist(raw),material_histogram:hist(mat),source_gap_fills:0,terrain_derived_water_fill_samples:0,terrain_derived_water_fill_indices:[],source_tile_unavailable:false,terrain_derived_water_fill_reason:null};}

function splitWC(t:any,src:WC|null){
 const terrain=Array.isArray(t.terrain_heights_m)?t.terrain_heights_m.map(Number):[];
 if(Number(t.terrain_valid_samples)!==625||Number(t.terrain_sample_width)!==25||Number(t.terrain_sample_height)!==25||terrain.length!==625)throw new Error(`TERRAIN_SECONDARY_EVIDENCE_INCOMPLETE:${t.tile_key}:${t.terrain_valid_samples}:${terrain.length}`);
 const raw:number[]=[],mat:number[]=[],derivedIdx:number[]=[];let idx=0;
 for(let y=0;y<25;y++){const lat=Number(t.north)+(Number(t.south)-Number(t.north))*(y/24);for(let x=0;x<25;x++){
  const lon=Number(t.west)+(Number(t.east)-Number(t.west))*(x/24);let c=src?wcPixel(src,lon,lat):0;
  if(WC_TO_MAT[c]===undefined){const z=terrain[idx];if(!Number.isFinite(z))throw new Error(`TERRAIN_SAMPLE_INVALID:${t.tile_key}:${idx}`);if(z<=0){c=80;derivedIdx.push(idx);}else throw new Error(`${src?'WORLDCOVER_NODATA_ABOVE_SEA_LEVEL':'[REDACTED_LONG_LITERAL]'}:${t.tile_key}:${idx}:${z.toFixed(3)}:${src?.name||'NO_COG'}:${lon},${lat}`);}
  raw.push(c);mat.push(WC_TO_MAT[c]);idx++;
 }}
 return{tile_key:String(t.tile_key),state_code:String(t.state_code),raw_classes:raw,material_classes:mat,raw_histogram:hist(raw),material_histogram:hist(mat),source_gap_fills:derivedIdx.length,terrain_derived_water_fill_samples:derivedIdx.length,terrain_derived_water_fill_indices:derivedIdx,source_tile_unavailable:src===null,terrain_derived_water_fill_reason:derivedIdx.length?(src===null?'[REDACTED_LONG_LITERAL]':'[REDACTED_LONG_LITERAL]'):null};
}

async function runBlock(block:any,tok:string){
 const {data:tm,error:te}=await db.rpc('[REDACTED_LONG_LITERAL]',{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token});if(te)throw te;const tiles=Array.isArray(tm?.tiles)?tm.tiles:[];if(tiles.length!==Number(block.required_tiles))throw new Error(`TILE_MAPPING:${tiles.length}/${block.required_tiles}`);
 let out:any[],source:any;
 if(String(block.source_key)===WORLD_COVER_KEY){
  const refs=new Map<string,any>();for(const t of tiles){const r=wcTileFor(Number(t.west),Number(t.south));refs.set(r.name,r);}
  const loadedResults=await Promise.all([...refs.values()].map(async r=>{try{return{name:r.name,src:await loadWC(r),error:null};}catch(e){return{name:r.name,src:null,error:String((e as any)?.message||e).slice(0,300)};}}));
  const by=new Map(loadedResults.map(x=>[x.name,x.src]));
  out=tiles.map((t:any)=>{const r=wcTileFor(Number(t.west),Number(t.south));return splitWC(t,by.get(r.name)||null);});
  const fills=out.reduce((a:number,x:any)=>a+Number(x.terrain_derived_water_fill_samples||0),0),unavailable=loadedResults.filter(x=>!x.src),loaded=loadedResults.filter(x=>x.src).map(x=>x.src as WC);
  source={source_key:block.source_key,source_name:'ESA WorldCover 2021 10m global land cover',source_url:'https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/',source_layer:'Map',source_year:2021,source_native_resolution_m:10,source_class_system:'ESA_WORLDCOVER_2021',access_method:'[REDACTED_LONG_LITERAL]',cog_tiles:loaded.map(x=>x.name),cog_count:loaded.length,cog_unavailable:unavailable.map(x=>x.name),cog_unavailable_count:unavailable.length,cog_errors:unavailable.map(x=>({name:x.name,error:x.error})),overview_min_width:1000,source_elapsed_ms:loaded.length?Math.max(...loaded.map(x=>x.elapsed_ms)):null,source_gap_fill_samples:fills,terrain_derived_water_fill_samples:fills,gap_fill_method:fills?'Only samples whose WorldCover class is NoData, or whose COG cannot be read, may become water when the matching frozen terrain sample is <= 0 m; any >0 m sample hard-fails':null,secondary_evidence:fills?'BridgePoint frozen USGS 3DEP terrain baseline (with previously recorded NOAA fallback where applicable)':null,truth:fills?'[REDACTED_LONG_LITERAL]':'[REDACTED_LONG_LITERAL]'};
 }else{
  const n=await nlcdGrid(block);out=tiles.map((t:any)=>splitNLCD(block,t,n.grid));source={source_key:block.source_key,source_name:'Annual NLCD 2025 Land Cover',source_url:n.source_url,source_layer:n.source_layer,source_year:2025,source_native_resolution_m:30,source_class_system:'USGS_ANNUAL_NLCD_2025',access_method:'OGC_WMS',source_elapsed_ms:n.source_ms,source_bytes:n.source_bytes,source_gap_fill_samples:0,terrain_derived_water_fill_samples:0,truth:'SOURCE_CLASSIFICATION_RGB_DOWNSAMPLED'};
 }
 const {data:p,error:pe}=await db.rpc('bridgepoint_surface_bulk_persist_v2673',{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token,p_tiles:out,p_source:source,p_error:null});if(pe)throw pe;if(p?.stored!==true)throw new Error(`PERSIST_REJECTED:${JSON.stringify(p).slice(0,500)}`);return{block_key:block.block_key,source_key:block.source_key,tiles:out.length,source};
}

Deno.serve(async(req:Request)=>{const started=Date.now();try{if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST required'}),{status:405,headers:H});const b=await req.json().catch(()=>({})),tok=String(b.task_token||'');const {data:ok,error:ae}=await db.rpc('bridgepoint_expansion_worker_auth_v90',{p_task_token:tok});if(ae||ok!==true)return new Response(JSON.stringify({complete:false,error:'invalid worker token'}),{status:401,headers:H});const {data:claim,error:ce}=await db.schema('automation').rpc('claim_surface_material_bulk_block_v2673',{p_limit:1});if(ce)throw ce;const blocks=Array.isArray(claim?.blocks)?claim.blocks:[];if(!blocks.length)return new Response(JSON.stringify({complete:true,version:2677,claimed:0,elapsed_ms:Date.now()-started}),{headers:H});const block=blocks[0];try{const result=await runBlock(block,tok);return new Response(JSON.stringify({complete:true,version:2677,claimed:1,completed:1,failed:0,elapsed_ms:Date.now()-started,result}),{headers:H});}catch(e){const msg=String((e as any)?.message||e).slice(0,1000);await db.rpc('bridgepoint_surface_bulk_persist_v2673',{p_task_token:tok,p_block_key:block.block_key,p_lease_token:block.lease_token,p_tiles:[],p_source:{},p_error:msg});return new Response(JSON.stringify({complete:true,version:2677,claimed:1,completed:0,failed:1,elapsed_ms:Date.now()-started,block_key:block.block_key,error:msg}),{headers:H});}}catch(e){return new Response(JSON.stringify({complete:false,version:2677,elapsed_ms:Date.now()-started,error:String((e as any)?.message||e)}),{status:500,headers:H});}});