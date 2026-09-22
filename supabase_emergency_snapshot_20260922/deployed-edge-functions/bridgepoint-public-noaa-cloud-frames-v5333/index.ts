import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const C={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS","content-type":"application/json","cache-control":"public,max-age=90,stale-while-revalidate=240"};
const json=(x:unknown,s=200)=>new Response(JSON.stringify(x),{status:s,headers:C});
const S="https://nowcoast.noaa.gov/geoserver/observations/satellite/ows",L="global_visible_imagery_mosaic";
function frames(raw:string){const out:string[]=[];for(const token of raw.trim().split(",").map(x=>x.trim()).filter(Boolean)){const p=token.split("/");if(p.length===3){const a=new Date(p[0]),b=new Date(p[1]),m=/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/i.exec(p[2]),step=((Number(m?.[1]||0)*3600)+(Number(m?.[2]||0)*60)+Number(m?.[3]||0))*1000;if(Number.isFinite(a.getTime())&&Number.isFinite(b.getTime())&&step>0)for(let t=a.getTime();t<=b.getTime()&&out.length<2400;t+=step)out.push(new Date(t).toISOString())}else{const d=new Date(token);if(Number.isFinite(d.getTime()))out.push(d.toISOString())}}return[...new Set(out)].sort()}
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:C});
 if(req.method!=="POST")return json({complete:false,error:"POST_REQUIRED"},405);
 try{
  const r=await fetch(S+"?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities",{headers:{"User-Agent":"BridgePoint Intelligence public NOAA renderer"},signal:AbortSignal.timeout(9000)});
  if(!r.ok)return json({complete:true,degraded:true,service_url:S,layer:L,frames:[]},200);
  const xml=await r.text(),at=xml.indexOf("<Name>"+L+"</Name>");if(at<0)return json({complete:true,degraded:true,service_url:S,layer:L,frames:[]},200);
  const matches:[number,string][]=[];const re=/<(?:Dimension|Extent)[^>]*name=["']time["'][^>]*>([\s\S]*?)<\/(?:Dimension|Extent)>/ig;let m:RegExpExecArray|null;while((m=re.exec(xml))!==null)matches.push([m.index,(m[1]||"").replace(/&amp;/g,"&").trim()]);matches.sort((a,b)=>Math.abs(a[0]-at)-Math.abs(b[0]-at));
  const cutoff=Date.now()-8*3600000,fs=frames(matches[0]?.[1]||"").filter(x=>{const t=new Date(x).getTime();return t>=cutoff&&t<=Date.now()+300000}).slice(-72);
  return json({complete:true,degraded:fs.length<2,provider:"NOAA nowCOAST",product:"Global visible satellite imagery",service_url:S,layer:L,frames:fs,latest_frame:fs.at(-1)??null,generated_at:new Date().toISOString()});
 }catch(e){return json({complete:true,degraded:true,service_url:S,layer:L,frames:[],error:String((e as any)?.message||e)},200)}
});