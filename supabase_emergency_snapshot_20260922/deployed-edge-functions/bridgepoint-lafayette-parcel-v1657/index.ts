import { inflateSync } from "npm:fflate@0.8.2";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const V=1657;
const URL="https://content.lafayetteassessor.com/uploads/2023_Parcelsfor_Tax_Roll_9ff7e43b7d.zip";
const TASK="6fb58a09-8052-4a1e-ab12-973f9457422f";
const DBF="2023_ParcelsforTaxRoll.dbf";
const td=new TextDecoder("utf-8",{fatal:false});

function u16(b:Uint8Array,o:number){return b[o]|(b[o+1]<<8)}
function u32(b:Uint8Array,o:number){return (b[o]|(b[o+1]<<8)|(b[o+2]<<16)|(b[o+3]<<24))>>>0}

async function rpc(name:string,body:any){
  const r=await fetch(`${U}/rest/v1/rpc/${name}`,{method:"POST",headers:{"content-type":"application/json","apikey":S,"authorization":`Bearer ${S}`},body:JSON.stringify(body),signal:AbortSignal.timeout(70000)});
  const t=await r.text();
  if(!r.ok) throw new Error(`RPC_${name}_${r.status}:${t.slice(0,500)}`);
  return t?JSON.parse(t):null;
}

