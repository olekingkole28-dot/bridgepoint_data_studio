-- BridgePoint V942: owner-facing parcel expansion progress truth.
-- Shows real lane activity, county discovery and state foundation progress without invented ETAs.

create or replace function public.bridgepoint_owner_parcel_progress_v942()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','api','accounts','automation'
as $function$
declare
  v_accel jsonb;
  v_lanes jsonb;
  v_counties jsonb;
  v_states jsonb;
  v_active_lanes int:=0;
  v_lane_successes bigint:=0;
  v_lane_failures int:=0;
  v_last_lane_activity timestamptz;
begin
  perform api.require_user();
  if not accounts.is_platform_admin() then
    raise exception 'Owner access required';
  end if;

  select jsonb_build_object(
    'last_run_at',last_run_at,
    'unreconciled_states',unreconciled_states,
    'zero_foundation_states',zero_foundation_states,
    'partial_states',partial_states,
    'provisional_states',provisional_states,
    'authoritative_states',authoritative_states,
    'tasks_prioritized',tasks_prioritized,
    'updated_at',updated_at
  ) into v_accel
  from automation.us_parcel_accelerator_state_v741
  where singleton=true;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'lane',lane,
      'active',in_flight_request_id is not null,
      'in_flight_request_id',in_flight_request_id,
      'queued_at',queued_at,
      'last_status_code',last_status_code,
      'last_response_at',last_response_at,
      'consecutive_failures',consecutive_failures,
      'total_successes',total_successes,
      'updated_at',updated_at
    ) order by lane),'[]'::jsonb),
    count(*) filter(where in_flight_request_id is not null),
    coalesce(sum(total_successes),0),
    coalesce(sum(consecutive_failures),0),
    max(greatest(coalesce(last_response_at,'epoch'::timestamptz),coalesce(updated_at,'epoch'::timestamptz)))
  into v_lanes,v_active_lanes,v_lane_successes,v_lane_failures,v_last_lane_activity
  from automation.priority_parcel_shard_state_v751;

  select jsonb_object_agg(target_status,n) into v_counties
  from (
    select target_status,count(*)::bigint n
    from automation.us_county_parcel_targets_v742
    group by target_status
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
    'state_code',state_code,
    'state_name',state_name,
    'data_status',data_status,
    'queue_status',queue_status,
    'run_status',run_status,
    'current_phase',current_phase,
    'overall_progress_pct',overall_progress_pct,
    'canonical_property_count',canonical_property_count,
    'expected_foundation_rows',expected_foundation_rows,
    'foundation_progress_pct',foundation_progress_pct,
    'denominator_status',denominator_status,
    'foundation_reconciled',foundation_reconciled,
    'property_queue_pending',property_queue_pending,
    'property_queue_processing',property_queue_processing,
    'last_activity_at',last_activity_at,
    'refreshed_at',refreshed_at
  ) order by
    case when data_status='LIVE' then 0 when current_phase='PROPERTY_FOUNDATION' then 1 else 2 end,
    state_code
  ),'[]'::jsonb)
  into v_states
  from automation.owner_state_progress_cache_v377;

  return jsonb_build_object(
    'complete',true,
    'version',942,
    'generated_at',now(),
    'system_state',case
      when v_active_lanes >= 5 and v_last_lane_activity > now()-interval '10 minutes' then 'ACTIVE'
      when v_last_lane_activity > now()-interval '30 minutes' then 'MOVING_SLOWLY'
      else 'NEEDS_ATTENTION'
    end,
    'active_lanes',v_active_lanes,
    'total_lanes',jsonb_array_length(v_lanes),
    'lane_successes',v_lane_successes,
    'current_lane_failures',v_lane_failures,
    'last_lane_activity_at',v_last_lane_activity,
    'accelerator',coalesce(v_accel,'{}'::jsonb),
    'county_discovery',coalesce(v_counties,'{}'::jsonb),
    'lanes',v_lanes,
    'states',v_states,
    'truth_note','Parcel progress uses real lane activity and cached state foundation truth. Unknown statewide denominators are not converted into invented percentages or ETAs.'
  );
end
$function$;

revoke all on function public.bridgepoint_owner_parcel_progress_v942() from public,anon;
grant execute on function public.bridgepoint_owner_parcel_progress_v942() to authenticated,service_role;
