-- Widen the shared lifecycle dispatch pressure gate so bounded public-hazard pulls
-- can coexist with ongoing global-geometry work. Preserve advisory locking,
-- in-flight request tracking, failure backoff, and private task-token handling.
CREATE OR REPLACE FUNCTION automation.dispatch_global_lifecycle_worker_v5830(p_worker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'automation', 'net', 'public'
 SET statement_timeout TO '10s'
AS $function$
declare
  wk text:=upper(trim(p_worker));
  st automation.global_lifecycle_dispatch_state_v5830%rowtype;
  rr net._http_response%rowtype;
  tok text; rid bigint; url text;
  q int:=0; active_n int:=0; io_n int:=0; lock_n int:=0;
begin
  if wk not in('USGS_EARTHQUAKE','CO_IDEAM') then
    return jsonb_build_object('complete',false,'version',5830,'error','UNKNOWN_WORKER');
  end if;
  if not pg_try_advisory_xact_lock(hashtextextended('bp-global-lifecycle-dispatch-'||wk,0)) then
    return jsonb_build_object('complete',true,'version',5830,'skipped','LOCKED','worker',wk);
  end if;

  select * into st from automation.global_lifecycle_dispatch_state_v5830 where worker_key=wk for update;

  if st.in_flight_request_id is not null then
    select * into rr from net._http_response where id=st.in_flight_request_id;
    if found then
      update automation.global_lifecycle_dispatch_state_v5830
      set last_status_code=rr.status_code,last_response_at=rr.created,
          consecutive_failures=case when rr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,
          in_flight_request_id=null,queued_at=null,
          last_error=case when rr.status_code between 200 and 299 then null else coalesce(rr.error_msg,'HTTP_'||rr.status_code::text) end,
          updated_at=now()
      where worker_key=wk;
      select * into st from automation.global_lifecycle_dispatch_state_v5830 where worker_key=wk;
    elsif st.queued_at is not null and now()-st.queued_at<interval '150 seconds' then
      return jsonb_build_object('complete',true,'version',5830,'skipped','IN_FLIGHT','worker',wk,'request_id',st.in_flight_request_id);
    else
      update automation.global_lifecycle_dispatch_state_v5830
      set in_flight_request_id=null,queued_at=null,consecutive_failures=consecutive_failures+1,
          last_error='STALE_HTTP_REQUEST',updated_at=now()
      where worker_key=wk;
      select * into st from automation.global_lifecycle_dispatch_state_v5830 where worker_key=wk;
    end if;
  end if;

  if st.consecutive_failures>=5 then
    return jsonb_build_object('complete',true,'version',5830,'skipped','FAILURE_BACKOFF','worker',wk,'failures',st.consecutive_failures);
  end if;

  select count(*)::int into q from net.http_request_queue;
  select
    count(*) filter(where backend_type='client backend' and state='active' and pid<>pg_backend_pid())::int,
    count(*) filter(where backend_type='client backend' and state='active' and wait_event_type='IO')::int,
    count(*) filter(where backend_type='client backend' and state='active' and wait_event_type='Lock')::int
  into active_n,io_n,lock_n
  from pg_stat_activity where datname=current_database();

  -- Permit a bounded extra hazard request alongside global geometry workers; retain load gates.
  if q>=44 or active_n>=20 or io_n>=8 or lock_n>=2 then
    update automation.global_lifecycle_dispatch_state_v5830
    set total_pressure_skips=total_pressure_skips+1,updated_at=now()
    where worker_key=wk;
    return jsonb_build_object('complete',true,'version',5830,'skipped','PRESSURE_GATE','worker',wk,
      'http_queue',q,'active',active_n,'io',io_n,'locks',lock_n);
  end if;

  select task_token into tok from automation.geographic_expansion_worker_secret_v90 where singleton;
  if tok is null then raise exception 'WORKER_TOKEN_MISSING'; end if;

  url:=case wk
    when 'USGS_EARTHQUAKE' then 'https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-global-earthquake-ingest-v5829'
    when 'CO_IDEAM' then 'https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-global-lifecycle-ingest-v5825'
  end;

  select net.http_post(
    url:=url,
    headers:='{"Content-Type":"application/json"}'::jsonb,
    body:=jsonb_build_object('task_token',tok,'dispatcher_version',5830),
    timeout_milliseconds:=120000
  ) into rid;

  update automation.global_lifecycle_dispatch_state_v5830
  set in_flight_request_id=rid,queued_at=now(),total_dispatches=total_dispatches+1,last_error=null,updated_at=now()
  where worker_key=wk;

  return jsonb_build_object('complete',true,'version',5830,'queued',true,'worker',wk,'request_id',rid,
    'http_queue',q,'active',active_n,'io',io_n,'locks',lock_n);
end
$function$;
