-- BridgePoint Intelligence V932
-- Source mirror of the live on-demand terrain dispatcher.
-- One in-flight request, bounded pg_net pressure, minute cadence only when priority work exists.

create or replace function automation.dispatch_usgs_3dep_priority_v932(p_batch_size integer default 20)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '8s'
as $$
declare
  s automation.usgs_3dep_priority_dispatch_state_v931%rowtype;
  hr net._http_response%rowtype;
  v_token text;
  v_request bigint;
  v_queue int:=0;
  v_still_queued boolean:=false;
  v_pending int:=0;
begin
  p_batch_size:=greatest(1,least(coalesce(p_batch_size,20),100));
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-usgs-3dep-priority-v932',0)) then
    return jsonb_build_object('complete',true,'version',932,'skipped','LOCKED');
  end if;

  select count(*) into v_pending
  from automation.usgs_3dep_priority_queue_v931
  where status in('QUEUED','RUNNING') and (status='QUEUED' or lease_until<now());

  select * into s
  from automation.usgs_3dep_priority_dispatch_state_v931
  where singleton=true
  for update;

  if s.in_flight_request_id is not null then
    select * into hr from net._http_response where id=s.in_flight_request_id;
    if found then
      update automation.usgs_3dep_priority_dispatch_state_v931
      set last_response_at=hr.created,
          last_status_code=hr.status_code,
          consecutive_failures=case when hr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,
          total_successes=total_successes+case when hr.status_code between 200 and 299 then 1 else 0 end,
          in_flight_request_id=null,
          queued_at=null,
          metadata=metadata||jsonb_build_object('last_response',left(coalesce(hr.content,''),3000),'last_error',hr.error_msg),
          updated_at=now()
      where singleton=true;
      select * into s from automation.usgs_3dep_priority_dispatch_state_v931 where singleton=true;
    else
      select exists(select 1 from net.http_request_queue q where q.id=s.in_flight_request_id) into v_still_queued;
      if v_still_queued then
        return jsonb_build_object('complete',true,'version',932,'skipped','HTTP_QUEUE_IN_FLIGHT','request_id',s.in_flight_request_id,'pending',v_pending);
      end if;
      if s.queued_at is not null and now()-s.queued_at<interval '120 seconds' then
        return jsonb_build_object('complete',true,'version',932,'skipped','RESPONSE_PENDING','request_id',s.in_flight_request_id,'pending',v_pending);
      end if;
      update automation.usgs_3dep_priority_dispatch_state_v931
      set in_flight_request_id=null,
          queued_at=null,
          consecutive_failures=consecutive_failures+1,
          updated_at=now(),
          metadata=metadata||jsonb_build_object('last_lost_request_recovered_at',now())
      where singleton=true;
    end if;
  end if;

  if v_pending=0 then
    return jsonb_build_object('complete',true,'version',932,'skipped','NO_PRIORITY_WORK');
  end if;

  select count(*) into v_queue from net.http_request_queue;
  if v_queue>28 then
    return jsonb_build_object('complete',true,'version',932,'skipped','HTTP_BACKPRESSURE','http_queue',v_queue,'pending',v_pending);
  end if;

  select task_token into v_token
  from automation.geographic_expansion_worker_secret_v90
  where singleton=true;
  if v_token is null then raise exception 'worker token missing'; end if;

  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-usgs-3dep-priority-v931',
    headers:='{"Content-Type":"application/json"}'::jsonb,
    body:=jsonb_build_object('task_token',v_token,'batch_size',p_batch_size),
    timeout_milliseconds:=55000
  ) into v_request;

  update automation.usgs_3dep_priority_dispatch_state_v931
  set in_flight_request_id=v_request,
      queued_at=now(),
      total_dispatches=total_dispatches+1,
      metadata=metadata||jsonb_build_object('last_http_queue',v_queue,'last_batch_size',p_batch_size,'last_pending',v_pending),
      updated_at=now()
  where singleton=true;

  perform net.wake();
  return jsonb_build_object('complete',true,'version',932,'queued',true,'request_id',v_request,'batch_size',p_batch_size,'pending',v_pending,'http_queue_before',v_queue);
end
$$;

revoke all on function automation.dispatch_usgs_3dep_priority_v932(integer) from public,anon,authenticated;
grant execute on function automation.dispatch_usgs_3dep_priority_v932(integer) to service_role,postgres;

do $$
begin
  if not exists(select 1 from cron.job where jobname='bridgepoint-usgs-3dep-priority-v932') then
    perform cron.schedule('bridgepoint-usgs-3dep-priority-v932','* * * * *','select automation.dispatch_usgs_3dep_priority_v932(20);');
  end if;
end
$$;
