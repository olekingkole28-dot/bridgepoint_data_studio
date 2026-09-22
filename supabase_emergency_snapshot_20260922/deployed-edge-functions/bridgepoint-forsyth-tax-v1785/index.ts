const H={"content-type":"application/json","cache-control":"no-store"};
const NONCE="forsyth-v1785-e4d1c826";
const BASE="https://forsythproperty.assurancegov.com";
function cookies(headers:Headers){
 const h:any=headers as any; const arr:string[] = typeof h.getSetCookie==='function' ? h.getSetCookie() : [];
 if(arr.length) return arr.map(x=>x.split(';')[0]).join('; ');
 const one=headers.get('set-cookie')||''; return one ? one.split(/,(?=[^;,]+=)/).map(x=>x.split(';')[0]).join('; ') : '';
}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:H});
 const b=await req.json().catch(()=>({})); if(String(b.nonce||'')!==NONCE) return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const g=await fetch(BASE+'/Property/Search',{headers:{'user-agent':'BridgePointIntelligence/1.0 (public-property-record-adapter)','accept':'text/html'},redirect:'manual',signal:AbortSignal.timeout(30000)});
 const html=await g.text(); const ck=cookies(g.headers);
 const tm=html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/i); if(!tm) throw new Error('CSRF_TOKEN_NOT_FOUND');
 const hasTurnstileField=/name=["'](?:cf-turnstile-response|turnstile)["']/i.test(html) || /class=["'][^"']*cf-turnstile/i.test(html);
 if(hasTurnstileField) return new Response(JSON.stringify({complete:false,blocked:true,reason:'TURNSTILE_FIELD_PRESENT_NO_BYPASS'}),{status:409,headers:H});
 const type=String(b.search_type||'parcel'), criteria=String(b.criteria??''), year=Number(b.year??2026);
 const form=new URLSearchParams();
 form.set('PropertySearchYear',String(year)); form.set('PropertySearchType',type); form.set('SearchCriteria.Criteria1',criteria); form.set('SearchCriteria.Criteria2',''); form.set('UseContains','False'); form.set('SelectedParcels',''); form.set('__RequestVerificationToken',tm[1]);
 const p=await fetch(BASE+'/Property/Search',{method:'POST',headers:{'user-agent':'BridgePointIntelligence/1.0 (public-property-record-adapter)','accept':'text/html, */*; q=0.01','content-type':'application/x-www-form-urlencoded; charset=UTF-8','x-requested-with':'XMLHttpRequest','referer':BASE+'/Property/Search',...(ck?{'cookie':ck}:{})},body:form.toString(),redirect:'manual',signal:AbortSignal.timeout(30000)});
 const out=await p.text();
 const parcels=[...out.matchAll(/ParcelNumber(?:Formatted)?(?:\\u0022|&quot;|\")?\s*[:=]\s*(?:\\u0022|&quot;|\")([^"<\\]+?)(?:\\u0022|&quot;|\")/gi)].map(m=>m[1]);
 const parcelText=[...out.matchAll(/(?:ParcelNumberFormatted|ParcelNumber)[^A-Za-z0-9]{1,30}([A-Za-z0-9-]{3,40})/gi)].map(m=>m[1]);
 const totalM=out.match(/(?:\\"total\\"|&quot;total&quot;|total)\s*[:=]\s*(\d+)/i);
 const turnstileResponse=/cf-turnstile|turnstile-response/i.test(out);
 return new Response(JSON.stringify({complete:true,version:1785,get_status:g.status,post_status:p.status,cookie_present:!!ck,csrf:true,turnstile_field_get:hasTurnstileField,turnstile_marker_post:turnstileResponse,search_type:type,criteria,year,response_bytes:out.length,total_hint:totalM?Number(totalM[1]):null,parcel_candidates:[...new Set([...parcels,...parcelText])].slice(0,30),preview:out.slice(0,3000)}),{headers:H});
}catch(e){return new Response(JSON.stringify({complete:false,version:1785,error:String((e as any)?.stack||(e as any)?.message||e)}),{status:500,headers:H});}});
