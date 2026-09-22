import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="forsyth-excess-v1786-42b6d8e1";
const RUN="fdbbb32c-5c14-420f-affd-3ce6059f77e0", CAND="5d04883b-e1b0-4eff-aae7-d966c29c6449";
const URL="https://forsythcountytax.com/excess-funds-listing-2/";
function decode(s:string){return s.replace(/<[^>]*>/g,' ').replace(/&nbsp;|&#160;/gi,' ').replace(/&amp;/gi,'&').replace(/&#39;|&apos;/gi,"'").replace(/&quot;/gi,'"').replace(/\s+/g,' ').trim();}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); if(String(b.nonce||'')!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const r=await fetch(URL,{headers:{'user-agent':'BridgePointIntelligence/1.0 (official-public-record-facts)'},signal:AbortSignal.timeout(30000)}); if(!r.ok)throw new Error(`HTTP_${r.status}`); const html=await r.text();
 const body=html.match(/<tbody>([\s\S]*?)<\/tbody>/i)?.[1]||''; if(!body)throw new Error('EXCESS_TABLE_NOT_FOUND');
 const ids=new Map<string,string>();
 for(const m of body.matchAll(/<tr[^>]*>[\s\S]*?<td[^>]*>[\s\S]*?<\/td>\s*<td[^>]*>([\s\S]*?)<\/td>/gi)){
   const raw=decode(m[1]); const compact=raw.replace(/[^A-Za-z0-9]/g,'').toUpperCase();
   if(!compact || compact.length<5 || compact.length>30)continue; ids.set(compact,raw.replace(/\s+/g,' '));
 }
 if(b.count_only)return new Response(JSON.stringify({complete:true,version:1786,unique_parcel_ids:ids.size,ids:[...ids.values()]}),{headers:H});
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const rows=[...ids.entries()].map(([compact,id])=>({run_id:RUN,candidate_id:CAND,state_code:'GA',source_record_id:compact,source_updated_at:new Date().toISOString(),payload:{parcel_id:id,parcel_id_compact:compact,county_fips:'13117',county_name:'Forsyth County',state_code:'GA',source_mode:'FORSYTH_TAX_COMMISSIONER_EXCESS_FUNDS_PARCEL_ID_ONLY_V1786',owner_retained:false,address_retained:false,tax_value_retained:false,payment_retained:false,geometry_retained:false,raw_resale:false},materialization_status:'PENDING'}));
 const q=await s.schema('staging').from('geographic_source_records_v90').upsert(rows,{onConflict:'candidate_id,source_record_id',ignoreDuplicates:true}); if(q.error)throw q.error;
 return new Response(JSON.stringify({complete:true,version:1786,unique_parcel_ids:ids.size,staged:rows.length,ids:[...ids.values()]}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1786,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
