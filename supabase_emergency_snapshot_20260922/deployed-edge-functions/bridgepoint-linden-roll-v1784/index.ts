import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { Buffer } from "node:buffer";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="linden-v1784-7f83ab0c", RUN="12b25f6b-d816-4ec5-8fc3-e109172beb9f", CAND="b5f91b18-0d04-45c6-b902-c55b9d1dd040";
const PDF="https://irp.cdn-website.com/0b76c777/files/uploaded/2025_PRE_MBOR_ASSESSMENT_ROLL.pdf";
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); if(String(b.nonce||req.headers.get("x-bridgepoint-nonce")||"")!==NONCE) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const r=await fetch(PDF,{headers:{"user-agent":"BridgePointIntelligence/1.0 (public-assessment-roll-parser)"},signal:AbortSignal.timeout(45000)}); if(!r.ok) throw new Error(`PDF_HTTP_${r.status}`);
 const buf=Buffer.from(await r.arrayBuffer());
 const mod:any=await import("npm:pdf-parse@1.1.1"); const parse=mod.default||mod;
 const parsed=await parse(buf); const text=String(parsed.text||"");
 const all=text.match(/\b61-\d{2}-\d{3}-\d{3}\b/g)||[]; const ids=new Set<string>();
 for(const raw of all){const id=raw.trim(); if(id.startsWith("61-80-")) continue; ids.add(id);}
 if(b.count_only) return new Response(JSON.stringify({complete:true,version:1784,pages:parsed.numpages||null,text_bytes:text.length,raw_matches:all.length,unique_real_property_ids:ids.size,sample:[...ids].slice(0,10)}),{headers:H});
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}}); const rows=[...ids].map(id=>({run_id:RUN,candidate_id:CAND,state_code:"MI",source_record_id:id,source_updated_at:new Date().toISOString(),payload:{parcel_id:id,property_number:id,county_fips:"26049",county_name:"Genesee County",municipality_name:"City of Linden",state_code:"MI",source_mode:"LINDEN_2025_ASSESSMENT_ROLL_PARCEL_ID_ONLY_V1784",owner_retained:false,address_retained:false,assessment_retained:false,tax_retained:false,legal_description_retained:false,sales_retained:false,geometry_retained:false,personal_property:false,raw_resale:false},materialization_status:"PENDING"}));
 let staged=0; for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500); const q=await s.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true}); if(q.error) throw q.error; staged+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1784,pages:parsed.numpages||null,unique_real_property_ids:ids.size,staged}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1784,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
