import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1796,NONCE="0972aef4-2031-4a58-86e7-b35de194709e";
const RUN="5de4b55b-4cf7-47bf-a1da-3933e23e6f66",CAND="1469659b-11e8-47ce-b37d-364a1dc0a620";
const Q="https://services.arcgis.com/CWv1abTnC3urn4bV/arcgis/rest/services/berncoparcels_forIDO/FeatureServer/0/query";
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));if(String(b.nonce||req.headers.get("x-bridgepoint-nonce")||"")!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const offset=Math.max(0,Number(b.offset||0)|0),limit=Math.min(Math.max(Number(b.limit||1000)|0,100),2000);
 const p=new URLSearchParams({where:"UPC IS NOT NULL",outFields:"OBJECTID,UPC",returnGeometry:"false",orderByFields:"OBJECTID ASC",resultOffset:String(offset),resultRecordCount:String(limit),f:"json"});
 const r=await fetch(Q,{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded","user-agent":"BridgePointIntelligence/1.0 (+official-open-data-foundation)"},body:p.toString(),signal:AbortSignal.timeout(30000)});
 const text=await r.text();if(!r.ok)throw new Error(`HTTP_${r.status}:${text.slice(0,300)}`);const j=JSON.parse(text);if(j?.error)throw new Error(`ARCGIS:${JSON.stringify(j.error).slice(0,500)}`);
 const fs=Array.isArray(j?.features)?j.features:[],rows:any[]=[];for(const f of fs){const x=f?.attributes||{},oid=x.OBJECTID,upc=String(x.UPC??"").trim();if(oid==null||!upc)continue;rows.push({run_id:RUN,candidate_id:CAND,state_code:"NM",source_record_id:String(oid),source_updated_at:new Date().toISOString(),payload:{OBJECTID:oid,UPC:upc,parcel_id:upc,county_fips:"35001",county_name:"Bernalillo County",state_code:"NM",source_mode:"BERNALILLO_CABQ_UPC_ONLY_V1796",owner_retained:false,address_retained:false,legal_description_retained:false,values_retained:false,geometry_retained:false,raw_resale:false},materialization_status:"PENDING"});}
 if(rows.length){const q=await s.schema("staging").from("geographic_source_records_v90").upsert(rows,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true});if(q.error)throw q.error;}
 return new Response(JSON.stringify({complete:true,version:V,offset,source_features:fs.length,staged:rows.length,next_offset:offset+fs.length,has_more:fs.length===limit}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:V,error:String((e as any)?.message||e)}),{status:500,headers:H});}});