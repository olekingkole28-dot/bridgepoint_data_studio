import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get('SUPABASE_URL')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const db = createClient(url, service, { auth: { persistSession: false } });

function b64ToBytes(s:string):Uint8Array {
  const clean=s.replace(/\s+/g,'');
  const bin=atob(clean);
  const out=new Uint8Array(bin.length);
  for(let i=0;i<bin.length;i++) out[i]=bin.charCodeAt(i);
  return out;
}
async function sha256(bytes:Uint8Array){
  const hash=await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(hash)).map(x=>x.toString(16).padStart(2,'0')).join('');
}

Deno.serve(async (req:Request)=>{
  try {
    const body=await req.json();
    const urls=Array.isArray(body?.urls)?body.urls.map(String):[];
    const expected=String(body?.expected_sha256||'');
    const objectPath=String(body?.object_path||'current-clean-v2.tar.gz');
    if(!urls.length || !expected) return new Response(JSON.stringify({complete:false,error:'urls and expected_sha256 required'}),{status:400,headers:{'content-type':'application/json'}});
    let b64='';
    for(const u of urls){
      const r=await fetch(u,{headers:{'cache-control':'no-cache'}});
      if(!r.ok) throw new Error(`download ${r.status}`);
      b64 += (await r.text()).trim();
    }
    const bytes=b64ToBytes(b64);
    const actual=await sha256(bytes);
    if(actual!==expected) throw new Error(`sha mismatch ${actual}`);
    const {error}=await db.storage.from('bridgepoint-release-handoff').upload(objectPath,bytes,{contentType:'application/gzip',upsert:true,cacheControl:'60'});
    if(error) throw error;
    const pub=db.storage.from('bridgepoint-release-handoff').getPublicUrl(objectPath).data.publicUrl;
    return new Response(JSON.stringify({complete:true,bytes:bytes.length,sha256:actual,object_path:objectPath,public_url:pub}),{headers:{'content-type':'application/json'}});
  } catch(e){
    return new Response(JSON.stringify({complete:false,error:String(e?.message||e)}),{status:500,headers:{'content-type':'application/json'}});
  }
});
