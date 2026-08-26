-- BridgePoint Intelligence V929
-- Self-resuming USGS 3DEP scheduler with adaptive validation batch sizing.
-- The underlying V927 dispatcher enforces shared pg_net backpressure and one in-flight request.

create or replace function automation.usgs_3dep_scheduler_tick_v929()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation'
set statement_timeout to '8s'
as $$
declare
  v_ok bigint:=0;
  v_failures integer:=0;
  v_complete integer:=0;
  v_total integer:=0;
  v_batch integer:=20;
  v_result jsonb;
begin
  select coalesce(sum(total_ok),0),coalesce(max(consecutive_failures),0),count(*) filter(where complete),count(*)
    into v_ok,v_failures,v_complete,v_total
  from automation.usgs_3dep_state_v927;

  if v_total=0 then
    return jsonb_build_object('complete',true,'version',929,'skipped','NO_STATE_ROWS');
  end if;
  if v_complete=v_total then
    return jsonb_build_object('complete',true,'version',929,'skipped','ALL_STATES_COMPLETE','total_ok',v_ok);
  end if;

  v_batch:=case
    when v_ok=0 then 20
    when v_failures>=2 then 20
    when v_ok<1000 then 50
    else 100
  end;

  select automation.dispatch_usgs_3dep_v927(v_batch) into v_result;
  return jsonb_build_object('complete',true,'version',929,'batch_size',v_batch,'total_ok',v_ok,'dispatch',v_result);
end
$$;

revoke all on function automation.usgs_3dep_scheduler_tick_v929() from public,anon,authenticated;
grant execute on function automation.usgs_3dep_scheduler_tick_v929() to service_role,postgres;

do $$
begin
  if not exists(select 1 from cron.job where jobname='bridgepoint-usgs-3dep-v929') then
    perform cron.schedule('bridgepoint-usgs-3dep-v929','* * * * *','select automation.usgs_3dep_scheduler_tick_v929();');
  end if;
end
$$;
