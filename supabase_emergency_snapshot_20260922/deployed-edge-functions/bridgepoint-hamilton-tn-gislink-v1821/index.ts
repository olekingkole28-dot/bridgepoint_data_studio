import { Unzip, UnzipInflate } from "npm:fflate@0.8.2";
const U=Deno.env.get('SUPABASE_URL')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const H={'content-type':'application/json','cache-control':'no-store'};
const V=1822;
const CAND='3b213fa4-fd7a-4c06-864d-8393e40f3aaa';
const TASK='50a22a98-3c57-4286-a26c-48e53ab95e16';
const ZIP='https://www.hamiltontn.gov/_downloadsAssessor/AssessorExportCSV.zip';
async function rpcPublic(name:string,body:any){const r=await fetch(`${U}/rest/v1/rpc/${name}`,{method:'POST',headers:{'content-type':'application/json','apikey':S,'authorization':`Bearer ${S}`},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});const t=await r.text();if(!r.ok)throw new Error(`RPC_${name}_${r.status}:${t.slice(0,400)}`);return t?JSON.parse(t):null;}
async function rpcAuto(name:string,body:any){const r=await fetch(`${U}/rest/v1/rpc/${name}`,{method:'POST',headers:{'content-type':'application/json','apikey':S,'authorization':`Bearer ${S}`,'Content-Profile':'automation','Accept-Profile':'automation'},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});const t=await r.text();if(!r.ok)throw new Error(`RPC_${name}_${r.status}:${t.slice(0,400)}`);return t?JSON.parse(t):null;}
async function assertCompliance(){const r=await fetch(`${U}/rest/v1/source_compliance_validation_v720?candidate_id=eq.${CAND}&select=activation_status,rights_status,privacy_status,local_law_status,allowed_use_scope`,{headers:{apikey:S,authorization:`Bearer ${S}`,'Accept-Profile':'automation'},signal:AbortSignal.timeout(15000)});const t=await r.text();if(!r.ok)throw new Error(`COMPLIANCE_HTTP_${r.status}:${t.slice(0,300)}`);const x=JSON.parse(t)?.[0];if(!x||x.activation_status!=='APPROVED'||x.rights_status!=='PASS'||x.privacy_status!=='PASS'||x.local_law_status!=='PASS'||!String(x.allowed_use_scope||'').includes('GISLink'))throw new Error('COMPLIANCE_NOT_APPROVED_GISLINK_ONLY');}
function firstField(line:string){line=line.replace(/^\uFEFF/,'');if(line.startsWith('"')){let out='';for(let i=1;i<line.length;i++){const c=line[i];if(c==='"'){if(line[i+1]==='"'){out+='"';i++;continue;}break;}out+=c;}return out.trim();}const i=line.indexOf(',');return (i>=0?line.slice(0,i):line).trim();}
Deno.serve(async(req:Request)=>{let authed=false;try{
 if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST_REQUIRED'}),{status:405,headers:H});
 const b=await req.json().catch(()=>({}));
 const token=String(b.task_token||req.headers.get('x-bridgepoint-worker-token')||'');
 if(await rpcPublic('bridgepoint_expansion_worker_auth_v90',{p_task_token:token})!==true)return new Response(JSON.stringify({complete:false,error:'UNAUTHORIZED'}),{status:401,headers:H});
 authed=true; await assertCompliance();
 const r=await fetch(ZIP,{headers:{'accept':'application/zip,*/*','accept-encoding':'identity','user-agent':'BridgePointIntelligence/1.0 (+official-public-assessor-gislink-ingest)'},redirect:'follow',signal:AbortSignal.timeout(120000)});
 if(!r.ok||!r.body)throw new Error(`ZIP_HTTP_${r.status}`);
 const ids=new Set<string>(); let archiveBytes=0,totalLines=0,targetStarted=false,targetName='';let zipErr:any=null;
 let resolveTarget!:()=>void,rejectTarget!:(e:any)=>void;const targetDone=new Promise<void>((res,rej)=>{resolveTarget=res;rejectTarget=rej});
 const unzip=new Unzip(file=>{
   const n=file.name.toLowerCase(); const target=n.endsWith('.csv')&&!n.includes('building');
   if(!target){file.ondata=(err,_data,_final)=>{if(err)zipErr=err};file.start();return;}
   if(targetStarted){file.ondata=(err,_data,_final)=>{if(err)zipErr=err};file.start();return;}
   targetStarted=true;targetName=file.name;const dec=new TextDecoder();let carry='';
   const handle=(line:string)=>{if(!line)return;totalLines++;const id=firstField(line);if(!id||/^gislink$/i.test(id))return;if(id.length<=64&&!/[\r\n]/.test(id))ids.add(id)};
   file.ondata=(err,data,final)=>{try{if(err){rejectTarget(err);return;}const text=dec.decode(data,{stream:!final});const all=carry+text;const lines=all.split(/\r?\n/);if(final){carry='';for(const ln of lines)handle(ln);resolveTarget();}else{carry=lines.pop()||'';for(const ln of lines)handle(ln);}}catch(e){rejectTarget(e)}};
   file.start();
 });
 unzip.register(UnzipInflate);
 const reader=r.body.getReader();while(true){const z=await reader.read();if(z.done)break;if(z.value){archiveBytes+=z.value.byteLength;unzip.push(z.value,false)}}unzip.push(new Uint8Array(0),true);
 if(zipErr)throw zipErr;if(!targetStarted)throw new Error('CSV_MEMBER_NOT_FOUND');
 await Promise.race([targetDone,new Promise((_,rej)=>setTimeout(()=>rej(new Error('CSV_DECOMPRESS_TIMEOUT')),60000))]);
 const arr=[...ids];let inserted=0;for(let i=0;i<arr.length;i+=5000){const x=await rpcAuto('stage_hamilton_tn_gislinks_v1821',{p_links:arr.slice(i,i+5000)});inserted+=Number(x?.inserted||0)}
 const done=await rpcAuto('complete_hamilton_tn_gislink_v1821',{p_unique:arr.length,p_total_lines:totalLines,p_archive_bytes:archiveBytes});
 return new Response(JSON.stringify({complete:true,version:V,candidate_id:CAND,task_id:TASK,target_file:targetName,archive_bytes:archiveBytes,total_lines:totalLines,unique_gislinks:arr.length,newly_inserted:inserted,projection:'GISLINK_ONLY',raw_archive_persisted:false,owner_address_value_legal_sale_geometry_persisted:false,completion:done}),{headers:H});
}catch(e){const msg=String((e as any)?.message||e);if(authed){try{await rpcAuto('fail_hamilton_tn_gislink_v1821',{p_error:msg})}catch{}}return new Response(JSON.stringify({complete:false,version:V,error:msg}),{status:500,headers:H});}});