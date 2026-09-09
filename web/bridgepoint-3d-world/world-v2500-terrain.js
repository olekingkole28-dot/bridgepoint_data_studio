const US_BOXES=[
  [-125,24,-66,50],[-180,51,-129,72],[-161,18,-154,23],[-68.5,17,-64,19.5],[144,13,145.5,14.5],[-171,-15,-168,-13]
];
const intersects=(r,b)=>r.east>b[0]&&r.west<b[2]&&r.north>b[1]&&r.south<b[3];
const deg=(v)=>Cesium.Math.toDegrees(v);

export async function enableBridgePointTerrain({viewer,supabase,tier='MEDIUM'}){
  if(!Cesium.CustomHeightmapTerrainProvider)return{enabled:false,reason:'Custom heightmap terrain is unavailable in this Cesium build.'};
  const {data:{session}}=await supabase.auth.getSession();
  if(!session)return{enabled:false,reason:'Signed-in BridgePoint access is required for the governed 3DEP terrain sampler.'};
  const size=tier==='LOW'?9:tier==='HIGH'?17:13;
  const maxLevel=tier==='LOW'?10:tier==='HIGH'?13:12;
  const tilingScheme=new Cesium.GeographicTilingScheme();
  const cache=new Map();
  const failures=new Map();
  const zero=new Float32Array(size*size);
  let sampled=0,misses=0;

  const provider=new Cesium.CustomHeightmapTerrainProvider({
    width:size,height:size,tilingScheme,
    credit:new Cesium.Credit('Terrain: U.S. Geological Survey 3DEP'),
    callback:(x,y,level)=>{
      if(level<4)return zero;
      if(level>maxLevel)return undefined;
      const r=tilingScheme.tileXYToRectangle(x,y,level);
      const box={west:deg(r.west),south:deg(r.south),east:deg(r.east),north:deg(r.north)};
      if(!US_BOXES.some(b=>intersects(box,b)))return zero;
      const key=`${level}/${x}/${y}`;
      const hit=cache.get(key);if(hit)return hit;
      const failedAt=failures.get(key);if(failedAt&&Date.now()-failedAt<90000)return undefined;
      const promise=(async()=>{
        const {data,error}=await supabase.functions.invoke('bridgepoint-world-terrain-v2500',{body:{...box,width:size,height:size,level,x,y}});
        if(error||!data?.complete||!Array.isArray(data.heights_m)||data.heights_m.length!==size*size){misses++;failures.set(key,Date.now());return undefined}
        sampled++;return new Float32Array(data.heights_m.map(Number));
      })().then(result=>{if(!result)cache.delete(key);return result}).catch(()=>{misses++;failures.set(key,Date.now());cache.delete(key);return undefined});
      cache.set(key,promise);
      if(cache.size>600){const first=cache.keys().next().value;if(first)cache.delete(first)}
      return promise;
    }
  });
  viewer.terrainProvider=provider;
  viewer.scene.globe.depthTestAgainstTerrain=true;
  viewer.scene.requestRender();
  return{enabled:true,provider,size,maxLevel,get stats(){return{sampled,misses,cached:cache.size}}};
}
