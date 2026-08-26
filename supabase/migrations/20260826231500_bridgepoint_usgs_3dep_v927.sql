-- BridgePoint Intelligence V927
-- Official USGS 3DEP national elevation adapter.
-- Uses the 3DEP ImageServer getSamples endpoint in bounded multipoint batches.
-- Provenance note: 3DEP dynamic elevation is LiDAR-derived where high-resolution
-- DEM is available and may fall back to lower-resolution elevation products.

begin;

create table if not exists analytics.us_property_elevation_v927(
  property_id uuid primary key,
  state_code text not null,
  longitude double precision not null,
  latitude double precision not null,
  elevation_m double precision,
  sample_status text not null default 'OK',
  resolution_m double precision,
  raster_id bigint,
  dataset_id text,
  product_name text,
  vertical_datum text,
  acquisition_date text,
  source_code text not null default 'USGS_3DEP_V918',
  source_url text not null default 'https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer',
  attributes jsonb not null default '{}'::jsonb,
  sampled_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint us_property_elevation_v927_status_chk check(sample_status in('OK','NO_DATA','INVALID')),
  constraint us_property_elevation_v927_lat_chk check(latitude between -90 and 90),
  constraint us_property_elevation_v927_lon_chk check(longitude between -180 and 180)
);
create index if not exists us_property_elevation_v927_state_idx on analytics.us_property_elevation_v927(state_code,property_id);
create index if not exists us_property_elevation_v927_resolution_idx on analytics.us_property_elevation_v927(resolution_m) where sample_status='OK';

