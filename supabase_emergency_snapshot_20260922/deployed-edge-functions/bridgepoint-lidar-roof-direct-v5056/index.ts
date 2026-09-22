import {createClient} from "npm:@supabase/supabase-js@2.112.4";
import {parse} from "npm:@loaders.gl/core@4.3.4";
import {LASLoader} from "npm:@loaders.gl/las@4.3.4";

const U=Deno.env.get("SUPABASE_URL")!;
const A=Deno.env.get("SUPABASE_ANON_KEY")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function authorize(req:Request){
  const auth=req.headers.get("authorization")||"";
  if(!auth.toLowerCase().startsWith("bearer "))return false;
  const token=auth.slice(7).trim();
  if(token===S)return true;
  const user=createClient(U,A,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:auth}}});
  const {data,error}=await user.auth.getUser(token);
  if(error||!data?.user)return false;
  const owner=await user.rpc("bridgepoint_owner_home_command_center_v2160");
  return !owner.error;
}

async function rpc(schema:string,name:string,body:any){
  const r=await fetch(U+"/rest/v1/rpc/"+name,{
    method:"POST",
    headers:{apikey:S,authorization:"Bearer "+S,"content-type":"application/json","content-profile":schema,"accept-profile":schema},
    body:JSON.stringify(body)
  });
  const t=await r.text();
  if(!r.ok)throw new Error(name+"_"+r.status+":"+t.slice(0,500));
  return t?JSON.parse(t):null;
}
const val=(a:any)=>a?.value??a;
function polys(g:any){if(g?.type==="Polygon")return[g.coordinates];if(g?.type==="MultiPolygon")return g.coordinates;return[]}
function inRing(x:number,y:number,r:any[]){let inside=false;for(let i=0,j=r.length-1;i<r.length;j=i++){const xi=+r[i][0],yi=+r[i][1],xj=+r[j][0],yj=+r[j][1];if(((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/((yj-yi)||1e-12)+xi))inside=!inside}return inside}
function insideGeom(x:number,y:number,g:any){for(const p of polys(g)){if(p?.[0]&&inRing(x,y,p[0])&&!p.slice(1).some((h:any)=>inRing(x,y,h)))return true}return false}
function pct(a:number[],q:number){if(!a.length)return NaN;const s=[...a].sort((x,y)=>x-y),p=(s.length-1)*q,i=Math.floor(p),f=p-i;return s[i+1]!==undefined?s[i]+f*(s[i+1]-s[i]):s[i]}
function solve3(A:number[][],b:number[]){const M=A.map((r,i)=>[...r,b[i]]);for(let c=0;c<3;c++){let p=c;for(let r=c+1;r<3;r++)if(Math.abs(M[r][c])>Math.abs(M[p][c]))p=r;[M[c],M[p]]=[M[p],M[c]];if(Math.abs(M[c][c])<1e-10)return null;const d=M[c][c];for(let j=c;j<4;j++)M[c][j]/=d;for(let r=0;r<3;r++){if(r===c)continue;const f=M[r][c];for(let j=c;j<4;j++)M[r][j]-=f*M[c][j]}}return[M[0][3],M[1][3],M[2][3]]}
function fit(pts:number[][]){const cx=pts.reduce((s,p)=>s+p[0],0)/pts.length,cy=pts.reduce((s,p)=>s+p[1],0)/pts.length;let xx=0,xy=0,yy=0,xz=0,yz=0,z=0;for(const p of pts){const dx=p[0]-cx,dy=p[1]-cy;xx+=dx*dx;xy+=dx*dy;yy+=dy*dy;xz+=dx*p[2];yz+=dy*p[2];z+=p[2]}const sol=solve3([[xx,xy,0],[xy,yy,0],[0,0,pts.length]],[xz,yz,z]);if(!sol)return null;const[a,b,c]=sol;let se=0;for(const p of pts){const pred=a*(p[0]-cx)+b*(p[1]-cy)+c;se+=(p[2]-pred)**2}return{pitch_deg:Math.atan(Math.hypot(a,b))*180/Math.PI,azimuth_deg:((Math.atan2(-a,-b)*180/Math.PI)%360+360)%360,rmse_m:Math.sqrt(se/pts.length),a,b,c,cx,cy}}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response(JSON.stringify({complete:false,error:"POST_REQUIRED"}),{status:405,headers:{"content-type":"application/json","cache-control":"no-store"}});
  if(!(await authorize(req)))return new Response(JSON.stringify({complete:false,error:"OWNER_OR_SERVICE_ROLE_REQUIRED"}),{status:403,headers:{"content-type":"application/json","cache-control":"no-store"}});
  try{
    const body=await req.json().catch(()=>({})),project=String(body.project_key||"AK_Fairbanks-NSBorough_2010"),buildingId=Number(body.building_id||8815),node=String(body.node_key||"9-410-182-257");
    if(!Number.isSafeInteger(buildingId)||buildingId<=0||project.length>180||node.length>180)throw new Error("INVALID_INPUT");
    const token=(await fetch(U+"/rest/v1/geographic_expansion_worker_secret_v90?singleton=eq.true&select=task_token",{headers:{apikey:S,authorization:"Bearer "+S,"accept-profile":"automation"}}).then(r=>r.json()))?.[0]?.task_token;
    if(!token)throw new Error("TOKEN_MISSING");
    const meta=await rpc("automation","lidar_roof_project_payload_v5052",{p_project_key:project}),bld=await rpc("public","bridgepoint_lidar_roof_building_v5056",{p_task_token:token,p_project_key:project,p_building_id:buildingId});
    if(!bld?.geometry_3857)throw new Error("BUILDING_PAYLOAD_MISSING");
    const base=String(meta.ept_url).replace(/\/ept\.json$/,""),r=await fetch(base+"/ept-data/"+node+".laz",{signal:AbortSignal.timeout(30000)});
    if(!r.ok)throw new Error("LAZ_"+r.status);
    const ab=await r.arrayBuffer(),p:any=await parse(ab,LASLoader,{las:{shape:"columnar",fp64:true}}),attrs=p?.attributes||{},pos=val(attrs.POSITION),cls=val(attrs.classification),count=p?.header?.vertexCount||(pos?Math.floor(pos.length/3):0);
    const all:number[][]=[],class6:number[][]=[],ground:number[][]=[];
    for(let i=0;i<count;i++){const x=pos[i*3],y=pos[i*3+1],z=pos[i*3+2],c=cls?Number(cls[i]):0;if(!insideGeom(x,y,bld.geometry_3857))continue;if(c===2)ground.push([x,y,z]);if(c===6)class6.push([x,y,z]);if(![2,7,9,18].includes(c))all.push([x,y,z])}
    const use=class6.length>=12?class6:all;
    if(use.length<12)return new Response(JSON.stringify({complete:false,version:5300,error:"INSUFFICIENT_BUILDING_POINTS",project,building_id:buildingId,node,decoded_points:count,inside_points:all.length,class6_points:class6.length,ground_points:ground.length}),{status:422,headers:{"content-type":"application/json","cache-control":"no-store"}});
    const zs=use.map(p=>p[2]),lo=pct(zs,.55),hi=pct(zs,.97),roof=use.filter(p=>p[2]>=lo&&p[2]<=hi+.75);
    if(roof.length<10)throw new Error("INSUFFICIENT_ROOF_POINTS");
    const f=fit(roof);if(!f)throw new Error("PLANE_FIT_FAILED");
    const flat=f.pitch_deg<3&&f.rmse_m<.45;
    return new Response(JSON.stringify({complete:true,version:5300,project_key:project,building_id:buildingId,node_key:node,bytes:ab.byteLength,decoded_points:count,inside_points:all.length,class6_points:class6.length,ground_points:ground.length,fit_points:roof.length,z:{p05:pct(zs,.05),p50:pct(zs,.5),p95:pct(zs,.95)},pitch_deg:f.pitch_deg,azimuth_deg:f.azimuth_deg,rmse_m:f.rmse_m,roof_shape:flat?"flat":null,pitch_truth:f.rmse_m<=1.25,direction_truth:f.rmse_m<=1.25,shape_truth:flat,truth_class:"SOURCE_DERIVED_LIDAR_ROOF_PLANE",source:"USGS 3DEP EPT"}),{headers:{"content-type":"application/json","cache-control":"no-store","x-content-type-options":"nosniff"}});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5300,error:"ROOF_DIAGNOSTIC_FAILED"}),{status:500,headers:{"content-type":"application/json","cache-control":"no-store"}});
  }
});