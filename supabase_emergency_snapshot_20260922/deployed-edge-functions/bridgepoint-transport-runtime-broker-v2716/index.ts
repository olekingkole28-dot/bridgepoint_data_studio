import { createClient } from "npm:@supabase/supabase-js@2.116.0";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET="living-world-archives";
const VERSION=2716;
const ISS="https://token.actions.githubusercontent.com";
const AUD="bridgepoint-transport-runtime-v2716";
const ALLOWED_WORKFLOWS=new Set([
  "olekingkole28-dot/bridgepoint_data_studio|olekingkole28-dot/bridgepoint_data_studio/.github/workflows/transport-runtime-v2716.yml@refs/heads/main",
  "olekingkole28-dot/bridgepoint-live|olekingkole28-dot/bridgepoint-live/.github/workflows/transport-runtime-pilot-v2716.yml@refs/heads/main"
]);
const JWKS="https://token.actions.githubusercontent.com/.well-known/jwks";
const STATES=new Set("AK AL AR AS AZ CA CO CT DC DE FL GA GU HI IA ID IL IN KS KY LA MA MD ME MI MN MO MP MS MT NC ND NE NH NJ NM NV NY OH OK OR PA PR RI SC SD TN TX UT VA VI VT WA WI WV WY".split(" "));
const sb=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
const PROJECT_REF=new URL(U).hostname.split(".")[0];
const DIRECT_STORAGE=`https://${PROJECT_REF}.storage.supabase.co/storage/v1`;
const H={"content-type":"application/json","access-control-allow-origin":"*","access-control-allow-headers":"content-type,x-bridgepoint-oidc","access-control-allow-methods":"POST,OPTIONS","cache-control":"no-store"};

