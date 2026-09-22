import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="tuscaloosa-flagship-v1788-3b87f114";
const RUN="4c01fc6f-fc75-4fca-9c22-89eec618cd23", CAND="8aae8e6e-40cc-4417-a878-27c9df2d8bbf";
const URL="https://www.alabamagis.com/TuscaloosaGov/CamaTemplates/reports/BasicResults.CFM";
function clean(v:string,n:number){const x=String(v||'').replace(/\D/g,'');return x?x.padStart(n,'0').slice(-n):'';}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));if(String(b.nonce||'')!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const m1=clean(b.m1,2),m2=clean(b.m2,2),m3=clean(b.m3,2),m4=clean(b.m4,1),m5=clean(b.m5,3),m6=clean(b.m6,3),m7=clean(b.m7,3);
 if(!m1)return new Response(JSON.stringify({complete:false,error:"M1_REQUIRED"}),{status:400,headers:H});
 const vals=[m1,m2,m3,m4,m5,m6,m7]; const p=new URLSearchParams();
 for(let i=0;i<7;i++)p.set(`Master__Map${i+1}`,vals[i]);
 for(let i=8;i<=14;i++)p.set(`Master__Map${i}`,"");
 p.set('Master__OWNER','');p.set('Parcel_Name_Operator','BEGINS_WITH');p.set('Master__Account','');p.set('Master__PPin','');p.set('MaxRecords',String(Math.min(Math.max(Number(b.max_records||1000)|0,100),1000)));
 const r=await fetch(URL,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded','user-agent':'BridgePointIntelligence/1.0 (Tuscaloosa public parcel-id foundation)','referer':'https://www.alabamagis.com/TuscaloosaGov/CamaTemplates/reports/BasicSearch.cfm'},body:p.toString(),signal:AbortSignal.timeout(45000)});
 const html=await r.text(); if(/Error Executing Database Query/i.test(html))return new Response(JSON.stringify({complete:false,version:1788,prefix:vals.filter(Boolean).join('-'),db_error:true,http_status:r.status}),{status:422,headers:H});
 const rm=html.match(/BASIC PARCEL SUMMARY<\/b>\s*-\s*(\d+)\s+Records/i); const reported=rm?Number(rm[1]):0;
 const ids=new Map<string,string>();
 const rx=/<td\s+nowrap>\s*(63\s+\d{2}\s+\d{2}\s+\d{2}\s+\d\s+\d{3}\s+\d{3}\.\d{3})\s*<br><\/td>/gi;
 for(const m of html.matchAll(rx)){const display=m[1].replace(/\s+/g,' ').trim();const compact=display.replace(/\D/g,'');if(compact.length===18)ids.set(compact,display);}
 if(b.count_only)return new Response(JSON.stringify({complete:true,version:1788,prefix:vals.filter(Boolean).join('-'),reported_records:reported,parsed_unique:ids.size,capped:reported>=Number(p.get('MaxRecords')),sample:[...ids.values()].slice(0,10)}),{headers:H});
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}}); const now=new Date().toISOString();
 const rows=[...ids.entries()].map(([compact,display])=>({run_id:RUN,candidate_id:CAND,state_code:'AL',source_record_id:`FLAGSHIP2027:${compact}`,source_updated_at:now,payload:{parcel_id:compact,parcel_number_display:display,tax_year:2027,county_fips:'01125',county_name:'Tuscaloosa County',state_code:'AL',source_projection:'PARCEL_ID_ONLY',source_mode:'[REDACTED_LONG_LITERAL]'},materialization_status:'PENDING'}));
 let staged=0;for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const q=await s.schema('staging').from('geographic_source_records_v90').upsert(chunk,{onConflict:'candidate_id,source_record_id',ignoreDuplicates:true});if(q.error)throw q.error;staged+=chunk.length;}
 return new Response(JSON.stringify({complete:true,version:1788,prefix:vals.filter(Boolean).join('-'),reported_records:reported,parsed_unique:ids.size,staged,capped:reported>=Number(p.get('MaxRecords'))}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1788,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
