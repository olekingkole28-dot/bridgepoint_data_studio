import { createClient } from 'npm:@supabase/supabase-js@2';
const ROOT='https://lancasterpa.devnetwedge.com';
const CANDIDATE='b07b7c39-e826-4dc7-b6f2-ff171c0453ef';
const KEY='lancaster-ingest-1761-7f4b2d9c';
const U=Deno.env.get('SUPABASE_URL')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const H={'content-type':'application/json','cache-control':'no-store'};
function ck(h:string){return h.split(/,(?=\s*[^;,]+=)/).map(x=>x.split(';')[0].trim()).filter(Boolean).join('; ')}
async function ft(url:string,init:RequestInit={}){const r=await fetch(url,{...init,redirect:'manual',signal:AbortSignal.timeout(15000),headers:{'user-agent':'BridgePointIntelligence/1.0 (+county-public-record-ingest)','accept':'text/html,application/json;q=0.9,*/*;q=0.5',...(init.headers||{})}});return{r,t:await r.text()}}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=='POST'||req.headers.get('x-bridgepoint-key')!==KEY)return new Response(JSON.stringify({complete:false,error:'UNAUTHORIZED'}),{status:401,headers:H});
 const body=await req.json().catch(()=>({})); const prefix=String(body.prefix||'334').trim(); const start=Math.max(0,Number(body.start||0)); const length=Math.min(100,Math.max(1,Number(body.length||100)));
 const sb=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:c,error:ce}=await sb.schema('automation').from('geographic_source_candidates_v86').select('candidate_id,run_id,decision_status,metadata').eq('candidate_id',CANDIDATE).single(); if(ce||!c)throw new Error('CANDIDATE_MISSING');
 const {data:v,error:ve}=await sb.schema('automation').from('source_compliance_validation_v720').select('activation_status,rights_status,privacy_status,local_law_status').eq('candidate_id',CANDIDATE).single(); if(ve||!v)throw new Error('COMPLIANCE_MISSING');
 if(c.decision_status!=='ACCEPTED'||c.metadata?.compliance_gate_v720!=='APPROVED'||v.activation_status!=='APPROVED')throw new Error('LEGAL_GATE_NOT_APPROVED');
 let a=await ft(ROOT+'/'); let cookie=ck(a.r.headers.get('set-cookie')||'');
 let p=await ft(ROOT+'/Search/ExecuteSearch',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded','cookie':cookie,'referer':ROOT+'/'},body:new URLSearchParams({property_key:prefix}).toString()}); cookie=[cookie,ck(p.r.headers.get('set-cookie')||'')].filter(Boolean).join('; ');
 const loc=p.r.headers.get('location')||'/Search/SearchResults'; let page=await ft(new URL(loc,ROOT).toString(),{headers:{cookie,'referer':ROOT+'/'}}); cookie=[cookie,ck(page.r.headers.get('set-cookie')||'')].filter(Boolean).join('; ');
 const dt=new URLSearchParams({draw:'1',start:String(start),length:String(length),'order[0][column]':'0','order[0][dir]':'asc','search[value]':'','search[regex]':'false'}); const cols=[['property_key_masked','Property Account Number'],['full_name','Owner'],['address','Address']]; cols.forEach((z,i)=>{dt.set(`columns[${i}][data]`,z[0]);dt.set(`columns[${i}][name]`,z[1]);dt.set(`columns[${i}][searchable]`,'true');dt.set(`columns[${i}][orderable]`,'true');dt.set(`columns[${i}][search][value]`,'');dt.set(`columns[${i}][search][regex]`,'false')});
 const rr=await ft(ROOT+'/Search/Results',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded','accept':'application/json','cookie':cookie,'referer':new URL(loc,ROOT).toString(),'x-requested-with':'XMLHttpRequest'},body:dt.toString()}); const j=JSON.parse(rr.t); const arr=Array.isArray(j?.data)?j.data:[]; const ids=[...new Set(arr.map((x:any)=>String(x?.property_key_masked??'').trim()).filter(Boolean))];
 const {data:ex}=await sb.schema('staging').from('geographic_source_records_v90').select('source_record_id').eq('candidate_id',CANDIDATE).in('source_record_id',ids.length?ids:['__none__']); const have=new Set((ex||[]).map((x:any)=>x.source_record_id));
 const rows=ids.filter(x=>!have.has(x)).map(x=>({run_id:c.run_id,candidate_id:CANDIDATE,state_code:'PA',source_record_id:x,record_hash:`42071|${x}`,payload:{parcel_id:x,apn:x,county_fips:'42071',county_name:'Lancaster County',state_code:'PA',source_mode:'LANCASTER_WEDGE_SEARCH_INDEX_V1761'},materialization_status:'PENDING'}));
 if(rows.length){const {error:ie}=await sb.schema('staging').from('geographic_source_records_v90').insert(rows); if(ie)throw ie;}
 await sb.schema('automation').from('geographic_source_candidates_v86').update({metadata:{...(c.metadata||{}),acquisition_status:'RUNNING',last_acquired_rows:(Number(c.metadata?.last_acquired_rows||0)+rows.length),last_acquired_prefix:prefix,last_acquired_at:new Date().toISOString(),projection:'PARCEL_ID_ONLY'}}).eq('candidate_id',CANDIDATE);
 return new Response(JSON.stringify({complete:true,candidate_id:CANDIDATE,prefix,start,records_filtered:Number(j?.recordsFiltered||0),returned:ids.length,inserted:rows.length,projection:'PARCEL_ID_ONLY',detail_pages_fetched:false,owner_address_persisted:false}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,error:String((e as any)?.message||e)}),{status:500,headers:H});}});