import { createClient } from "npm:@supabase/supabase-js@2";

const U=Deno.env.get('SUPABASE_URL')!;
const A=Deno.env.get('SUPABASE_ANON_KEY')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CORS={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
};
const H={...CORS,'content-type':'application/json'};
const service=createClient(U,S,{auth:{persistSession:false}});

const toRad=(d:number)=>d*Math.PI/180;
const toDeg=(r:number)=>(r*180/Math.PI+360)%360;
function distanceM(aLat:number,aLng:number,bLat:number,bLng:number){
  const R=6371000;const dLat=toRad(bLat-aLat),dLng=toRad(bLng-aLng);
  const x=Math.sin(dLat/2)**2+Math.cos(toRad(aLat))*Math.cos(toRad(bLat))*Math.sin(dLng/2)**2;
  return 2*R*Math.asin(Math.min(1,Math.sqrt(x)));
}
function bearing(aLat:number,aLng:number,bLat:number,bLng:number){
  const y=Math.sin(toRad(bLng-aLng))*Math.cos(toRad(bLat));
  const x=Math.cos(toRad(aLat))*Math.sin(toRad(bLat))-Math.sin(toRad(aLat))*Math.cos(toRad(bLat))*Math.cos(toRad(bLng-aLng));
  return toDeg(Math.atan2(y,x));
}
function angleDelta(a:number,b:number){return Math.abs(((a-b+540)%360)-180);}
function rows(payload:any):any[]{
  const r=payload?.result?.data??payload?.currentPageItems??payload?.result??payload?.data??[];
  if(Array.isArray(r))return r;
  if(Array.isArray(r?.data))return r.data;
  if(Array.isArray(r?.currentPageItems))return r.currentPageItems;
  return [];
}
function validDate(v:any){if(!v)return null;const d=new Date(String(v));return Number.isFinite(d.getTime())?d.toISOString():null;}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{status:200,headers:CORS});
  let propertyId='';
  let stateCode='';
  let stage='START';
  try{
    if(req.method!=='POST')return new Response(JSON.stringify({complete:false,error:'POST required'}),{status:405,headers:H});
    const auth=req.headers.get('authorization')||'';
    const user=createClient(U,A,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
    const me=await user.auth.getUser();
    if(me.error||!me.data.user)return new Response(JSON.stringify({complete:false,error:'Sign in required'}),{status:401,headers:H});
    const body=await req.json().catch(()=>({}));
    propertyId=String(body.property_id||'').trim();
    if(!/^[0-9a-f-]{36}$/i.test(propertyId))throw new Error('Valid property_id required');

    stage='EXISTING_MEDIA';
    const existing=await service.schema('core').from('property_media_v137')
      .select('property_media_id,media_type,media_url,thumbnail_url,source_name,captured_at,confidence,metadata')
      .eq('property_id',propertyId).eq('active',true)
      .in('media_type',['FIELD_PHOTO','STREET_VIEW','PHOTO','EXTERIOR','ASSESSOR_PHOTO','COMMUNITY_PHOTO'])
      .order('is_primary',{ascending:false}).order('captured_at',{ascending:false,nullsFirst:false}).limit(1);
    if(existing.error)throw existing.error;
    if(existing.data?.length){
      return new Response(JSON.stringify({complete:true,discovered:false,reason:'EXISTING_FRONT_MEDIA',media:existing.data[0],resolver_version:289}),{headers:H});
    }

    stage='PROPERTY_LOOKUP';
    const property=await service.schema('core').from('properties')
      .select('property_id,state_code,latitude,longitude,municipality,postal_code')
      .eq('property_id',propertyId).single();
    if(property.error)throw property.error;
    const p=property.data;stateCode=String(p.state_code||'').trim().toUpperCase();
    const lat=Number(p.latitude),lng=Number(p.longitude);
    if(!Number.isFinite(lat)||!Number.isFinite(lng))throw new Error('Property does not have usable coordinates');

    stage='RECENT_LOOKUP';
    const prior=await service.schema('product').from('property_street_media_lookup_v186')
      .select('lookup_status,selected_media_id,looked_up_at,error_message')
      .eq('property_id',propertyId).eq('provider','KARTAVIEW').order('looked_up_at',{ascending:false}).limit(1);
    if(prior.error)throw prior.error;
    const last=prior.data?.[0];
    if(last){
      const age=Date.now()-Date.parse(last.looked_up_at);
      if(last.lookup_status==='NO_COVERAGE'&&age<7*86400000)return new Response(JSON.stringify({complete:true,discovered:false,reason:'RECENT_NO_COVERAGE',resolver_version:289}),{headers:H});
      if(last.lookup_status==='FAILED'&&age<30*60*1000)return new Response(JSON.stringify({complete:true,discovered:false,reason:'RECENT_PROVIDER_FAILURE',resolver_version:289}),{headers:H});
    }

    stage='SOURCE_REGISTRY';
    const source=await service.schema('product').from('property_media_sources_v161')
      .select('service_url,active,license_note').eq('state_code',stateCode).eq('source_key','kartaview_public_street').maybeSingle();
    if(source.error)throw source.error;
    if(!source.data?.active){
      await service.schema('product').from('property_street_media_lookup_v186').insert({
        property_id:propertyId,provider:'KARTAVIEW',lookup_status:'NO_COVERAGE',candidate_count:0,
        error_message:'No active KartaView source registered for this state',metadata:{state_code:stateCode,stage,resolver_version:289}
      });
      return new Response(JSON.stringify({complete:true,discovered:false,reason:'STATE_SOURCE_NOT_ENABLED',state_code:stateCode,resolver_version:289}),{headers:H});
    }

    stage='PROVIDER_FETCH';
    const q=new URL(source.data.service_url);
    q.searchParams.set('lat',String(lat));q.searchParams.set('lng',String(lng));
    q.searchParams.set('radius','180');q.searchParams.set('zoomLevel','18');q.searchParams.set('join','sequence');q.searchParams.set('orderBy','id');q.searchParams.set('orderDirection','desc');
    const response=await fetch(q,{headers:{accept:'application/json','user-agent':'BridgePointIntelligence/1.0'},signal:AbortSignal.timeout(9000)});
    const txt=await response.text();let payload:any;try{payload=JSON.parse(txt)}catch{payload={};}
    if(!response.ok)throw new Error(`KartaView ${response.status}: ${txt.slice(0,250)}`);
    const candidates=rows(payload).map((raw:any)=>raw?.data&&typeof raw.data==='object'?{...raw,...raw.data}:raw).filter((x:any)=>x&&typeof x==='object');

    stage='CANDIDATE_RANK';
    const ranked:any[]=[];
    for(const c of candidates){
      const photoLat=Number(c.lat??c.matchLat),photoLng=Number(c.lng??c.matchLng);
      const mediaUrl=String(c.fileurl??c.fileUrl??c.url??'').trim();
      if(!Number.isFinite(photoLat)||!Number.isFinite(photoLng)||!/^https?:\/\//i.test(mediaUrl))continue;
      if(c.visibility&&String(c.visibility).toLowerCase()!=='public')continue;
      if(c.status&&String(c.status).toLowerCase()!=='active')continue;
      const dist=distanceM(photoLat,photoLng,lat,lng);if(dist>200)continue;
      const target=bearing(photoLat,photoLng,lat,lng);
      const h=Number(c.heading);const hasHeading=Number.isFinite(h);
      const delta=hasHeading?angleDelta(h,target):90;
      if(hasHeading&&delta>105)continue;
      const score=dist+(hasHeading?delta*1.35:95);
      ranked.push({c,dist,target,heading:hasHeading?h:null,delta,score});
    }
    ranked.sort((a,b)=>a.score-b.score);
    const best=ranked[0];
    if(!best){
      await service.schema('product').from('property_street_media_lookup_v186').insert({property_id:propertyId,provider:'KARTAVIEW',lookup_status:'NO_COVERAGE',candidate_count:candidates.length,metadata:{radius_m:180,state_code:stateCode,municipality:p.municipality,postal_code:p.postal_code,stage,resolver_version:289}});
      return new Response(JSON.stringify({complete:true,discovered:false,reason:'NO_USABLE_FRONT_FACING_COVERAGE',candidate_count:candidates.length,resolver_version:289}),{headers:H});
    }

    stage='MEDIA_PERSIST';
    const c=best.c;const photoId=String(c.id??c.photoId??c.photo_id??'').trim()||null;
    const thumb=String(c.fileurlTh??c.thumbnailUrl??c.thumb??'').trim()||null;
    const captured=validDate(c.shotDate??c.dateAdded??c.dateProcessed);
    const distanceScore=Math.max(0,1-Math.min(best.dist,200)/200);
    const headingScore=Math.max(0,1-Math.min(best.delta,105)/105);
    const confidence=Math.max(.38,Math.min(.95,.42+distanceScore*.28+headingScore*.25));
    const mediaUrl=String(c.fileurl??c.fileUrl??c.url);
    const sourceUrl=photoId?`https://api.openstreetcam.org/2.0/photo/${encodeURIComponent(photoId)}`:q.toString();
    const meta={provider:'KartaView',external_photo_id:photoId,photo_lat:Number(c.lat??c.matchLat),photo_lng:Number(c.lng??c.matchLng),heading:best.heading,target_bearing:best.target,heading_delta_deg:Number(best.delta.toFixed(2)),distance_m:Number(best.dist.toFixed(2)),sequence_id:c.sequenceId??c.sequence?.id??null,projection:c.projection??null,attribution:'KartaView / Grab contributor imagery',license:'CC BY-SA 4.0',selection_method:'nearest_public_frame_facing_property',raw_bytes_stored:false,resolver_version:289};

    const up=await service.schema('core').from('property_media_v137').upsert({
      property_id:propertyId,media_type:'STREET_VIEW',media_url:mediaUrl,thumbnail_url:thumb,source_name:'KartaView Public Street-Level Imagery',source_url:sourceUrl,
      observed_at:new Date().toISOString(),captured_at:captured,license_note:'KartaView public street imagery; attribution required; CC BY-SA 4.0.',confidence,is_primary:false,active:true,metadata:meta,updated_at:new Date().toISOString()
    },{onConflict:'property_id,media_url'}).select('property_media_id,media_type,media_url,thumbnail_url,source_name,captured_at,confidence,metadata').single();
    if(up.error)throw up.error;

    await service.schema('product').from('property_street_media_lookup_v186').insert({property_id:propertyId,provider:'KARTAVIEW',lookup_status:'FOUND',candidate_count:candidates.length,selected_media_id:up.data.property_media_id,selected_photo_external_id:photoId,distance_m:best.dist,heading_delta:best.delta,metadata:{radius_m:180,state_code:stateCode,selection_score:best.score,resolver_version:289}});
    return new Response(JSON.stringify({complete:true,discovered:true,media:up.data,candidate_count:candidates.length,resolver_version:289}),{headers:H});
  }catch(e){
    const msg=String((e as any)?.message||e).slice(0,1500);
    if(/^[0-9a-f-]{36}$/i.test(propertyId)){
      try{
        await service.schema('product').from('property_street_media_lookup_v186').insert({
          property_id:propertyId,provider:'KARTAVIEW',lookup_status:'FAILED',candidate_count:0,error_message:msg,
          metadata:{state_code:stateCode||null,stage,resolver_version:289}
        });
      }catch(_){ }
    }
    return new Response(JSON.stringify({complete:false,error:msg,stage,resolver_version:289}),{status:400,headers:H});
  }
});