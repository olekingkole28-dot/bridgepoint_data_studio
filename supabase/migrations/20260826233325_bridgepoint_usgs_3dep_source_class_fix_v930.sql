-- BridgePoint Intelligence V930
-- Align USGS 3DEP with the governed source_registry class contract.
-- Official-provider provenance belongs in metadata; source_class must use the
-- existing BridgePoint eligibility vocabulary. Also records the EPQS fallback.

create or replace function public.bridgepoint_3dep_persist_v927(
  p_task_token text,
  p_state_code text,
  p_lease_token uuid,
  p_samples jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation','analytics'
set statement_timeout to '20s'
as $$
declare
  v_auth boolean;
  s automation.usgs_3dep_state_v927%rowtype;
  r jsonb;
  v_seen integer:=0;
  v_ok integer:=0;
  v_no_data integer:=0;
  v_elev double precision;
  v_status text;
  v_property uuid;
  v_lon double precision;
  v_lat double precision;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;
  if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  if jsonb_typeof(p_samples)<>'array' then raise exception 'samples must be array'; end if;

  select * into s
  from automation.usgs_3dep_state_v927
  where state_code=upper(p_state_code)
  for update;
  if not found then raise exception 'unknown state'; end if;
  if s.lease_token is distinct from p_lease_token then raise exception 'lease token mismatch'; end if;
  if s.lease_until is null or s.lease_until<now()-interval '30 seconds' then raise exception 'lease expired'; end if;

  for r in select value from jsonb_array_elements(p_samples) loop
    v_seen:=v_seen+1;
    v_property:=nullif(r->>'property_id','')::uuid;
    v_lon:=nullif(r->>'longitude','')::double precision;
    v_lat:=nullif(r->>'latitude','')::double precision;
    v_status:=upper(coalesce(nullif(r->>'sample_status',''),'NO_DATA'));
    if v_status not in('OK','NO_DATA','INVALID') then v_status:='INVALID'; end if;
    v_elev:=nullif(r->>'elevation_m','')::double precision;
    if v_status='OK' and (v_elev is null or v_elev < -12000 or v_elev > 10000) then v_status:='INVALID'; end if;

    insert into analytics.us_property_elevation_v927(
      property_id,state_code,longitude,latitude,elevation_m,sample_status,resolution_m,raster_id,
      dataset_id,product_name,vertical_datum,acquisition_date,attributes,sampled_at,updated_at)
    values(
      v_property,upper(p_state_code),v_lon,v_lat,
      case when v_status='OK' then v_elev else null end,v_status,
      nullif(r->>'resolution_m','')::double precision,
      nullif(r->>'raster_id','')::bigint,
      nullif(r->>'dataset_id',''),nullif(r->>'product_name',''),nullif(r->>'vertical_datum',''),
      nullif(r->>'acquisition_date',''),coalesce(r->'attributes','{}'::jsonb),now(),now())
    on conflict(property_id) do update
    set state_code=excluded.state_code,
        longitude=excluded.longitude,
        latitude=excluded.latitude,
        elevation_m=excluded.elevation_m,
        sample_status=excluded.sample_status,
        resolution_m=excluded.resolution_m,
        raster_id=excluded.raster_id,
        dataset_id=excluded.dataset_id,
        product_name=excluded.product_name,
        vertical_datum=excluded.vertical_datum,
        acquisition_date=excluded.acquisition_date,
        attributes=excluded.attributes,
        sampled_at=now(),
        updated_at=now();

    if v_status='OK' then v_ok:=v_ok+1; else v_no_data:=v_no_data+1; end if;
  end loop;

  update analytics.us_building_geometry_v700 g
  set ground_elevation_m=e.elevation_m,
      metadata=coalesce(g.metadata,'{}'::jsonb)||jsonb_build_object(
        'ground_elevation_source','USGS_3DEP_V918',
        'ground_elevation_sampled_at',e.sampled_at,
        'ground_elevation_resolution_m',e.resolution_m),
      updated_at=now()
  from analytics.us_property_elevation_v927 e
  where e.property_id=g.property_id
    and e.state_code=upper(p_state_code)
    and e.sample_status='OK'
    and e.property_id in (
      select nullif(value->>'property_id','')::uuid
      from jsonb_array_elements(p_samples)
    );

  update automation.usgs_3dep_state_v927
  set cursor_property_id=claim_end_property_id,
      claim_end_property_id=null,
      lease_token=null,
      lease_until=null,
      total_sampled=total_sampled+v_seen,
      total_ok=total_ok+v_ok,
      total_no_data=total_no_data+v_no_data,
      last_success_at=now(),
      consecutive_failures=0,
      last_error=null,
      updated_at=now()
  where state_code=upper(p_state_code);

  update automation.source_registry
  set source_url='https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer',
      access_method='ARCGIS_IMAGESERVER_WITH_EPQS_FALLBACK',
      enabled=true,
      health_status='HEALTHY',
      last_checked_at=now(),
      last_successful_import_at=now(),
      total_records_ingested=coalesce(total_records_ingested,0)+v_ok,
      last_run_records_found=v_seen,
      last_run_records_inserted=v_ok,
      consecutive_failures=0,
      last_error=null,
      parser_version='v927',
      configuration=coalesce(configuration,'{}'::jsonb)||jsonb_build_object(
        'source_class','INTELLIGENCE_ELIGIBLE',
        'adapter_status','ACTIVE',
        'batch_mode','MULTIPOINT_WITH_EPQS_FALLBACK',
        'max_batch_size',100),
      metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
        'role','NATIONAL_TERRAIN_LIDAR_BASELINE',
        'official_provider','USGS',
        'verified_service_at',now(),
        'service_data_type','esriImageServiceDataTypeElevation',
        'fallback_service','USGS_EPQS',
        'truth_note','3DEP elevation is evidence-gated; national coverage does not imply direct high-resolution LiDAR for every location'),
      updated_at=now()
  where source_code='USGS_3DEP_V918';

  return jsonb_build_object(
    'complete',true,
    'version',930,
    'state_code',upper(p_state_code),
    'seen',v_seen,
    'ok',v_ok,
    'no_data_or_invalid',v_no_data,
    'cursor',s.claim_end_property_id);
end
$$;

revoke all on function public.bridgepoint_3dep_persist_v927(text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_3dep_persist_v927(text,text,uuid,jsonb) to service_role;
