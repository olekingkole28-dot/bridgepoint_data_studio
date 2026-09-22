import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const U=Deno.env.get('SUPABASE_URL')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BUCKET='living-world-archives';
const ISS='https://token.actions.githubusercontent.com';
const AUD='bridgepoint-building-crosswalk-v2752';
const JWKS='https://token.actions.githubusercontent.com/.well-known/jwks';
const WORKFLOWS=new Set(['olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-v2752.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-ny-v2761.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-dc-v2763.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-parallel-v2772.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-spatial-v2775.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-rescue-v2779.yml@refs/heads/main','olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-rescue-subparts-v2780.yml@refs/heads/main']);
// v2781 isolated rescue allowlist
// v2781 isolated rescue allowlist
// v2781 isolated rescue allowlist
WORKFLOWS.add('olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-rescue-ny6-v2783.yml@refs/heads/main');
WORKFLOWS.add('olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-rescue-ny6-v2784.yml@refs/heads/main');
WORKFLOWS.add('olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-rescue-ny6-v2787.yml@refs/heads/main');
const ALLOWED_REPO='olekingkole28-dot/bridgepoint-live';
const STATES=new Set(['DC','LA','NY','PA']);
const sb=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});

function b64(s:string){
  s=s.replace(/-/g,'+').replace(/_/g,'/');
  while(s.length%4)s+='=';
  const r=atob(s),o=new Uint8Array(r.length);
  for(let i=0;i<r.length;i++)o[i]=r.charCodeAt(i);
  return o;
}
async function verify(t:string){
  const p=t.split('.');
  if(p.length!==3)throw Error('OIDC_FORMAT');
  const h=JSON.parse(new TextDecoder().decode(b64(p[0])));
  const c=JSON.parse(new TextDecoder().decode(b64(p[1])));
  const rr=await fetch(JWKS,{signal:AbortSignal.timeout(10000)});
  if(!rr.ok)throw Error('OIDC_JWKS');
  const ks=await rr.json();
  const j=(ks.keys||[]).find((x:any)=>x.kid===h.kid);
  if(!j)throw Error('OIDC_KID');
  const k=await crypto.subtle.importKey('jwk',j,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
  if(!(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',k,b64(p[2]),new TextEncoder().encode(p[0]+'.'+p[1]))))throw Error('OIDC_SIGNATURE');
  const n=Math.floor(Date.now()/1000);
  if(c.iss!==ISS)throw Error('OIDC_ISSUER');
  if(!(c.aud===AUD||(Array.isArray(c.aud)&&c.aud.includes(AUD))))throw Error('OIDC_AUDIENCE');
  if(Number(c.exp||0)<n-30)throw Error('OIDC_TIME');
  if(String(c.repository||'')!==ALLOWED_REPO)throw Error('OIDC_REPOSITORY');
  if(String(c.ref||'')!=='refs/heads/main')throw Error('OIDC_REF');
  if(!WORKFLOWS.has(String(c.workflow_ref||'')))throw Error('OIDC_WORKFLOW');
  return c;
}
function stateOf(b:any){
  const s=String(b?.state_code||'').toUpperCase();
  if(!STATES.has(s))throw Error('INVALID_STATE');
  return s;
}
function partPath(s:string,i:number){
  return `buildings/v2752/current-crosswalk/${s}/part-${String(i).padStart(5,'0')}.parquet`;
}
function js(x:any,status=200){return new Response(JSON.stringify(x),{status,headers:{'content-type':'application/json'}})}

Deno.serve(async req=>{
  try{
    const b=await req.json().catch(()=>({}));
    const claims=await verify(String(b?.oidc_token||''));
    const wf=String(claims?.workflow_ref||'');
    if(wf==='olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-parallel-v2772.yml@refs/heads/main'
       && String(claims?.run_id||'')!=='34540191497'){
      throw Error('PARALLEL_RUN_SUPERSEDED');
    }
    if(wf==='olekingkole28-dot/bridgepoint-live/.github/workflows/current-building-crosswalk-rescue-subparts-v2780.yml@refs/heads/main'
       && String(claims?.run_id||'')==='34547002578'){
      throw Error('RESCUE_RUN_SUPERSEDED');
    }
    const act=String(b?.action||'');
    const state=stateOf(b);

    if(act==='catalog'){
      const {data,error}=await sb.rpc('bridgepoint_public_current_crosswalk_catalog_v2752',{p_state_code:state});
      if(error)throw Error(`CATALOG_RPC:${error.message}`);
      return js(data);
    }
    if(act==='local_page'){
      const after=Number(b?.after_id||0);
      const limit=Math.min(Math.max(Number(b?.limit||10000),100),10000);
      if(!Number.isSafeInteger(after)||after<0)throw Error('INVALID_AFTER_ID');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_local_page_v2752',{
        p_state_code:state,p_after_id:after,p_limit:limit
      });
      if(error)throw Error(`LOCAL_PAGE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='local_lane_page'){
      const after=Number(b?.after_id||0),lane=Number(b?.lane),lanes=Number(b?.lanes);
      const limit=Math.min(Math.max(Number(b?.limit||10000),100),10000);
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes))throw Error('INVALID_LANE_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_local_lane_page_v2772',{
        p_state_code:state,p_lane:lane,p_lanes:lanes,p_after_id:after,p_limit:limit
      });
      if(error)throw Error(`LOCAL_LANE_PAGE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='prepare_spatial'){
      const lanes=Number(b?.lanes);
      if(!Number.isSafeInteger(lanes)||lanes<2||lanes>16)throw Error('INVALID_SPATIAL_LANES');
      const {data,error}=await sb.rpc('bridgepoint_prepare_current_crosswalk_spatial_v2775',{
        p_state_code:state,p_lanes:lanes
      });
      if(error)throw Error(`PREPARE_SPATIAL_RPC:${error.message}`);
      return js(data);
    }
    if(act==='local_spatial_lane_page'){
      const after=Number(b?.after_id||0),lane=Number(b?.lane),lanes=Number(b?.lanes);
      const limit=Math.min(Math.max(Number(b?.limit||10000),100),10000);
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes))throw Error('INVALID_SPATIAL_LANE_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_spatial_lane_page_v2775',{
        p_state_code:state,p_lane:lane,p_lanes:lanes,p_after_id:after,p_limit:limit
      });
      if(error)throw Error(`LOCAL_SPATIAL_LANE_PAGE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='local_spatial_sublane_page'){
      const after=Number(b?.after_id||0),lane=Number(b?.lane),lanes=Number(b?.lanes);
      const sublane=Number(b?.sublane),sublanes=Number(b?.sublanes);
      const limit=Math.min(Math.max(Number(b?.limit||10000),100),10000);
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes)||!Number.isSafeInteger(sublane)||!Number.isSafeInteger(sublanes))throw Error('INVALID_SPATIAL_SUBLANE_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_spatial_sublane_page_v2780',{
        p_state_code:state,p_lane:lane,p_lanes:lanes,p_sublane:sublane,p_sublanes:sublanes,p_after_id:after,p_limit:limit
      });
      if(error)throw Error(`LOCAL_SPATIAL_SUBLANE_PAGE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='local_spatial_substripe_page'){
      const after=Number(b?.after_id||0),lane=Number(b?.lane),lanes=Number(b?.lanes);
      const sublane=Number(b?.sublane),sublanes=Number(b?.sublanes);
      const limit=Math.min(Math.max(Number(b?.limit||10000),100),10000);
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes)||!Number.isSafeInteger(sublane)||!Number.isSafeInteger(sublanes))throw Error('INVALID_SPATIAL_SUBSTRIPE_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_spatial_substripe_page_v2783',{
        p_state_code:state,p_lane:lane,p_lanes:lanes,p_sublane:sublane,p_sublanes:sublanes,p_after_id:after,p_limit:limit
      });
      if(error)throw Error(`LOCAL_SPATIAL_SUBSTRIPE_PAGE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='source_runs_substripe'){
      const lane=Number(b?.lane),lanes=Number(b?.lanes);
      const sublane=Number(b?.sublane),sublanes=Number(b?.sublanes);
      if(!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes)||!Number.isSafeInteger(sublane)||!Number.isSafeInteger(sublanes))throw Error('INVALID_SPATIAL_SUBSTRIPE_RUN_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_spatial_substripe_source_runs_v27',{
        p_state_code:state,p_lane:lane,p_lanes:lanes,p_sublane:sublane,p_sublanes:sublanes
      });
      if(error)throw Error(`SOURCE_RUNS_SUBSTRIPE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='source_runs_spatial'){
      const lane=Number(b?.lane),lanes=Number(b?.lanes);
      if(!Number.isSafeInteger(lane)||!Number.isSafeInteger(lanes))throw Error('INVALID_SPATIAL_RUN_ARGS');
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_spatial_source_runs_v2775',{
        p_state_code:state,p_lane:lane,p_lanes:lanes
      });
      if(error)throw Error(`SOURCE_RUNS_SPATIAL_RPC:${error.message}`);
      return js(data);
    }
    if(act==='parts'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_parts_v2762',{p_state_code:state});
      if(error)throw Error(`PARTS_RPC:${error.message}`);
      return js(data);
    }
    if(act==='source_runs'){
      const {data,error}=await sb.rpc('bridgepoint_public_current_crosswalk_source_runs_v2769',{p_state_code:state});
      if(error)throw Error(`SOURCE_RUNS_RPC:${error.message}`);
      return js(data);
    }
    if(act==='archive_parts'){
      const {data,error}=await sb.rpc('bridgepoint_public_building_archive_parts_v2760',{
        p_state_code:state,p_asset_kind:'building'
      });
      if(error)throw Error(`ARCHIVE_PARTS_RPC:${error.message}`);
      const parts=Array.isArray(data?.parts)?data.parts:[];
      if(!parts.length)throw Error('ARCHIVE_PARTS_EMPTY');
      const out=[];
      for(const p of parts){
        if(String(p?.status||'')!=='VERIFIED'||!p?.object_path)throw Error('ARCHIVE_PART_NOT_VERIFIED');
        const {data:signed,error:se}=await sb.storage.from(BUCKET).createSignedUrl(String(p.object_path),21600);
        if(se||!signed?.signedUrl)throw Error(`ARCHIVE_SIGN:${se?.message||'no signed url'}`);
        out.push({
          part_index:Number(p.part_index),
          row_count:Number(p.row_count||0),
          file_bytes:Number(p.file_bytes||0),
          object_path:String(p.object_path),
          signed_url:signed.signedUrl
        });
      }
      return js({complete:true,state_code:state,parts:out,part_count:out.length});
    }
    if(act==='report'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_report_v2752',{
        p_state_code:state,p_status:String(b?.status||'BUILDING'),p_metadata:b?.metadata||{}
      });
      if(error)throw Error(`REPORT_RPC:${error.message}`);
      return js(data);
    }
    if(act==='prepare_parallel'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_prepare_parallel_v2772',{p_state_code:state});
      if(error)throw Error(`PREPARE_PARALLEL_RPC:${error.message}`);
      return js(data);
    }
    if(act==='reset_parts'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_reset_parts_v2752',{p_state_code:state});
      if(error)throw Error(`RESET_RPC:${error.message}`);
      return js(data);
    }
    if(act==='sign_part'){
      const i=Number(b?.part_index);
      if(!Number.isSafeInteger(i)||i<0)throw Error('INVALID_PART');
      const path=partPath(state,i);
      const {data,error}=await sb.storage.from(BUCKET).createSignedUploadUrl(path,{upsert:true});
      if(error||!data)throw Error(`SIGN:${error?.message||'no data'}`);
      return js({complete:true,path,signed_url:data.signedUrl});
    }
    if(act==='finalize_part'){
      const i=Number(b?.part_index);
      if(!Number.isSafeInteger(i)||i<0)throw Error('INVALID_PART');
      const path=partPath(state,i);
      if(String(b?.object_path||path)!==path)throw Error('INVALID_OBJECT_PATH');
      const fb=Number(b?.file_bytes||0);
      const sha=String(b?.sha256||'').toLowerCase();
      if(!Number.isSafeInteger(fb)||fb<=0||!/^[0-9a-f]{64}$/.test(sha))throw Error('INVALID_FILE_PROOF');

      const prefix=`buildings/v2752/current-crosswalk/${state}`;
      const name=`part-${String(i).padStart(5,'0')}.parquet`;
      const {data:list,error:le}=await sb.storage.from(BUCKET).list(prefix,{limit:1000,search:name});
      if(le)throw Error(`LIST:${le.message}`);
      const o=(list||[]).find((x:any)=>x.name===name);
      if(!o)throw Error('OBJECT_NOT_FOUND');
      const storageSize=Number((o as any).metadata?.size??0);
      if(storageSize>0&&storageSize!==fb)throw Error(`SIZE_MISMATCH:${storageSize}:${fb}`);

      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_finalize_part_v2752',{
        p_state_code:state,
        p_part_index:i,
        p_object_path:path,
        p_row_count:Number(b?.row_count||0),
        p_confirmed_rows:Number(b?.confirmed_rows||0),
        p_candidate_rows:Number(b?.candidate_rows||0),
        p_unmatched_rows:Number(b?.unmatched_rows||0),
        p_file_bytes:fb,
        p_sha256:sha,
        p_validation:b?.validation||{},
        p_metadata:{...(b?.metadata||{}),storage_size:storageSize}
      });
      if(error)throw Error(`FINALIZE_PART_RPC:${error.message}`);

      const {data:download,error:downloadError}=await sb.storage.from(BUCKET).createSignedUrl(path,3600);
      if(downloadError||!download?.signedUrl)throw Error(`DOWNLOAD_SIGN:${downloadError?.message||'no signed url'}`);
      const {data:imported,error:importError}=await sb.rpc('bridgepoint_import_current_crosswalk_part_v2759',{
        p_state_code:state,
        p_part_index:i,
        p_signed_url:download.signedUrl
      });
      if(importError)throw Error(`IMPORT_RPC:${importError.message}`);
      return js({finalized:data,imported});
    }
    if(act==='complete_sharded'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_complete_sharded_v2752',{
        p_state_code:state,
        p_part_count:Number(b?.part_count||0),
        p_source_files:Number(b?.source_files||0),
        p_aggregate_sha256:String(b?.aggregate_sha256||'').toLowerCase(),
        p_validation:b?.validation||{},
        p_metadata:b?.metadata||{}
      });
      if(error)throw Error(`COMPLETE_RPC:${error.message}`);
      return js(data);
    }
    if(act==='complete_parallel'){
      const {data,error}=await sb.rpc('bridgepoint_current_crosswalk_complete_parallel_v2772',{
        p_state_code:state,
        p_lane_count:Number(b?.lane_count||0),
        p_source_files:Number(b?.source_files||0),
        p_aggregate_sha256:String(b?.aggregate_sha256||'').toLowerCase(),
        p_metadata:b?.metadata||{}
      });
      if(error)throw Error(`COMPLETE_PARALLEL_RPC:${error.message}`);
      return js(data);
    }

    return js({complete:false,error:'UNKNOWN_ACTION'},400);
  }catch(e){
    return js({complete:false,error:String((e as any)?.message||e)},500);
  }
});