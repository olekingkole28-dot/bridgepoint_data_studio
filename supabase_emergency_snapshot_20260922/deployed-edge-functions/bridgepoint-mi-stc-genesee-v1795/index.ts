import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { getDocumentProxy } from "npm:unpdf@1.8.1";
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="mi-stc-genesee-v1795-5f2d7a", RUN="163f9ea8-84ac-44c5-9351-af4d1940ed4a", CAND="5e0e7601-0c04-41a6-8e68-7e4ac81b35cf";
const PDF="https://www.michigan.gov/taxes/-/media/Project/Websites/taxes/154-Petition-Orders/2026-154-Petition-Orders/2-24-2026-CONCURRENCE-ORDERS.pdf?hash=C23732B981ED281C02C6276FB81147D8&rev=2210d32fd2c54337bb5570c3a20c3039";
const PARCEL=/\b\d{2}-\d{2}-\d{3}-\d{3}\b/g;
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const b=await req.json().catch(()=>({})); if(String(b.nonce||req.headers.get("x-bridgepoint-nonce")||"")!==NONCE) return new Response("unauthorized",{status:401});
 const pageStart=Math.max(1,Number(b.page_start??1)), pageCount=Math.max(1,Math.min(120,Number(b.page_count??120)));
 const r=await fetch(PDF,{headers:{"user-agent":"BridgePointIntelligence/1.0 (official-state-tax-order-parser)"},signal:AbortSignal.timeout(60000)}); if(!r.ok) throw new Error(`PDF_HTTP_${r.status}`);
 const data=new Uint8Array(await r.arrayBuffer()); const doc:any=await getDocumentProxy(data,{maxImageSize:16777216,disableFontFace:true,useSystemFonts:true}); const totalPages=doc.numPages;
 const pageEnd=Math.min(totalPages,pageStart+pageCount-1); const ids=new Set<string>(); const proof:any[]=[];
 for(let p=pageStart;p<=pageEnd;p++){const page=await doc.getPage(p); const tc=await page.getTextContent(); const text=(tc.items as any[]).map((x:any)=>String(x.str||"")).join(" ").replace(/\s+/g," ");
   const isGenesee=/County\s*:\s*GENESEE/i.test(text)||(/\bGENESEE\b/i.test(text)&&/Assessment\s*Unit\s*:/i.test(text));
   const isReal=/Classification\s*:\s*(?:[^A-Z]{0,20})?REAL\b/i.test(text)||/\bREAL\b/.test(text);
   if(isGenesee&&isReal){const mm=text.match(PARCEL)||[]; if(mm.length){const id=mm[0].trim(); ids.add(id); proof.push({page:p,parcel_id:id});}}
   page.cleanup?.();}
 await doc.destroy?.();
 if(b.inspect_only) return new Response(JSON.stringify({complete:true,version:1795,total_pages:totalPages,page_start:pageStart,page_end:pageEnd,unique_genesee_real_ids:ids.size,proof}),{headers:H});
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}}); const now=new Date().toISOString();
 const rows=[...ids].map(id=>({run_id:RUN,candidate_id:CAND,state_code:"MI",source_record_id:id,source_updated_at:now,payload:{parcel_id:id,property_number:id,county_fips:"26049",county_name:"Genesee County",state_code:"MI",classification:"REAL",source_mode:"MICHIGAN_STC_154_GENESEE_REAL_PARCEL_ID_ONLY_V1795",owner_retained:false,address_retained:false,assessment_retained:false,tax_retained:false,legal_description_retained:false,geometry_retained:false,personal_property:false,raw_pdf_retained:false,raw_resale:false},materialization_status:"PENDING"}));
 let attempted=0; for(let i=0;i<rows.length;i+=200){const chunk=rows.slice(i,i+200); const q=await sb.schema("staging").from("geographic_source_records_v90").upsert(chunk,{onConflict:"candidate_id,source_record_id",ignoreDuplicates:true}); if(q.error) throw q.error; attempted+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1795,total_pages:totalPages,page_start:pageStart,page_end:pageEnd,unique_genesee_real_ids:ids.size,attempted_stage:attempted,proof,eof:pageEnd>=totalPages}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1795,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});