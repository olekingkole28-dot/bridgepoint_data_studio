import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods":"POST, OPTIONS",
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"private, max-age=60"}});
const SERVICE="https://nowcoast.noaa.gov/geoserver/observations/satellite/ows";
const LAYER="global_visible_imagery_mosaic";
const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
const anonKey=Deno.env.get("SUPABASE_ANON_KEY")!;

async function requireWeather(req:Request){
  const auth=req.headers.get("Authorization")??req.headers.get("authorization")??"";
  if(!auth)return {ok:false,status:401,error:"Authentication required"};
  const user=createClient(supabaseUrl,anonKey,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data,error}=await user.rpc("bridgepoint_customer_access_contract_v318");
  const flags=(data&&typeof data==="object")?(data as any).feature_flags??{}:{};
  if(error||flags.weather_intelligence!==true)return {ok:false,status:403,error:"Weather Intelligence is not included in this account's active package"};
  return {ok:true,status:200,error:null};
}

function framesFromDimension(raw:string){
  const value=raw.trim();
  if(!value)return [] as string[];
  const out:string[]=[];
  for(const token of value.split(',').map(x=>x.trim()).filter(Boolean)){
    const parts=token.split('/');
    if(parts.length===3){
      const start=new Date(parts[0]),end=new Date(parts[1]);
      const m=/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/i.exec(parts[2]);
      const step=((Number(m?.[1]??0)*3600)+(Number(m?.[2]??0)*60)+Number(m?.[3]??0))*1000;
      if(Number.isFinite(start.getTime())&&Number.isFinite(end.getTime())&&step>0){
        for(let t=start.getTime();t<=end.getTime()&&out.length<2000;t+=step)out.push(new Date(t).toISOString());
      }
    }else{
      const d=new Date(token);if(Number.isFinite(d.getTime()))out.push(d.toISOString());
    }
  }
  return [...new Set(out)].sort();
}

function closestTimeDimension(xml:string,layerAt:number){
  const matches:[number,string][]=[];
  const re=/<(?:Dimension|Extent)[^>]*name=["']time["'][^>]*>([\s\S]*?)<\/(?:Dimension|Extent)>/ig;
  let m:RegExpExecArray|null;
  while((m=re.exec(xml))!==null)matches.push([m.index,(m[1]??'').replace(/&amp;/g,'&').trim()]);
  if(matches.length===0)return null;
  matches.sort((a,b)=>Math.abs(a[0]-layerAt)-Math.abs(b[0]-layerAt));
  return matches[0][1]||null;
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{status:200,headers:cors});
  if(req.method!=="POST")return json({complete:false,error:"Method not allowed"},405);
  const access=await requireWeather(req);
  if(!access.ok)return json({complete:false,error:access.error,required_feature:"weather_intelligence",entitlement_contract_version:318},access.status);
  try{
    const url=`${SERVICE}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`;
    const res=await fetch(url,{headers:{"User-Agent":"BridgePoint-Intelligence/1.0"},signal:AbortSignal.timeout(8000)});
    if(!res.ok)return json({complete:false,error:`NOAA nowCOAST capabilities returned ${res.status}`,service_url:SERVICE,layer:LAYER},502);
    const xml=await res.text();
    const layerAt=xml.indexOf(`<Name>${LAYER}</Name>`);
    if(layerAt<0)return json({complete:false,error:"NOAA satellite cloud layer is not currently listed by nowCOAST",service_url:SERVICE,layer:LAYER,frame_count:0,frames:[]},502);
    const rawDimension=closestTimeDimension(xml,layerAt);
    if(!rawDimension)return json({complete:false,error:"NOAA satellite frame history is temporarily unavailable. Showing the latest cloud image only.",service_url:SERVICE,layer:LAYER,frame_count:0,frames:[],latest_frame:null,generated_at:new Date().toISOString(),attribution:"NOAA nowCOAST",fallback_dimension:false,entitlement_contract_version:318},200);
    let frames=framesFromDimension(rawDimension);
    const cutoff=Date.now()-8*60*60*1000;
    frames=frames.filter(x=>{const t=new Date(x).getTime();return Number.isFinite(t)&&t>=cutoff&&t<=Date.now()+5*60*1000;}).slice(-72);
    if(frames.length<2)return json({complete:false,error:"NOAA has not published enough confirmed satellite frames to animate yet. Showing the latest available image.",service_url:SERVICE,layer:LAYER,frame_count:frames.length,frames,latest_frame:frames.at(-1)??null,generated_at:new Date().toISOString(),attribution:"NOAA nowCOAST",fallback_dimension:false,entitlement_contract_version:318},200);
    return json({complete:true,provider:"NOAA nowCOAST",product:"Weather satellite cloud imagery",service_url:SERVICE,layer:LAYER,frame_count:frames.length,frames,latest_frame:frames.at(-1),generated_at:new Date().toISOString(),attribution:"NOAA nowCOAST",fallback_dimension:false,frame_source:"NOAA_WMS_CAPABILITIES",entitlement_contract_version:318});
  }catch(e){return json({complete:false,error:String((e as any)?.message??e),service_url:SERVICE,layer:LAYER,frame_count:0,frames:[]},502);}
});