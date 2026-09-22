import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"POST, OPTIONS",
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"private, max-age=120"}});
const SAT_PAGE="https://www.star.nesdis.noaa.gov/goes/conus.php?sat=G19&src=nav";
const ALERTS="https://api.weather.gov/alerts/active?status=actual&message_type=alert";
const UA="BridgePoint Intelligence / bridgepointintelligence.online / bridgepointintelligence@gmail.com";

function isoFromNoaaFilename(url:string){
  const m=/\/(\d{4})(\d{3})(\d{2})(\d{2})_GOES19-ABI-CONUS-GEOCOLOR-/i.exec(url);
  if(!m)return null;
  const year=Number(m[1]),doy=Number(m[2]),hour=Number(m[3]),minute=Number(m[4]);
  if(!year||!doy||hour>23||minute>59)return null;
  const d=new Date(Date.UTC(year,0,1,hour,minute));
  d.setUTCDate(d.getUTCDate()+doy-1);
  return d.toISOString();
}
function clean(value:unknown){return String(value??"").replace(/\s+/g," ").trim();}
function stormLike(event:string){
  return /(tornado|severe thunderstorm|thunderstorm|flash flood|flood|hurricane|tropical storm|storm surge|snow squall|blizzard|ice storm|winter storm|high wind|dust storm)/i.test(event);
}
function severeLike(event:string,severity:string){
  return /(tornado|severe thunderstorm|flash flood|hurricane|storm surge|extreme wind)/i.test(event)||/extreme|severe/i.test(severity);
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{status:200,headers:cors});
  if(req.method!=="POST")return json({complete:false,error:"POST required"},405);
  const generatedAt=new Date().toISOString();
  let satellite:any={ok:false,provider:"NOAA NESDIS/STAR",product:"GOES-19 GeoColor",coverage:"CONUS",source_page:SAT_PAGE,image_url:null,image_time:null,update_cadence_minutes:5,error:null};
  let alerts:any={ok:false,provider:"NOAA/NWS",source:"api.weather.gov active alerts",active_count:null,storm_alert_count:null,severe_count:null,counts:{},top_alerts:[],error:null};

  try{
    const sat=await fetch(SAT_PAGE,{headers:{"User-Agent":UA,"Accept":"text/html"},signal:AbortSignal.timeout(9000)});
    if(!sat.ok)throw new Error(`NOAA satellite page HTTP ${sat.status}`);
    const html=await sat.text();
    const patterns=[
      /https:\/\/cdn\.star\.nesdis\.noaa\.gov\/GOES19\/ABI\/CONUS\/GEOCOLOR\/[^"'<>\s]*1250x750\.jpg/ig,
      /https:\/\/cdn\.star\.nesdis\.noaa\.gov\/GOES19\/ABI\/CONUS\/GEOCOLOR\/[^"'<>\s]*625x375\.jpg/ig,
      /https:\/\/cdn\.star\.nesdis\.noaa\.gov\/GOES19\/ABI\/CONUS\/GEOCOLOR\/[^"'<>\s]*416x250\.jpg/ig,
    ];
    let image:string|null=null;
    for(const re of patterns){const matches=[...html.matchAll(re)].map(m=>m[0]);if(matches.length){image=matches[matches.length-1];break;}}
    if(!image){
      const rel=[...html.matchAll(/(?:href|src)=["']([^"']*GOES19\/ABI\/CONUS\/GEOCOLOR\/[^"']*1250x750\.jpg)["']/ig)].map(m=>m[1]);
      if(rel.length){const v=rel[rel.length-1];image=v.startsWith("http")?v:`https://cdn.star.nesdis.noaa.gov/${v.replace(/^\/+/,"")}`;}
    }
    if(!image)throw new Error("Current GOES-19 GeoColor image link was not found");
    satellite={...satellite,ok:true,image_url:image,image_time:isoFromNoaaFilename(image),retrieved_at:generatedAt,error:null};
  }catch(e){satellite={...satellite,error:String((e as any)?.message??e),retrieved_at:generatedAt};}

  try{
    const res=await fetch(ALERTS,{headers:{"User-Agent":UA,"Accept":"application/geo+json"},signal:AbortSignal.timeout(10000)});
    if(!res.ok)throw new Error(`NWS alerts HTTP ${res.status}`);
    const body=await res.json();
    const features=Array.isArray(body?.features)?body.features:[];
    const rows=features.map((f:any)=>f?.properties??{});
    const stormRows=rows.filter((p:any)=>stormLike(clean(p.event)));
    const severeRows=stormRows.filter((p:any)=>severeLike(clean(p.event),clean(p.severity)));
    const counts:Record<string,number>={};
    for(const p of stormRows){const key=clean(p.event)||"Weather alert";counts[key]=(counts[key]??0)+1;}
    const top=stormRows
      .sort((a:any,b:any)=>{
        const rank=(x:any)=>severeLike(clean(x.event),clean(x.severity))?0:/warning/i.test(clean(x.event))?1:/watch/i.test(clean(x.event))?2:3;
        return rank(a)-rank(b)||String(a.expires??"").localeCompare(String(b.expires??""));
      })
      .slice(0,12)
      .map((p:any)=>({event:clean(p.event),severity:clean(p.severity),certainty:clean(p.certainty),urgency:clean(p.urgency),area:clean(p.areaDesc),headline:clean(p.headline),effective:p.effective??null,expires:p.expires??null,sender_name:clean(p.senderName)}));
    alerts={...alerts,ok:true,active_count:rows.length,storm_alert_count:stormRows.length,severe_count:severeRows.length,counts,top_alerts:top,retrieved_at:generatedAt,error:null};
  }catch(e){alerts={...alerts,error:String((e as any)?.message??e),retrieved_at:generatedAt};}

  return json({
    complete:satellite.ok||alerts.ok,
    contract_version:229,
    generated_at:generatedAt,
    refresh_seconds:300,
    satellite,
    alerts,
    coverage_note:"Satellite image covers the continental U.S.; the NWS active-alert feed is nationwide, including Alaska, Hawaii, Puerto Rico, U.S. territories, and marine zones when issued.",
    accuracy_note:"BridgePoint refreshes this panel every 5 minutes to match the NOAA GOES CONUS image cadence. NWS recommends alert clients request no more frequently than every 30 seconds; BridgePoint's 5-minute cadence stays well within that guidance.",
    sources:[
      {name:"NOAA NESDIS/STAR GOES-19 CONUS GeoColor",url:SAT_PAGE,cadence:"5 minutes"},
      {name:"NOAA/NWS Active Alerts API",url:"https://api.weather.gov/alerts/active",cadence:"5 minutes in BridgePoint"}
    ]
  },satellite.ok||alerts.ok?200:502);
});