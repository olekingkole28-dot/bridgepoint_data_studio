-- BridgePoint Intelligence V936
-- Connect owner portable STATE export requests to an authenticated local agent.
-- COUNTRY/WORLD remain unclaimed until their aggregation workers are implemented.

alter table automation.portable_export_requests_v900
  add column if not exists node_id uuid,
  add column if not exists claimed_at timestamptz,
  add column if not exists lease_expires_at timestamptz,
  add column if not exists attempt integer not null default 0,
  add column if not exists max_attempts integer not null default 3,
  add column if not exists available_at timestamptz not null default now();

create index if not exists portable_export_requests_v900_runnable_idx
  on automation.portable_export_requests_v900(status,available_at,requested_at)
  where status in ('QUEUED','RETRY');
create index if not exists portable_export_requests_v900_lease_idx
  on automation.portable_export_requests_v900(lease_expires_at)
  where status='RUNNING';

create or replace function public.bridgepoint_internal_portable_export_claim_v936(p_node_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '8s'
as $$
declare
  v_job automation.portable_export_requests_v900%rowtype;
  v_caps jsonb;
begin
  if auth.role()<>'service_role' then raise exception 'service_role required'; end if;

  select capabilities into v_caps
  from automation.local_reasoning_nodes_v584
  where node_id=p_node_id and enabled and status<>'REVOKED';
  if not found then raise exception 'node unavailable'; end if;
  if coalesce((v_caps->>'portable_export_authority')::boolean,false) is not true then
    return jsonb_build_object('ok',true,'version',936,'job',null,'reason','PORTABLE_EXPORT_AUTHORITY_NOT_ADVERTISED');
  end if;

  with pick as (
    select request_id
    from automation.portable_export_requests_v900
    where status in('QUEUED','RETRY')
      and available_at<=now()
      and attempt<max_attempts
      and scope_kind='STATE'
      and scope_key ~ '^[A-Z]{2}$'
    order by requested_at
    for update skip locked
    limit 1
  )
  update automation.portable_export_requests_v900 j
  set status='RUNNING',node_id=p_node_id,claimed_at=now(),lease_expires_at=now()+interval '8 hours',
      attempt=j.attempt+1,error_text=null,updated_at=now()
  from pick
  where j.request_id=pick.request_id
  returning j.* into v_job;

  if v_job.request_id is null then
    return jsonb_build_object('ok',true,'version',936,'job',null);
  end if;

  return jsonb_build_object('ok',true,'version',936,'job',jsonb_build_object(
    'request_id',v_job.request_id,
    'scope_kind',v_job.scope_kind,
    'scope_key',v_job.scope_key,
    'requested_format',v_job.requested_format,
    'attempt',v_job.attempt,
    'lease_expires_at',v_job.lease_expires_at
  ));
end
$$;
revoke all on function public.bridgepoint_internal_portable_export_claim_v936(uuid) from public,anon,authenticated;
grant execute on function public.bridgepoint_internal_portable_export_claim_v936(uuid) to service_role;

create or replace function public.bridgepoint_internal_portable_export_complete_v936(
  p_node_id uuid,p_request_id uuid,p_result jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '8s'
as $$
declare v_scope text; v_key text;
begin
  if auth.role()<>'service_role' then raise exception 'service_role required'; end if;
  update automation.portable_export_requests_v900
  set status='SUCCEEDED',result=coalesce(p_result,'{}'::jsonb),completed_at=now(),lease_expires_at=null,error_text=null,updated_at=now()
  where request_id=p_request_id and node_id=p_node_id and status='RUNNING'
  returning scope_kind,scope_key into v_scope,v_key;
  if v_scope is null then raise exception 'portable export is not claimable by node'; end if;
  return jsonb_build_object('ok',true,'version',936,'request_id',p_request_id,'scope_kind',v_scope,'scope_key',v_key,'status','SUCCEEDED','completed_at',now());
end
$$;
revoke all on function public.bridgepoint_internal_portable_export_complete_v936(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_internal_portable_export_complete_v936(uuid,uuid,jsonb) to service_role;

create or replace function public.bridgepoint_internal_portable_export_fail_v936(
  p_node_id uuid,p_request_id uuid,p_error text,p_result jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','automation'
set statement_timeout to '8s'
as $$
declare v_attempt int; v_max int; v_status text;
begin
  if auth.role()<>'service_role' then raise exception 'service_role required'; end if;
  select attempt,max_attempts into v_attempt,v_max
  from automation.portable_export_requests_v900
  where request_id=p_request_id and node_id=p_node_id and status='RUNNING'
  for update;
  if not found then raise exception 'portable export is not claimable by node'; end if;
  v_status:=case when v_attempt>=v_max then 'FAILED' else 'RETRY' end;
  update automation.portable_export_requests_v900
  set status=v_status,error_text=left(coalesce(p_error,'PORTABLE_EXPORT_FAILED'),1800),
      result=coalesce(p_result,'{}'::jsonb),lease_expires_at=null,
      available_at=case when v_status='RETRY' then now()+interval '15 minutes' else available_at end,
      completed_at=case when v_status='FAILED' then now() else null end,updated_at=now()
  where request_id=p_request_id;
  return jsonb_build_object('ok',true,'version',936,'request_id',p_request_id,'status',v_status,'attempt',v_attempt,'max_attempts',v_max);
end
$$;
revoke all on function public.bridgepoint_internal_portable_export_fail_v936(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_internal_portable_export_fail_v936(uuid,uuid,text,jsonb) to service_role;

create or replace function automation.portable_export_scheduler_v936()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation'
set statement_timeout to '8s'
as $$
declare v_recovered int:=0; v_failed int:=0;
begin
  update automation.portable_export_requests_v900
  set status=case when attempt>=max_attempts then 'FAILED' else 'RETRY' end,
      error_text=coalesce(error_text,'LEASE_EXPIRED'),
      available_at=case when attempt>=max_attempts then available_at else now()+interval '15 minutes' end,
      lease_expires_at=null,
      completed_at=case when attempt>=max_attempts then now() else completed_at end,
      updated_at=now()
  where status='RUNNING' and lease_expires_at<now();
  get diagnostics v_recovered=row_count;
  select count(*) into v_failed from automation.portable_export_requests_v900 where status='FAILED';
  return jsonb_build_object('complete',true,'version',936,'leases_recovered',v_recovered,
    'queue',jsonb_build_object(
      'queued',(select count(*) from automation.portable_export_requests_v900 where status in('QUEUED','RETRY')),
      'running',(select count(*) from automation.portable_export_requests_v900 where status='RUNNING'),
      'succeeded',(select count(*) from automation.portable_export_requests_v900 where status='SUCCEEDED'),
      'failed',v_failed));
end
$$;

do $$
declare j bigint;
begin
  select jobid into j from cron.job where jobname='bridgepoint-portable-export-v936' order by jobid limit 1;
  if j is null then
    perform cron.schedule('bridgepoint-portable-export-v936','*/5 * * * *','select automation.portable_export_scheduler_v936();');
  else
    perform cron.alter_job(j,schedule:='*/5 * * * *',command:='select automation.portable_export_scheduler_v936();',active:=true);
  end if;
end $$;
