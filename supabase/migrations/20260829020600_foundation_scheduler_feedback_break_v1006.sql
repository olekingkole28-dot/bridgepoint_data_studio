-- BridgePoint V1006
-- Break the pg_cron startup-timeout feedback loop, dedupe foundation materializer scheduling,
-- and gate canonical boosters on real local database pressure rather than noisy governor labels.
create or replace function automation.expansion_native_foundation_booster_v454(p_lane integer, p_lanes integer default 10)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','public','cron'
set statement_timeout to '58s'
as $function$
declare
  v_active int:=0; v_long int:=0; v_locks int:=0; v_io int:=0; v_fail int:=0;
  v_db_gb numeric:=0; v_property_pending bigint:=0; v_mode text;
  v_warning_gb numeric:=2800;
begin
  if p_lanes<1 or p_lane<0 or p_lane>=p_lanes then raise exception 'Invalid lane'; end if;

  select count(*) filter(where a.backend_type='client backend' and a.state='active')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.query_start is not null and now()-a.query_start>interval '90 seconds')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.wait_event_type='Lock')::int,
         count(*) filter(where a.backend_type='client backend' and a.state='active' and a.wait_event_type='IO')::int
    into v_active,v_long,v_locks,v_io
  from pg_stat_activity a
  where a.datname=current_database() and a.pid<>pg_backend_pid();

  select count(*)::int into v_fail
  from cron.job_run_details d
  where d.start_time>=now()-interval '5 minutes'
    and d.status='failed'
    and coalesce(d.return_message,'') not in ('job startup timeout','job canceled');

  select coalesce(pending,0) into v_property_pending from automation.v40_property_queue_health limit 1;
  select mode into v_mode from automation.overnight_throughput_governor_state_v395 where singleton=true;
  select warning_database_gb into v_warning_gb from automation.capacity_policy_v627 where singleton=true;
  v_db_gb:=round(pg_database_size(current_database())::numeric/1073741824.0,2);

  if v_db_gb>=coalesce(v_warning_gb,2800) or v_active>14 or v_long>1 or v_locks>1 or v_io>2 or v_fail>2 or v_property_pending>=2500 then
    return jsonb_build_object('complete',true,'skipped',true,'reason','LOCAL_PRESSURE_GATE','lane',p_lane,'governor_mode',v_mode,'active_clients',v_active,'long_queries',v_long,'lock_waits',v_locks,'io_waits',v_io,'execution_failures_5m',v_fail,'property_pending',v_property_pending,'database_size_gb',v_db_gb,'version',1006);
  end if;

  return automation.expansion_native_foundation_lane_v417(p_lane,p_lanes)
         || jsonb_build_object('booster_version',1006,'pressure_gate','GREEN','governor_mode',v_mode,'execution_failures_5m',v_fail);
end
$function$;

create or replace function automation.overnight_throughput_governor_v446()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','public','pattern_engine','cron'
set statement_timeout to '20s'
as $function$
declare
  v_active int:=0; v_long int:=0; v_fail int:=0; v_startup int:=0;
  v_pattern bigint:=0; v_entity bigint:=0; v_property bigint:=0;
  v_source bigint:=0; v_us_source bigint:=0; v_source_done bigint:=0; v_db_gb numeric:=0;
  v_us_total int:=0; v_us_live int:=0;
  v_mode text:='BALANCED'; v_action text:='V1006_BALANCED';
  rec record;
