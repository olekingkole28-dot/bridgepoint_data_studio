import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const V = 5300;
const H = {
  "content-type":"application/json",
  "cache-control":"no-store",
  "access-control-allow-origin":"*",
  "access-control-allow-methods":"POST,OPTIONS",
  "access-control-allow-headers":"content-type,apikey,authorization"
};
const out=(b:any,s=200)=>new Response(JSON.stringify(b),{status:s,headers:H});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers:H});
  if(req.method!=="POST") return out({complete:false,version:V,error:"POST_REQUIRED"},405);
  const body=await req.json().catch(()=>({}));
  const q=String(body?.q||"").replace(/[\u0000-\u001f\u007f]/g," ").replace(/\s+/g," ").trim().slice(0,220);
  if(q.length<4) return out({complete:true,version:V,count:0,results:[]});

  try{
    const u=new URL("https://geocoding.geo.census.gov/geocoder/locations/onelineaddress");
    u.searchParams.set("address",q);
    u.searchParams.set("benchmark","Public_AR_Current");
    u.searchParams.set("format","json");
    const r=await fetch(u,{headers:{accept:"application/json","user-agent":"BridgePointIntelligence/1.0"},signal:AbortSignal.timeout(5500)});
    const t=await r.text();
    if(!r.ok) return out({complete:false,version:V,error:"CENSUS_HTTP_"+r.status},502);
    const j=JSON.parse(t);
    const m=Array.isArray(j?.result?.addressMatches)?j.result.addressMatches[0]:null;
    if(!m?.coordinates) return out({complete:true,version:V,count:0,results:[],resolver:"US_CENSUS_NO_MATCH"});
    const lng=Number(m.coordinates.x),lat=Number(m.coordinates.y);
    if(!Number.isFinite(lng)||!Number.isFinite(lat)) return out({complete:true,version:V,count:0,results:[],resolver:"US_CENSUS_BAD_COORDS"});

    let pd:any=null;
    try{
      const rr=await db.rpc("[REDACTED_LONG_LITERAL]",{p_lng:lng,p_lat:lat,p_radius_m:180});
      if(!rr.error) pd=rr.data;
    }catch(_){}

    const p=pd?.property||{};
    const row={
      property_id:p.property_id||null,
      full_address:p.display_address||m.matchedAddress||q,
      geocoder_address:m.matchedAddress||q,
      municipality:p.municipality||null,
      state_code:p.state_code||null,
      postal_code:p.postal_code||null,
      parcel_number:p.parcel_number||null,
      longitude:lng,
      latitude:lat,
      match_reason:pd?.resolved?"CENSUS_GEOCODE_TO_PROPERTY":"CENSUS_GEOCODE_LOCATION",
      match_score:pd?.resolved?0.82:0.64,
      property_resolved:pd?.resolved===true,
      resolver:"US_CENSUS_PUBLIC_AR_CURRENT"
    };
    return out({complete:true,version:V,count:1,results:[row],resolver:row.match_reason});
  }catch(e){
    return out({complete:false,version:V,error:String((e as any)?.message||e).slice(0,300)},502);
  }
});