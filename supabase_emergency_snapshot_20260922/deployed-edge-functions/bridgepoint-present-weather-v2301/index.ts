import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const H={"content-type":"application/json; charset=utf-8","cache-control":"no-store","access-control-allow-origin":"*","access-control-allow-headers":"authorization,apikey,content-type","access-control-allow-methods":"POST,OPTIONS"};
const URL="https://aviationweather.gov/data/cache/metars.cache.csv.gz";
const UA="BridgePoint Intelligence present-weather/2301 (NOAA/NWS Aviation Weather Center METAR)";
let cache:{at:number,rows:any[]}|null=null;
const num=(v:any)=>{const n=Number(v);return Number.isFinite(n)?n:null};
const clamp=(v:number,a:number,b:number)=>Math.max(a,Math.min(b,v));
function csvLine(line:string){const out:string[]=[];let cur="",q=false;for(let i=0;i<line.length;i++){const c=line[i];if(c==='"'){if(q&&line[i+1]==='"'){cur+='"';i++}else q=!q}else if(c===','&&!q){out.push(cur);cur=""}else cur+=c}out.push(cur);return out}
function parse(text:string){
 const lines=text.split(/\r?\n/).filter(Boolean);const hi=lines.findIndex(x=>/^raw_text,station_id,/i.test(x.trim()));if(hi<0)return[];
 const headers=csvLine(lines[hi]).map(x=>x.trim());const rows=[];
 for(let i=hi+1;i<lines.length;i++){
  const v=csvLine(lines[i]);if(v.length<5)continue;const o:any={};headers.forEach((k,j)=>{if(k)o[k]=v[j]??""});
  const lat=num(o.latitude),lng=num(o.longitude);if(lat==null||lng==null)continue;
  const c=num(o.temp_c),vis=num(o.visibility_statute_mi);rows.push({station:o.station_id||null,lng,lat,observed_at:o.observation_time||null,weather:o.wx_string||null,rawdata:o.raw_text||null,wind_dir_deg:num(o.wind_dir_degrees),wind_speed_kt:num(o.wind_speed_kt),wind_gust_kt:num(o.wind_gust_kt),visibility_mi:vis,temperature_f:c==null?null:c*9/5+32,dewpoint_f:num(o.dewpoint_c)==null?null:Number(o.dewpoint_c)*9/5+32,flight_category:o.flight_category||null,source:"NOAA/NWS Aviation Weather Center METAR"})
 }
 return rows
}
async function download(){
 if(cache&&Date.now()-cache.at<120000)return cache.rows;
 const ctl=new AbortController(),t=setTimeout(()=>ctl.abort(),15000);
 try{
  const r=await fetch(URL,{headers:{"user-agent":UA,"accept":"application/gzip,*/*"},signal:ctl.signal});if(!r.ok)throw new Error(`AWC HTTP ${r.status}`);
  const bytes=new Uint8Array(await r.arrayBuffer());let text="";
  if(bytes[0]===0x1f&&bytes[1]===0x8b){const stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));text=await new Response(stream).text()}else text=new TextDecoder().decode(bytes);
  const rows=parse(text);if(!rows.length)throw new Error("AWC METAR cache parsed zero rows");cache={at:Date.now(),rows};return rows
 }finally{clearTimeout(t)}
}
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:H});
 if(req.method!=="POST")return new Response(JSON.stringify({error:"POST required"}),{status:405,headers:H});
 try{
  const b=await req.json().catch(()=>({}));const w=clamp(Number(b.west??-130),-180,180),s=clamp(Number(b.south??18),-90,90),e=clamp(Number(b.east??-60),-180,180),n=clamp(Number(b.north??58),-90,90),limit=clamp(Number(b.limit??500),20,900);
  if(!(w<e&&s<n))throw new Error("valid bbox required");const all=await download();
  const observations=all.filter(x=>x.lng>=w&&x.lng<=e&&x.lat>=s&&x.lat<=n).sort((a,b)=>String(b.observed_at||"").localeCompare(String(a.observed_at||""))).slice(0,limit);
  return new Response(JSON.stringify({complete:true,version:2301,generated_at:new Date().toISOString(),observations,source:{key:"NOAA_AWC_METAR",provider:"NOAA/NWS Aviation Weather Center",url:URL,refresh_seconds:60,role:"present weather codes for rain/snow/hail/freezing precipitation/fog/thunderstorm activity"},truth_notice:"METAR present-weather codes are station observations. They drive precipitation/fog/thunderstorm visualization near reporting stations; they are not exact lightning strike locations or a continuous precipitation field."}),{headers:H})
 }catch(e){return new Response(JSON.stringify({complete:false,version:2301,error:String((e as any)?.message||e),observations:[]}),{status:400,headers:H})}
});
