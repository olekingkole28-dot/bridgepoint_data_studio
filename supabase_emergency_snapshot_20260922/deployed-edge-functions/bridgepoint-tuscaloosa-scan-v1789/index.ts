import { createClient } from "npm:@supabase/supabase-js@2.112.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="tuscaloosa-scan-v1789-87f41bd2";
const RUN="4c01fc6f-fc75-4fca-9c22-89eec618cd23",CAND="8aae8e6e-40cc-4417-a878-27c9df2d8bbf";
const URL="https://www.alabamagis.com/TuscaloosaGov/CamaTemplates/reports/BasicResults.CFM";
const sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
function clean(v:any,n:number){const x=String(v??'').replace(/\D/g,'');return x?x.padStart(n,'0').slice(-n):'';}
async function postPrefix(m1:string,m2:string,max=1000){
 const p=new URLSearchParams();p.set('Master__Map1',m1);p.set('Master__Map2',m2);for(let i=3;i<=14;i++)p.set(`Master__Map${i}`,'');p.set('Master__OWNER','');p.set('Parcel_Name_Operator','BEGINS_WITH');p.set('Master__Account','');p.set('Master__PPin','');p.set('MaxRecords',String(max));
 const r=await fetch(URL,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded','user-agent':'BridgePointIntelligence/1.0 (Tuscaloosa public parcel-id foundation)','referer':'https://www.alabamagis.com/TuscaloosaGov/CamaTemplates/reports/BasicSearch.cfm'},body:p.toString(),signal:AbortSignal.timeout(35000)});
 const html=await r.text(); if(/Error Executing Database Query/i.test(html)) return {ok:false,status:r.status,reported:null,ids:new Map<string,string>(),db_error:true};
 const rm=html.match(/BASIC PARCEL SUMMARY<\/b>\s*-\s*(\d+)\s+Records/i);const reported=rm?Number(rm[1]):0;const ids=new Map<string,string>();
 const rx=/<td\s+nowrap>\s*(63\s+\d{2}\s+\d{2}\s+\d{2}\s+\d\s+\d{3}\s+\d{3}\.\d{3})\s*<br><\/td>/gi;
 for(const m of html.matchAll(rx)){const display=m[1].replace(/\s+/g,' ').trim();const compact=display.replace(/\D/g,'');if(compact.length===18)ids.set(compact,display);}
 return {ok:true,status:r.status,reported,ids,db_error:false};
}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));if(String(b.nonce||'')!==NONCE)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const m1=clean(b.m1,2);if(!m1)return new Response(JSON.stringify({complete:false,error:"M1_REQUIRED"}),{status:400,headers:H});
 const start=Math.max(0,Math.min(99,Number(b.m2_start??0)|0)),end=Math.max(start,Math.min(99,Number(b.m2_end??99)|0));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});const all=new Map<string,string>();const shards:any[]=[];let capped=0,errors=0,staged=0;
 for(let i=start;i<=end;i++){
   const m2=String(i).padStart(2,'0'); const q=await postPrefix(m1,m2,1000); if(!q.ok){errors++;shards.push({m2,error:'DB_ERROR'});await sleep(100);continue;}
   if((q.reported??0)>=1000)capped++;
   for(const [k,v] of q.ids) all.set(k,v);
   shards.push({m2,reported:q.reported,parsed:q.ids.size,capped:(q.reported??0)>=1000}); await sleep(60);
 }
 if(!b.count_only){const now=new Date().toISOString();const rows=[...all.entries()].map(([compact,display])=>({run_id:RUN,candidate_id:CAND,state_code:'AL',source_record_id:`FLAGSHIP2027:${compact}`,source_updated_at:now,payload:{parcel_id:compact,parcel_number_display:display,tax_year:2027,county_fips:'01125',county_name:'Tuscaloosa County',state_code:'AL',source_projection:'PARCEL_ID_ONLY',source_mode:'[REDACTED_LONG_LITERAL]'},materialization_status:'PENDING'}));for(let i=0;i<rows.length;i+=500){const chunk=rows.slice(i,i+500);const q=await s.schema('staging').from('geographic_source_records_v90').upsert(chunk,{onConflict:'candidate_id,source_record_id',ignoreDuplicates:true});if(q.error)throw q.error;staged+=chunk.length;}}
 return new Response(JSON.stringify({complete:true,version:1789,m1,m2_start:start,m2_end:end,unique_parcel_ids:all.size,staged,capped_shards:capped,error_shards:errors,shards}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1789,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
