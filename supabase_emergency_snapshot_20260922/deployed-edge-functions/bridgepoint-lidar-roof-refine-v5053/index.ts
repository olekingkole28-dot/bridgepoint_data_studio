import {parse} from "npm:@loaders.gl/core@4.3.4";
import {LASLoader} from "npm:@loaders.gl/las@4.3.4";

const U=Deno.env.get("SUPABASE_URL")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const JSONH={"content-type":"application/json"};
const hierarchyCache=new Map<string,any>();
const nodeCache=new Map<string,any>();

function cacheSet(map:Map<string,any>,key:string,value:any,limit:number){
  if(map.has(key))map.delete(key);
  map.set(key,value);
  while(map.size>limit){const first=map.keys().next().value;if(first===undefined)break;map.delete(first)}
}
async function rpc(name:string,body:any){
  const r=await fetch(U+"/rest/v1/rpc/"+name,{
    method:"POST",
    headers:{apikey:S,authorization:"Bearer "+S,"content-type":"application/json","content-profile":"automation","accept-profile":"automation"},
    body:JSON.stringify(body)
  });
  const t=await r.text();
  if(!r.ok)throw new Error(name+"_"+r.status+":"+t.slice(0,700));
  return t?JSON.parse(t):null;
}
function bboxGeom(g:any){
  let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
  const walk=(x:any)=>{
    if(!Array.isArray(x))return;
    if(x.length>=2&&typeof x[0]==="number"&&typeof x[1]==="number"){
      minX=Math.min(minX,x[0]);maxX=Math.max(maxX,x[0]);minY=Math.min(minY,x[1]);maxY=Math.max(maxY,x[1]);return;
    }
    for(const y of x)walk(y);
  };
  walk(g?.coordinates);
  return [minX,minY,maxX,maxY];
}
function pointInRing(x:number,y:number,ring:any[]){
  let inside=false;
  for(let i=0,j=ring.length-1;i<ring.length;j=i++){
    const xi=ring[i]?.[0],yi=ring[i]?.[1],xj=ring[j]?.[0],yj=ring[j]?.[1];
    if(!Number.isFinite(xi)||!Number.isFinite(yi)||!Number.isFinite(xj)||!Number.isFinite(yj))continue;
    const hit=((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi+1e-15)+xi);
    if(hit)inside=!inside;
  }
  return inside;
}
function pointInPolygon(x:number,y:number,poly:any[]){
  if(!poly?.length||!pointInRing(x,y,poly[0]))return false;
  for(let i=1;i<poly.length;i++)if(pointInRing(x,y,poly[i]))return false;
  return true;
}
function pointInGeometry(x:number,y:number,g:any){
  if(g?.type==="Polygon")return pointInPolygon(x,y,g.coordinates);
  if(g?.type==="MultiPolygon")return (g.coordinates||[]).some((p:any)=>pointInPolygon(x,y,p));
  return false;
}
function nodeParts(key:string){
  const p=key.split("-").map(Number);
  return {d:p[0],x:p[1],y:p[2],z:p[3]};
}
function nodeXYBounds(key:string,b:number[]){
  const n=nodeParts(key),div=2**n.d,w=(b[3]-b[0])/div,h=(b[4]-b[1])/div;
  return [b[0]+n.x*w,b[1]+n.y*h,b[0]+(n.x+1)*w,b[1]+(n.y+1)*h];
}
function intersects(a:number[],b:number[]){
  return a[0]<=b[2]&&a[2]>=b[0]&&a[1]<=b[3]&&a[3]>=b[1];
}
async function hierarchyPage(base:string,key:string){
  const ck=base+"|"+key;if(hierarchyCache.has(ck))return hierarchyCache.get(ck);
  const r=await fetch(base+"/ept-hierarchy/"+key+".json",{headers:{accept:"application/json"},signal:AbortSignal.timeout(20000)});
  if(!r.ok)throw new Error("HIER_"+key+"_"+r.status);
  const data=await r.json();cacheSet(hierarchyCache,ck,data,24);return data;
}
async function nodesForBuilding(base:string,bounds:number[],bbox:number[]){
  const queue=["0-0-0-0"],visited=new Set<string>(),positive:any[]=[];
  while(queue.length&&visited.size<18){
    const page=queue.shift()!;if(visited.has(page))continue;visited.add(page);
    const h=await hierarchyPage(base,page);
    for(const [key,v0] of Object.entries(h)){
      const v=Number(v0);if(!intersects(nodeXYBounds(key,bounds),bbox))continue;
      if(v===-1){if(!visited.has(key))queue.push(key)}
      else if(v>0){const d=nodeParts(key).d;positive.push({key,count:v,d})}
    }
  }
  if(!positive.length)return [];
  const maxDepth=Math.max(...positive.map(x=>x.d));
  const candidates=positive
    .filter(x=>x.d>=Math.max(0,maxDepth-3))
    .sort((a,b)=>b.d-a.d||a.count-b.count);
  const chosen:any[]=[];let expected=0;
  for(const n of candidates){
    if(chosen.length>=12)break;
    if(expected>220000&&chosen.length>=3)break;
    chosen.push(n);expected+=n.count;
  }
  return chosen;
}
function attrValue(a:any){return a?.value||a||null}
function quantile(vals:number[],q:number){
  if(!vals.length)return NaN;
  const a=[...vals].sort((x,y)=>x-y),p=(a.length-1)*q,lo=Math.floor(p),hi=Math.ceil(p);
  return lo===hi?a[lo]:a[lo]+(a[hi]-a[lo])*(p-lo);
}
function fitPlane(points:number[][]){
  if(points.length<12)return null;
  let mx=0,my=0,mz=0;for(const p of points){mx+=p[0];my+=p[1];mz+=p[2]}
  mx/=points.length;my/=points.length;mz/=points.length;
  let sxx=0,syy=0,sxy=0,sxz=0,syz=0;
  for(const p of points){const x=p[0]-mx,y=p[1]-my,z=p[2]-mz;sxx+=x*x;syy+=y*y;sxy+=x*y;sxz+=x*z;syz+=y*z}
  const det=sxx*syy-sxy*sxy;if(Math.abs(det)<1e-8)return null;
  const a=(sxz*syy-syz*sxy)/det,b=(syz*sxx-sxz*sxy)/det;
  let se=0;for(const p of points){const pred=mz+a*(p[0]-mx)+b*(p[1]-my),e=p[2]-pred;se+=e*e}
  const rmse=Math.sqrt(se/points.length);
  const pitch=Math.atan(Math.sqrt(a*a+b*b))*180/Math.PI;
  let az=Math.atan2(-a,-b)*180/Math.PI;if(az<0)az+=360;
  return {a,b,c:mz-a*mx-b*my,rmse,pitch,azimuth:az};
}
function plane3(p1:number[],p2:number[],p3:number[]){
  const ux=p2[0]-p1[0],uy=p2[1]-p1[1],uz=p2[2]-p1[2];
  const vx=p3[0]-p1[0],vy=p3[1]-p1[1],vz=p3[2]-p1[2];
  const nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;
  if(Math.abs(nz)<1e-8)return null;
  const a=-nx/nz,b=-ny/nz,c=p1[2]-a*p1[0]-b*p1[1];
  const pitch=Math.atan(Math.sqrt(a*a+b*b))*180/Math.PI;
  return {a,b,c,pitch};
}
function dominantPlane(points:number[][]){
  if(points.length<20){const f=fitPlane(points);return f?{...f,inlier_count:points.length,inlier_ratio:1}:null}
  const n=points.length,tol=.42;let best:any=null,bestCount=0;
  for(let iter=0;iter<96;iter++){
    let i=(iter*37)%n,j=(iter*67+11)%n,k=(iter*97+23)%n;
    if(j===i)j=(j+1)%n;if(k===i||k===j)k=(k+2)%n;
    const m=plane3(points[i],points[j],points[k]);if(!m||m.pitch>80)continue;
    let count=0;
    for(const p of points)if(Math.abs(p[2]-(m.a*p[0]+m.b*p[1]+m.c))<=tol)count++;
    if(count>bestCount){bestCount=count;best=m}
  }
  if(!best||bestCount<Math.max(20,Math.floor(n*.12))){
    const f=fitPlane(points);return f?{...f,inlier_count:n,inlier_ratio:1}:null
  }
  const inliers=points.filter(p=>Math.abs(p[2]-(best.a*p[0]+best.b*p[1]+best.c))<=tol);
  const f=fitPlane(inliers);if(!f)return null;
  return {...f,inlier_count:inliers.length,inlier_ratio:inliers.length/n}
}
function pushCapped(arr:any[],v:any,cap:number){if(arr.length<cap)arr.push(v)}
async function decodeNode(base:string,key:string){
  const ck=base+"|"+key;if(nodeCache.has(ck))return nodeCache.get(ck);
  const r=await fetch(base+"/ept-data/"+key+".laz",{signal:AbortSignal.timeout(30000)});
  if(!r.ok)throw new Error("LAZ_"+key+"_"+r.status);
  const ab=await r.arrayBuffer();
  const parsed:any=await parse(ab,LASLoader,{las:{shape:"columnar",fp64:true}});
  const attrs=parsed?.attributes||parsed?.data?.attributes||{};
  const pos=attrValue(attrs.POSITION||attrs.position),cls=attrValue(attrs.classification||attrs.CLASSIFICATION);
  const n=parsed?.header?.vertexCount||parsed?.loaderData?.pointsCount||(pos?Math.floor(pos.length/3):0);
  const out={pos,cls,n,bytes:ab.byteLength};
  cacheSet(nodeCache,ck,out,18);
  return out;
}
async function deriveBuilding(base:string,projectBounds:number[],b:any){
  const id=Number(b.building_id),g=b.geometry_3857;
  const bb=bboxGeom(g);if(!bb.every(Number.isFinite))return {building_id:id,status:"BAD_GEOMETRY"};
  const expanded=[bb[0]-6,bb[1]-6,bb[2]+6,bb[3]+6];
  const nodes=await nodesForBuilding(base,projectBounds,expanded);
  if(!nodes.length)return {building_id:id,status:"NO_EPT_NODES"};
  const insideAll:number[][]=[],insideClass6:number[][]=[],groundClass2:number[]=[],outsideZ:number[]=[];
  let decoded=0;
  for(const n of nodes){
    const d=await decodeNode(base,n.key);decoded+=d.n||0;if(!d.pos)continue;
    for(let i=0;i<d.n;i++){
      const x=Number(d.pos[i*3]),y=Number(d.pos[i*3+1]),z=Number(d.pos[i*3+2]);
      if(!Number.isFinite(x)||!Number.isFinite(y)||!Number.isFinite(z))continue;
      if(x<expanded[0]||x>expanded[2]||y<expanded[1]||y>expanded[3])continue;
      const c=d.cls?Number(d.cls[i]):NaN;
      if(pointInGeometry(x,y,g)){
        pushCapped(insideAll,[x,y,z],8000);
        if(c===6)pushCapped(insideClass6,[x,y,z],8000);
      }else{
        if(c===2)pushCapped(groundClass2,z,5000);
        pushCapped(outsideZ,z,5000);
      }
    }
  }
  let roof=insideClass6.length>=20?insideClass6:insideAll;
  if(roof.length<18)return {building_id:id,status:"INSUFFICIENT_ROOF_POINTS",roof_point_count:roof.length,ground_point_count:groundClass2.length,decoded_point_count:decoded,nodes_used:nodes.map(x=>x.key)};
  const rz=roof.map(p=>p[2]),lo=quantile(rz,.05),hi=quantile(rz,.98);
  roof=roof.filter(p=>p[2]>=lo&&p[2]<=hi);
  const groundVals=groundClass2.length>=8?groundClass2:outsideZ;
  if(groundVals.length<8)return {building_id:id,status:"INSUFFICIENT_GROUND_POINTS",roof_point_count:roof.length,ground_point_count:groundVals.length,decoded_point_count:decoded,nodes_used:nodes.map(x=>x.key)};
  const ground=quantile(groundVals,groundClass2.length>=8?.5:.15),roofTop=quantile(roof.map(p=>p[2]),.95),height=roofTop-ground;
  if(!Number.isFinite(height)||height<1.5||height>250)return {building_id:id,status:"HEIGHT_QUALITY_REJECT",roof_height_m:height,roof_point_count:roof.length,ground_point_count:groundVals.length,decoded_point_count:decoded,nodes_used:nodes.map(x=>x.key)};
  const plane=dominantPlane(roof);
  const pitch=plane&&plane.pitch<=75&&plane.rmse<=.75&&plane.inlier_ratio>=.12?plane.pitch:null;
  const az=plane&&pitch!=null?plane.azimuth:null;
  return {
    building_id:id,status:"DERIVED",
    roof_height_m:Number(height.toFixed(3)),
    pitch_deg:pitch==null?null:Number(pitch.toFixed(3)),
    azimuth_deg:az==null?null:Number(az.toFixed(3)),
    plane_rmse_m:plane?Number(plane.rmse.toFixed(3)):null,
    plane_inlier_count:plane?.inlier_count||0,
    plane_inlier_ratio:plane?Number(plane.inlier_ratio.toFixed(4)):null,
    roof_point_count:roof.length,ground_point_count:groundVals.length,decoded_point_count:decoded,
    ground_z_m:Number(ground.toFixed(3)),roof_top_z_m:Number(roofTop.toFixed(3)),
    nodes_used:nodes.map(x=>x.key)
  };
}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("POST required",{status:405});
  let body:any={};try{body=await req.json()}catch{}
  const token=String(body.task_token||"");
  let claim:any=null;
  try{
    claim=await rpc("lidar_roof_refine_claim_v5053",{p_task_token:token,p_building_limit:Math.min(Math.max(Number(body.building_limit||4),1),4)});
    if(!claim||claim.skipped)return new Response(JSON.stringify(claim||{complete:true,version:5054,skipped:"NO_CLAIM"}),{headers:JSONH});
    const base=String(claim.project?.ept_url||"").replace(/\/ept\.json$/,""),bounds=claim.project?.ept_bounds;
    if(!base||!Array.isArray(bounds))throw new Error("CLAIM_PROJECT_METADATA_MISSING");
    const results:any[]=[];
    for(const b of claim.buildings||[]){
      try{results.push(await deriveBuilding(base,bounds,b))}
      catch(e){results.push({building_id:Number(b.building_id),status:"BUILDING_ERROR",error:String((e as any)?.message||e).slice(0,400)})}
    }
    const finished=await rpc("lidar_roof_refine_finish_v5053",{
      p_task_token:token,p_derivation_id:claim.derivation_id,p_lease_token:claim.lease_token,
      p_next_building_id:claim.next_building_id,p_success:true,p_results:results,p_error:null
    });
    return new Response(JSON.stringify({complete:true,version:5054,project_key:claim.project_key,derivation_id:claim.derivation_id,claim_count:claim.building_count,cache:{hierarchy:hierarchyCache.size,nodes:nodeCache.size},results,finish:finished}),{headers:JSONH})
  }catch(e){
    if(claim?.derivation_id&&claim?.lease_token){
      try{await rpc("lidar_roof_refine_finish_v5053",{p_task_token:token,p_derivation_id:claim.derivation_id,p_lease_token:claim.lease_token,p_next_building_id:claim.next_building_id||0,p_success:false,p_results:[],p_error:String((e as any)?.message||e).slice(0,800)})}catch{}
    }
    return new Response(JSON.stringify({complete:false,version:5054,error:String((e as any)?.message||e)}),{status:500,headers:JSONH})
  }
});