function js(v:any,status=200){return new Response(JSON.stringify(v),{status,headers:H})}
function b64(s:string){s=s.replace(/-/g,"+").replace(/_/g,"/");while(s.length%4)s+="=";const r=atob(s),o=new Uint8Array(r.length);for(let i=0;i<r.length;i++)o[i]=r.charCodeAt(i);return o}
async function verify(token:string){
  const p=token.split("."); if(p.length!==3) throw Error("OIDC_FORMAT");
  const h=JSON.parse(new TextDecoder().decode(b64(p[0]))),c=JSON.parse(new TextDecoder().decode(b64(p[1])));
  if(h.alg!=="RS256"||!h.kid) throw Error("OIDC_HEADER");
  const rr=await fetch(JWKS,{signal:AbortSignal.timeout(10000)}); if(!rr.ok) throw Error("OIDC_JWKS_FETCH");
  const ks=await rr.json(),j=(ks.keys||[]).find((x:any)=>x.kid===h.kid); if(!j) throw Error("OIDC_KID");
  const k=await crypto.subtle.importKey("jwk",j,{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["verify"]);
  if(!(await crypto.subtle.verify("RSASSA-PKCS1-v1_5",k,b64(p[2]),new TextEncoder().encode(p[0]+"."+p[1])))) throw Error("OIDC_SIGNATURE");
  const n=Math.floor(Date.now()/1000);
  if(c.iss!==ISS) throw Error("OIDC_ISSUER");
  const a=c.aud;if(!(a===AUD||(Array.isArray(a)&&a.includes(AUD)))) throw Error("OIDC_AUDIENCE");
  if(Number(c.exp||0)<n-30||Number(c.nbf||0)>n+30) throw Error("OIDC_TIME");
  if(c.ref!=="refs/heads/main") throw Error("OIDC_REF");
  if(!["push","workflow_dispatch"].includes(String(c.event_name||""))) throw Error("OIDC_EVENT");
  const pair=String(c.repository||"")+"|"+String(c.workflow_ref||"");
  if(!ALLOWED_WORKFLOWS.has(pair)) throw Error("OIDC_REPO_WORKFLOW");
  return true;
}
function stateOf(v:any){const s=String(v||"").toUpperCase();if(!STATES.has(s))throw Error("INVALID_STATE");return s}
async function auth(b:any){const t=String(b?.oidc_token||"");if(!t)throw Error("OIDC_REQUIRED");await verify(t)}
async function authHeader(req:Request){const t=String(req.headers.get("x-bridgepoint-oidc")||"");if(!t)throw Error("OIDC_REQUIRED");await verify(t)}
function validTusUrl(raw:string){
  let u:URL;try{u=new URL(raw)}catch{throw Error("TUS_URL_FORMAT")}
  const expected=new URL(DIRECT_STORAGE);
  if(u.protocol!=="https:"||u.host!==expected.host||!u.pathname.startsWith("/storage/v1/upload/resumable/"))throw Error("TUS_URL_SCOPE");
  return u.toString();
}
function tusMeta(name:string,value:string){return name+" "+btoa(unescape(encodeURIComponent(value)))}
async function sourceObjects(state:string){
  const a=sb.schema("automation");
  const {data:man,error:me}=await a.from("transport_archive_manifest_v2696")
    .select("state_code,asset_kind,status,row_count,file_bytes,object_path,sha256,metadata")
    .eq("state_code",state).eq("status","VERIFIED");
  if(me) throw Error("MANIFEST:"+me.message);
  const out:any[]=[];
  for(const m of man||[]){
    const kind=String(m.asset_kind);
    const path=String(m.object_path||"");
    if(path.endsWith("/")){
      const {data:parts,error:pe}=await a.from("transport_archive_parts_v2705")
        .select("asset_kind,part_index,object_path,row_count,file_bytes,sha256,status")
        .eq("state_code",state).eq("asset_kind",kind).eq("status","VERIFIED").order("part_index");
      if(pe) throw Error("PARTS:"+pe.message);
      if(!(parts||[]).length) throw Error("VERIFIED_ARCHIVE_HAS_NO_PARTS:"+state+":"+kind);
      for(const p of parts||[])out.push({...p,state_code:state});
    }else{
      out.push({state_code:state,asset_kind:kind,part_index:null,object_path:path,row_count:m.row_count,file_bytes:m.file_bytes,sha256:m.sha256,status:m.status});
    }
  }
  if(out.length<2)throw Error("ARCHIVE_NOT_COMPLETE:"+state);
  return out;
}
async function approvedSourcePath(state:string,path:string){
  const rows=await sourceObjects(state);
  const hit=rows.find((x:any)=>x.object_path===path);
  if(!hit)throw Error("SOURCE_PATH_NOT_VERIFIED");
  return hit;
}
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:H});
  if(req.method!=="POST")return js({complete:false,version:VERSION,error:"POST_REQUIRED"},405);
  try{
    const url=new URL(req.url);
    if(url.searchParams.get("action")==="tus_patch"){
      await authHeader(req);
      stateOf(url.searchParams.get("state_code"));
      const uploadUrl=validTusUrl(String(url.searchParams.get("upload_url")||""));
      const offset=Number(url.searchParams.get("offset")||req.headers.get("upload-offset")||"0");
      if(!Number.isSafeInteger(offset)||offset<0)throw Error("TUS_OFFSET");
      const rr=await fetch(uploadUrl,{
        method:"PATCH",
        headers:{
          "authorization":`Bearer ${S}`,
          "apikey":S,
          "tus-resumable":"1.0.0",
          "upload-offset":String(offset),
          "content-type":"application/offset+octet-stream"
        },
        body:req.body
      });
      const next=Number(rr.headers.get("upload-offset")||offset);
      const body=rr.ok?"":(await rr.text()).slice(0,1200);
      if(!rr.ok)return js({complete:false,version:VERSION,error:"TUS_PATCH_"+rr.status,detail:body,offset},rr.status);
      return js({complete:true,version:VERSION,offset:next});
    }
    const b=await req.json().catch(()=>({})),act=String(b?.action||"status");
    if(act==="public_runtime_url"){
      const state=stateOf(b?.state_code);
      const {data,error}=await sb.schema("automation").from("transport_runtime_manifest_v2716")
        .select("status,object_path,file_bytes,sha256,minzoom,maxzoom,segment_rows,connector_rows,verified_at,metadata")
        .eq("state_code",state).eq("status","VERIFIED").maybeSingle();
      if(error)throw Error("RUNTIME_MANIFEST:"+error.message);
      if(!data?.object_path)return js({complete:true,version:VERSION,state_code:state,available:false});
      const {data:signed,error:se}=await sb.storage.from(BUCKET).createSignedUrl(data.object_path,900);
      if(se||!signed)throw Error("RUNTIME_SIGN:"+se?.message);
      return js({complete:true,version:VERSION,state_code:state,available:true,url:signed.signedUrl,expires_seconds:900,...data});
    }
    await auth(b);
    const state=stateOf(b?.state_code);
    if(act==="tus_create"){
      const bytes=Number(b?.file_bytes);
      if(!Number.isSafeInteger(bytes)||bytes<=0||bytes>536870912)throw Error("TUS_LENGTH");
      const path=`transport-runtime/v2716/${state}/transport.pmtiles`;
      const meta=[
        tusMeta("bucketName",BUCKET),
        tusMeta("objectName",path),
        tusMeta("contentType","application/octet-stream"),
        tusMeta("cacheControl","3600")
      ].join(",");
      const rr=await fetch(DIRECT_STORAGE+"/upload/resumable",{
        method:"POST",
        headers:{
          "authorization":`Bearer ${S}`,
          "apikey":S,
          "tus-resumable":"1.0.0",
          "upload-length":String(bytes),
          "upload-metadata":meta,
          "x-upsert":"true"
        }
      });
      const detail=rr.ok?"":(await rr.text()).slice(0,1200);
      if(rr.status!==201)throw Error("TUS_CREATE_"+rr.status+":"+detail);
      const loc=rr.headers.get("location");if(!loc)throw Error("TUS_LOCATION_MISSING");
      const uploadUrl=new URL(loc,DIRECT_STORAGE+"/upload/resumable").toString();
      validTusUrl(uploadUrl);
      await sb.schema("automation").from("transport_runtime_manifest_v2716").upsert({state_code:state,status:"BUILDING",object_path:path,last_error:null,updated_at:new Date().toISOString()},{onConflict:"state_code"});
      return js({complete:true,version:VERSION,state_code:state,upload_url:uploadUrl,file_bytes:bytes});
    }
    if(act==="tus_head"){
      const uploadUrl=validTusUrl(String(b?.upload_url||""));
      const rr=await fetch(uploadUrl,{method:"HEAD",headers:{"authorization":`Bearer ${S}`,"apikey":S,"tus-resumable":"1.0.0"}});
      const detail=rr.ok?"":(await rr.text()).slice(0,1200);
      if(!rr.ok)throw Error("TUS_HEAD_"+rr.status+":"+detail);
      return js({complete:true,version:VERSION,state_code:state,offset:Number(rr.headers.get("upload-offset")||0),length:Number(rr.headers.get("upload-length")||0)});
    }
    if(act==="fail"){
      const now=new Date().toISOString();
      const {error}=await sb.schema("automation").from("transport_runtime_manifest_v2716").upsert({
        state_code:state,status:"FAILED",last_error:String(b?.error||"runtime build failed").slice(0,1200),updated_at:now
      },{onConflict:"state_code"});
      if(error)throw Error("RUNTIME_FAIL_RECEIPT:"+error.message);
      return js({complete:true,version:VERSION,state_code:state,status:"FAILED"});
    }
    if(act==="list_sources"){
      const objects=await sourceObjects(state);
      const summary:any={segment_rows:0,connector_rows:0,source_bytes:0};
      for(const x of objects){summary.source_bytes+=Number(x.file_bytes||0);summary[String(x.asset_kind)+"_rows"]+=Number(x.row_count||0)}
      return js({complete:true,version:VERSION,state_code:state,objects,summary});
    }
    if(act==="sign_download"){
      const path=String(b?.object_path||"");await approvedSourcePath(state,path);
      const {data,error}=await sb.storage.from(BUCKET).createSignedUrl(path,3600);
      if(error||!data)throw Error("SOURCE_SIGN:"+error?.message);
      return js({complete:true,version:VERSION,state_code:state,object_path:path,url:data.signedUrl,expires_seconds:3600});
    }
    if(act==="sign_upload"){
      const path=`transport-runtime/v2716/${state}/transport.pmtiles`;
      const {data,error}=await sb.storage.from(BUCKET).createSignedUploadUrl(path,{upsert:true});
      if(error||!data)throw Error("RUNTIME_UPLOAD_SIGN:"+error?.message);
      await sb.schema("automation").from("transport_runtime_manifest_v2716").upsert({state_code:state,status:"BUILDING",object_path:path,last_error:null,updated_at:new Date().toISOString()},{onConflict:"state_code"});
      return js({complete:true,version:VERSION,state_code:state,object_path:path,signed_url:data.signedUrl,upload_token:data.token,expires_seconds:7200});
    }
    if(act==="finalize"){
      const path=`transport-runtime/v2716/${state}/transport.pmtiles`;
      const bytes=Number(b?.file_bytes),sha=String(b?.sha256||"").toLowerCase(),segmentRows=Number(b?.segment_rows||0),connectorRows=Number(b?.connector_rows||0);
      const minzoom=Number(b?.minzoom??5),maxzoom=Number(b?.maxzoom??16);
      if(!Number.isSafeInteger(bytes)||bytes<=0||!/^[0-9a-f]{64}$/.test(sha))throw Error("INVALID_OUTPUT_RECEIPT");
      if(!Number.isSafeInteger(segmentRows)||!Number.isSafeInteger(connectorRows)||segmentRows<0||connectorRows<0)throw Error("INVALID_ROW_COUNTS");
      const [srcs,listResp]=await Promise.all([sourceObjects(state),sb.storage.from(BUCKET).list(`transport-runtime/v2716/${state}`,{limit:20,search:"transport.pmtiles"})]);
      if(listResp.error)throw Error("RUNTIME_LIST:"+listResp.error.message);
      const obj=(listResp.data||[]).find((x:any)=>x.name==="transport.pmtiles");if(!obj)throw Error("RUNTIME_OBJECT_MISSING");
      const storageSize=Number((obj as any).metadata?.size??0);if(storageSize>0&&storageSize!==bytes)throw Error("RUNTIME_SIZE_MISMATCH");
      const expectedSeg=srcs.filter((x:any)=>x.asset_kind==="segment").reduce((a:number,x:any)=>a+Number(x.row_count||0),0);
      const expectedCon=srcs.filter((x:any)=>x.asset_kind==="connector").reduce((a:number,x:any)=>a+Number(x.row_count||0),0);
      if(segmentRows!==expectedSeg||connectorRows!==expectedCon)throw Error("RUNTIME_ROW_COUNT_MISMATCH");
      const now=new Date().toISOString();
      const {error}=await sb.schema("automation").from("transport_runtime_manifest_v2716").upsert({
        state_code:state,status:"VERIFIED",object_path:path,file_bytes:bytes,sha256:sha,
        segment_rows:segmentRows,connector_rows:connectorRows,minzoom,maxzoom,
        generated_at:String(b?.generated_at||now),verified_at:now,last_error:null,
        metadata:{...(b?.metadata||{}),storage_size:storageSize,source_object_count:srcs.length,source_archive_version:2696,truth:"[REDACTED_LONG_LITERAL]"},
        updated_at:now
      },{onConflict:"state_code"});
      if(error)throw Error("RUNTIME_FINALIZE:"+error.message);
      return js({complete:true,version:VERSION,state_code:state,status:"VERIFIED",object_path:path,file_bytes:bytes,segment_rows:segmentRows,connector_rows:connectorRows});
    }
    return js({complete:false,version:VERSION,error:"UNKNOWN_ACTION"},400);
  }catch(e){return js({complete:false,version:VERSION,error:String((e as any)?.message||e)},500)}
});