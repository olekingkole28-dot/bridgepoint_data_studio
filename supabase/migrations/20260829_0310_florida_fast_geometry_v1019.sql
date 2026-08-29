-- BridgePoint Florida fast foundation + deferred geometry checkpoint v1019
-- Production state: FL reserved from generic foundation claimers; 8k attributes-first source lane;
-- four interleaved centroid lanes with 500-row DB apply chunks in Edge worker.

create table if not exists automation.florida_geometry_lane_state_v1018(
  lane integer primary key check (lane between 0 and 3),
  next_window_start bigint not null,
  last_window_end bigint not null default 0,
  max_oid bigint not null default 0,
  records_seen bigint not null default 0,
  staging_rows_updated bigint not null default 0,
  properties_updated bigint not null default 0,
  addresses_updated bigint not null default 0,
  consecutive_failures integer not null default 0,
  last_error text,
  last_success_at timestamptz,
  last_dispatched_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into automation.florida_geometry_lane_state_v1018(lane,next_window_start) values
  (0,0),(1,2000),(2,4000),(3,6000)
on conflict(lane) do nothing;

create or replace function public.bridgepoint_claim_foundation_tasks_v633(p_limit integer default 12)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
as $function$
declare v_tasks jsonb; n int:=least(greatest(coalesce(p_limit,12),1),20); recovered int:=0;
begin
  if auth.role()<>'service_role' then raise exception 'service_role required'; end if;
  update automation.geographic_source_tasks_v90 t
     set task_status='QUEUED',next_retry_at=now(),updated_at=now(),
         result=coalesce(t.result,'{}'::jsonb)||jsonb_build_object('global_foundation_stale_recovery_v633',true,'recovered_at',now())
   where t.task_type='ACQUIRE_PROPERTY_FOUNDATION' and t.task_status='RUNNING'
     and t.updated_at<now()-interval '5 minutes';
  get diagnostics recovered=row_count;
  with picked as (
    select t.source_task_id
      from automation.geographic_source_tasks_v90 t
      join automation.geographic_source_candidates_v86 c on c.candidate_id=t.candidate_id
      join automation.geographic_expansion_runs_v86 g on g.run_id=t.run_id
      left join automation.state_foundation_denominators_v403 d on d.state_code=t.state_code
     where t.task_type='ACQUIRE_PROPERTY_FOUNDATION'
       and t.task_status='QUEUED'
       and upper(coalesce(t.state_code,'')) not in ('AR','FL')
       and (t.next_retry_at is null or t.next_retry_at<=now())
       and c.decision_status='ACCEPTED'
       and c.source_category='PROPERTY_PARCEL'
       and (g.current_phase='PROPERTY_FOUNDATION' or (d.state_code is not null and not d.foundation_reconciled))
       and g.run_status in('RUNNING','INGESTION','MATCHING','VALIDATION','READY')
       and automation.expansion_candidate_scope_v197(c.state_code,c.candidate_name,c.provider,c.source_url,c.metadata) in('TARGET','NATIONAL')
       and automation.expansion_adapter_mode_v197(c.source_category,c.access_method)='ROW_INGEST'
     order by coalesce(nullif(t.cursor->>'estimated_total_rows','')::numeric,0) desc,t.updated_at,t.state_code
     for update of t skip locked
     limit n
  ), upd as (
    update automation.geographic_source_tasks_v90 t
       set task_status='RUNNING',updated_at=now()
      from picked p
     where t.source_task_id=p.source_task_id
     returning t.*
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.state_code),'[]'::jsonb)
    into v_tasks
    from (
      select u.*,c.source_category,c.candidate_name,c.provider,c.source_url,c.access_method,c.metadata candidate_metadata
        from upd u join automation.geographic_source_candidates_v86 c on c.candidate_id=u.candidate_id
    ) x;
  return jsonb_build_object('complete',true,'version',1017,'claimed',jsonb_array_length(v_tasks),'recovered_stale',recovered,'reserved_states',jsonb_build_array('AR','FL'),'tasks',v_tasks);
end
$function$;