begin
  select count(*)::int,
         count(*) filter(where query_start is not null and now()-query_start>interval '90 seconds')::int
    into v_active,v_long
  from pg_stat_activity a
  where a.datname=current_database() and a.pid<>pg_backend_pid()
    and a.backend_type='client backend' and a.state='active';

  select count(*)::int into v_fail
  from cron.job_run_details d
  left join cron.job j on j.jobid=d.jobid
  where d.start_time>=now()-interval '5 minutes'
    and d.status='failed'
    and coalesce(j.active,true)
    and coalesce(d.return_message,'') not in ('job startup timeout','job canceled');

  select count(*) filter(where d.return_message='job startup timeout')::int into v_startup
  from cron.job_run_details d join cron.job j on j.jobid=d.jobid
  where d.start_time>=greatest(now()-interval '5 minutes',pg_postmaster_start_time()) and d.status='failed' and j.active;

  select count(*) into v_pattern from pattern_engine.entity_pattern_queue_v36 where status='PENDING';
  select count(*) into v_entity from automation.entity_reprocess_queue where status='PENDING';
  select coalesce(pending,0) into v_property from automation.v40_property_queue_health;
  select count(*) into v_source from automation.geographic_source_tasks_v90 where task_status in('QUEUED','PENDING','RETRY');
  select count(*) into v_us_source
  from automation.jurisdiction_source_tasks_v675 t join automation.jurisdictions_v675 j using(jurisdiction_key)
  where j.country_code='US' and t.task_status in('QUEUED','DISCOVERING','VALIDATING','CANDIDATE_FOUND');
  select count(*) into v_source_done from automation.geographic_source_tasks_v90 where task_status='SUCCEEDED' and updated_at>=now()-interval '5 minutes';
  select count(*),count(*) filter(where build_status='LIVE') into v_us_total,v_us_live from automation.jurisdictions_v675 where country_code='US';
  v_db_gb:=round(pg_database_size(current_database())::numeric/1073741824.0,2);

  if v_db_gb>=coalesce((select warning_database_gb from automation.capacity_policy_v627 where singleton=true),2800)
     or v_active>=24 or v_long>=6 or v_fail>=8 or (v_startup>=16 and v_active>=18) then
    v_mode:='PRESSURE'; v_action:='V1006_REAL_PRESSURE_BACKOFF';
    for rec in
      select c.jobid,v.schedule,v.enabled from (values
        ('bridgepoint-entity-reprocessing-v344-1','53 seconds',true),('bridgepoint-entity-reprocessing-v344-2','59 seconds',true),('bridgepoint-entity-reprocessing-v344-3','55 seconds',false),('bridgepoint-entity-reprocessing-v344-4','56 seconds',false),('bridgepoint-entity-reprocessing-v344-5','57 seconds',false),('bridgepoint-entity-reprocessing-v344-6','58 seconds',false),
        ('bridgepoint-event-reprocessing','47 seconds',true),
        ('bridgepoint-noaa-us-point-batch-v346-1','43 seconds',true),('bridgepoint-noaa-us-point-batch-v346-2','49 seconds',true),('bridgepoint-noaa-us-point-batch-v346-3','45 seconds',false),('bridgepoint-noaa-us-point-batch-v346-4','46 seconds',false),('bridgepoint-noaa-us-point-batch-v349-5','49 seconds',false),
        ('bridgepoint-pattern-v36-1','51 seconds',true),('bridgepoint-pattern-v36-2','57 seconds',true),('bridgepoint-pattern-v36-3','53 seconds',false),('bridgepoint-pattern-v36-4','59 seconds',false),
        ('bridgepoint expansion bulk materializer shard 0','49 seconds',false),('bridgepoint expansion bulk materializer shard 1','59 seconds',false),('bridgepoint expansion bulk materializer shard 2','43 seconds',false),('bridgepoint expansion bulk materializer shard 3','41 seconds',false),('bridgepoint expansion bulk materializer shard 4','43 seconds',false),
        ('bridgepoint-expansion-foundation-booster-v454-0','50 seconds',true),('bridgepoint-expansion-foundation-booster-v454-1','51 seconds',true),('bridgepoint-expansion-foundation-booster-v454-2','52 seconds',true),('bridgepoint-expansion-foundation-booster-v454-3','53 seconds',true),('bridgepoint-expansion-foundation-booster-v454-4','54 seconds',true),('bridgepoint-expansion-foundation-booster-v454-5','55 seconds',true),('bridgepoint-expansion-foundation-booster-v454-6','56 seconds',true),('bridgepoint-expansion-foundation-booster-v454-7','57 seconds',true),('bridgepoint-expansion-foundation-booster-v454-8','58 seconds',true),('bridgepoint-expansion-foundation-booster-v454-9','59 seconds',true),
        ('bridgepoint-expansion-materializer-target-refresh-v398','47 seconds',true),
        ('bridgepoint-pattern-score-handoff-v370-1','53 seconds',true),('bridgepoint-pattern-score-handoff-v370-2','59 seconds',true),('bridgepoint-pattern-score-handoff-v370-3','*/5 * * * *',false)
      ) as v(jobname,schedule,enabled) join cron.job c on c.jobname=v.jobname
    loop perform cron.alter_job(rec.jobid,rec.schedule,null,null,null,rec.enabled); end loop;
  elsif v_active<=18 and v_long<=2 and v_fail<=2
        and (v_pattern>50000 or v_entity>50000 or v_source>=25 or v_us_source>250 or v_us_live<v_us_total) then
    v_mode:='SPRINT'; v_action:='V1006_US_COMPLETION_DEDUPED_PARALLELISM';
    for rec in
      select c.jobid,v.schedule,v.enabled from (values
        ('bridgepoint-entity-reprocessing-v344-1','23 seconds',true),('bridgepoint-entity-reprocessing-v344-2','29 seconds',true),('bridgepoint-entity-reprocessing-v344-3','31 seconds',false),('bridgepoint-entity-reprocessing-v344-4','37 seconds',false),('bridgepoint-entity-reprocessing-v344-5','41 seconds',false),('bridgepoint-entity-reprocessing-v344-6','43 seconds',false),
        ('bridgepoint-event-reprocessing','31 seconds',true),
        ('bridgepoint-noaa-us-point-batch-v346-1','31 seconds',true),('bridgepoint-noaa-us-point-batch-v346-2','37 seconds',true),('bridgepoint-noaa-us-point-batch-v346-3','41 seconds',true),('bridgepoint-noaa-us-point-batch-v346-4','43 seconds',true),('bridgepoint-noaa-us-point-batch-v349-5','47 seconds',true),
        ('bridgepoint-pattern-v36-1','29 seconds',true),('bridgepoint-pattern-v36-2','31 seconds',true),('bridgepoint-pattern-v36-3','37 seconds',true),('bridgepoint-pattern-v36-4','41 seconds',true),
        ('bridgepoint expansion bulk materializer shard 0','19 seconds',false),('bridgepoint expansion bulk materializer shard 1','23 seconds',false),('bridgepoint expansion bulk materializer shard 2','29 seconds',false),('bridgepoint expansion bulk materializer shard 3','31 seconds',false),('bridgepoint expansion bulk materializer shard 4','37 seconds',false),
        ('bridgepoint-expansion-foundation-booster-v454-0','19 seconds',true),('bridgepoint-expansion-foundation-booster-v454-1','23 seconds',true),('bridgepoint-expansion-foundation-booster-v454-2','27 seconds',true),('bridgepoint-expansion-foundation-booster-v454-3','29 seconds',true),('bridgepoint-expansion-foundation-booster-v454-4','31 seconds',true),('bridgepoint-expansion-foundation-booster-v454-5','33 seconds',true),('bridgepoint-expansion-foundation-booster-v454-6','37 seconds',true),('bridgepoint-expansion-foundation-booster-v454-7','39 seconds',true),('bridgepoint-expansion-foundation-booster-v454-8','41 seconds',true),('bridgepoint-expansion-foundation-booster-v454-9','47 seconds',true),
        ('bridgepoint-expansion-materializer-target-refresh-v398','17 seconds',true),
        ('bridgepoint-pattern-score-handoff-v370-1','19 seconds',true),('bridgepoint-pattern-score-handoff-v370-2','23 seconds',true),('bridgepoint-pattern-score-handoff-v370-3','29 seconds',true)
      ) as v(jobname,schedule,enabled) join cron.job c on c.jobname=v.jobname
    loop perform cron.alter_job(rec.jobid,rec.schedule,null,null,null,rec.enabled); end loop;
  end if;

  insert into automation.overnight_throughput_governor_state_v395(singleton,mode,active_clients,long_queries,recent_cron_failures,pattern_pending,entity_pending,property_pending,last_action,updated_at)
  values(true,v_mode,v_active,v_long,v_fail,v_pattern,v_entity,v_property,v_action,now())
  on conflict(singleton) do update set mode=excluded.mode,active_clients=excluded.active_clients,long_queries=excluded.long_queries,recent_cron_failures=excluded.recent_cron_failures,pattern_pending=excluded.pattern_pending,entity_pending=excluded.entity_pending,property_pending=excluded.property_pending,last_action=excluded.last_action,updated_at=now();

  insert into automation.overnight_throughput_governor_history_v397(mode,active_clients,long_queries,recent_cron_failures,startup_timeouts,pattern_pending,entity_pending,property_pending,source_tasks_pending,entity_completed_5m,source_succeeded_5m,action)
  values(v_mode,v_active,v_long,v_fail,v_startup,v_pattern,v_entity,v_property,v_source+v_us_source,0,v_source_done,v_action);

  return jsonb_build_object('complete',true,'version',1006,'compute_profile','SUPABASE_16XL','mode',v_mode,'action',v_action,'active_clients',v_active,'long_queries',v_long,'execution_failures',v_fail,'startup_timeouts',v_startup,'pattern_pending',v_pattern,'entity_pending',v_entity,'property_pending',v_property,'legacy_source_pending',v_source,'us_source_pending',v_us_source,'us_live',v_us_live,'us_total',v_us_total,'database_size_gb',v_db_gb,'updated_at',now());
end
$function$;
