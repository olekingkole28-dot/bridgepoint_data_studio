import {parse} from "npm:@loaders.gl/core@4.3.4";
import {LASLoader} from "npm:@loaders.gl/las@4.3.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
async function rpc(name:string,body:any){const r=await fetch(U+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:S,authorization:"Bearer "+S,"content-type":"application/json","content-profile":"automation","accept-profile":"automation"},body:JSON.stringify(body)});const t=await r.text();if(!r.ok)throw new Error(name+"_"+r.status+":"+t.slice(0,300));return t?JSON.parse(t):null}
Deno.serve(async(req)=>{
 try{
  const b=await req.json().catch(()=>({})),key=String(b.project_key||"AK_BrooksCamp_2012"),node=String(b.node||"0-0-0-0");
  const m=await rpc("lidar_roof_project_payload_v5052",{p_project_key:key});if(!m?.ept_url)throw new Error("PROJECT_NOT_FOUND");
  const base=String(m.ept_url).replace(/\/ept\.json$/,""),url=base+"/ept-data/"+node+".laz";
  const r=await fetch(url,{signal:AbortSignal.timeout(30000)});if(!r.ok)throw new Error("LAZ_"+r.status);const ab=await r.arrayBuffer();
  const parsed:any=await parse(ab,LASLoader,{las:{shape:"columnar",fp64:true}});
  const attrs=parsed?.attributes||parsed?.data?.attributes||{};
  const pos=attrs.POSITION?.value||attrs.POSITION||attrs.position?.value||attrs.position;
  const n=parsed?.header?.vertexCount||parsed?.loaderData?.pointsCount||parsed?.length||(pos?Math.floor(pos.length/3):0);
  const sample=[];if(pos){for(let i=0;i<Math.min(5,n);i++)sample.push([pos[i*3],pos[i*3+1],pos[i*3+2]])}
  return new Response(JSON.stringify({complete:true,version:5053,project:key,node,bytes:ab.byteLength,count:n,attr_keys:Object.keys(attrs),sample,header:parsed?.header||null}),{headers:{"content-type":"application/json"}})
 }catch(e){return new Response(JSON.stringify({complete:false,version:5053,error:String((e as any)?.message||e)}),{status:500,headers:{"content-type":"application/json"}})}
});