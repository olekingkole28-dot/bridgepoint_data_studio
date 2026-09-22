import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json","cache-control":"no-store"};
const td=new TextDecoder();
function u16(b:Uint8Array,o:number){return b[o]|(b[o+1]<<8)}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const body=await req.json().catch(()=>({}));
 const s=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
 const a=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(body.task_token||req.headers.get("x-bridgepoint-worker-token")||"")});
 if(a.error||a.data!==true)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const url=String(body.target_url||""); if(!/^https?:\/\//i.test(url)) throw new Error("TARGET_URL_REQUIRED");
 const maxCompressed=Math.min(Math.max(Number(body.max_compressed||4194304),262144),16777216);
 const wantText=Math.min(Math.max(Number(body.max_text||262144),4096),1048576);
 const r=await fetch(url,{headers:{Range:`bytes=0-${maxCompressed-1}`,Accept:"application/octet-stream","Accept-Encoding":"identity","User-Agent":"BridgePointIntelligence/1.0"},redirect:"follow",signal:AbortSignal.timeout(60000)});
 if(!(r.status===206||r.status===200)) throw new Error(`HTTP_${r.status}`);
 const b=new Uint8Array(await r.arrayBuffer());
 if(b.length<30||b[0]!==0x50||b[1]!==0x4b||b[2]!==0x03||b[3]!==0x04) throw new Error("ZIP_LOCAL_HEADER_NOT_FOUND");
 const method=u16(b,8), fn=u16(b,26), ex=u16(b,28), dataOff=30+fn+ex;
 const name=td.decode(b.slice(30,30+fn));
 if(method!==8) throw new Error(`UNSUPPORTED_METHOD_${method}`);
 const comp=b.slice(dataOff);
 const src=new ReadableStream<Uint8Array>({start(c){c.enqueue(comp);c.close();}});
 const ds=new DecompressionStream("deflate-raw");
 const reader=src.pipeThrough(ds).getReader();
 const chunks:Uint8Array[]=[];let total=0;let streamError:string|null=null;
 try{while(total<wantText){const x=await reader.read();if(x.done)break;if(x.value){const take=x.value.slice(0,Math.max(0,wantText-total));chunks.push(take);total+=take.length;if(total>=wantText){try{await reader.cancel();}catch{}break;}}}}catch(e){streamError=String((e as any)?.message||e)}
 const out=new Uint8Array(total);let p=0;for(const c of chunks){out.set(c,p);p+=c.length;}
 let text=td.decode(out).replace(/\u0000/g,"");
 text=text.replace(/[^\x09\x0A\x0D\x20-\x7E\u00A0-\uFFFF]/g,"");
 return new Response(JSON.stringify({complete:true,version:1929,http_status:r.status,entry_name:name,method,data_offset:dataOff,compressed_bytes_available:comp.length,text_bytes:total,stream_error:streamError,text}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,version:1929,error:String((e as any)?.message||e)}),{status:500,headers:H});}});