create table if not exists automation.usgs_3dep_state_v927(
  state_code text primary key,
  priority integer not null default 100,
  cursor_property_id uuid,
  claim_end_property_id uuid,
  lease_token uuid,
  lease_until timestamptz,
  batch_size integer,
  total_claimed bigint not null default 0,
  total_sampled bigint not null default 0,
  total_ok bigint not null default 0,
  total_no_data bigint not null default 0,
  complete boolean not null default false,
  last_run_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures integer not null default 0,
  last_error text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into automation.usgs_3dep_state_v927(state_code,priority,metadata)
select j.region_code,
       case j.build_status when 'LIVE' then 1 when 'SCORING' then 10 when 'FOUNDATION' then 20 else 50 end,
       jsonb_build_object('jurisdiction_key',j.jurisdiction_key,'jurisdiction_name',j.jurisdiction_name,'build_status_at_seed',j.build_status)
from automation.jurisdictions_v675 j
where j.country_code='US' and j.jurisdiction_kind in('SUBDIVISION','TERRITORY') and j.region_code is not null
on conflict(state_code) do update
set priority=least(automation.usgs_3dep_state_v927.priority,excluded.priority),
    metadata=automation.usgs_3dep_state_v927.metadata||excluded.metadata,
    updated_at=now();

create table if not exists automation.usgs_3dep_dispatch_state_v927(
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
insert into automation.usgs_3dep_dispatch_state_v927(singleton) values(true) on conflict(singleton) do nothing;

create or replace function public.bridgepoint_3dep_claim_v927(p_task_token text,p_batch_size integer default 250)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation','core'
set statement_timeout to '12s'
as $$
declare
  v_auth boolean; s automation.usgs_3dep_state_v927%rowtype; v_rows jsonb; v_end uuid; v_token uuid; v_count integer; tries integer:=0;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;
  if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  p_batch_size:=greatest(1,least(coalesce(p_batch_size,250),500));
  loop
    tries:=tries+1;
    select * into s from automation.usgs_3dep_state_v927
    where complete=false and (lease_until is null or lease_until<now())
    order by priority,last_success_at nulls first,last_run_at nulls first,state_code
    for update skip locked limit 1;
    if not found then return jsonb_build_object('complete',true,'version',927,'claimed',false,'reason','NO_RUNNABLE_STATE'); end if;

    select jsonb_agg(jsonb_build_object('property_id',p.property_id,'state_code',trim(p.state_code::text),'longitude',p.longitude,'latitude',p.latitude) order by p.property_id),
           (array_agg(p.property_id order by p.property_id desc))[1],count(*)
      into v_rows,v_end,v_count
    from (
      select property_id,state_code,longitude,latitude from core.properties
      where active and state_code=s.state_code::bpchar
        and latitude between -90 and 90 and longitude between -180 and 180
        and (s.cursor_property_id is null or property_id>s.cursor_property_id)
      order by property_id limit p_batch_size
    ) p;

    if coalesce(v_count,0)=0 then
      update automation.usgs_3dep_state_v927
      set complete=true,lease_token=null,lease_until=null,claim_end_property_id=null,last_run_at=now(),last_error=null,updated_at=now(),metadata=metadata||jsonb_build_object('completed_at',now())
      where state_code=s.state_code;
      if tries>=5 then return jsonb_build_object('complete',true,'version',927,'claimed',false,'reason','ADVANCED_COMPLETED_STATES'); end if;
      continue;
    end if;

    v_token:=gen_random_uuid();
    update automation.usgs_3dep_state_v927
    set lease_token=v_token,lease_until=now()+interval '3 minutes',claim_end_property_id=v_end,batch_size=v_count,total_claimed=total_claimed+v_count,last_run_at=now(),updated_at=now()
    where state_code=s.state_code;
    return jsonb_build_object('complete',true,'version',927,'claimed',true,'state_code',s.state_code,'lease_token',v_token,'batch_size',v_count,'rows',coalesce(v_rows,'[]'::jsonb));
  end loop;
end
$$;
revoke all on function public.bridgepoint_3dep_claim_v927(text,integer) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_claim_v927(text,integer) to service_role;

create or replace function public.bridgepoint_3dep_persist_v927(p_task_token text,p_state_code text,p_lease_token uuid,p_samples jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation','analytics'
set statement_timeout to '20s'
as $$
declare
  v_auth boolean; s automation.usgs_3dep_state_v927%rowtype; r jsonb; v_seen integer:=0; v_ok integer:=0; v_no_data integer:=0;
  v_elev double precision; v_status text; v_property uuid; v_lon double precision; v_lat double precision;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;
  if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  if jsonb_typeof(p_samples)<>'array' then raise exception 'samples must be array'; end if;
  select * into s from automation.usgs_3dep_state_v927 where state_code=upper(p_state_code) for update;
  if not found then raise exception 'unknown state'; end if;
  if s.lease_token is distinct from p_lease_token then raise exception 'lease token mismatch'; end if;
  if s.lease_until is null or s.lease_until<now()-interval '30 seconds' then raise exception 'lease expired'; end if;

  for r in select value from jsonb_array_elements(p_samples) loop
    v_seen:=v_seen+1;
    v_property:=nullif(r->>'property_id','')::uuid; v_lon:=nullif(r->>'longitude','')::double precision; v_lat:=nullif(r->>'latitude','')::double precision;
    v_status:=upper(coalesce(nullif(r->>'sample_status',''),'NO_DATA'));
    if v_status not in('OK','NO_DATA','INVALID') then v_status:='INVALID'; end if;
    v_elev:=nullif(r->>'elevation_m','')::double precision;
    if v_status='OK' and (v_elev is null or v_elev < -12000 or v_elev > 10000) then v_status:='INVALID'; end if;

    insert into analytics.us_property_elevation_v927(property_id,state_code,longitude,latitude,elevation_m,sample_status,resolution_m,raster_id,dataset_id,product_name,vertical_datum,acquisition_date,attributes,sampled_at,updated_at)
    values(v_property,upper(p_state_code),v_lon,v_lat,case when v_status='OK' then v_elev else null end,v_status,
      nullif(r->>'resolution_m','')::double precision,nullif(r->>'raster_id','')::bigint,nullif(r->>'dataset_id',''),nullif(r->>'product_name',''),nullif(r->>'vertical_datum',''),nullif(r->>'acquisition_date',''),coalesce(r->'attributes','{}'::jsonb),now(),now())
    on conflict(property_id) do update set state_code=excluded.state_code,longitude=excluded.longitude,latitude=excluded.latitude,elevation_m=excluded.elevation_m,sample_status=excluded.sample_status,resolution_m=excluded.resolution_m,raster_id=excluded.raster_id,dataset_id=excluded.dataset_id,product_name=excluded.product_name,vertical_datum=excluded.vertical_datum,acquisition_date=excluded.acquisition_date,attributes=excluded.attributes,sampled_at=now(),updated_at=now();
    if v_status='OK' then v_ok:=v_ok+1; else v_no_data:=v_no_data+1; end if;
  end loop;

  update analytics.us_building_geometry_v700 g
  set ground_elevation_m=e.elevation_m,
      metadata=coalesce(g.metadata,'{}'::jsonb)||jsonb_build_object('ground_elevation_source','USGS_3DEP_V918','ground_elevation_sampled_at',e.sampled_at,'ground_elevation_resolution_m',e.resolution_m),updated_at=now()
  from analytics.us_property_elevation_v927 e
  where e.property_id=g.property_id and e.state_code=upper(p_state_code) and e.sample_status='OK'
    and e.property_id in (select nullif(value->>'property_id','')::uuid from jsonb_array_elements(p_samples));

  update automation.usgs_3dep_state_v927
  set cursor_property_id=claim_end_property_id,claim_end_property_id=null,lease_token=null,lease_until=null,total_sampled=total_sampled+v_seen,total_ok=total_ok+v_ok,total_no_data=total_no_data+v_no_data,last_success_at=now(),consecutive_failures=0,last_error=null,updated_at=now()
  where state_code=upper(p_state_code);

  update automation.source_registry
  set source_url='https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer',access_method='ARCGIS_IMAGESERVER_GETSAMPLES',enabled=true,health_status='HEALTHY',last_checked_at=now(),last_successful_import_at=now(),total_records_ingested=coalesce(total_records_ingested,0)+v_ok,last_run_records_found=v_seen,last_run_records_inserted=v_ok,consecutive_failures=0,last_error=null,parser_version='v927',
      configuration=coalesce(configuration,'{}'::jsonb)||jsonb_build_object('source_class','USGS_OFFICIAL','adapter_status','ACTIVE','batch_mode','MULTIPOINT_GETSAMPLES','max_batch_size',500),
      metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('role','NATIONAL_TERRAIN_LIDAR_BASELINE','verified_service_at',now(),'service_data_type','esriImageServiceDataTypeElevation'),updated_at=now()
  where source_code='USGS_3DEP_V918';

  return jsonb_build_object('complete',true,'version',927,'state_code',upper(p_state_code),'seen',v_seen,'ok',v_ok,'no_data_or_invalid',v_no_data,'cursor',s.claim_end_property_id);
end
$$;
revoke all on function public.bridgepoint_3dep_persist_v927(text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_persist_v927(text,text,uuid,jsonb) to service_role;

create or replace function public.bridgepoint_3dep_fail_v927(p_task_token text,p_state_code text,p_lease_token uuid,p_error text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '5s'
as $$
declare v_auth boolean; v_released boolean:=false;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;
  if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  update automation.usgs_3dep_state_v927 set lease_token=null,lease_until=null,claim_end_property_id=null,consecutive_failures=consecutive_failures+1,last_error=left(coalesce(p_error,'unknown'),1500),updated_at=now()
  where state_code=upper(p_state_code) and lease_token=p_lease_token;
  v_released:=found;
  return jsonb_build_object('complete',true,'version',927,'released',v_released,'state_code',upper(p_state_code));
end
$$;
revoke all on function public.bridgepoint_3dep_fail_v927(text,text,uuid,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_fail_v927(text,text,uuid,text) to service_role;

create or replace function automation.dispatch_usgs_3dep_v927(p_batch_size integer default 150)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '8s'
as $$
declare s automation.usgs_3dep_dispatch_state_v927%rowtype; hr net._http_response%rowtype; v_token text; v_request bigint; v_queue int:=0; v_still_queued boolean:=false;
begin
  p_batch_size:=greatest(1,least(coalesce(p_batch_size,150),500));
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-usgs-3dep-v927',0)) then return jsonb_build_object('complete',true,'version',927,'skipped','LOCKED'); end if;
  select * into s from automation.usgs_3dep_dispatch_state_v927 where singleton=true for update;
  if s.in_flight_request_id is not null then
    select * into hr from net._http_response where id=s.in_flight_request_id;
    if found then
      update automation.usgs_3dep_dispatch_state_v927 set last_response_at=hr.created,last_status_code=hr.status_code,consecutive_failures=case when hr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,total_successes=total_successes+case when hr.status_code between 200 and 299 then 1 else 0 end,in_flight_request_id=null,queued_at=null,metadata=metadata||jsonb_build_object('last_response',left(coalesce(hr.content,''),3000),'last_error',hr.error_msg),updated_at=now() where singleton=true;
      select * into s from automation.usgs_3dep_dispatch_state_v927 where singleton=true;
    else
      select exists(select 1 from net.http_request_queue q where q.id=s.in_flight_request_id) into v_still_queued;
      if v_still_queued then return jsonb_build_object('complete',true,'version',927,'skipped','HTTP_QUEUE_IN_FLIGHT','request_id',s.in_flight_request_id);
      elsif s.queued_at is not null and now()-s.queued_at<interval '120 seconds' then return jsonb_build_object('complete',true,'version',927,'skipped','RESPONSE_PENDING','request_id',s.in_flight_request_id);
      else update automation.usgs_3dep_dispatch_state_v927 set in_flight_request_id=null,queued_at=null,consecutive_failures=consecutive_failures+1,metadata=metadata||jsonb_build_object('last_lost_request_recovered_at',now()),updated_at=now() where singleton=true;
      end if;
    end if;
  end if;
  select count(*) into v_queue from net.http_request_queue;
  if v_queue>22 then return jsonb_build_object('complete',true,'version',927,'skipped','HTTP_BACKPRESSURE','http_queue',v_queue); end if;
  select task_token into v_token from automation.geographic_expansion_worker_secret_v90 where singleton=true;
  if v_token is null then raise exception 'worker token missing'; end if;
  select net.http_post(url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-usgs-3dep-worker-v927',headers:='{"Content-Type":"application/json"}'::jsonb,body:=jsonb_build_object('task_token',v_token,'batch_size',p_batch_size),timeout_milliseconds:=55000) into v_request;
  update automation.usgs_3dep_dispatch_state_v927 set in_flight_request_id=v_request,queued_at=now(),total_dispatches=total_dispatches+1,metadata=metadata||jsonb_build_object('last_http_queue',v_queue,'last_batch_size',p_batch_size),updated_at=now() where singleton=true;
  return jsonb_build_object('complete',true,'version',927,'queued',true,'request_id',v_request,'batch_size',p_batch_size,'http_queue_before',v_queue);
end
$$;

update automation.source_registry
set source_url='https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer',
    access_method='ARCGIS_IMAGESERVER_GETSAMPLES',
    health_status=case when last_successful_import_at is null then 'NOT_RUN' else health_status end,
    configuration=coalesce(configuration,'{}'::jsonb)||jsonb_build_object('source_class','USGS_OFFICIAL','adapter_status',case when last_successful_import_at is null then 'READY_FOR_VALIDATION' else 'ACTIVE' end,'batch_mode','MULTIPOINT_GETSAMPLES','max_batch_size',500),
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('role','NATIONAL_TERRAIN_LIDAR_BASELINE','service_data_type','esriImageServiceDataTypeElevation'),updated_at=now()
where source_code='USGS_3DEP_V918';

commit;
