import { PNG } from "npm:pngjs@7.0.0";
import jpeg from "npm:jpeg-js@0.4.4";
import { Buffer } from "node:buffer";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const VERSION=5560;

const db=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
async function rpc(name:string,body:any){
  const {data,error}=await db.schema("automation").rpc(name,body);
  if(error)throw new Error(`${name}_RPC:${error.code||""}:${error.message||error}`);
  return data;
}
function mercatorPixel(lng:number,lat:number,z:number,x:number,y:number,w:number,h:number){
  const n=2**z;
  const xf=(lng+180)/360*n;
  const phi=Math.max(-85.05112878,Math.min(85.05112878,lat))*Math.PI/180;
  const yf=(1-Math.log(Math.tan(phi)+1/Math.cos(phi))/Math.PI)/2*n;
  return {px:(xf-x)*w,py:(yf-y)*h};
}
function decode(bytes:Uint8Array,contentType:string){
  const ct=contentType.toLowerCase();
  if(ct.includes("png") || (bytes[0]===137&&bytes[1]===80)){
    const p=PNG.sync.read(Buffer.from(bytes));
    return {width:p.width,height:p.height,data:new Uint8Array(p.data),channels:4};
  }
  const j=jpeg.decode(bytes,{useTArray:true,formatAsRGBA:true});
  if(!j?.data)throw new Error("IMAGE_DECODE_FAILED");
  return {width:j.width,height:j.height,data:new Uint8Array(j.data),channels:4};
}
function usable(img:any){
  const d=img.data,w=img.width,h=img.height;
  let opaque=0,total=0,sum=0,sum2=0;
  const step=Math.max(1,Math.floor(Math.sqrt((w*h)/4096)));
  for(let yy=0;yy<h;yy+=step)for(let xx=0;xx<w;xx+=step){
    const i=(yy*w+xx)*4,a=d[i+3];total++;
    if(a>20){opaque++;const v=(d[i]+d[i+1]+d[i+2])/3;sum+=v;sum2+=v*v}
  }
  if(!total||opaque/total<0.55)return false;
  const mean=sum/Math.max(1,opaque),variance=sum2/Math.max(1,opaque)-mean*mean;
  return variance>18;
}
function sample(img:any,px:number,py:number){
  const x0=Math.round(px),y0=Math.round(py),rad=2;
  let r=0,g=0,b=0,n=0;
  for(let yy=y0-rad;yy<=y0+rad;yy++)for(let xx=x0-rad;xx<=x0+rad;xx++){
    if(xx<0||yy<0||xx>=img.width||yy>=img.height)continue;
    const i=(yy*img.width+xx)*4;if(img.data[i+3]<40)continue;
    const rr=img.data[i],gg=img.data[i+1],bb=img.data[i+2];
    // Ignore nearly black/white nodata artifacts.
    if(rr+gg+bb<24||rr+gg+bb>744)continue;
    r+=rr;g+=gg;b+=bb;n++;
  }
  if(n<3)return null;
  r=Math.round(r/n);g=Math.round(g/n);b=Math.round(b/n);
  const hex="#"+[r,g,b].map(v=>v.toString(16).padStart(2,"0")).join("");
  return {hex,n};
}
async function imageFor(t:any){
  const z=Number(t.z),x=Number(t.x),y=Number(t.y);
  const oam={
    key:"OPENAERIALMAP_CC_BY4",
    url:`https://global.imagery.hotosm.org/${z}/${x}/${y}.png`,
    license:"CC BY 4.0",
    confidence:0.9
  };
  const world=20037508.342789244;
  const span=(world*2)/(2**z);
  const minx=-world+x*span;
  const maxx=minx+span;
  const maxy=world-y*span;
  const miny=maxy-span;
  const usgsUrl=new URL("https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/export");
  usgsUrl.searchParams.set("bbox",`${minx},${miny},${maxx},${maxy}`);
  usgsUrl.searchParams.set("bboxSR","3857");
  usgsUrl.searchParams.set("imageSR","3857");
  usgsUrl.searchParams.set("size","512,512");
  usgsUrl.searchParams.set("format","png32");
  usgsUrl.searchParams.set("transparent","false");
  usgsUrl.searchParams.set("f","image");
  const usgs={
    key:"USGS_NATIONAL_MAP_ORTHO",
    url:usgsUrl.toString(),
    license:"PUBLIC DOMAIN U.S. GOVERNMENT",
    confidence:0.86
  };
  const pref=String(t.source_preference||"USGS_THEN_OAM").toUpperCase();
  const candidates=pref.startsWith("OAM")?[oam,usgs]:[usgs,oam];
  const errors:string[]=[];
  for(const c of candidates){
    try{
      const r=await fetch(c.url,{headers:{accept:"image/png,image/jpeg","user-agent":"BridgePointIntelligence/5550 photoreal-roof"},signal:AbortSignal.timeout(18000)});
      if(!r.ok){errors.push(`${c.key}:${r.status}`);continue}
      const bytes=new Uint8Array(await r.arrayBuffer());
      if(bytes.length<500){errors.push(`${c.key}:SMALL`);continue}
      const img=decode(bytes,r.headers.get("content-type")||"");
      if(!usable(img)){errors.push(`${c.key}:UNUSABLE`);continue}
      return {...c,img};
    }catch(e){errors.push(`${c.key}:${String((e as any)?.message||e).slice(0,120)}`)}
  }
  throw new Error("NO_IMAGERY:"+errors.join("|"));
}
async function runTile(t:any){
  const lease=String(t.lease_token||"");
  try{
    const b=await rpc("photoreal_tile_buildings_v5549",{p_z:Number(t.z),p_x:Number(t.x),p_y:Number(t.y),p_limit:900});
    const buildings=Array.isArray(b?.buildings)?b.buildings:[];
    if(!buildings.length){
      const fin=await rpc("finish_photoreal_roof_tile_v5549",{p_z:t.z,p_x:t.x,p_y:t.y,p_lease_token:lease,p_success:true,p_records:[]});
      return {tile:`${t.z}/${t.x}/${t.y}`,buildings:0,persisted:fin?.persisted||0};
    }
    const src=await imageFor(t);
    const records:any[]=[];
    for(const row of buildings){
      const lng=Number(row.lng),lat=Number(row.lat);
      if(!Number.isFinite(lng)||!Number.isFinite(lat))continue;
      const p=mercatorPixel(lng,lat,Number(t.z),Number(t.x),Number(t.y),src.img.width,src.img.height);
      const s=sample(src.img,p.px,p.py);if(!s)continue;
      records.push({
        building_geometry_id:String(row.building_geometry_id),
        property_id:row.property_id||null,
        state_code:String(row.state_code||t.state_code||""),
        roof_color:s.hex,
        roof_color_source:src.key,
        sample_confidence:String(Math.min(.98,src.confidence+(s.n>=20?.03:0))),
        source_url:src.url,
        source_license:src.license,
        metadata:{worker_version:VERSION,sample_pixels:s.n,imagery_width:src.img.width,imagery_height:src.img.height}
      });
    }
    const fin=await rpc("finish_photoreal_roof_tile_v5549",{p_z:t.z,p_x:t.x,p_y:t.y,p_lease_token:lease,p_success:true,p_records:records});
    return {tile:`${t.z}/${t.x}/${t.y}`,source:src.key,buildings:buildings.length,persisted:Number(fin?.persisted||0)};
  }catch(e){
    const msg=String((e as any)?.message||e);
    try{await rpc("finish_photoreal_roof_tile_v5549",{p_z:t.z,p_x:t.x,p_y:t.y,p_lease_token:lease,p_success:false,p_records:[],p_error:msg.slice(0,850)})}catch{}
    return {tile:`${t.z}/${t.x}/${t.y}`,error:msg.slice(0,350)};
  }
}
Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const body=await req.json().catch(()=>({}));
    const tok=String(body.task_token||"");
    const auth=await rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:tok});
    if(auth!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
    const limit=Math.max(1,Math.min(10,Number(body.tile_limit||6)));
    const claim=await rpc("claim_photoreal_roof_tiles_v5549",{p_limit:limit});
    const tiles=Array.isArray(claim?.tiles)?claim.tiles:[];
    const results:any[]=[];
    for(let i=0;i<tiles.length;i+=2){
      results.push(...await Promise.all(tiles.slice(i,i+2).map(runTile)));
    }
    return new Response(JSON.stringify({
      complete:true,version:VERSION,claimed:tiles.length,
      tiles_completed:results.filter(x=>!x.error).length,
      buildings_persisted:results.reduce((a,x)=>a+Number(x.persisted||0),0),
      results
    }),{headers:H});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:VERSION,error:String((e as any)?.message||e)}),{status:500,headers:H});
  }
});