create or replace function public.bridgepoint_priority_foundation_runs_v754(p_lane integer,p_limit integer default 1)
returns jsonb
language sql
stable security definer
set search_path to 'pg_catalog','automation','public'
as $function$
with eligible as (
  select distinct on (r.state_code)
         r.run_id,r.state_code,r.run_status,r.current_phase,r.updated_at,
         d.expected_rows,d.canonical_property_count,
         greatest(coalesce(d.expected_rows,0)-coalesce(d.canonical_property_count,0),0)::bigint as known_missing_rows,
         t.source_task_id,t.updated_at as task_updated_at,
         coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)::bigint as source_total_rows,
         coalesce(nullif(t.result->>'offset_to','')::bigint,nullif(t.cursor->>'offset','')::bigint,
                  nullif(t.result->>'keyset_rows_seen','')::bigint,nullif(t.result->>'progress_to','')::bigint,
                  nullif(t.cursor->>'keyset_rows_seen','')::bigint,nullif(t.cursor->>'progress_to','')::bigint,0)::bigint as source_seen_rows,
         coalesce((t.result->>'effective_done')::boolean,false) as source_effective_done
  from automation.geographic_expansion_runs_v86 r
  join automation.geographic_source_tasks_v90 t
    on t.run_id=r.run_id and t.task_type='ACQUIRE_PROPERTY_FOUNDATION'
   and t.task_status='QUEUED' and (t.next_retry_at is null or t.next_retry_at<=now())
  join automation.geographic_source_candidates_v86 c on c.candidate_id=t.candidate_id and c.decision_status='ACCEPTED'
  left join automation.state_foundation_denominators_v403 d on d.state_code=r.state_code
  where (r.current_phase='PROPERTY_FOUNDATION' or (d.state_code is not null and not d.foundation_reconciled))
    and r.state_code is not null
    and upper(r.state_code) not in ('AR','FL')
    and automation.expansion_candidate_scope_v197(c.state_code,c.candidate_name,c.provider,c.source_url,c.metadata) in('TARGET','NATIONAL')
    and automation.expansion_adapter_mode_v197(c.source_category,c.access_method)='ROW_INGEST'
    and not (
      coalesce((t.result->>'effective_done')::boolean,false)
      and coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)>0
      and coalesce(nullif(t.result->>'offset_to','')::bigint,nullif(t.cursor->>'offset','')::bigint,
                   nullif(t.result->>'keyset_rows_seen','')::bigint,nullif(t.result->>'progress_to','')::bigint,
                   nullif(t.cursor->>'keyset_rows_seen','')::bigint,nullif(t.cursor->>'progress_to','')::bigint,0)
          >= floor(coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)*0.995)
    )
  order by r.state_code,
           greatest(
             coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)
             - coalesce(nullif(t.result->>'offset_to','')::bigint,nullif(t.cursor->>'offset','')::bigint,
                        nullif(t.result->>'keyset_rows_seen','')::bigint,nullif(t.result->>'progress_to','')::bigint,
                        nullif(t.cursor->>'keyset_rows_seen','')::bigint,nullif(t.cursor->>'progress_to','')::bigint,0),0
           ) desc,
           greatest(coalesce(d.expected_rows,0)-coalesce(d.canonical_property_count,0),0) desc,
           t.updated_at
), ordered as (
  select eligible.*,
         greatest(source_total_rows-source_seen_rows,0)::bigint as source_remaining_rows,
         row_number() over(order by
           case when source_total_rows>0 and source_seen_rows<source_total_rows then 0 else 1 end,
           greatest(source_total_rows-source_seen_rows,0) desc,
           known_missing_rows desc,
           task_updated_at,state_code) as rn
  from eligible
), picked as (
  select * from ordered
  where mod((rn-1)::int,6)=least(greatest(coalesce(p_lane,0),0),5)
  order by rn
  limit least(greatest(coalesce(p_limit,1),1),3)
)
select jsonb_build_object('complete',true,'version',1017,'lane',least(greatest(coalesce(p_lane,0),0),5),
  'selection_policy','UNREAD_SOURCE_ROWS_FIRST__AR_FL_RESERVED__6_SHARDS',
  'runs',coalesce(jsonb_agg(to_jsonb(p)-'rn' order by p.rn),'[]'::jsonb))
from picked p;
$function$;

