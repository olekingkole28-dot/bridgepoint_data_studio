const KEY="ks-orka-1814-4f8c1d7a";
function urls(s:string){const out=new Set<string>();for(const m of s.matchAll(/https?:\/\/[^\s"'<>]+/gi)) out.add(m[0].replace(/&amp;/g,'&'));return [...out];}
Deno.serve(async(req:Request)=>{try{
 if(req.method!=="POST") return new Response("method",{status:405});
 const body=await req.json().catch(()=>({}));
 if(String(body.key||"")!==KEY) return Response.json({complete:false,error:"UNAUTHORIZED"},{status:401});
 const county=String(body.county||"").trim(); if(!/^[A-Za-z .'-]{2,40}$/.test(county)) return Response.json({complete:false,error:"INVALID_COUNTY"},{status:400});
 const intro=`https://www.kansasgis.org/orka/intro.cfm?countyName=${encodeURIComponent(county)}`;
 const r1=await fetch(intro,{redirect:"manual",headers:{"user-agent":"BridgePointIntelligence/1.0 (public ORKA configuration probe)"},signal:AbortSignal.timeout(30000)});
 const html1=await r1.text(); const setCookies=r1.headers.getSetCookie?.()||[]; const cookie=setCookies.map(x=>x.split(';')[0]).join('; '); if(!cookie) throw new Error("NO_SESSION_COOKIE");
 const r2=await fetch("https://www.kansasgis.org/orka/map.cfm",{redirect:"follow",headers:{cookie,"user-agent":"BridgePointIntelligence/1.0 (public ORKA configuration probe)"},signal:AbortSignal.timeout(30000)}); const html2=await r2.text();
 const found=[...new Set([...urls(html1),...urls(html2)])]; const serviceUrls=found.filter(u=>/arcgis|MapServer|FeatureServer|rest\/services/i.test(u)); const jsSrc=[...html2.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)].map(m=>m[1]);
 return Response.json({complete:true,version:1814,county,intro_status:r1.status,map_status:r2.status,cookie_set:true,map_bytes:html2.length,service_urls:serviceUrls,all_urls:found.slice(0,150),script_src:jsSrc.slice(0,100),map_head:html2.slice(0,30000)});
}catch(e){return Response.json({complete:false,version:1814,error:String((e as any)?.message||e)},{status:500});}});