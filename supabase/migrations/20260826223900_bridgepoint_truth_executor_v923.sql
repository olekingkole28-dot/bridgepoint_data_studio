-- BridgePoint Intelligence V923
-- Truth-aware physical requirement execution, LiDAR source routing, and
-- nationwide imagery truth performance repair.
--
-- This migration intentionally preserves existing V703/V910 implementations
-- and patches only known predicates/mappings with defensive assertions.

begin;

-- 1) Do not classify LiDAR/elevation discovery as building-footprint discovery.
do $$
declare
  ddl text;
begin
  select pg_get_functiondef('public.bridgepoint_claim_parity_gap_discovery_v703(integer)'::regprocedure)
    into ddl;

  if position('when ''ELEVATION_LIDAR'' then ''PHYSICAL_BUILDINGS''' in ddl) > 0 then
    ddl := replace(
      ddl,
      'when ''ELEVATION_LIDAR'' then ''PHYSICAL_BUILDINGS''',
      'when ''ELEVATION_LIDAR'' then ''ELEVATION_LIDAR'''
    );
    execute ddl;
  elsif position('when ''ELEVATION_LIDAR'' then ''ELEVATION_LIDAR''' in ddl) = 0 then
    raise exception 'V923: expected ELEVATION_LIDAR routing predicate not found';
  end if;
end
$$;

-- 2) Make nationwide imagery truth state filtering index-friendly.
do $$
declare
  ddl text;
  old_count int;
begin
  select pg_get_functiondef('automation.refresh_imagery_truth_v910()'::regprocedure)
    into ddl;

  old_count :=
    (length(ddl) - length(replace(ddl, 'trim(p.state_code::text)=r.state_code', '')))
    / length('trim(p.state_code::text)=r.state_code');

  if old_count > 0 then
    ddl := replace(
      ddl,
      'trim(p.state_code::text)=r.state_code',
      'p.state_code=r.state_code::bpchar'
    );
    execute ddl;
  elsif position('p.state_code=r.state_code::bpchar' in ddl) = 0 then
    raise exception 'V923: expected imagery state predicate not found';
  end if;
end
$$;