create or replace function automation.dispatch_florida_parcel_fast_v1017()
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '10s'
as $function$
declare q int:=0; v_ready int:=0; v_token text; v_request bigint; v_mode text; v_db numeric; v_hard numeric:=3200;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-florida-parcel-fast-v1017',0)) then
    return jsonb_build_object('complete',true,'version',1017,'skipped','LOCKED');
  end if;
  q:=automation.http_queue_pressure_v917();
  if q>=25 then return jsonb_build_object('complete',true,'version',1017,'skipped','HTTP_BACKPRESSURE','http_queue',q); end if;
  select mode into v_mode from automation.overnight_throughput_governor_state_v395 where singleton=true;
  select hard_stop_database_gb into v_hard from automation.capacity_policy_v627 where singleton=true;
  v_db:=round(pg_database_size(current_database())::numeric/1073741824,2);
  select count(*) into v_ready
  from automation.geographic_source_tasks_v90 t
  join automation.geographic_expansion_runs_v86 r on r.run_id=t.run_id
  where r.state_code='FL' and t.task_type='ACQUIRE_PROPERTY_FOUNDATION' and t.task_status='QUEUED'
    and (t.next_retry_at is null or t.next_retry_at<=now());
  if coalesce(v_mode,'BALANCED')<>'SPRINT' or v_db>=coalesce(v_hard,3200) or v_ready=0 then
    return jsonb_build_object('complete',true,'version',1017,'skipped','SAFETY_GATE','mode',v_mode,'database_size_gb',v_db,'ready_fl_tasks',v_ready);
  end if;
  select task_token into v_token from automation.geographic_expansion_worker_secret_v90 where singleton=true;
  if v_token is null then raise exception 'Expansion worker token missing'; end if;
  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-florida-parcel-fast-v1017',
    headers:='{"Content-Type":"application/json"}'::jsonb,
    body:=jsonb_build_object('task_token',v_token,'page',8000),
    timeout_milliseconds:=85000
  ) into v_request;
  return jsonb_build_object('complete',true,'version',1017,'queued',true,'request_id',v_request,'ready_fl_tasks',v_ready,'database_size_gb',v_db,'page',8000);
end
$function$;

create or replace function automation.apply_florida_geometry_batch_v1018(p_lane integer,p_records jsonb,p_window_start bigint,p_window_end bigint,p_max_oid bigint,p_done boolean default false)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','automation','staging','core','public'
set statement_timeout to '25s'
as $function$
declare n_input int:=0; n_stage int:=0; n_prop int:=0; n_addr int:=0; v_next bigint;
begin
  if p_lane<0 or p_lane>3 then raise exception 'Invalid Florida geometry lane'; end if;
  if jsonb_typeof(coalesce(p_records,'[]'::jsonb))<>'array' then raise exception 'p_records must be an array'; end if;
  n_input:=jsonb_array_length(coalesce(p_records,'[]'::jsonb));
  v_next:=p_window_start+8000;
  with r as (
    select source_record_id,lat,lng from jsonb_to_recordset(coalesce(p_records,'[]'::jsonb)) as x(source_record_id text,lat double precision,lng double precision)
    where source_record_id is not null and lat between 24 and 32 and lng between -88 and -79
  )
  update staging.geographic_source_records_v90 sr
     set payload=coalesce(sr.payload,'{}'::jsonb)||jsonb_build_object('_bridgepoint_latitude',r.lat,'_bridgepoint_longitude',r.lng,'_bridgepoint_geometry_enriched_v1018',true,'_bridgepoint_geometry_enriched_at',now())
    from r,automation.geographic_source_candidates_v86 c
   where sr.candidate_id=c.candidate_id and c.state_code='FL' and c.source_category='PROPERTY_PARCEL' and sr.source_record_id=r.source_record_id;
  get diagnostics n_stage=row_count;
  with r as (
    select source_record_id,lat,lng from jsonb_to_recordset(coalesce(p_records,'[]'::jsonb)) as x(source_record_id text,lat double precision,lng double precision)
    where source_record_id is not null and lat between 24 and 32 and lng between -88 and -79
  ), s as (
    select sr.canonical_property_id,r.lat,r.lng from staging.geographic_source_records_v90 sr
    join automation.geographic_source_candidates_v86 c on c.candidate_id=sr.candidate_id and c.state_code='FL' and c.source_category='PROPERTY_PARCEL'
    join r on r.source_record_id=sr.source_record_id where sr.canonical_property_id is not null
  )
  update core.properties p set latitude=coalesce(p.latitude,s.lat),longitude=coalesce(p.longitude,s.lng),centroid_geom=coalesce(p.centroid_geom,st_setsrid(st_makepoint(s.lng,s.lat),4326)),metadata=coalesce(p.metadata,'{}'::jsonb)||jsonb_build_object('florida_geometry_enriched_v1018',true),updated_at=now()
  from s where p.property_id=s.canonical_property_id;
  get diagnostics n_prop=row_count;
  with r as (
    select source_record_id,lat,lng from jsonb_to_recordset(coalesce(p_records,'[]'::jsonb)) as x(source_record_id text,lat double precision,lng double precision)
    where source_record_id is not null and lat between 24 and 32 and lng between -88 and -79
  ), s as (
    select p.primary_address_id,r.lat,r.lng from staging.geographic_source_records_v90 sr
    join automation.geographic_source_candidates_v86 c on c.candidate_id=sr.candidate_id and c.state_code='FL' and c.source_category='PROPERTY_PARCEL'
    join r on r.source_record_id=sr.source_record_id
    join core.properties p on p.property_id=sr.canonical_property_id where p.primary_address_id is not null
  )
  update core.addresses a set location_geom=coalesce(a.location_geom,st_setsrid(st_makepoint(s.lng,s.lat),4326)),geocode_status=coalesce(a.geocode_status,'source_provided'),geocode_confidence=greatest(coalesce(a.geocode_confidence,0),0.90),updated_at=now()
  from s where a.address_id=s.primary_address_id;
  get diagnostics n_addr=row_count;
  update automation.florida_geometry_lane_state_v1018
     set next_window_start=v_next,last_window_end=p_window_end,max_oid=greatest(max_oid,coalesce(p_max_oid,0)),records_seen=records_seen+n_input,staging_rows_updated=staging_rows_updated+n_stage,properties_updated=properties_updated+n_prop,addresses_updated=addresses_updated+n_addr,consecutive_failures=0,last_error=null,last_success_at=now(),completed_at=case when p_done then coalesce(completed_at,now()) else completed_at end,updated_at=now()
   where lane=p_lane;
  return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'records',n_input,'staging_rows_updated',n_stage,'properties_updated',n_prop,'addresses_updated',n_addr,'window_start',p_window_start,'window_end',p_window_end,'next_window_start',v_next,'max_oid',p_max_oid,'lane_done',p_done);
