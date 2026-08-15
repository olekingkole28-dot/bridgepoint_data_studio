-- BridgePoint V68
-- Official Connecticut permit context, municipal-source readiness, and strict ranking.

create schema if not exists staging;

create table if not exists staging.ct_decd_permit_context_v68 (
  source_record_key text primary key,
  report_year integer not null check (report_year between 1900 and 2200),
  municipality text not null,
  municipality_key text not null,
  county text,
  total_units integer not null default 0,
  one_unit integer not null default 0,
  two_unit integer not null default 0,
  three_four_units integer not null default 0,
  five_plus_units integer not null default 0,
  demolitions integer not null default 0,
  data_source text,
  source_updated_at timestamptz,
  source_row_id text,
  payload_hash text not null,
  first_seen_at timestamptz not null default now(),
  processed_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ct_decd_permit_context_v68_municipality_year_idx
  on staging.ct_decd_permit_context_v68 (municipality_key, report_year desc);

alter table staging.ct_decd_permit_context_v68 enable row level security;
revoke all on staging.ct_decd_permit_context_v68 from anon, authenticated;

insert into automation.source_registry (
  source_code, source_name, provider, source_category, geographic_scope,
  state_code, source_url, access_method, refresh_frequency,
  refresh_interval_minutes, enabled, priority, default_confidence,
  health_status, last_watermark, next_scheduled_check_at, configuration, metadata
)
values (
  'CT_DECD_PERMIT_CONTEXT',
  'Connecticut DECD Annual Construction and Permit Context',
  'Connecticut Department of Economic and Community Development',
  'MUNICIPAL_PERMIT_CONTEXT', 'STATEWIDE', 'CT',
  'https://data.ct.gov/resource/wmfh-25km.json', 'SOCRATA_API', 'WEEKLY',
  10080, true, 45, 0.95, 'NOT_RUN',
  jsonb_build_object('updated_at','1970-01-01T00:00:00.000Z','id','')::text,
  now(),
  jsonb_build_object(
    'dataset_id','wmfh-25km',
    'task_token',encode(gen_random_bytes(32),'hex'),
    'edge_function','bridgepoint-ct-permit-context-refresh-v68',
    'locked_until',null,
    'has_more',true,
    'lean_retention',true,
    'raw_payload_retained',false
  ),
  jsonb_build_object(
    'family','PERMIT_CONTEXT',
    'granularity','MUNICIPALITY_YEAR',
    'property_specific',false,
    'description','Official municipal construction permits and demolitions; contextual evidence only',
    'flutter_icon','construction'
  )
)
on conflict (source_code) do update set
  source_name=excluded.source_name, provider=excluded.provider,
  source_category=excluded.source_category, source_url=excluded.source_url,
  access_method=excluded.access_method, refresh_frequency=excluded.refresh_frequency,
  refresh_interval_minutes=excluded.refresh_interval_minutes, enabled=true,
  priority=excluded.priority, default_confidence=excluded.default_confidence,
  next_scheduled_check_at=coalesce(automation.source_registry.next_scheduled_check_at,now()),
  configuration=automation.source_registry.configuration ||
    (excluded.configuration - 'task_token') ||
    case when automation.source_registry.configuration ? 'task_token' then '{}'::jsonb
         else jsonb_build_object('task_token',excluded.configuration->>'task_token') end,
  metadata=automation.source_registry.metadata || excluded.metadata,
  updated_at=now();

-- Registered but deliberately not activated: the public dataset is stale.
insert into automation.source_registry (
  source_code, source_name, provider, source_category, geographic_scope,
  state_code, source_url, access_method, refresh_frequency,
  refresh_interval_minutes, enabled, priority, default_confidence,
  health_status, last_error, configuration, metadata
)
values (
  'CT_MONTHLY_BUILDING_PERMIT_TRENDS',
  'Connecticut Monthly Building Permit Trends',
  'Connecticut Department of Economic and Community Development',
  'STATEWIDE_PERMIT_TREND', 'STATEWIDE', 'CT',
  'https://data.ct.gov/resource/5vjm-esav.json', 'SOCRATA_API', 'MONTHLY',
  43200, false, 90, 0.70, 'DISABLED',
  'Official feed currently ends in 2021; disabled to prevent stale intelligence.',
  jsonb_build_object('dataset_id','5vjm-esav','activation_status','STALE_SOURCE'),
  jsonb_build_object('property_specific',false,'flutter_icon','timeline')
)
on conflict (source_code) do update set enabled=false, health_status='DISABLED',
  last_error=excluded.last_error, configuration=excluded.configuration,
  metadata=automation.source_registry.metadata || excluded.metadata, updated_at=now();

-- SeeClickFix public API terms do not permit silent commercial bulk reuse.
insert into automation.source_registry (
  source_code, source_name, provider, source_category, geographic_scope,
  state_code, source_url, access_method, refresh_frequency,
  refresh_interval_minutes, enabled, priority, default_confidence,
  health_status, last_error, configuration, metadata
)
values (
  'CT_MUNICIPAL_311_SEECLICKFIX',
  'Connecticut Municipal 311 / SeeClickFix', 'SeeClickFix and participating municipalities',
  'MUNICIPAL_311', 'MUNICIPAL', 'CT',
  'https://seeclickfix.com/api/v2/', 'REST_API', 'HOURLY', 60,
  false, 35, 0.80, 'DISABLED',
  'Commercial bulk ingestion is disabled until written data-use permission is recorded.',
  jsonb_build_object('activation_status','COMMERCIAL_PERMISSION_REQUIRED','adapter_ready',true),
  jsonb_build_object('property_specific',true,'flutter_icon','report_problem','commercial_ingestion',false)
)
on conflict (source_code) do update set enabled=false, health_status='DISABLED',
  last_error=excluded.last_error, configuration=automation.source_registry.configuration || excluded.configuration,
  metadata=automation.source_registry.metadata || excluded.metadata, updated_at=now();

create or replace function public.bridgepoint_stage_ct_decd_permit_context_v68(p_records jsonb)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','staging' set statement_timeout='120s' as $$
declare v_inserted bigint := 0; v_updated bigint := 0;
begin
  if jsonb_typeof(p_records) is distinct from 'array' then
    raise exception 'p_records must be a JSON array';
  end if;
  if jsonb_array_length(p_records)>500 then raise exception 'Maximum batch is 500'; end if;

  with parsed as (
    select
      coalesce(nullif(r->>'year','')::integer,0) report_year,
      btrim(coalesce(r->>'places','')) municipality,
      lower(regexp_replace(btrim(coalesce(r->>'places','')),'[^a-zA-Z0-9]+','','g')) municipality_key,
      nullif(btrim(r->>'county'),'') county,
      coalesce(nullif(r->>'total_units','')::numeric,0)::integer total_units,
      coalesce(nullif(r->>'_1_unit','')::numeric,0)::integer one_unit,
      coalesce(nullif(r->>'_2_unit','')::numeric,0)::integer two_unit,
      coalesce(nullif(r->>'_3_and_4_units','')::numeric,0)::integer three_four_units,
      coalesce(nullif(r->>'_5_or_more_units','')::numeric,0)::integer five_plus_units,
      coalesce(nullif(r->>'demolitions','')::numeric,0)::integer demolitions,
      nullif(btrim(r->>'data_source'),'') data_source,
      nullif(r->>':updated_at','')::timestamptz source_updated_at,
      nullif(r->>':id','') source_row_id,
      encode(extensions.digest((r - ':created_at')::text,'sha256'),'hex') payload_hash
    from jsonb_array_elements(p_records) r
  ), valid as (
    select *, report_year::text || '|' || municipality_key source_record_key
    from parsed where report_year between 1990 and 2200 and municipality_key<>''
  ), upserted as (
    insert into staging.ct_decd_permit_context_v68 as t (
      source_record_key,report_year,municipality,municipality_key,county,total_units,
      one_unit,two_unit,three_four_units,five_plus_units,demolitions,data_source,
      source_updated_at,source_row_id,payload_hash
    ) select source_record_key,report_year,municipality,municipality_key,county,total_units,
      one_unit,two_unit,three_four_units,five_plus_units,demolitions,data_source,
      source_updated_at,source_row_id,payload_hash from valid
    on conflict (source_record_key) do update set
      municipality=excluded.municipality,county=excluded.county,total_units=excluded.total_units,
      one_unit=excluded.one_unit,two_unit=excluded.two_unit,
      three_four_units=excluded.three_four_units,five_plus_units=excluded.five_plus_units,
      demolitions=excluded.demolitions,data_source=excluded.data_source,
      source_updated_at=excluded.source_updated_at,source_row_id=excluded.source_row_id,
      payload_hash=excluded.payload_hash,processed_at=now(),updated_at=now()
    where t.payload_hash is distinct from excluded.payload_hash
    returning (xmax=0) inserted
  ) select count(*) filter(where inserted),count(*) filter(where not inserted)
    into v_inserted,v_updated from upserted;
  return jsonb_build_object('complete',true,'submitted',jsonb_array_length(p_records),
    'inserted',v_inserted,'updated',v_updated);
end $$;

revoke all on function public.bridgepoint_stage_ct_decd_permit_context_v68(jsonb) from public,anon,authenticated;
grant execute on function public.bridgepoint_stage_ct_decd_permit_context_v68(jsonb) to service_role;

create or replace function public.bridgepoint_ct_permit_refresh_state_v68()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation' as $$
declare s automation.source_registry%rowtype; lock_until timestamptz; due boolean;
begin
  select * into s from automation.source_registry where source_code='CT_DECD_PERMIT_CONTEXT' for update;
  if not found then raise exception 'Permit context source missing'; end if;
  begin lock_until := nullif(s.configuration->>'locked_until','')::timestamptz; exception when others then lock_until:=null; end;
  due := s.enabled and (lock_until is null or lock_until<=now()) and
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

revoke all on function public.bridgepoint_ct_permit_refresh_state_v68() from public,anon,authenticated;
grant execute on function public.bridgepoint_ct_permit_refresh_state_v68() to service_role;

create or replace function public.bridgepoint_ct_permit_refresh_commit_v68(
  p_watermark text,p_found bigint,p_staged bigint,p_inserted bigint,p_updated bigint,
  p_has_more boolean,p_error text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation' as $$
declare failed boolean:=p_error is not null; next_check timestamptz;
begin
  next_check:=case when failed then now()+interval '15 minutes'
                   when coalesce(p_has_more,false) then now()
                   else now()+interval '7 days' end;
  update automation.source_registry set
    last_checked_at=now(),
    last_successful_import_at=case when failed then last_successful_import_at else now() end,
    last_watermark=case when failed then last_watermark else coalesce(nullif(p_watermark,''),last_watermark) end,
    next_scheduled_check_at=next_check,
    total_records_ingested=total_records_ingested+case when failed then 0 else greatest(coalesce(p_inserted,0),0) end,
    last_run_records_found=greatest(coalesce(p_found,0),0),
    last_run_records_inserted=greatest(coalesce(p_inserted,0),0),
    last_run_records_updated=greatest(coalesce(p_updated,0),0),
    consecutive_failures=case when failed then consecutive_failures+1 else 0 end,
    last_error=p_error,health_status=case when failed then 'DEGRADED' else 'HEALTHY' end,
    parser_version='BRIDGEPOINT_PERMIT_CONTEXT_V68',
    configuration=configuration||jsonb_build_object('locked_until',null,'has_more',coalesce(p_has_more,false),'last_commit_at',now()),
    updated_at=now()
  where source_code='CT_DECD_PERMIT_CONTEXT';
  return jsonb_build_object('complete',not coalesce(p_has_more,false) and not failed,
    'status',case when failed then 'failed' when p_has_more then 'continuing' else 'completed' end,
    'next_check_at',next_check);
end $$;

revoke all on function public.bridgepoint_ct_permit_refresh_commit_v68(text,bigint,bigint,bigint,bigint,boolean,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_ct_permit_refresh_commit_v68(text,bigint,bigint,bigint,bigint,boolean,text) to service_role;

create or replace function automation.ct_permit_scheduler_tick_v68()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation','net' as $$
declare s record; request_id bigint;
begin
  select source_code,configuration->>'task_token' token into s
  from automation.source_registry where source_code='CT_DECD_PERMIT_CONTEXT' and enabled
    and (next_scheduled_check_at is null or next_scheduled_check_at<=now() or coalesce((configuration->>'has_more')::boolean,false));
  if not found then return jsonb_build_object('complete',true,'requests_created',0); end if;
  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-ct-permit-context-refresh-v68',
    headers:=jsonb_build_object('Content-Type','application/json'),
    body:=jsonb_build_object('task_token',s.token,'page_size',500,'max_pages',10),
    timeout_milliseconds:=300000) into request_id;
  return jsonb_build_object('complete',true,'requests_created',1,'request_id',request_id);
end $$;

revoke all on function automation.ct_permit_scheduler_tick_v68() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-ct-permit-context-v68') then
    perform cron.unschedule('bridgepoint-ct-permit-context-v68');
  end if;
  perform cron.schedule('bridgepoint-ct-permit-context-v68','17 * * * *',
    'select automation.ct_permit_scheduler_tick_v68();');
end $$;

create or replace function public.bridgepoint_flutter_permit_context_v68(p_municipality text default null)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','staging','api' as $$
declare uid uuid; rows jsonb;
begin
  uid:=api.require_user();
  select coalesce(jsonb_agg(to_jsonb(x) order by x.report_year desc,x.municipality),'[]'::jsonb) into rows
  from (
    select report_year,municipality,county,total_units,one_unit,two_unit,
      three_four_units,five_plus_units,demolitions,source_updated_at,updated_at
    from staging.ct_decd_permit_context_v68
    where lower(municipality)<>'connecticut'
      and (p_municipality is null or municipality_key=lower(regexp_replace(btrim(p_municipality),'[^a-zA-Z0-9]+','','g')))
    order by report_year desc,municipality limit 1000
  ) x;
  return jsonb_build_object('complete',true,'granularity','MUNICIPALITY_YEAR',
    'property_specific',false,'generated_at',now(),'rows',rows);
end $$;

grant execute on function public.bridgepoint_flutter_permit_context_v68(text) to authenticated;
revoke execute on function public.bridgepoint_flutter_permit_context_v68(text) from anon;

-- Strict, evidence-aware ranking without destroying historical raw scores.
create materialized view if not exists opportunity_engine.strict_ranked_opportunities_v68 as
with eligible as (
  select o.*,
    (o.opportunity_score*0.20 + o.urgency_score*0.25 + o.relevance_score*0.20 +
     o.confidence_score*100*0.15 + least(o.source_count,6)/6.0*10 +
     least(o.pattern_count,8)/8.0*10 +
     greatest(0,10-least(10,extract(epoch from (now()-o.latest_evidence_at))/86400.0/30.0)))::numeric quality_value
  from opportunity_engine.opportunities_v38 o
  where o.opportunity_status='active' and o.confidence_score>=0.80
    and o.source_count>=2 and o.pattern_count>=2 and o.matched_pattern_count>=1
    and o.latest_evidence_at>=now()-interval '730 days'
), ranked as (
  select e.*,
    percent_rank() over(partition by e.vertical_key order by e.quality_value,e.latest_evidence_at,e.opportunity_id) vertical_percentile,
    row_number() over(partition by e.vertical_key order by e.quality_value desc,e.latest_evidence_at desc,e.opportunity_id) vertical_rank,
    row_number() over(order by e.quality_value desc,e.latest_evidence_at desc,e.opportunity_id) global_rank
  from eligible e
)
select r.*,round((40+59.9*r.vertical_percentile)::numeric,2) strict_score,
  case when r.vertical_percentile>=.995 then 'critical'
       when r.vertical_percentile>=.98 then 'high'
       when r.vertical_percentile>=.90 then 'medium' else 'watch' end strict_tier
from ranked r;

create unique index if not exists strict_ranked_opportunities_v68_id_idx
  on opportunity_engine.strict_ranked_opportunities_v68(opportunity_id);
create index if not exists strict_ranked_opportunities_v68_lookup_idx
  on opportunity_engine.strict_ranked_opportunities_v68(vertical_key,strict_score desc,vertical_rank);

create or replace function automation.refresh_strict_rankings_v68()
returns jsonb language plpgsql security definer set search_path='pg_catalog','public','opportunity_engine' as $$
begin
  refresh materialized view concurrently opportunity_engine.strict_ranked_opportunities_v68;
  return jsonb_build_object('complete',true,'refreshed_at',now());
end $$;
revoke all on function automation.refresh_strict_rankings_v68() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-strict-ranking-v68') then
    perform cron.unschedule('bridgepoint-strict-ranking-v68');
  end if;
  perform cron.schedule('bridgepoint-strict-ranking-v68','*/5 * * * *',
    'select automation.refresh_strict_rankings_v68();');
end $$;
