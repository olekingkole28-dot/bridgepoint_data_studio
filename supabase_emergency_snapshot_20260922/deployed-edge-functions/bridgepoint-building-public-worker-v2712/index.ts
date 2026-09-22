import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const U=Deno.env.get('SUPABASE_URL')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BUCKET='living-world-archives';
const ISS='https://token.actions.githubusercontent.com';
const AUD='bridgepoint-building-public-v2712';
const REPO='olekingkole28-dot/bridgepoint-live';
const WF='olekingkole28-dot/bridgepoint-live/.github/workflows/building-public-worker-v2712.yml';
const JWKS='https://token.actions.githubusercontent.com/.well-known/jwks';
const STATES=new Set('AK AL AR AS AZ CA CO CT DC DE FL GA GU HI IA ID IL IN KS KY LA MA MD ME MI MN MO MP MS MT NC ND NE NH NJ NM NV NY OH OK OR PA PR RI SC SD TN TX UT VA VI VT WA WI WV WY'.split(' '));
const sb=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});

function b64(s:string){s=s.replace(/-/g,'+').replace(/_/g,'/');while(s.length%4)s+='=';const r=atob(s),o=new Uint8Array(r.length);for(let i=0;i<r.length;i++)o[i]=r.charCodeAt(i);return o}
async function verify(t:string){
  const p=t.split('.'); if(p.length!==3) throw Error('OIDC_FORMAT');
  const h=JSON.parse(new TextDecoder().decode(b64(p[0]))), c=JSON.parse(new TextDecoder().decode(b64(p[1])));
  const rr=await fetch(JWKS,{signal:AbortSignal.timeout(10000)}); if(!rr.ok) throw Error('OIDC_JWKS');
  const ks=await rr.json(), j=(ks.keys||[]).find((x:any)=>x.kid===h.kid); if(!j) throw Error('OIDC_KID');
  const k=await crypto.subtle.importKey('jwk',j,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
  if(!(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',k,b64(p[2]),new TextEncoder().encode(p[0]+'.'+p[1])))) throw Error('OIDC_SIGNATURE');
  const n=Math.floor(Date.now()/1000);
  if(c.iss!==ISS) throw Error('OIDC_ISSUER');
  if(!(c.aud===AUD||(Array.isArray(c.aud)&&c.aud.includes(AUD)))) throw Error('OIDC_AUDIENCE');
  if(Number(c.exp||0)<n-30) throw Error('OIDC_TIME');
  if(c.repository!==REPO || c.repository_owner!=='olekingkole28-dot' || c.ref!=='refs/heads/main') throw Error('OIDC_REPO_REF');
  if(c.event_name!=='push') throw Error('OIDC_EVENT');
  if(String(c.workflow_ref||'')!==WF+'@refs/heads/main') throw Error('OIDC_WORKFLOW');
  return c;
}
async function auth(b:any){ await verify(String(b?.oidc_token||'')); }
function target(b:any){const state=String(b?.state_code||'').toUpperCase(),kind=String(b?.asset_kind||'').toLowerCase();if(!STATES.has(state))throw Error('INVALID_STATE');if(!['building','building_part'].includes(kind))throw Error('INVALID_KIND');return{state,kind}}
function pathFor(s:string,k:string,i:number){return `buildings/v2710/${s}/${k}/part-${String(i).padStart(5,'0')}.parquet`}
function js(x:any,s=200){return new Response(JSON.stringify(x),{status:s,headers:{'content-type':'application/json'}})}

Deno.serve(async req=>{
  try{
    const b=await req.json().catch(()=>({}));
    const act=String(b?.action||'status');
    if(act==='status'){
      const {data,error}=await sb.rpc('bridgepoint_public_building_archive_status_v2710');
      if(error) throw Error(error.message);
      return js(data);
    }
    await auth(b);
    const {state,kind}=target(b);
    if(act==='report'){
      const {data,error}=await sb.rpc('bridgepoint_building_archive_report_v2710',{p_state_code:state,p_asset_kind:kind,p_status:String(b.status),p_stage:String(b.stage||'UNKNOWN'),p_message:String(b.message||''),p_metadata:{...(b.metadata||{}),runner_repo:REPO,worker_version:2712}});
      if(error) throw Error(error.message); return js(data);
    }
    if(act==='reset_parts'){
      const {data,error}=await sb.rpc('bridgepoint_building_archive_reset_parts_v2710',{p_state_code:state,p_asset_kind:kind});
      if(error) throw Error(error.message); return js(data);
    }
    if(act==='sign_part'){
      const i=Number(b.part_index); if(!Number.isSafeInteger(i)||i<0) throw Error('INVALID_PART');
      const path=pathFor(state,kind,i);
      const {data,error}=await sb.storage.from(BUCKET).createSignedUploadUrl(path,{upsert:true});
      if(error||!data) throw Error(`SIGN:${error?.message||'no data'}`);
      return js({complete:true,path,signed_url:data.signedUrl});
    }
    if(act==='finalize_part'){
      const i=Number(b.part_index),path=pathFor(state,kind,i),v=b.validation||{},rc=Number(b.row_count),fb=Number(b.file_bytes),sha=String(b.sha256||'').toLowerCase();
      if(!Number.isSafeInteger(i)||i<0||!Number.isFinite(rc)||rc<0||!Number.isFinite(fb)||fb<=0||!/^[a-f0-9]{64}$/.test(sha)) throw Error('INVALID_FINALIZE');
      const prefix=`buildings/v2710/${state}/${kind}`,name=`part-${String(i).padStart(5,'0')}.parquet`;
      const {data:list,error:le}=await sb.storage.from(BUCKET).list(prefix,{limit:1000,search:name}); if(le) throw Error(le.message);
      const o=(list||[]).find((x:any)=>x.name===name); if(!o) throw Error('OBJECT_NOT_FOUND');
      const ss=Number((o as any).metadata?.size??0); if(ss>0&&ss!==fb) throw Error('SIZE_MISMATCH');
      const {data,error}=await sb.rpc('bridgepoint_building_archive_finalize_part_v2710',{p_state_code:state,p_asset_kind:kind,p_part_index:i,p_object_path:path,p_row_count:rc,p_file_bytes:fb,p_sha256:sha,p_validation:v,p_metadata:{...(b.metadata||{}),storage_size:ss,runner_repo:REPO,worker_version:2712}});
      if(error) throw Error(error.message); return js(data);
    }
    if(act==='complete_sharded'){
      const {data,error}=await sb.rpc('bridgepoint_building_archive_complete_sharded_v2710',{p_state_code:state,p_asset_kind:kind,p_part_count:Number(b.part_count),p_total_rows:Number(b.total_rows),p_total_bytes:Number(b.total_bytes),p_aggregate_sha256:String(b.aggregate_sha256||''),p_metadata:{...(b.metadata||{}),runner_repo:REPO,worker_version:2712}});
      if(error) throw Error(error.message); return js(data);
    }
    return js({complete:false,error:'UNKNOWN_ACTION'},400);
  }catch(e){return js({complete:false,error:String((e as any)?.message||e)},500)}
});
