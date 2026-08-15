-- BridgePoint V85
-- Official Connecticut HIC registration trust layer. This source verifies
-- registration status; it is deliberately excluded from property lead scoring.

create table if not exists staging.ct_hic_registry_v85(
  credential_key text primary key,
  registrant_name text,
  registrant_type text,
  business_name text,
  dba_name text,
  full_credential_code text not null,
  credential_subcategory text,
  credential text,
  status text,
  status_reason text,
  active boolean not null default false,
  issue_date date,
  effective_date date,
  expiration_date date,
  city text,
  state_code text,
  postal_code text,
  record_refreshed_on timestamptz,
  payload_hash text not null,
  first_seen_at timestamptz not null default now(),
  processed_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ct_hic_registry_v85_name_idx
  on staging.ct_hic_registry_v85 using gin(to_tsvector('simple',coalesce(registrant_name,'')||' '||coalesce(business_name,'')||' '||coalesce(dba_name,'')));
create index if not exists ct_hic_registry_v85_city_status_idx
  on staging.ct_hic_registry_v85(lower(city),active,expiration_date desc);
create index if not exists ct_hic_registry_v85_refreshed_idx
  on staging.ct_hic_registry_v85(record_refreshed_on desc);
alter table staging.ct_hic_registry_v85 enable row level security;
revoke all on staging.ct_hic_registry_v85 from public,anon,authenticated;

insert into automation.source_registry(
  source_code,source_name,provider,source_category,geographic_scope,state_code,
  source_url,access_method,refresh_frequency,refresh_interval_minutes,enabled,
  priority,default_confidence,health_status,last_watermark,next_scheduled_check_at,
  configuration,metadata)
values(
  'CT_DCP_HIC_REGISTRY','Connecticut Home Improvement Contractor Registry',
  'Connecticut Department of Consumer Protection','CONTRACTOR_TRUST','STATEWIDE','CT',
  'https://data.ct.gov/resource/5r9m-qgni.json','SOCRATA_API','DAILY',1440,true,
  75,.98,'NOT_RUN',jsonb_build_object('refreshed_on','1970-01-01T00:00:00.000','credential','')::text,now(),
  jsonb_build_object('dataset_id','5r9m-qgni','task_token',encode(gen_random_bytes(32),'hex'),
    'edge_function','bridgepoint-ct-hic-registry-refresh-v85','locked_until',null,'has_more',true,
    'raw_payload_retained',false,'scoring_enabled',false),
  jsonb_build_object('family','CONTRACTOR_TRUST','property_specific',false,'scoring_enabled',false,
    'description','Official active and inactive home-improvement contractor registrations; verification and trust only',
    'flutter_icon','verified_user','limitation','Registration does not prove skill, insurance, workmanship, or suitability.')
)
on conflict(source_code) do update set
  source_name=excluded.source_name,provider=excluded.provider,source_url=excluded.source_url,
  enabled=true,refresh_interval_minutes=excluded.refresh_interval_minutes,
  next_scheduled_check_at=coalesce(automation.source_registry.next_scheduled_check_at,now()),
  configuration=automation.source_registry.configuration||(excluded.configuration-'task_token')||
    case when automation.source_registry.configuration?'task_token' then '{}'::jsonb
         else jsonb_build_object('task_token',excluded.configuration->>'task_token') end,
  metadata=automation.source_registry.metadata||excluded.metadata,updated_at=now();

create or replace function public.bridgepoint_stage_ct_hic_registry_v85(p_records jsonb)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','staging' set statement_timeout='120s' as $$
declare v_inserted bigint:=0;v_updated bigint:=0;
begin
  if jsonb_typeof(p_records) is distinct from 'array' then raise exception 'p_records must be a JSON array'; end if;
  if jsonb_array_length(p_records)>1000 then raise exception 'Maximum batch is 1000'; end if;
  with parsed as(
    select
      coalesce(nullif(btrim(r->>'name'),''),nullif(btrim(r->>'registrantname'),'')) registrant_name,
      coalesce(nullif(btrim(r->>'type'),''),nullif(btrim(r->>'registranttype'),'')) registrant_type,
      coalesce(nullif(btrim(r->>'businessname'),''),nullif(btrim(r->>'business_name'),'')) business_name,
      coalesce(nullif(btrim(r->>'dba'),''),nullif(btrim(r->>'dbaname'),'')) dba_name,
      upper(btrim(coalesce(r->>'fullcredentialcode',r->>'full_credential_code',r->>'credentialcode',''))) full_credential_code,
      nullif(btrim(r->>'credentialsubcategory'),'') credential_subcategory,
      nullif(btrim(r->>'credential'),'') credential,
      upper(nullif(btrim(r->>'status'),'')) status,
      nullif(btrim(r->>'statusreason'),'') status_reason,
      lower(coalesce(r->>'active','')) in('1','true','yes','active') active,
      nullif(left(coalesce(r->>'issuedate',''),10),'')::date issue_date,
      nullif(left(coalesce(r->>'effectivedate',''),10),'')::date effective_date,
      nullif(left(coalesce(r->>'expirationdate',''),10),'')::date expiration_date,
      nullif(btrim(r->>'city'),'') city,
      upper(nullif(btrim(r->>'state'),'')) state_code,
      nullif(btrim(r->>'zip'),'') postal_code,
      nullif(r->>'recordrefreshedon','')::timestamptz record_refreshed_on,
      encode(extensions.digest(r::text,'sha256'),'hex') payload_hash
    from jsonb_array_elements(p_records) r
  ),valid as(
    select *,lower(full_credential_code) credential_key from parsed where full_credential_code<>''
  ),upserted as(
    insert into staging.ct_hic_registry_v85 as t(
      credential_key,registrant_name,registrant_type,business_name,dba_name,
      full_credential_code,credential_subcategory,credential,status,status_reason,
      active,issue_date,effective_date,expiration_date,city,state_code,postal_code,
      record_refreshed_on,payload_hash)
    select credential_key,registrant_name,registrant_type,business_name,dba_name,
      full_credential_code,credential_subcategory,credential,status,status_reason,
      active,issue_date,effective_date,expiration_date,city,state_code,postal_code,
      record_refreshed_on,payload_hash from valid
    on conflict(credential_key) do update set
      registrant_name=excluded.registrant_name,registrant_type=excluded.registrant_type,
      business_name=excluded.business_name,dba_name=excluded.dba_name,
      credential_subcategory=excluded.credential_subcategory,credential=excluded.credential,
      status=excluded.status,status_reason=excluded.status_reason,active=excluded.active,
      issue_date=excluded.issue_date,effective_date=excluded.effective_date,
      expiration_date=excluded.expiration_date,city=excluded.city,state_code=excluded.state_code,
      postal_code=excluded.postal_code,record_refreshed_on=excluded.record_refreshed_on,
      payload_hash=excluded.payload_hash,processed_at=now(),updated_at=now()
    where t.payload_hash is distinct from excluded.payload_hash returning xmax=0 inserted
  ) select count(*) filter(where inserted),count(*) filter(where not inserted) into v_inserted,v_updated from upserted;
  return jsonb_build_object('complete',true,'submitted',jsonb_array_length(p_records),'inserted',v_inserted,'updated',v_updated);
end $$;

create or replace function public.bridgepoint_ct_hic_refresh_state_v85()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation' as $$
declare s automation.source_registry%rowtype;lock_until timestamptz;due boolean;
begin
  select * into s from automation.source_registry where source_code='CT_DCP_HIC_REGISTRY' for update;
  if not found then raise exception 'HIC registry source missing'; end if;
  begin lock_until:=nullif(s.configuration->>'locked_until','')::timestamptz;exception when others then lock_until:=null;end;
  due:=s.enabled and (lock_until is null or lock_until<=now()) and
    (coalesce((s.configuration->>'has_more')::boolean,false) or s.next_scheduled_check_at is null or s.next_scheduled_check_at<=now());
  if due then
    lock_until:=now()+interval '12 minutes';
    update automation.source_registry set last_checked_at=now(),updated_at=now(),
      configuration=configuration||jsonb_build_object('locked_until',lock_until,'locked_at',now())
    where source_id=s.source_id;
  end if;
  return jsonb_build_object('source_code',s.source_code,'enabled',s.enabled,'due',due,
    'task_token',s.configuration->>'task_token','last_watermark',s.last_watermark,
    'next_scheduled_check_at',s.next_scheduled_check_at,'locked_until',lock_until);
end $$;

create or replace function public.bridgepoint_ct_hic_refresh_commit_v85(
  p_watermark text,p_found bigint,p_inserted bigint,p_updated bigint,p_has_more boolean,p_error text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation' as $$
declare failed boolean:=p_error is not null;next_check timestamptz;
begin
  next_check:=case when failed then now()+interval '15 minutes' when coalesce(p_has_more,false) then now() else now()+interval '1 day' end;
  update automation.source_registry set last_checked_at=now(),
    last_successful_import_at=case when failed then last_successful_import_at else now() end,
    last_watermark=case when failed then last_watermark else coalesce(nullif(p_watermark,''),last_watermark) end,
    next_scheduled_check_at=next_check,
    total_records_ingested=total_records_ingested+case when failed then 0 else greatest(coalesce(p_inserted,0),0) end,
    last_run_records_found=greatest(coalesce(p_found,0),0),
    last_run_records_inserted=greatest(coalesce(p_inserted,0),0),
    last_run_records_updated=greatest(coalesce(p_updated,0),0),
    consecutive_failures=case when failed then consecutive_failures+1 else 0 end,
    last_error=p_error,health_status=case when failed then 'DEGRADED' else 'HEALTHY' end,
    parser_version='BRIDGEPOINT_CT_HIC_V85',
    configuration=configuration||jsonb_build_object('locked_until',null,'has_more',coalesce(p_has_more,false),'last_commit_at',now()),
    updated_at=now() where source_code='CT_DCP_HIC_REGISTRY';
  return jsonb_build_object('complete',not coalesce(p_has_more,false) and not failed,
    'status',case when failed then 'failed' when p_has_more then 'continuing' else 'completed' end,'next_check_at',next_check);
end $$;

create or replace function automation.ct_hic_scheduler_tick_v85()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation','net' as $$
declare s record;request_id bigint;
begin
  select configuration->>'task_token' token into s from automation.source_registry
  where source_code='CT_DCP_HIC_REGISTRY' and enabled and
    (next_scheduled_check_at is null or next_scheduled_check_at<=now() or coalesce((configuration->>'has_more')::boolean,false));
  if not found then return jsonb_build_object('complete',true,'requests_created',0); end if;
  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-ct-hic-registry-refresh-v85',
    headers:=jsonb_build_object('Content-Type','application/json'),
    body:=jsonb_build_object('task_token',s.token,'page_size',1000,'max_pages',20),
    timeout_milliseconds:=300000) into request_id;
  return jsonb_build_object('complete',true,'requests_created',1,'request_id',request_id);
end $$;

create or replace function public.bridgepoint_search_ct_contractors_v85(p_query text default null,p_city text default null,p_limit integer default 25)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','staging' as $$
declare uid uuid:=api.require_user();v_query text:=nullif(btrim(coalesce(p_query,'')),'');v_city text:=nullif(btrim(coalesce(p_city,'')),'');v_rows jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(x) order by x.active desc,x.expiration_date desc nulls last,x.display_name),'[]'::jsonb) into v_rows from(
    select full_credential_code,coalesce(nullif(business_name,''),nullif(dba_name,''),registrant_name,'Unnamed registrant') display_name,
      registrant_name,business_name,dba_name,credential,status,status_reason,active,
      issue_date,effective_date,expiration_date,city,state_code,postal_code,record_refreshed_on
    from staging.ct_hic_registry_v85
    where (v_city is null or lower(city)=lower(v_city)) and
      (v_query is null or full_credential_code ilike '%'||v_query||'%' or registrant_name ilike '%'||v_query||'%'
        or business_name ilike '%'||v_query||'%' or dba_name ilike '%'||v_query||'%')
    order by active desc,expiration_date desc nulls last limit least(greatest(coalesce(p_limit,25),1),100)
  ) x;
  return jsonb_build_object('complete',true,'source','Connecticut Department of Consumer Protection',
    'dataset_id','5r9m-qgni','generated_at',now(),'results',v_rows,
    'limitation','Registration status does not prove skill, insurance, workmanship, complaint history, or suitability. Verify the current official record and insurance before hiring or assigning work.');
