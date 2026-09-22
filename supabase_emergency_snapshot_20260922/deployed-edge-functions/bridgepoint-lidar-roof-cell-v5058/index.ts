import {parse} from "npm:@loaders.gl/core@4.3.4";
import {LASLoader} from "npm:@loaders.gl/las@4.3.4";
const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
async function rpc(name:string,body:any){const r=await fetch(U+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:S,authorization:"Bearer "+S,"content-type":"application/json"},body:JSON.stringify(body)});const t=await r.text();if(!r.ok)throw new Error(name+"_"+r.status+":"+t.slice(0,600));return t?JSON.parse(t):null}
const val=(a:any)=>a?.value??a;
function polys(g:any){if(g?.type==="Polygon")return [g.coordinates];if(g?.type==="MultiPolygon")return g.coordinates;return []}
function inRing(x:number,y:number,r:any[]){let inside=false;for(let i=0,j=r.length-1;i<r.length;j=i++){const xi=+r[i][0],yi=+r[i][1],xj=+r[j][0],yj=+r[j][1];if(((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/((yj-yi)||1e-12)+xi))inside=!inside}return inside}
function insideGeom(x:number,y:number,g:any){for(const p of polys(g)){if(p?.[0]&&inRing(x,y,p[0])&&!p.slice(1).some((h:any)=>inRing(x,y,h)))return true}return false}
function pct(a:number[],q:number){if(!a.length)return NaN;const s=[...a].sort((x,y)=>x-y),p=(s.length-1)*q,i=Math.floor(p),f=p-i;return s[i+1]!==undefined?s[i]+f*(s[i+1]-s[i]):s[i]}
function solve3(A:number[][],b:number[]){const M=A.map((r,i)=>[...r,b[i]]);for(let c=0;c<3;c++){let p=c;for(let r=c+1;r<3;r++)if(Math.abs(M[r][c])>Math.abs(M[p][c]))p=r;[M[c],M[p]]=[M[p],M[c]];if(Math.abs(M[c][c])<1e-10)return null;const d=M[c][c];for(let j=c;j<4;j++)M[c][j]/=d;for(let r=0;r<3;r++){if(r===c)continue;const f=M[r][c];for(let j=c;j<4;j++)M[r][j]-=f*M[c][j]}}return[M[0][3],M[1][3],M[2][3]]}
function fit(pts:number[][]){const cx=pts.reduce((s,p)=>s+p[0],0)/pts.length,cy=pts.reduce((s,p)=>s+p[1],0)/pts.length;let xx=0,xy=0,yy=0,xz=0,yz=0,z=0;for(const p of pts){const dx=p[0]-cx,dy=p[1]-cy;xx+=dx*dx;xy+=dx*dy;yy+=dy*dy;xz+=dx*p[2];yz+=dy*p[2];z+=p[2]}const sol=solve3([[xx,xy,0],[xy,yy,0],[0,0,pts.length]],[xz,yz,z]);if(!sol)return null;const[a,b,c]=sol;let se=0;for(const p of pts){const pred=a*(p[0]-cx)+b*(p[1]-cy)+c;se+=(p[2]-pred)**2}return{pitch_deg:Math.atan(Math.hypot(a,b))*180/Math.PI,azimuth_deg:((Math.atan2(-a,-b)*180/Math.PI)%360+360)%360,rmse_m:Math.sqrt(se/pts.length),a,b,c,cx,cy}}
Deno.serve(async(req)=>{
 let claim:any=null,token="",emptyDrained=0,buildingBatch=12;
 try{
   if(req.method!=="POST")return new Response("POST required",{status:405});
   const body=await req.json().catch(()=>({}));token=String(body.task_token||"");if(!token)throw new Error("TASK_TOKEN_REQUIRED");
   const started=Date.now();
   let b:any=null;
   for(let drain=0;drain<40;drain++){
     claim=await rpc("bridgepoint_lidar_roof_cell_claim_v5058",{p_task_token:token});
     if(!claim?.claimed)return new Response(JSON.stringify({complete:true,version:5063,skipped:"NO_USEFUL_CELL_DUE",empty_cells_drained:emptyDrained}),{headers:{"content-type":"application/json"}});
     const pointN=Number(claim.point_count||0);
     buildingBatch=pointN<=50000?20:pointN<=150000?16:12;
     b=await rpc("bridgepoint_lidar_roof_cell_buildings_v5058",{p_task_token:token,p_project_key:claim.project_key,p_node_key:claim.node_key,p_after_building_id:Number(claim.building_cursor||0),p_limit:buildingBatch});
     const buildings=b?.buildings||[];
     if(buildings.length){
       break;
     }
     await rpc("bridgepoint_lidar_roof_cell_finish_v5058",{p_task_token:token,p_project_key:claim.project_key,p_node_key:claim.node_key,p_lease_token:claim.lease_token,p_success:true,p_last_building_id:Number(claim.building_cursor||0),p_has_more:false,p_materialized:0,p_skipped:0,p_error:null});
     emptyDrained++;
     claim=null;
     b=null;
     if(Date.now()-started>18000)break;
   }
   if(!claim||!b?.buildings?.length)return new Response(JSON.stringify({complete:true,version:5063,skipped:"EMPTY_DRAIN_BUDGET",empty_cells_drained:emptyDrained}),{headers:{"content-type":"application/json"}});
   const buildings=b.buildings;
   const base=String(claim.ept_url).replace(/\/ept\.json$/,""),url=base+"/ept-data/"+claim.node_key+".laz";
   const fr=await fetch(url,{signal:AbortSignal.timeout(35000)});if(!fr.ok)throw new Error("LAZ_"+fr.status+":"+url);
   const ab=await fr.arrayBuffer(),parsed:any=await parse(ab,LASLoader,{las:{shape:"columnar",fp64:true}}),attrs=parsed?.attributes||{},pos=val(attrs.POSITION),cls=val(attrs.classification),pointN=parsed?.header?.vertexCount||(pos?Math.floor(pos.length/3):0);
   if(!pos||pointN<1)throw new Error("NO_LAZ_POINTS");
   const fits:any[]=[];let skipped=0,lastId=Number(claim.building_cursor||0);
   for(const building of buildings){
     const id=Number(building.building_id);lastId=Math.max(lastId,id);
     const nonground:number[][]=[],class6:number[][]=[];
     for(let i=0;i<pointN;i++){const x=pos[i*3],y=pos[i*3+1],z=pos[i*3+2];if(!insideGeom(x,y,building.geometry_3857))continue;const c=cls?Number(cls[i]):0;if(c===6)class6.push([x,y,z]);if(![2,7,9,18].includes(c))nonground.push([x,y,z])}
     const use=class6.length>=12?class6:nonground;
     if(use.length<12){skipped++;continue}
     const zs=use.map(p=>p[2]),lo=pct(zs,.55),hi=pct(zs,.97),roof=use.filter(p=>p[2]>=lo&&p[2]<=hi+.75);
     if(roof.length<10){skipped++;continue}
     const f=fit(roof);if(!f||!Number.isFinite(f.rmse_m)||f.rmse_m>1.25||f.pitch_deg<0||f.pitch_deg>90){skipped++;continue}
     const flat=f.pitch_deg<3&&f.rmse_m<=.45;
     fits.push({building_id:id,pitch_deg:f.pitch_deg,azimuth_deg:f.azimuth_deg,rmse_m:f.rmse_m,fit_points:roof.length,decoded_points:pointN,inside_points:nonground.length,class6_points:class6.length,roof_shape:flat?"flat":null,plane_model:{a:f.a,b:f.b,c:f.c,cx:f.cx,cy:f.cy}})
   }
   let materialized=0;
   if(fits.length){const m=await rpc("bridgepoint_lidar_roof_materialize_batch_v5058",{p_task_token:token,p_project_key:claim.project_key,p_node_key:claim.node_key,p_fits:fits});materialized=Number(m?.materialized||0)}
   await rpc("bridgepoint_lidar_roof_cell_finish_v5058",{p_task_token:token,p_project_key:claim.project_key,p_node_key:claim.node_key,p_lease_token:claim.lease_token,p_success:true,p_last_building_id:lastId,p_has_more:!!b?.has_more,p_materialized:materialized,p_skipped:skipped,p_error:null});
   return new Response(JSON.stringify({complete:true,version:5063,project_key:claim.project_key,node_key:claim.node_key,decoded_points:pointN,building_batch:buildingBatch,buildings_examined:buildings.length,materialized,skipped,has_more:!!b?.has_more,empty_cells_drained:emptyDrained}),{headers:{"content-type":"application/json"}})
 }catch(e){
   try{if(claim?.claimed)await rpc("bridgepoint_lidar_roof_cell_finish_v5058",{p_task_token:token,p_project_key:claim.project_key,p_node_key:claim.node_key,p_lease_token:claim.lease_token,p_success:false,p_last_building_id:Number(claim.building_cursor||0),p_has_more:true,p_materialized:0,p_skipped:0,p_error:String((e as any)?.message||e)})}catch(_){}
   return new Response(JSON.stringify({complete:false,version:5063,error:String((e as any)?.message||e),project_key:claim?.project_key||null,node_key:claim?.node_key||null,empty_cells_drained:emptyDrained}),{status:500,headers:{"content-type":"application/json"}})
 }
});