-- 3) Requirement-specific physical executor. This prevents generic building
-- geometry/twin work from being counted as LiDAR or historical-imagery work.
create or replace function automation.master_requirement_execute_v923(p_req_key text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','public','bridgepoint_ai','product','analytics'
set statement_timeout to '55s'
as $$
declare
  g text;
  a jsonb := '[]'::jsonb;
  r jsonb;
  good int := 0;
  enabled_elevation_sources int := 0;
  successful_elevation_sources int := 0;
  elevation_geometry_rows bigint := 0;
  verified_historic_sources int := 0;
  historic_years int := 0;
  twins bigint := 0;
begin
  select action_group into g
  from automation.master_requirement_executor_v763
  where req_key = p_req_key and enabled;

  if g is null then
    return jsonb_build_object(
      'complete', false,
      'executed', false,
      'blocker', 'NO_NATIVE_EXECUTOR',
      'req_key', p_req_key,
      'version', 923
    );
  end if;

  if p_req_key = 'DATA_LIDAR_ELEVATION' then
    begin
      r := automation.sync_us_candidate_task_truth_v779();
      a := a || jsonb_build_array(jsonb_build_object(
        'action','sync_us_candidate_task_truth_v779','result',r));
      if not (r ? 'skipped') then good := good + 1; end if;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','sync_us_candidate_task_truth_v779','error',sqlerrm));
    end;

    begin
      r := to_jsonb(automation.dispatch_gap_discovery_v703());
      a := a || jsonb_build_array(jsonb_build_object(
        'action','dispatch_gap_discovery_v703','result',r));
      good := good + 1;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','dispatch_gap_discovery_v703','error',sqlerrm));
    end;

    select count(*) filter (where enabled),
           count(*) filter (
             where enabled
               and last_successful_import_at is not null
               and coalesce(health_status,'') not in ('FAILED','OUTAGE','DISABLED'))
      into enabled_elevation_sources, successful_elevation_sources
    from automation.source_registry
    where source_category in ('ELEVATION_LIDAR','LIDAR','ELEVATION');

    select count(*) into elevation_geometry_rows
    from analytics.us_building_geometry_v700
    where ground_elevation_m is not null;

    return jsonb_build_object(
      'complete', true,
      'executed', good > 0,
      'req_key', p_req_key,
      'action_group', g,
      'version', 923,
      'actions', a,
      'enabled_elevation_sources', enabled_elevation_sources,
      'successful_elevation_sources', successful_elevation_sources,
      'existing_ground_elevation_geometry_rows', elevation_geometry_rows,
      'blocker', case
        when enabled_elevation_sources = 0 then 'NO_ENABLED_ELEVATION_LIDAR_SOURCE'
        when successful_elevation_sources = 0 then 'NO_VERIFIED_ELEVATION_LIDAR_INGEST'
        else null
      end,
      'truth_rule', 'Building-height geometry is not accepted as LiDAR/elevation completion. This executor routes ELEVATION_LIDAR discovery to the correct source category and requires actual enabled/ingested elevation evidence.'
    );
  end if;

  if p_req_key = 'DATA_HISTORIC_IMAGERY' then
    begin
      r := automation.refresh_imagery_truth_v910();
      a := a || jsonb_build_array(jsonb_build_object(
        'action','refresh_imagery_truth_v910','result',r));
      if not (r ? 'skipped') then good := good + 1; end if;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','refresh_imagery_truth_v910','error',sqlerrm));
    end;

    begin
      r := automation.media_geography_guard_tick_v718();
      a := a || jsonb_build_array(jsonb_build_object(
        'action','media_geography_guard_tick_v718','result',r));
      if not (r ? 'skipped') then good := good + 1; end if;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','media_geography_guard_tick_v718','error',sqlerrm));
    end;

    begin
      r := to_jsonb(automation.dispatch_gap_discovery_v703());
      a := a || jsonb_build_array(jsonb_build_object(
        'action','dispatch_gap_discovery_v703','result',r));
      good := good + 1;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','dispatch_gap_discovery_v703','error',sqlerrm));
    end;

    select count(*) filter (
             where active and verification_status='VERIFIED'
               and media_kind='AERIAL' and captured_year is not null),
           count(distinct captured_year) filter (
             where active and verification_status='VERIFIED'
               and media_kind='AERIAL' and captured_year is not null)
      into verified_historic_sources, historic_years
    from product.property_media_sources_v161;

    return jsonb_build_object(
      'complete', true,
      'executed', good > 0,
      'req_key', p_req_key,
      'action_group', g,
      'version', 923,
      'actions', a,
      'verified_dated_aerial_sources', verified_historic_sources,
      'distinct_capture_years', historic_years,
      'blocker', case
        when verified_historic_sources = 0 then 'NO_VERIFIED_DATED_AERIAL_SOURCE'
        else null
      end,
      'truth_rule', 'Current basemap imagery does not satisfy historical imagery. Completion requires verified dated aerial sources; this executor refreshes truth, guards geography, and actively dispatches source-gap discovery.'
    );
  end if;

  if p_req_key = 'TWIN_DIGITAL' then
    begin
      r := automation.materialize_national_digital_twins_v756(5000);
      a := a || jsonb_build_array(jsonb_build_object(
        'action','materialize_national_digital_twins_v756','result',r));
      if not (r ? 'skipped') then good := good + 1; end if;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','materialize_national_digital_twins_v756','error',sqlerrm));
    end;

    begin
      r := bridgepoint_ai.digital_twin_climate_tick_v503();
      a := a || jsonb_build_array(jsonb_build_object(
        'action','digital_twin_climate_tick_v503','result',r));
      if not (r ? 'skipped') then good := good + 1; end if;
    exception when others then
      a := a || jsonb_build_array(jsonb_build_object(
        'action','digital_twin_climate_tick_v503','error',sqlerrm));
    end;

    select count(*) into twins from bridgepoint_ai.digital_twins_v503;

    return jsonb_build_object(
      'complete', true,
      'executed', good > 0,
      'req_key', p_req_key,
      'action_group', g,
      'version', 923,
      'actions', a,
      'digital_twins', twins,
      'truth_rule', 'Twin materialization and source-onboarding/simulation work are advanced directly. Partial L0/L1/L2 twins remain partial and exact-replica claims stay evidence-gated.'
    );
  end if;

  return automation.master_requirement_execute_v773(p_req_key);
end
$$;

-- 4) Run the requirement ledger against V923 and never count a blocked result
-- as successful autonomous execution.
create or replace function automation.master_requirement_native_tick_v923(p_limit integer default 2)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','bridgepoint_ai'
set statement_timeout to '115s'
as $$
declare
  x record;
  res jsonb;
  rid bigint;
  ok boolean;
  ran int := 0;
  failed int := 0;
  mins int;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-master-requirement-native-v923',0)) then
    return jsonb_build_object('complete',true,'version',923,'skipped','LOCKED');
  end if;

  for x in
    select s.req_key, s.action_group, l.priority
    from automation.master_requirement_native_state_v765 s
    join bridgepoint_ai.master_completion_ledger_v586 l using (req_key)
    join automation.master_requirement_executor_v763 m
      on m.req_key=s.req_key and m.enabled
    where l.status <> 'PROVEN_DONE'
      and s.next_run_at <= now()
    order by l.priority, s.last_run_at nulls first, s.req_key
    limit greatest(1,least(coalesce(p_limit,2),4))
    for update of s skip locked
  loop
    insert into automation.master_requirement_native_runs_v765(req_key,action_group)
    values(x.req_key,x.action_group)
    returning run_id into rid;

    begin
      res := automation.master_requirement_execute_v923(x.req_key);
      ok := coalesce((res->>'executed')::boolean,false)
        and coalesce((res->>'complete')::boolean,false)
        and nullif(res->>'blocker','') is null;

      update automation.master_requirement_native_runs_v765
      set finished_at=now(), success=ok, result=res
      where run_id=rid;

      mins := case x.action_group
        when 'PHYSICAL' then 1
        when 'PARCEL' then 2
        when 'AUTONOMY' then 2
        when 'INTELLIGENCE' then 2
        when 'PERMITS' then 5
        when 'CODE' then 5
        when 'FEMA' then 5
        when 'SOURCE_HEALTH' then 5
        when 'QA' then 10
        when 'SECURITY' then 30
        when 'BACKUP' then 30
        else 10
      end;

      update automation.master_requirement_native_state_v765
      set last_run_at=now(),
          next_run_at=now()+make_interval(mins=>mins),
          last_success=ok,
          last_result=res,
          consecutive_failures=case when ok then 0 else consecutive_failures+1 end,
          total_runs=total_runs+1,
          updated_at=now()
      where req_key=x.req_key;

      update bridgepoint_ai.master_completion_ledger_v586
      set status='IN_PROGRESS',
          verification=coalesce(verification,'{}'::jsonb)||jsonb_build_object(
            'native_executor_version',923,
            'native_last_run_id',rid,
            'native_last_run_at',now(),
            'native_last_result',res,
            'awaiting_independent_verification',true,
            'native_execution_is_not_completion',true),
          updated_at=now()
      where req_key=x.req_key
        and status <> 'PROVEN_DONE';

      if ok then ran := ran+1; else failed := failed+1; end if;
    exception when others then
      update automation.master_requirement_native_runs_v765
      set finished_at=now(), success=false, error_text=sqlerrm
      where run_id=rid;

      update automation.master_requirement_native_state_v765
      set last_run_at=now(),
          next_run_at=now()+interval '10 minutes',
          last_success=false,
          last_result=jsonb_build_object('error',sqlerrm,'executor_version',923),
          consecutive_failures=consecutive_failures+1,
          total_runs=total_runs+1,
          updated_at=now()
      where req_key=x.req_key;

      failed := failed+1;
    end;
  end loop;

  return jsonb_build_object(
    'complete',true,
    'version',923,
    'successful_requirements',ran,
    'failed_requirements',failed,
    'mapped_open',(
      select count(*)
      from automation.master_requirement_native_state_v765 s
      join bridgepoint_ai.master_completion_ledger_v586 l using(req_key)
      where l.status <> 'PROVEN_DONE')
  );
end
$$;

-- 5) Advance the existing cron lane without creating a duplicate scheduler.
select cron.alter_job(
  386,
  command := 'select automation.master_requirement_native_tick_v923(2);'
);

commit;
