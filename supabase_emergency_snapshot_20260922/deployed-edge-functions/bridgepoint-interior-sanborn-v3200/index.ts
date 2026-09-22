import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"POST, OPTIONS",
  "content-type":"application/json; charset=utf-8"
};

function stateHint(v:any){
  const s=JSON.stringify(v||[]).toLowerCase();
  const map:any={
    "alabama":"AL","alaska":"AK","arizona":"AZ","arkansas":"AR","california":"CA","colorado":"CO","connecticut":"CT","delaware":"DE",
    "district of columbia":"DC","florida":"FL","georgia":"GA","hawaii":"HI","idaho":"ID","illinois":"IL","indiana":"IN","iowa":"IA",
    "kansas":"KS","kentucky":"KY","louisiana":"LA","maine":"ME","maryland":"MD","massachusetts":"MA","michigan":"MI","minnesota":"MN",
    "mississippi":"MS","missouri":"MO","montana":"MT","nebraska":"NE","nevada":"NV","new hampshire":"NH","new jersey":"NJ","new mexico":"NM",
    "new york":"NY","north carolina":"NC","north dakota":"ND","ohio":"OH","oklahoma":"OK","oregon":"OR","pennsylvania":"PA","rhode island":"RI",
    "south carolina":"SC","south dakota":"SD","tennessee":"TN","texas":"TX","utah":"UT","vermont":"VT","virginia":"VA","washington":"WA",
    "west virginia":"WV","wisconsin":"WI","wyoming":"WY","puerto rico":"PR","guam":"GU","american samoa":"AS","virgin islands":"VI",
    "northern mariana":"MP"
  };
  for(const [name,code] of Object.entries(map)) if(s.includes(name)) return code;
  return null;
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="POST") return new Response(JSON.stringify({ok:false,error:"POST only"}),{status:405,headers:cors});
  try{
    const body=await req.json().catch(()=>({}));
    const token=String(body.task_token||"");
    const page=Math.max(1,Math.min(10000,Number(body.page||1)));
    const pageSize=Math.max(1,Math.min(100,Number(body.page_size||100)));
    const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
    const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const s=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});

    const sec=await s.schema("automation").from("geographic_expansion_worker_secret_v90").select("task_token").eq("singleton",true).maybeSingle();
    if(sec.error||!sec.data||token!==String(sec.data.task_token)) return new Response(JSON.stringify({ok:false,error:"unauthorized"}),{status:401,headers:cors});

    const url=new URL("https://www.loc.gov/collections/sanborn-maps/");
    url.searchParams.set("fo","json");
    url.searchParams.set("at","results,pagination");
    url.searchParams.set("c",String(pageSize));
    url.searchParams.set("sp",String(page));
    const r=await fetch(url,{headers:{"User-Agent":"BridgePoint-Interior-Research/1.0"}});
    if(!r.ok) throw new Error("LOC_"+r.status);
    const j=await r.json();
    const results=Array.isArray(j.results)?j.results:[];
    const rows=results.map((x:any)=>{
      const itemUrl=String(x.id||x.url||"");
      const locId=String(x.item_id||itemUrl.split("/item/")[1]?.split("/")[0]||itemUrl);
      const locations=x.location||x.locations||[];
      const resources=x.resources||[];
      const imageCount=Array.isArray(x.image_url)?x.image_url.length:(Array.isArray(resources)?resources.length:null);
      const title=String(x.title||"");
      let city=null;
      if(Array.isArray(locations)&&locations.length){
        const vals=locations.map((v:any)=>typeof v==="string"?v:String(v?.title||v?.label||"")).filter(Boolean);
        city=vals[0]||null;
      }
      return {
        loc_id:locId||itemUrl,
        item_url:itemUrl,
        title,
        date_text:String(x.date||x.created_published_date||""),
        state_hint:stateHint(locations),
        city_hint:city,
        locations,
        resources,
        image_count:imageCount,
        digitized:!!(x.image_url||x.resources||x.online_format),
        metadata:{
          original_format:x.original_format||null,
          contributor:x.contributor||x.contributors||null,
          partof:x.partof||null,
          description:x.description||null,
          subject:x.subject||null,
          shelf_id:x.shelf_id||null
        },
        fetched_at:new Date().toISOString(),
        updated_at:new Date().toISOString()
      };
    }).filter((x:any)=>x.loc_id&&x.item_url);

    let persisted=0;
    if(rows.length){
      const up=await s.schema("staging").from("loc_sanborn_catalog_v3200").upsert(rows,{onConflict:"loc_id"});
      if(up.error) throw new Error("UPSERT_"+up.error.message);
      persisted=rows.length;
    }
    const total=Number(j?.pagination?.total||0);
    const pages=Number(j?.pagination?.total_pages||Math.ceil(total/pageSize)||0);
    const next=page<pages?page+1:null;
    await s.schema("automation").from("interior_layout_task_v3200").update({
      status:next?"RUNNING":"COMPLETE",
      cursor:{page:next||page,page_size:pageSize},
      result:{last_page:page,last_persisted:persisted,total_items:total,total_pages:pages},
      attempts:page,
      updated_at:new Date().toISOString(),
      last_error:null
    }).eq("state_code","US").eq("task_type","INGEST_SANBORN_CATALOG");

    return new Response(JSON.stringify({ok:true,version:3200,page,page_size:pageSize,fetched:results.length,persisted,total,total_pages:pages,next_page:next}),{headers:cors});
  }catch(e){
    return new Response(JSON.stringify({ok:false,version:3200,error:String(e?.message||e)}),{status:500,headers:cors});
  }
});