end
$function$;

create or replace function automation.dispatch_florida_geometry_v1018(p_lane integer)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '10s'
as $function$
declare q int:=0; v_token text; v_request bigint; st automation.florida_geometry_lane_state_v1018%rowtype; v_db numeric; v_hard numeric:=3200; v_mode text;
begin
  if p_lane<0 or p_lane>3 then raise exception 'Invalid Florida geometry lane'; end if;
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-florida-geometry-v1018-'||p_lane,0)) then return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'skipped','LOCKED'); end if;
  select * into st from automation.florida_geometry_lane_state_v1018 where lane=p_lane for update;
  if st.completed_at is not null then return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'skipped','DONE'); end if;
  if st.last_dispatched_at is not null and now()-st.last_dispatched_at<interval '12 seconds' then return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'skipped','RECENTLY_DISPATCHED'); end if;
  q:=automation.http_queue_pressure_v917();
  if q>=25 then return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'skipped','HTTP_BACKPRESSURE','http_queue',q); end if;
  select mode into v_mode from automation.overnight_throughput_governor_state_v395 where singleton=true;
  select hard_stop_database_gb into v_hard from automation.capacity_policy_v627 where singleton=true;
  v_db:=round(pg_database_size(current_database())::numeric/1073741824,2);
  if coalesce(v_mode,'BALANCED')<>'SPRINT' or v_db>=coalesce(v_hard,3200) then return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'skipped','SAFETY_GATE','mode',v_mode,'database_size_gb',v_db); end if;
  select task_token into v_token from automation.geographic_expansion_worker_secret_v90 where singleton=true;
  if v_token is null then raise exception 'Expansion worker token missing'; end if;
  select net.http_post(url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-florida-geometry-v1018',headers:='{"Content-Type":"application/json"}'::jsonb,body:=jsonb_build_object('task_token',v_token,'lane',p_lane),timeout_milliseconds:=60000) into v_request;
  update automation.florida_geometry_lane_state_v1018 set last_dispatched_at=now(),updated_at=now() where lane=p_lane;
  return jsonb_build_object('complete',true,'version',1018,'lane',p_lane,'queued',true,'request_id',v_request,'database_size_gb',v_db);
end
$function$;

-- Idempotently replace production schedules.
do $$ declare r record; begin
  for r in select jobid from cron.job where jobname in (
    'bridgepoint-florida-parcel-fast-v1017',
    'bridgepoint-florida-geometry-v1019-0','bridgepoint-florida-geometry-v1019-1','bridgepoint-florida-geometry-v1019-2','bridgepoint-florida-geometry-v1019-3'
  ) loop perform cron.unschedule(r.jobid); end loop;
end $$;
select cron.schedule('bridgepoint-florida-parcel-fast-v1017','13 seconds',$$select automation.dispatch_florida_parcel_fast_v1017();$$);
select cron.schedule('bridgepoint-florida-geometry-v1019-0','17 seconds',$$select automation.dispatch_florida_geometry_v1018(0);$$);
select cron.schedule('bridgepoint-florida-geometry-v1019-1','19 seconds',$$select automation.dispatch_florida_geometry_v1018(1);$$);
select cron.schedule('bridgepoint-florida-geometry-v1019-2','23 seconds',$$select automation.dispatch_florida_geometry_v1018(2);$$);
select cron.schedule('bridgepoint-florida-geometry-v1019-3','29 seconds',$$select automation.dispatch_florida_geometry_v1018(3);$$);
