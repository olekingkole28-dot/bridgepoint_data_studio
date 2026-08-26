-- BridgePoint Intelligence V924
-- Prevent Open Buildings dispatcher lanes from treating requests that are
-- still present in pg_net's HTTP queue as failed/timeouts.

begin;

create or replace function automation.dispatch_open_building_lane_v924(p_lane_id integer)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '8s'
as $$
declare
  s automation.open_building_dispatch_lanes_v921%rowtype;
  hr net._http_response%rowtype;
  v_token text;
  v_request bigint;
  v_queue int:=0;
  v_remaining bigint:=0;
  v_complete bigint:=0;
  v_still_queued boolean:=false;
begin
  if p_lane_id<0 or p_lane_id>7 then raise exception 'invalid lane'; end if;
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-open-building-lane-'||p_lane_id::text,0)) then
    return jsonb_build_object('complete',true,'version',924,'lane',p_lane_id,'skipped','LOCKED');
  end if;

  insert into automation.open_building_dispatch_lanes_v921(lane_id)
  values(p_lane_id) on conflict(lane_id) do nothing;
  select * into s from automation.open_building_dispatch_lanes_v921 where lane_id=p_lane_id for update;

  if s.in_flight_request_id is not null then
    select * into hr from net._http_response where id=s.in_flight_request_id;
    if found then
      update automation.open_building_dispatch_lanes_v921
      set last_response_at=hr.created,
          last_status_code=hr.status_code,
          consecutive_failures=case when hr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,
          total_successes=total_successes+case when hr.status_code between 200 and 299 then 1 else 0 end,
          in_flight_request_id=null,
          queued_at=null,
          updated_at=now(),
          metadata=metadata||jsonb_build_object(
            'last_response_bytes',coalesce(length(hr.content),0),
            'last_error',hr.error_msg,
            'last_reconciled_at',now())
      where lane_id=p_lane_id;
      select * into s from automation.open_building_dispatch_lanes_v921 where lane_id=p_lane_id;
    else
      select exists(select 1 from net.http_request_queue q where q.id=s.in_flight_request_id)
        into v_still_queued;
      if v_still_queued then
        return jsonb_build_object(
          'complete',true,'version',924,'lane',p_lane_id,
          'skipped','HTTP_QUEUE_IN_FLIGHT','request_id',s.in_flight_request_id,
          'queued_seconds',extract(epoch from (now()-coalesce(s.queued_at,now())))::int);
      elsif s.queued_at is not null and now()-s.queued_at<interval '120 seconds' then
        return jsonb_build_object(
          'complete',true,'version',924,'lane',p_lane_id,
          'skipped','RESPONSE_PENDING','request_id',s.in_flight_request_id);
      else
        update automation.open_building_dispatch_lanes_v921
        set in_flight_request_id=null,
            queued_at=null,
            consecutive_failures=consecutive_failures+1,
            updated_at=now(),
            metadata=metadata||jsonb_build_object('last_lost_request_recovered_at',now())
        where lane_id=p_lane_id;
      end if;
    end if;
  end if;

  select count(*) into v_queue from net.http_request_queue;
  if v_queue>22 then
    return jsonb_build_object('complete',true,'version',924,'lane',p_lane_id,'skipped','HTTP_BACKPRESSURE','http_queue',v_queue);
  end if;

  select count(*) filter(where status<>'COMPLETE'),
         count(*) filter(where status='COMPLETE')
    into v_remaining,v_complete
  from automation.open_building_tile_queue_v918
  where source_key='MICROSOFT_GLOBALML_BUILDINGS';

  if v_remaining=0 then
    return jsonb_build_object('complete',true,'version',924,'lane',p_lane_id,'skipped','SOURCE_COMPLETE','tiles_complete',v_complete);
  end if;

  select task_token into v_token
  from automation.geographic_expansion_worker_secret_v90
  where singleton=true;
  if v_token is null then raise exception 'worker token missing'; end if;

  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-open-buildings-worker-v918',
    headers:='{"Content-Type":"application/json"}'::jsonb,
    body:=jsonb_build_object('task_token',v_token,'action','run','lane_id',p_lane_id),
    timeout_milliseconds:=60000
  ) into v_request;

  update automation.open_building_dispatch_lanes_v921
  set in_flight_request_id=v_request,
      queued_at=now(),
      total_dispatches=total_dispatches+1,
      updated_at=now(),
      metadata=metadata||jsonb_build_object('last_http_queue',v_queue,'dispatcher_version',924)
  where lane_id=p_lane_id;

  return jsonb_build_object(
    'complete',true,'version',924,'lane',p_lane_id,'queued',true,
    'request_id',v_request,'http_queue_before',v_queue,
    'tiles_remaining',v_remaining,'tiles_complete',v_complete);
end
$$;

select cron.alter_job(399, command := 'select automation.dispatch_open_building_lane_v924(0);');
select cron.alter_job(400, command := 'select automation.dispatch_open_building_lane_v924(1);');
select cron.alter_job(401, command := 'select automation.dispatch_open_building_lane_v924(2);');

commit;
