-- BridgePoint Intelligence V925
-- Durable evidence bridge from external GitHub/browser verification into the
-- production requirement ledger. Database cron cannot self-certify UI QA.

begin;

create table if not exists automation.external_verification_evidence_v925(
  verification_key text primary key,
  status text not null,
  verifier_version integer not null,
  release_version integer,
  trigger_sha text,
  source_url text not null,
  verified_at timestamptz not null,
  ingested_at timestamptz not null default now(),
  evidence jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint external_verification_status_v925_chk check(status in('VERIFIED','FAILED','STALE'))
);

create index if not exists external_verification_evidence_v925_verified_idx
  on automation.external_verification_evidence_v925(status,verified_at desc);

create table if not exists automation.external_verification_dispatch_state_v925(
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

insert into automation.external_verification_dispatch_state_v925(singleton)
values(true) on conflict(singleton) do nothing;

create or replace function public.bridgepoint_record_external_verification_v925(
  p_task_token text,
  p_evidence jsonb,
  p_source_url text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '8s'
as $$
declare
  v_auth boolean;
  v_status text;
  v_verifier integer;
  v_release integer;
  v_sha text;
  v_verified_at timestamptz;
  v_checks jsonb;
  v_all_required boolean;
begin
  select public.bridgepoint_expansion_worker_auth_v90(p_task_token) into v_auth;
  if coalesce(v_auth,false) is not true then raise exception 'invalid task token'; end if;
  if jsonb_typeof(p_evidence)<>'object' then raise exception 'evidence must be object'; end if;
  if p_source_url !~ '^https://raw\.githubusercontent\.com/olekingkole28-dot/bridgepoint-live/' then
    raise exception 'untrusted verification source';
  end if;

  v_status:=upper(coalesce(p_evidence->>'status',''));
  v_verifier:=nullif(p_evidence->>'verifier_version','')::integer;
  v_release:=nullif(p_evidence->>'property_twin_release','')::integer;
  v_sha:=nullif(p_evidence->>'trigger_sha','');
  v_verified_at:=nullif(p_evidence->>'verified_at','')::timestamptz;
  v_checks:=coalesce(p_evidence->'checks','{}'::jsonb);
  v_all_required:=
    coalesce((v_checks->>'current_release_contract')::boolean,false) and
    coalesce((v_checks->>'custom_domain_https_200')::boolean,false) and
    coalesce((v_checks->>'public_secret_boundary_checked')::boolean,false) and
    coalesce((v_checks->>'phone_390x844_home_app_twin_passed')::boolean,false) and
    coalesce((v_checks->>'tablet_768x1024_home_app_twin_passed')::boolean,false) and
    coalesce((v_checks->>'desktop_1440x900_home_app_twin_passed')::boolean,false) and
    coalesce((v_checks->>'flutter_runtime_mounted_all_viewports')::boolean,false) and
    coalesce((v_checks->>'property_twin_auth_shell_all_viewports')::boolean,false) and
    coalesce((v_checks->>'horizontal_overflow_guard_all_viewports')::boolean,false);

  if v_status<>'VERIFIED'
     or coalesce(v_verifier,0)<925
     or coalesce(v_release,0)<922
     or v_verified_at is null
     or v_verified_at<now()-interval '7 days'
     or not v_all_required then
    raise exception 'verification evidence failed policy';
  end if;

  insert into automation.external_verification_evidence_v925(
    verification_key,status,verifier_version,release_version,trigger_sha,source_url,verified_at,ingested_at,evidence,updated_at)
  values('CURRENT_LIVE_V925','VERIFIED',v_verifier,v_release,v_sha,p_source_url,v_verified_at,now(),p_evidence,now())
  on conflict(verification_key) do update
  set status=excluded.status,
      verifier_version=excluded.verifier_version,
      release_version=excluded.release_version,
      trigger_sha=excluded.trigger_sha,
      source_url=excluded.source_url,
      verified_at=excluded.verified_at,
      ingested_at=now(),
      evidence=excluded.evidence,
      updated_at=now();

  return jsonb_build_object(
    'complete',true,'version',925,'recorded',true,
    'verification_key','CURRENT_LIVE_V925','verified_at',v_verified_at,'release_version',v_release);
end
$$;

revoke all on function public.bridgepoint_record_external_verification_v925(text,jsonb,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_record_external_verification_v925(text,jsonb,text) to service_role;

create or replace function automation.master_requirement_execute_v925(p_req_key text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','bridgepoint_ai'
set statement_timeout to '55s'
as $$
declare
  e automation.external_verification_evidence_v925%rowtype;
  fresh boolean:=false;
  responsive boolean:=false;
begin
  if p_req_key in('RELEASE_PUBLIC_POSTDEPLOY_VERIFY','APP_AUTOMATED_RESPONSIVE_QA_V734') then
    select * into e
    from automation.external_verification_evidence_v925
    where verification_key='CURRENT_LIVE_V925';

    fresh:=found
      and e.status='VERIFIED'
      and e.verifier_version>=925
      and coalesce(e.release_version,0)>=922
      and e.verified_at>=now()-interval '7 days';

    responsive:=fresh
      and coalesce((e.evidence->'checks'->>'phone_390x844_home_app_twin_passed')::boolean,false)
      and coalesce((e.evidence->'checks'->>'tablet_768x1024_home_app_twin_passed')::boolean,false)
      and coalesce((e.evidence->'checks'->>'desktop_1440x900_home_app_twin_passed')::boolean,false)
      and coalesce((e.evidence->'checks'->>'flutter_runtime_mounted_all_viewports')::boolean,false)
      and coalesce((e.evidence->'checks'->>'property_twin_auth_shell_all_viewports')::boolean,false)
      and coalesce((e.evidence->'checks'->>'horizontal_overflow_guard_all_viewports')::boolean,false);

    if p_req_key='RELEASE_PUBLIC_POSTDEPLOY_VERIFY' then
      return jsonb_build_object(
        'complete',true,'executed',fresh,'version',925,'req_key',p_req_key,'action_group','QA',
        'blocker',case when fresh then null else 'NO_FRESH_EXTERNAL_RELEASE_VERIFICATION' end,
        'evidence',case when fresh then jsonb_build_object(
          'verification_key',e.verification_key,'verified_at',e.verified_at,'release_version',e.release_version,
          'trigger_sha',e.trigger_sha,'source_url',e.source_url) else null end,
        'truth_rule','Release verification requires fresh externally executed CI/browser evidence; database cron cannot self-certify it.'
      );
    end if;

    return jsonb_build_object(
      'complete',true,'executed',responsive,'version',925,'req_key',p_req_key,'action_group','QA',
      'blocker',case when responsive then null else 'NO_FRESH_MULTI_VIEWPORT_BROWSER_VERIFICATION' end,
      'evidence',case when responsive then jsonb_build_object(
        'verification_key',e.verification_key,'verified_at',e.verified_at,'release_version',e.release_version,
        'checks',e.evidence->'checks') else null end,
      'truth_rule','Responsive QA requires fresh phone, tablet and desktop browser evidence with live Flutter and Property Twin runtime checks. Static HTTP success is insufficient.'
    );
  end if;

  return automation.master_requirement_execute_v923(p_req_key);
end
$$;

create or replace function automation.master_requirement_native_tick_v925(p_limit integer default 2)
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
  ran int:=0;
  failed int:=0;
  mins int;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-master-requirement-native-v925',0)) then
    return jsonb_build_object('complete',true,'version',925,'skipped','LOCKED');
  end if;

  for x in
    select s.req_key,s.action_group,l.priority
    from automation.master_requirement_native_state_v765 s
    join bridgepoint_ai.master_completion_ledger_v586 l on l.req_key=s.req_key
    join automation.master_requirement_executor_v763 m on m.req_key=s.req_key and m.enabled
    where l.status<>'PROVEN_DONE' and s.next_run_at<=now()
    order by l.priority,s.last_run_at nulls first,s.req_key
    limit greatest(1,least(coalesce(p_limit,2),4))
    for update of s skip locked
  loop
    insert into automation.master_requirement_native_runs_v765(req_key,action_group)
    values(x.req_key,x.action_group) returning run_id into rid;
    begin
      res:=automation.master_requirement_execute_v925(x.req_key);
      ok:=coalesce((res->>'executed')::boolean,false)
          and coalesce((res->>'complete')::boolean,false)
          and nullif(res->>'blocker','') is null;

      update automation.master_requirement_native_runs_v765
      set finished_at=now(),success=ok,result=res where run_id=rid;

      mins:=case x.action_group
        when 'PHYSICAL' then 1 when 'PARCEL' then 2 when 'AUTONOMY' then 2
        when 'INTELLIGENCE' then 2 when 'PERMITS' then 5 when 'CODE' then 5
        when 'FEMA' then 5 when 'SOURCE_HEALTH' then 5 when 'QA' then 10
        when 'SECURITY' then 30 when 'BACKUP' then 30 else 10 end;

      update automation.master_requirement_native_state_v765
      set last_run_at=now(),next_run_at=now()+make_interval(mins=>mins),last_success=ok,last_result=res,
          consecutive_failures=case when ok then 0 else consecutive_failures+1 end,
          total_runs=total_runs+1,updated_at=now()
      where req_key=x.req_key;

      update bridgepoint_ai.master_completion_ledger_v586
      set status='IN_PROGRESS',
          verification=coalesce(verification,'{}'::jsonb)||jsonb_build_object(
            'native_executor_version',925,'native_last_run_id',rid,'native_last_run_at',now(),
            'native_last_result',res,'awaiting_independent_verification',not ok,
            'native_execution_is_not_completion',true),
          updated_at=now()
      where req_key=x.req_key and status<>'PROVEN_DONE';

      if ok then ran:=ran+1; else failed:=failed+1; end if;
    exception when others then
      update automation.master_requirement_native_runs_v765
      set finished_at=now(),success=false,error_text=sqlerrm where run_id=rid;
      update automation.master_requirement_native_state_v765
      set last_run_at=now(),next_run_at=now()+interval '10 minutes',last_success=false,
          last_result=jsonb_build_object('error',sqlerrm,'executor_version',925),
          consecutive_failures=consecutive_failures+1,total_runs=total_runs+1,updated_at=now()
      where req_key=x.req_key;
      failed:=failed+1;
    end;
  end loop;

  return jsonb_build_object(
    'complete',true,'version',925,'successful_requirements',ran,'failed_requirements',failed,
    'mapped_open',(select count(*) from automation.master_requirement_native_state_v765 s
      join bridgepoint_ai.master_completion_ledger_v586 l using(req_key)
      where l.status<>'PROVEN_DONE'));
end
$$;

create or replace function automation.dispatch_live_verification_sync_v925()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','net'
set statement_timeout to '8s'
as $$
declare
  s automation.external_verification_dispatch_state_v925%rowtype;
  hr net._http_response%rowtype;
  v_token text;
  v_request bigint;
  v_queue int:=0;
  v_still_queued boolean:=false;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('bridgepoint-live-verification-sync-v925',0)) then
    return jsonb_build_object('complete',true,'version',925,'skipped','LOCKED');
  end if;

  select * into s from automation.external_verification_dispatch_state_v925 where singleton=true for update;

  if s.in_flight_request_id is not null then
    select * into hr from net._http_response where id=s.in_flight_request_id;
    if found then
      update automation.external_verification_dispatch_state_v925
      set last_response_at=hr.created,last_status_code=hr.status_code,
          consecutive_failures=case when hr.status_code between 200 and 299 then 0 else consecutive_failures+1 end,
          total_successes=total_successes+case when hr.status_code between 200 and 299 then 1 else 0 end,
          in_flight_request_id=null,queued_at=null,
          metadata=metadata||jsonb_build_object('last_response',left(coalesce(hr.content,''),2000),'last_error',hr.error_msg),
          updated_at=now()
      where singleton=true;
      select * into s from automation.external_verification_dispatch_state_v925 where singleton=true;
    else
      select exists(select 1 from net.http_request_queue q where q.id=s.in_flight_request_id) into v_still_queued;
      if v_still_queued then
        return jsonb_build_object('complete',true,'version',925,'skipped','HTTP_QUEUE_IN_FLIGHT','request_id',s.in_flight_request_id);
      elsif s.queued_at is not null and now()-s.queued_at<interval '120 seconds' then
        return jsonb_build_object('complete',true,'version',925,'skipped','RESPONSE_PENDING','request_id',s.in_flight_request_id);
      else
        update automation.external_verification_dispatch_state_v925
        set in_flight_request_id=null,queued_at=null,consecutive_failures=consecutive_failures+1,
            metadata=metadata||jsonb_build_object('last_lost_request_recovered_at',now()),updated_at=now()
        where singleton=true;
      end if;
    end if;
  end if;

  select count(*) into v_queue from net.http_request_queue;
  if v_queue>22 then
    return jsonb_build_object('complete',true,'version',925,'skipped','HTTP_BACKPRESSURE','http_queue',v_queue);
  end if;

  select task_token into v_token from automation.geographic_expansion_worker_secret_v90 where singleton=true;
  if v_token is null then raise exception 'worker token missing'; end if;

  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-live-verification-sync-v925',
    headers:='{"Content-Type":"application/json"}'::jsonb,
    body:=jsonb_build_object('task_token',v_token),
    timeout_milliseconds:=45000
  ) into v_request;

  update automation.external_verification_dispatch_state_v925
  set in_flight_request_id=v_request,queued_at=now(),total_dispatches=total_dispatches+1,
      metadata=metadata||jsonb_build_object('last_http_queue',v_queue),updated_at=now()
  where singleton=true;

  return jsonb_build_object('complete',true,'version',925,'queued',true,'request_id',v_request,'http_queue_before',v_queue);
end
$$;

select cron.alter_job(386, command := 'select automation.master_requirement_native_tick_v925(2);');

do $$
declare j bigint;
begin
  select jobid into j from cron.job where jobname='bridgepoint-live-verification-sync-v925' order by jobid limit 1;
  if j is null then
    perform cron.schedule('bridgepoint-live-verification-sync-v925','*/10 * * * *','select automation.dispatch_live_verification_sync_v925();');
  else
    perform cron.alter_job(j,schedule:='*/10 * * * *',command:='select automation.dispatch_live_verification_sync_v925();',active:=true);
  end if;
end $$;

commit;
