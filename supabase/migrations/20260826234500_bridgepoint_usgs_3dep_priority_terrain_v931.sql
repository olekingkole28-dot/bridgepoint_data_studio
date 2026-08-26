-- BridgePoint Intelligence V931/V932
-- Customer-priority USGS 3DEP terrain enrichment for Property Twin.
-- Missing terrain is queued on Property Twin access, processed ahead of background backfill,
-- and cached in analytics.us_property_elevation_v927 with evidence-preserving provenance.

create table if not exists automation.usgs_3dep_priority_queue_v931(
  property_id uuid primary key references core.properties(property_id) on delete cascade,
  state_code text not null,
  priority integer not null default 100,
  status text not null default 'QUEUED' check(status in('QUEUED','RUNNING','COMPLETE','FAILED')),
  lease_token uuid,
  lease_until timestamptz,
  attempts integer not null default 0,
  requested_at timestamptz not null default now(),
  last_requested_at timestamptz not null default now(),
  last_error text,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create index if not exists usgs_3dep_priority_queue_v931_work_idx on automation.usgs_3dep_priority_queue_v931(status,priority desc,last_requested_at) where status in('QUEUED','RUNNING');

create table if not exists automation.usgs_3dep_priority_dispatch_state_v931(
  singleton boolean primary key default true check(singleton),
  in_flight_request_id bigint,
  queued_at timestamptz,
  last_response_at timestamptz,
  last_status_code integer,
  consecutive_failures integer not null default 0,
  total_dispatches bigint not null default 0,
  total_successes bigint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into automation.usgs_3dep_priority_dispatch_state_v931(singleton) values(true) on conflict(singleton) do nothing;

create or replace function public.bridgepoint_property_terrain_v931(p_property_id uuid)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','api','product','core','automation','analytics'
set statement_timeout to '8s'
as $$
declare uid uuid:=api.require_user(); p record; e analytics.us_property_elevation_v927%rowtype; v_owner boolean:=product.has_platform_override(uid);
begin
  select property_id,upper(btrim(state_code)) state_code into p from core.properties where property_id=p_property_id and active limit 1;
  if p.property_id is null then return jsonb_build_object('complete',false,'version',931,'error','PROPERTY_NOT_FOUND'); end if;
  if not v_owner and not product.user_has_state_access_v77(uid,p.state_code) then return jsonb_build_object('complete',true,'version',931,'locked',true,'required_geography',p.state_code); end if;
  select * into e from analytics.us_property_elevation_v927 where property_id=p_property_id;
  if found then
    return jsonb_build_object('complete',true,'version',931,'property_id',p_property_id,'state_code',p.state_code,'available',e.sample_status='OK','sample_status',e.sample_status,'elevation_m',e.elevation_m,'resolution_m',e.resolution_m,'high_resolution_dem',coalesce(e.resolution_m<=2,false),'source_code',e.source_code,'source_url',e.source_url,'dataset_id',e.dataset_id,'product_name',e.product_name,'vertical_datum',e.vertical_datum,'acquisition_date',e.acquisition_date,'sampled_at',e.sampled_at,'provenance',e.attributes,'truth_note','3DEP terrain elevation; high-resolution DEM may be lidar-derived where available and is not represented as a surveyed spot elevation');
  end if;
  insert into automation.usgs_3dep_priority_queue_v931(property_id,state_code,priority,status,requested_at,last_requested_at,updated_at)
  values(p_property_id,p.state_code,100,'QUEUED',now(),now(),now())
  on conflict(property_id) do update set priority=greatest(automation.usgs_3dep_priority_queue_v931.priority,100),status=case when automation.usgs_3dep_priority_queue_v931.status='COMPLETE' then 'COMPLETE' else 'QUEUED' end,last_requested_at=now(),updated_at=now();
  return jsonb_build_object('complete',true,'version',931,'property_id',p_property_id,'state_code',p.state_code,'available',false,'queued',true,'sample_status','PENDING','source_code','USGS_3DEP_V918','truth_note','Terrain enrichment queued from official USGS 3DEP service');
end $$;
revoke all on function public.bridgepoint_property_terrain_v931(uuid) from public,anon;
grant execute on function public.bridgepoint_property_terrain_v931(uuid) to authenticated,service_role;

create or replace function public.bridgepoint_3dep_priority_claim_v931(p_task_token text,p_batch_size integer default 20)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','automation','analytics'
set statement_timeout to '10s'
as $$
declare v_auth boolean;v_state text;v_token uuid;v_rows jsonb;v_count int;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth; if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  p_batch_size:=greatest(1,least(coalesce(p_batch_size,20),100));
  update automation.usgs_3dep_priority_queue_v931 q set status='COMPLETE',completed_at=coalesce(q.completed_at,now()),lease_token=null,lease_until=null,last_error=null,updated_at=now(),metadata=q.metadata||jsonb_build_object('completed_from_existing_cache',true) from analytics.us_property_elevation_v927 e where e.property_id=q.property_id and e.sample_status='OK' and q.status<>'COMPLETE';
  select q.state_code into v_state from automation.usgs_3dep_priority_queue_v931 q where q.status in('QUEUED','RUNNING') and (q.status='QUEUED' or q.lease_until<now()) order by q.priority desc,q.last_requested_at,q.property_id limit 1;
  if v_state is null then return jsonb_build_object('complete',true,'version',931,'claimed',false,'reason','NO_PRIORITY_WORK'); end if;
  v_token:=gen_random_uuid();
  with c as (select q.property_id from automation.usgs_3dep_priority_queue_v931 q where q.state_code=v_state and q.status in('QUEUED','RUNNING') and (q.status='QUEUED' or q.lease_until<now()) order by q.priority desc,q.last_requested_at,q.property_id for update skip locked limit p_batch_size),
  u as (update automation.usgs_3dep_priority_queue_v931 q set status='RUNNING',lease_token=v_token,lease_until=now()+interval '3 minutes',attempts=q.attempts+1,updated_at=now() from c where q.property_id=c.property_id returning q.property_id,q.state_code)
  select jsonb_agg(jsonb_build_object('property_id',u.property_id,'state_code',u.state_code,'longitude',p.longitude,'latitude',p.latitude) order by u.property_id),count(*) into v_rows,v_count from u join core.properties p on p.property_id=u.property_id where p.active and p.latitude between -90 and 90 and p.longitude between -180 and 180;
  if coalesce(v_count,0)=0 then update automation.usgs_3dep_priority_queue_v931 set status='FAILED',last_error='PROPERTY_COORDINATES_UNAVAILABLE',lease_token=null,lease_until=null,updated_at=now() where lease_token=v_token; return jsonb_build_object('complete',true,'version',931,'claimed',false,'reason','NO_GEOCODED_PRIORITY_WORK'); end if;
  return jsonb_build_object('complete',true,'version',931,'claimed',true,'state_code',v_state,'lease_token',v_token,'batch_size',v_count,'rows',v_rows);
end $$;
revoke all on function public.bridgepoint_3dep_priority_claim_v931(text,integer) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_priority_claim_v931(text,integer) to service_role;

create or replace function public.bridgepoint_3dep_priority_persist_v931(p_task_token text,p_state_code text,p_lease_token uuid,p_samples jsonb)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','automation','analytics'
set statement_timeout to '20s'
as $$
declare v_auth boolean;r jsonb;v_seen int:=0;v_ok int:=0;v_non_ok int:=0;v_status text;v_elev double precision;v_property uuid;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth; if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  if jsonb_typeof(p_samples)<>'array' then raise exception 'samples must be array'; end if;
  if not exists(select 1 from automation.usgs_3dep_priority_queue_v931 where lease_token=p_lease_token and state_code=upper(p_state_code) and status='RUNNING') then raise exception 'priority lease token mismatch'; end if;
  for r in select value from jsonb_array_elements(p_samples) loop
    v_seen:=v_seen+1;v_property:=nullif(r->>'property_id','')::uuid;v_status:=upper(coalesce(nullif(r->>'sample_status',''),'NO_DATA'));if v_status not in('OK','NO_DATA','INVALID') then v_status:='INVALID'; end if;v_elev:=nullif(r->>'elevation_m','')::double precision;if v_status='OK' and (v_elev is null or v_elev < -12000 or v_elev > 10000) then v_status:='INVALID'; end if;
    insert into analytics.us_property_elevation_v927(property_id,state_code,longitude,latitude,elevation_m,sample_status,resolution_m,raster_id,dataset_id,product_name,vertical_datum,acquisition_date,attributes,sampled_at,updated_at)
    values(v_property,upper(p_state_code),nullif(r->>'longitude','')::double precision,nullif(r->>'latitude','')::double precision,case when v_status='OK' then v_elev else null end,v_status,nullif(r->>'resolution_m','')::double precision,nullif(r->>'raster_id','')::bigint,nullif(r->>'dataset_id',''),nullif(r->>'product_name',''),nullif(r->>'vertical_datum',''),nullif(r->>'acquisition_date',''),coalesce(r->'attributes','{}'::jsonb),now(),now())
    on conflict(property_id) do update set state_code=excluded.state_code,longitude=excluded.longitude,latitude=excluded.latitude,elevation_m=excluded.elevation_m,sample_status=excluded.sample_status,resolution_m=excluded.resolution_m,raster_id=excluded.raster_id,dataset_id=excluded.dataset_id,product_name=excluded.product_name,vertical_datum=excluded.vertical_datum,acquisition_date=excluded.acquisition_date,attributes=excluded.attributes,sampled_at=now(),updated_at=now();
    update automation.usgs_3dep_priority_queue_v931 set status='COMPLETE',completed_at=now(),lease_token=null,lease_until=null,last_error=null,updated_at=now(),metadata=metadata||jsonb_build_object('sample_status',v_status) where property_id=v_property and lease_token=p_lease_token;
    if v_status='OK' then v_ok:=v_ok+1; else v_non_ok:=v_non_ok+1; end if;
  end loop;
  update automation.source_registry set last_checked_at=now(),last_successful_import_at=now(),total_records_ingested=coalesce(total_records_ingested,0)+v_ok,last_run_records_found=v_seen,last_run_records_inserted=v_ok,consecutive_failures=0,last_error=null,updated_at=now() where source_code='USGS_3DEP_V918';
  return jsonb_build_object('complete',true,'version',931,'state_code',upper(p_state_code),'seen',v_seen,'ok',v_ok,'non_ok',v_non_ok);
end $$;
revoke all on function public.bridgepoint_3dep_priority_persist_v931(text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_priority_persist_v931(text,text,uuid,jsonb) to service_role;

create or replace function public.bridgepoint_3dep_priority_fail_v931(p_task_token text,p_lease_token uuid,p_error text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','automation' set statement_timeout to '5s'
as $$ declare v_auth boolean;v_count int; begin select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;update automation.usgs_3dep_priority_queue_v931 set status=case when attempts>=5 then 'FAILED' else 'QUEUED' end,lease_token=null,lease_until=null,last_error=left(coalesce(p_error,'unknown'),1500),updated_at=now() where lease_token=p_lease_token;get diagnostics v_count=row_count;return jsonb_build_object('complete',true,'version',931,'released',v_count);end $$;
revoke all on function public.bridgepoint_3dep_priority_fail_v931(text,uuid,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_priority_fail_v931(text,uuid,text) to service_role;

create or replace function automation.dispatch_usgs_3dep_priority_v932(p_batch_size integer default 20)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','automation','net' set statement_timeout to '8s'
as $$
declare s automation.usgs_3dep_priority_dispatch_state_v931%rowtype;hr net._http_response%rowtype;v_token text;v_request bigint;v_queue int:=0;v_still_queued boolean:=false;v_pending int:=0;
begin
  p_batch_size:=greatest(1,least(coalesce(p_batch_size,20),100));if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-usgs-3dep-priority-v932',0)) then return jsonb_build_object('complete',true,'version',932,'skipped','LOCKED'); end if;
  select count(*) into v_pending from automation.usgs_3dep_priority_queue_v931 where status in('QUEUED','RUNNING') and (status='QUEUED' or lease_until<now());select * into s from automation.usgs_3dep_priority_dispatch_state_v931 where singleton=true for update;
  if s.in_flight_request_id is not null then select * into hr from net._http_response where id=s.in_flight_request_id;if found then update automation.usgs_3dep_priority_dispatch_state_v931 set last_response_at=hr.created,last_status_code=hr.status_code,consecutive_failures=case when hr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,total_successes=total_successes+case when hr.status_code between 200 and 299 then 1 else 0 end,in_flight_request_id=null,queued_at=null,metadata=metadata||jsonb_build_object('last_response',left(coalesce(hr.content,''),3000),'last_error',hr.error_msg),updated_at=now() where singleton=true;select * into s from automation.usgs_3dep_priority_dispatch_state_v931 where singleton=true;else select exists(select 1 from net.http_request_queue q where q.id=s.in_flight_request_id) into v_still_queued;if v_still_queued then return jsonb_build_object('complete',true,'version',932,'skipped','HTTP_QUEUE_IN_FLIGHT','request_id',s.in_flight_request_id,'pending',v_pending); end if;if s.queued_at is not null and now()-s.queued_at<interval '120 seconds' then return jsonb_build_object('complete',true,'version',932,'skipped','RESPONSE_PENDING','request_id',s.in_flight_request_id,'pending',v_pending); end if;update automation.usgs_3dep_priority_dispatch_state_v931 set in_flight_request_id=null,queued_at=null,consecutive_failures=consecutive_failures+1,updated_at=now(),metadata=metadata||jsonb_build_object('last_lost_request_recovered_at',now()) where singleton=true;end if;end if;
  if v_pending=0 then return jsonb_build_object('complete',true,'version',932,'skipped','NO_PRIORITY_WORK'); end if;select count(*) into v_queue from net.http_request_queue;if v_queue>28 then return jsonb_build_object('complete',true,'version',932,'skipped','HTTP_BACKPRESSURE','http_queue',v_queue,'pending',v_pending); end if;select task_token into v_token from automation.geographic_expansion_worker_secret_v90 where singleton=true;if v_token is null then raise exception 'worker token missing'; end if;
  select net.http_post(url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-usgs-3dep-priority-v931',headers:='{"Content-Type":"application/json"}'::jsonb,body:=jsonb_build_object('task_token',v_token,'batch_size',p_batch_size),timeout_milliseconds:=55000) into v_request;
  update automation.usgs_3dep_priority_dispatch_state_v931 set in_flight_request_id=v_request,queued_at=now(),total_dispatches=total_dispatches+1,metadata=metadata||jsonb_build_object('last_http_queue',v_queue,'last_batch_size',p_batch_size,'last_pending',v_pending),updated_at=now() where singleton=true;perform net.wake();return jsonb_build_object('complete',true,'version',932,'queued',true,'request_id',v_request,'batch_size',p_batch_size,'pending',v_pending,'http_queue_before',v_queue);
end $$;
revoke all on function automation.dispatch_usgs_3dep_priority_v932(integer) from public,anon,authenticated;
grant execute on function automation.dispatch_usgs_3dep_priority_v932(integer) to service_role,postgres;

do $$ begin if not exists(select 1 from cron.job where jobname='bridgepoint-usgs-3dep-priority-v932') then perform cron.schedule('bridgepoint-usgs-3dep-priority-v932','* * * * *','select automation.dispatch_usgs_3dep_priority_v932(20);'); end if; end $$;

create or replace function public.bridgepoint_property_twin_v918(p_property_id uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','api','product','core','automation' set statement_timeout to '12s'
as $$
declare uid uuid:=api.require_user();p record;v_owner boolean:=product.has_platform_override(uid);site jsonb;media jsonb;geom jsonb;twin jsonb;intel jsonb;terrain jsonb;needs_building boolean;needs_front boolean;needs_geo boolean;
begin
 select property_id,upper(btrim(state_code)) state_code,latitude,longitude,parcel_geom into p from core.properties where property_id=p_property_id and active limit 1;if p.property_id is null then return jsonb_build_object('complete',false,'version',918,'error','PROPERTY_NOT_FOUND'); end if;if not v_owner and not product.user_has_state_access_v77(uid,p.state_code) then return jsonb_build_object('complete',true,'version',918,'locked',true,'required_geography',p.state_code); end if;
 site:=public.bridgepoint_property_site_3d_v918(p_property_id,220,900);media:=public.bridgepoint_property_media_bundle_v169(p_property_id);begin geom:=public.bridgepoint_property_geometry_v854(p_property_id,25);exception when others then geom:='{}'::jsonb;end;begin twin:=public.bridgepoint_digital_twin_summary_v856(p_property_id);exception when others then twin:='{}'::jsonb;end;begin intel:=public.bridgepoint_property_intelligence_v907(p_property_id);exception when others then intel:='{}'::jsonb;end;begin terrain:=public.bridgepoint_property_terrain_v931(p_property_id);exception when others then terrain:=jsonb_build_object('complete',false,'version',931,'available',false,'error','TERRAIN_LOOKUP_UNAVAILABLE');end;
 needs_geo:=p.latitude is null or p.longitude is null;needs_building:=coalesce((site->>'building_count')::int,0)=0 or coalesce(site->>'structure_mode','') in ('TARGET_BUILDING_PENDING','NEARBY_BUILDINGS_TARGET_PENDING');needs_front:=coalesce((media->>'front_available')::boolean,false)=false;
 if needs_geo then insert into automation.property_twin_enrichment_queue_v918(property_id,capability_key,priority,status,requested_at,updated_at) values(p_property_id,'GEOCODE',100,'QUEUED',now(),now()) on conflict(property_id,capability_key) do update set priority=greatest(automation.property_twin_enrichment_queue_v918.priority,100),status=case when automation.property_twin_enrichment_queue_v918.status='COMPLETE' then 'COMPLETE' else 'QUEUED' end,updated_at=now();end if;if needs_building then insert into automation.property_twin_enrichment_queue_v918(property_id,capability_key,priority,status,requested_at,updated_at) values(p_property_id,'BUILDING_GEOMETRY',95,'QUEUED',now(),now()) on conflict(property_id,capability_key) do update set priority=greatest(automation.property_twin_enrichment_queue_v918.priority,95),status=case when automation.property_twin_enrichment_queue_v918.status='COMPLETE' then 'COMPLETE' else 'QUEUED' end,updated_at=now();end if;if needs_front then insert into automation.property_twin_enrichment_queue_v918(property_id,capability_key,priority,status,requested_at,updated_at) values(p_property_id,'FRONT_IMAGERY',90,'QUEUED',now(),now()) on conflict(property_id,capability_key) do update set priority=greatest(automation.property_twin_enrichment_queue_v918.priority,90),status=case when automation.property_twin_enrichment_queue_v918.status='COMPLETE' then 'COMPLETE' else 'QUEUED' end,updated_at=now();end if;
 return jsonb_build_object('complete',true,'version',918,'property_id',p_property_id,'state_code',p.state_code,'site_3d',site,'terrain',terrain,'media',media,'geometry',geom,'digital_twin',twin,'intelligence',intel,'capabilities',jsonb_build_object('geocoded',not needs_geo,'terrain',coalesce((terrain->>'available')::boolean,false),'site_3d',coalesce((site->>'site_context_available')::boolean,false),'structure_3d',not needs_building,'front_imagery',not needs_front,'aerial',coalesce((media->>'aerial_available')::boolean,false),'historical_aerial',coalesce((media->>'aerial_history_count')::int,0)>0),'enrichment_queued',jsonb_build_object('geocode',needs_geo,'terrain',coalesce((terrain->>'queued')::boolean,false),'building_geometry',needs_building,'front_imagery',needs_front),'terrain_contract_version',931,'product_contract','BEST_AVAILABLE_NOW_AUTOMATIC_FIDELITY_UPGRADE_V931');
end $$;
revoke all on function public.bridgepoint_property_twin_v918(uuid) from public,anon;
grant execute on function public.bridgepoint_property_twin_v918(uuid) to authenticated,service_role;