async function sizeOf(url:string){
  const r=await fetch(url,{method:"HEAD",headers:{"Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(15000)});
  const n=Number(r.headers.get("content-length")||0);
  if(!r.ok||!n) throw new Error(`ARCHIVE_HEAD_${r.status}`);
  return {n,url:r.url};
}

async function rf(url:string,a:number,z:number){
  const r=await fetch(url,{headers:{Range:`bytes=${a}-${z}`,Accept:"application/octet-stream","Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(30000)});
  if(!(r.status===206||r.status===200)) throw new Error(`RANGE_HTTP_${r.status}`);
  let b=new Uint8Array(await r.arrayBuffer());
  if(r.status===200 && b.length>(z-a+1) && a>0) b=b.slice(a,Math.min(z+1,b.length));
  return {b,url:r.url};
}

function eocd(b:Uint8Array){for(let i=b.length-22;i>=0;i--)if(b[i]===80&&b[i+1]===75&&b[i+2]===5&&b[i+3]===6)return i;return -1}

async function fetchDbf(){
  const sm=await sizeOf(URL);
  const tailLen=Math.min(sm.n,70000);
  const tail=await rf(sm.url,sm.n-tailLen,sm.n-1);
  const e=eocd(tail.b); if(e<0) throw new Error("ZIP_EOCD_NOT_FOUND");
  const cdSize=u32(tail.b,e+12),cdOff=u32(tail.b,e+16);
  const cd=await rf(sm.url,cdOff,cdOff+cdSize-1);
  let p=0,hit:any=null;
  while(p+46<=cd.b.length){
    if(!(cd.b[p]===80&&cd.b[p+1]===75&&cd.b[p+2]===1&&cd.b[p+3]===2)) break;
    const method=u16(cd.b,p+10),cs=u32(cd.b,p+20),us=u32(cd.b,p+24),fn=u16(cd.b,p+28),ex=u16(cd.b,p+30),cm=u16(cd.b,p+32),lo=u32(cd.b,p+42);
    const name=td.decode(cd.b.slice(p+46,p+46+fn));
    if(name.toLowerCase()===DBF.toLowerCase()){hit={name,method,cs,us,lo};break}
    p+=46+fn+ex+cm;
  }
  if(!hit) throw new Error("DBF_ENTRY_NOT_FOUND");
  const lh=await rf(sm.url,hit.lo,hit.lo+65535);
  const lfn=u16(lh.b,26),lex=u16(lh.b,28),dataStart=hit.lo+30+lfn+lex;
  const cr=await rf(sm.url,dataStart,dataStart+hit.cs-1);
  if(hit.method!==8) throw new Error(`ZIP_METHOD_${hit.method}_UNSUPPORTED`);
  const out=inflateSync(cr.b);
  if(out.length!==hit.us) throw new Error(`DBF_SIZE_MISMATCH_${out.length}_${hit.us}`);
  return out;
}

function parseFields(b:Uint8Array,headerLen:number){
  const fields:any[]=[]; let dataOff=1;
  for(let p=32;p+32<=headerLen;p+=32){
    if(b[p]===0x0d) break;
    const raw=b.slice(p,p+11); let z=raw.indexOf(0); if(z<0) z=raw.length;
    const name=td.decode(raw.slice(0,z)).trim(); if(!name) break;
    const type=String.fromCharCode(b[p+11]); const len=b[p+16]; const dec=b[p+17];
    fields.push({name,type,len,dec,off:dataOff}); dataOff+=len;
  }
  return fields;
}

function clean(s:string){return s.replace(/\u0000/g,"").trim()}

Deno.serve(async(req:Request)=>{
  let authed=false;
  try{
    if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
    const x=await req.json().catch(()=>({}));
    const token=String(x.task_token||req.headers.get("x-bridgepoint-worker-token")||"");
    const a=await rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:token});
    if(a!==true) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
    authed=true;

    const start=Math.max(0,Number(x.offset||0)|0);
    const page=Math.min(Math.max(Number(x.page||2000)|0,250),4000);
    const dbf=await fetchDbf();
    const n=u32(dbf,4),headerLen=u16(dbf,8),recordLen=u16(dbf,10);
    if(n<=0||headerLen<33||recordLen<2) throw new Error("INVALID_DBF_HEADER");
    const fields=parseFields(dbf,headerLen);
    const wanted=new Set(["GlobalID","Name","PrimaryUse","SUB_ID","StatedArea","StatedAr_1","Calculated","Research_S"]);
    const picked=fields.filter((f:any)=>wanted.has(f.name));
    if(!picked.some((f:any)=>f.name==="GlobalID")||!picked.some((f:any)=>f.name==="Name")) throw new Error("REQUIRED_DBF_FIELDS_MISSING");

    const end=Math.min(n,start+page); const records:any[]=[];
    for(let i=start;i<end;i++){
      const base=headerLen+i*recordLen; if(base+recordLen>dbf.length) break;
      if(dbf[base]===0x2a) continue;
      const vals:any={};
      for(const f of picked){vals[f.name]=clean(td.decode(dbf.slice(base+f.off,base+f.off+f.len)));}
      const rid=vals.GlobalID||vals.Name; if(!rid) continue;
      const acreage=vals.Calculated||vals.StatedArea||null;
      records.push({
        _bridgepoint_source_record_id:String(rid),
        GlobalID:vals.GlobalID||null,
        Name:vals.Name||null,
        PrimaryUse:vals.PrimaryUse||null,
        SUB_ID:vals.SUB_ID||null,
        StatedArea:vals.StatedArea||null,
        StatedAr_1:vals.StatedAr_1||null,
        Calculated:vals.Calculated||null,
        Research_S:vals.Research_S||null,
        parcel_number:vals.Name||null,
        parcel_id:vals.Name||null,
        acreage,
        land_use_code:vals.PrimaryUse||null,
        county_name:"Lafayette",
        county_fips:"22055",
        state_code:"LA",
        source_year:2023
      });
    }

    const done=end>=n;
    const next={pagination_mode:"OFFSET_DBF_V1657",offset:end,estimated_total_rows:n,keyset_rows_seen:end};
    const staged=await rpc("bridgepoint_expansion_worker_stage_records_v90",{
      p_source_task_id:TASK,
      p_records:records,
      p_next_cursor:next,
      p_done:done,
      p_result:{lafayette_dbf_worker_v1657:true,batch_size:records.length,progress_from:start,progress_to:end,estimated_total_rows:n,dbf_header_length:headerLen,dbf_record_length:recordLen,privacy_minimized:true,owner_field_excluded:true,confidential_taxpayer_fields_excluded:true,source_url:URL,last_batch_at:new Date().toISOString()}
    });
    return new Response(JSON.stringify({complete:true,version:V,records:records.length,from:start,to:end,total:n,done,staged}),{headers:H});
  }catch(e){
    const msg=String((e as any)?.message||e);
    if(authed){try{await rpc("bridgepoint_expansion_worker_fail_task_v90",{p_source_task_id:TASK,p_error:msg,p_detail:{lafayette_dbf_worker_v1657:true,source_url:URL,privacy_minimized:true,owner_field_excluded:true}});}catch{}}
    return new Response(JSON.stringify({complete:false,version:V,error:msg}),{status:500,headers:H});
  }
});