end $$;

revoke all on function public.bridgepoint_stage_ct_hic_registry_v85(jsonb) from public,anon,authenticated;
revoke all on function public.bridgepoint_ct_hic_refresh_state_v85() from public,anon,authenticated;
revoke all on function public.bridgepoint_ct_hic_refresh_commit_v85(text,bigint,bigint,bigint,boolean,text) from public,anon,authenticated;
revoke all on function automation.ct_hic_scheduler_tick_v85() from public,anon,authenticated;
revoke execute on function public.bridgepoint_search_ct_contractors_v85(text,text,integer) from public,anon;
grant execute on function public.bridgepoint_stage_ct_hic_registry_v85(jsonb) to service_role;
grant execute on function public.bridgepoint_ct_hic_refresh_state_v85() to service_role;
grant execute on function public.bridgepoint_ct_hic_refresh_commit_v85(text,bigint,bigint,bigint,boolean,text) to service_role;
grant execute on function public.bridgepoint_search_ct_contractors_v85(text,text,integer) to authenticated,service_role;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-ct-hic-registry-v85') then
    perform cron.unschedule('bridgepoint-ct-hic-registry-v85');
  end if;
  perform cron.schedule('bridgepoint-ct-hic-registry-v85','23 * * * *','select automation.ct_hic_scheduler_tick_v85();');
end $$;

comment on table staging.ct_hic_registry_v85 is
  'Official CT DCP HIC registration roster. Trust/verification only; never a property-opportunity score input.';
