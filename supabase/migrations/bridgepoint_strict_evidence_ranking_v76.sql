-- BridgePoint V76
-- Absolute, evidence-depth ranking with customer-safe explanations.
-- The raw V38 opportunity record is preserved; customer surfaces read this strict layer.

create materialized view if not exists opportunity_engine.strict_ranked_opportunities_v76 as
with eligible as (
  select o.*,
    (
      least(greatest(coalesce(o.opportunity_score,0),0),100)*0.12 +
      least(greatest(coalesce(o.urgency_score,0),0),100)*0.12 +
      least(greatest(coalesce(o.relevance_score,0),0),100)*0.12 +
      least(greatest(coalesce(o.confidence_score,0),0),1)*100*0.10 +
      least(coalesce(o.source_count,0),7)/7.0*14 +
      least(coalesce(o.signal_count,0),40)/40.0*16 +
      least(coalesce(o.matched_pattern_count,0),5)/5.0*10 +
      least(coalesce(o.pattern_count,0),10)/10.0*5 +
      greatest(0,9-least(9,
        extract(epoch from (now()-o.latest_evidence_at))/86400.0/60.0))
    )::numeric quality_value
  from opportunity_engine.opportunities_v38 o
  where o.opportunity_status='active'
    and o.confidence_score>=0.85
    and o.source_count>=3
    and o.signal_count>=5
    and o.pattern_count>=2
    and o.matched_pattern_count>=1
    and (o.source_count>=4 or o.signal_count>=10)
    and o.latest_evidence_at>=now()-interval '730 days'
), ranked as (
  select e.*,
    percent_rank() over(
      partition by e.vertical_key
      order by e.quality_value,e.latest_evidence_at,e.opportunity_id
    ) vertical_percentile,
    row_number() over(
      partition by e.vertical_key
      order by e.quality_value desc,e.latest_evidence_at desc,e.opportunity_id
    ) vertical_rank,
    row_number() over(
      order by e.quality_value desc,e.latest_evidence_at desc,e.opportunity_id
    ) global_rank
  from eligible e
)
select r.*,round(r.quality_value,2) strict_score,
  case when r.quality_value>=85 then 'critical'
       when r.quality_value>=82 then 'high'
       when r.quality_value>=78 then 'medium'
       else 'watch' end strict_tier
from ranked r;

create unique index if not exists strict_ranked_opportunities_v76_id_idx
  on opportunity_engine.strict_ranked_opportunities_v76(opportunity_id);
create index if not exists strict_ranked_opportunities_v76_lookup_idx
  on opportunity_engine.strict_ranked_opportunities_v76(
    vertical_key,strict_score desc,vertical_rank);
create index if not exists strict_ranked_opportunities_v76_global_idx
  on opportunity_engine.strict_ranked_opportunities_v76(
    strict_score desc,quality_value desc,latest_evidence_at desc);

revoke all on opportunity_engine.strict_ranked_opportunities_v76
  from public,anon,authenticated;

create or replace function automation.refresh_strict_rankings_v76()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','opportunity_engine' as $$
begin
  refresh materialized view concurrently
    opportunity_engine.strict_ranked_opportunities_v76;
  return jsonb_build_object(
    'complete',true,'engine_version',76,'ranking_mode','ABSOLUTE_EVIDENCE_DEPTH',
    'refreshed_at',now());
end $$;
revoke all on function automation.refresh_strict_rankings_v76()
  from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-strict-ranking-v68') then
    perform cron.unschedule('bridgepoint-strict-ranking-v68');
  end if;
  if exists(select 1 from cron.job where jobname='bridgepoint-strict-ranking-v76') then
    perform cron.unschedule('bridgepoint-strict-ranking-v76');
  end if;
  perform cron.schedule(
    'bridgepoint-strict-ranking-v76','*/5 * * * *',
    'select automation.refresh_strict_rankings_v76();');
end $$;

create or replace function public.bridgepoint_flutter_opportunities_v57(
  p_model_key text default 'all', p_limit integer default 50,
  p_offset integer default 0, p_priority text default null,
  p_stage text default null)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','opportunity_engine','core'
set statement_timeout='25s' as $$
declare
  v_model_key text:=lower(btrim(coalesce(p_model_key,'all')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),500);
  v_offset integer:=greatest(coalesce(p_offset,0),0);
  v_priority text:=nullif(lower(btrim(coalesce(p_priority,''))),'');
  v_stage text:=nullif(lower(btrim(coalesce(p_stage,''))),'');
  v_total bigint:=0; v_rows jsonb:='[]'::jsonb;
begin
  select count(*) into v_total
  from opportunity_engine.strict_ranked_opportunities_v76 o
  where o.strict_score>=78
    and public.bridgepoint_flutter_v38_matches(
      v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
    and (v_priority is null or o.strict_tier=v_priority)
    and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.rank_value),'[]'::jsonb)
    into v_rows
  from (
    select o.opportunity_id,o.property_id,o.vertical_key model_key,
      o.opportunity_name model_name,
      case when v_model_key='all' then o.global_rank else o.vertical_rank end rank_value,
      coalesce(a.full_address,
        concat_ws(', ',p.municipality,p.postal_code,p.state_code)) full_address,
      p.parcel_number,p.municipality,p.county,p.postal_code,p.latitude,p.longitude,
      p.property_type,p.property_subtype,p.land_use_description,p.year_built,
      p.assessed_total_value,o.strict_score score,o.strict_tier priority,
      round(o.confidence_score*100,2) confidence_score,
      coalesce(o.signal_count,0) event_count,
      coalesce(o.signal_count,0) distinct_signal_count,
      o.opportunity_name top_signal_type,o.opportunity_name title,
      format(
        '%s is supported by %s property-linked evidence signals, %s corroborating compound patterns, and %s independent source families. Evidence confidence is %s%%. Its current intelligence stage is %s, and its absolute evidence score is %s/100.',
        o.opportunity_name,coalesce(o.signal_count,0),
        coalesce(o.matched_pattern_count,0),coalesce(o.source_count,0),
        round(o.confidence_score*100,0),
        initcap(replace(lower(coalesce(o.intelligence_stage,'active')),'_',' ')),
        round(o.strict_score,1)) explanation,
      o.intelligence_stage stage,o.first_detected_at detected_at,
      o.updated_at last_detected_at,o.recommended_action,o.pattern_count,
      o.matched_pattern_count,o.source_count,o.signal_count,
      o.opportunity_family,o.opportunity_key,o.vertical_key,o.urgency_score,
      o.relevance_score,o.property_intelligence_score,
      round(o.quality_value,2) evidence_quality_score,o.vertical_percentile,
      jsonb_build_object(
        'base_opportunity',round(o.opportunity_score,1),
        'urgency',round(o.urgency_score,1),
        'relevance',round(o.relevance_score,1),
        'confidence_percent',round(o.confidence_score*100,1),
        'evidence_signals',o.signal_count,
        'corroborating_patterns',o.matched_pattern_count,
        'independent_sources',o.source_count,
        'freshness_at',o.latest_evidence_at) score_components
    from opportunity_engine.strict_ranked_opportunities_v76 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=78
      and public.bridgepoint_flutter_v38_matches(
        v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (v_priority is null or o.strict_tier=v_priority)
      and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
    order by o.strict_score desc,o.quality_value desc,
      o.latest_evidence_at desc,o.opportunity_id
    limit v_limit offset v_offset
  ) x;
  return jsonb_build_object(
    'complete',true,'generated_at',now(),'engine_version',76,
    'ranking_mode','ABSOLUTE_EVIDENCE_DEPTH','minimum_score',78,
    'score_definition','Absolute evidence quality, not a percentile',
    'eligibility','85%+ confidence, 3+ sources, 5+ signals, 2+ patterns, and corroboration',
    'requested_model_key',v_model_key,'total_results',v_total,
    'returned_results',jsonb_array_length(v_rows),'limit',v_limit,'offset',v_offset,
    'has_more',v_offset+jsonb_array_length(v_rows)<v_total,
    'opportunities',v_rows);
end $$;

create or replace function public.bridgepoint_flutter_intelligence_map_v57(
  p_model_key text default 'all',p_min_lat double precision default null,
  p_max_lat double precision default null,p_min_lng double precision default null,
  p_max_lng double precision default null,p_min_score numeric default null,
  p_limit integer default 500)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','opportunity_engine','core'
set statement_timeout='25s' as $$
declare v_limit integer:=least(greatest(coalesce(p_limit,500),1),1000);
  v_rows jsonb:='[]'::jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(x) order by x.opportunity_score desc),'[]'::jsonb)
    into v_rows
  from (
    select 'STRICT_EVIDENCE_V76'::text intelligence_type,o.opportunity_id,
      o.property_id,o.opportunity_name title,
      format(
        '%s is supported by %s property-linked evidence signals, %s corroborating compound patterns, and %s independent source families. Evidence confidence is %s%%. Current stage: %s. Absolute evidence score: %s/100.',
        o.opportunity_name,coalesce(o.signal_count,0),
        coalesce(o.matched_pattern_count,0),coalesce(o.source_count,0),
        round(o.confidence_score*100,0),
        initcap(replace(lower(coalesce(o.intelligence_stage,'active')),'_',' ')),
        round(o.strict_score,1)) explanation,
      o.intelligence_stage stage,o.strict_tier priority,
      o.strict_score opportunity_score,
      round(o.confidence_score*100,2) opportunity_confidence_percent,
      o.first_detected_at detected_at,o.updated_at last_detected_at,
      o.vertical_key model_key,o.opportunity_name model_name,p.latitude,p.longitude,
      p.parcel_number,p.municipality,p.county,p.postal_code,p.property_type,
      p.property_subtype,p.land_use_description,p.year_built,p.assessed_total_value,
      a.full_address,o.strict_score final_score,
      o.property_intelligence_score overall_score,o.strict_score rank_value,
      o.strict_tier score_status,o.confidence_score*100 confidence_score,
      o.signal_count event_count,o.signal_count distinct_signal_count,
      o.source_count verified_event_count,o.source_count,o.pattern_count,
      o.matched_pattern_count,o.opportunity_name top_signal_type,
      o.recommended_action,o.quality_value evidence_quality_score
    from opportunity_engine.strict_ranked_opportunities_v76 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=greatest(coalesce(p_min_score,78),78)
      and p.latitude is not null and p.longitude is not null
      and public.bridgepoint_flutter_v38_matches(
        p_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (p_min_lat is null or p.latitude>=p_min_lat)
      and (p_max_lat is null or p.latitude<=p_max_lat)
      and (p_min_lng is null or p.longitude>=p_min_lng)
      and (p_max_lng is null or p.longitude<=p_max_lng)
    order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc
    limit v_limit+1
  ) x;
  return jsonb_build_object(
    'complete',true,'generated_at',now(),'engine_version',76,
    'ranking_mode','ABSOLUTE_EVIDENCE_DEPTH','minimum_score',78,
    'requested_model_key',lower(coalesce(p_model_key,'all')),'limit',v_limit,
    'returned_points',least(jsonb_array_length(v_rows),v_limit),
    'has_more',jsonb_array_length(v_rows)>v_limit,
    'point_type','STRICT_EVIDENCE_V76',
    'points',(select coalesce(jsonb_agg(value),'[]'::jsonb)
      from (select value from jsonb_array_elements(v_rows) limit v_limit) q));
end $$;

create or replace function customer_workspace.refresh_notifications_v74(p_user_id uuid)
returns void language plpgsql security definer
set search_path='pg_catalog','customer_workspace','opportunity_engine','core','automation','intelligence' as $$
declare day_key text:=to_char(current_date,'YYYY-MM-DD');
  new_signals bigint:=0; refreshed_sources bigint:=0; strict_changes bigint:=0;
  due_item record; top_item record;
begin
  insert into customer_workspace.notification_preferences_v74(user_id)
  values(p_user_id) on conflict(user_id) do nothing;
  select count(*) into new_signals from intelligence.signals
    where created_at>=now()-interval '24 hours';
  select count(*) into refreshed_sources from automation.source_registry
    where last_successful_import_at>=now()-interval '24 hours';
  select count(*) into strict_changes
    from opportunity_engine.strict_ranked_opportunities_v76
    where strict_score>=78 and updated_at>=now()-interval '24 hours';
  insert into customer_workspace.notifications_v74(
    user_id,notification_type,title,message,action_page,dedupe_key)
  select p_user_id,'DAILY_BRIEF','Your Daily Brief is ready',
    format('%s new evidence signals, %s refreshed sources, and %s strict opportunity updates in the last 24 hours.',
      new_signals,refreshed_sources,strict_changes),'daily_brief','daily-brief:'||day_key
  where (select daily_brief and in_app_enabled
    from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
  on conflict(user_id,dedupe_key) do update set message=excluded.message;
  select o.opportunity_id,o.opportunity_name,o.strict_score,a.full_address
    into top_item
  from opportunity_engine.strict_ranked_opportunities_v76 o
  join core.properties p on p.property_id=o.property_id
  left join core.addresses a on a.address_id=p.primary_address_id
  where o.strict_score>=78
  order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc limit 1;
  if top_item.opportunity_id is not null then
    insert into customer_workspace.notifications_v74(
      user_id,notification_type,title,message,action_page,action_id,dedupe_key)
    select p_user_id,'CRITICAL_OPPORTUNITY','Top opportunity to review',
      format('%s at %s has an absolute evidence score of %s/100.',
        top_item.opportunity_name,
        coalesce(top_item.full_address,'a Connecticut property'),
        round(top_item.strict_score,1)),
      'opportunities',top_item.opportunity_id,'top-opportunity:'||day_key
    where (select critical_opportunities and in_app_enabled
      from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
    on conflict(user_id,dedupe_key) do update
      set message=excluded.message,action_id=excluded.action_id;
  end if;
  for due_item in
    select saved_opportunity_id,title,next_action_at
    from customer_workspace.saved_opportunities_v70
    where user_id=p_user_id and lead_stage not in('WON','LOST')
      and next_action_at is not null and next_action_at<=now()+interval '24 hours'
    order by next_action_at limit 20
  loop
    insert into customer_workspace.notifications_v74(
      user_id,notification_type,title,message,action_page,action_id,dedupe_key)
    select p_user_id,'FOLLOW_UP','Follow-up due: '||due_item.title,
      case when due_item.next_action_at<now() then 'This saved opportunity is overdue.'
           else 'This saved opportunity is due within 24 hours.' end,
      'my_work',due_item.saved_opportunity_id,
      'follow-up:'||due_item.saved_opportunity_id::text||':'||day_key
    where (select saved_follow_ups and in_app_enabled
      from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
    on conflict(user_id,dedupe_key) do nothing;
  end loop;
end $$;

create or replace function public.bridgepoint_daily_brief_v74()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','accounts','auth','customer_workspace','opportunity_engine','core','automation','intelligence' as $$
declare uid uuid:=api.require_user(); display text; new_signals bigint:=0;
  refreshed_sources bigint:=0; strict_changes bigint:=0; due_count bigint:=0;
  top_rows jsonb:='[]'::jsonb; unread bigint:=0;
begin
  select coalesce(nullif(btrim(p.display_name),''),
    nullif(btrim(u.raw_user_meta_data->>'display_name'),''),
    initcap(split_part(u.email,'@',1)),'there') into display
  from auth.users u left join customer_workspace.profiles_v70 p on p.user_id=u.id
  where u.id=uid;
  select count(*) into new_signals from intelligence.signals
    where created_at>=now()-interval '24 hours';
  select count(*) into refreshed_sources from automation.source_registry
    where last_successful_import_at>=now()-interval '24 hours';
  select count(*) into strict_changes
    from opportunity_engine.strict_ranked_opportunities_v76
    where strict_score>=78 and updated_at>=now()-interval '24 hours';
  select count(*) into due_count from customer_workspace.saved_opportunities_v70
    where user_id=uid and lead_stage not in('WON','LOST')
      and next_action_at is not null and next_action_at<=now()+interval '24 hours';
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc),'[]'::jsonb)
    into top_rows from (
    select o.opportunity_id,o.property_id,o.opportunity_name title,
      o.strict_score score,round(o.confidence_score*100,0) confidence,
      o.strict_tier priority,
      format('%s property-linked signals, %s corroborating patterns, and %s independent sources support this ranking.',
        o.signal_count,o.matched_pattern_count,o.source_count) reason,
      o.recommended_action,o.vertical_key,
      coalesce(a.full_address,
        concat_ws(', ',p.municipality,p.state_code)) full_address
    from opportunity_engine.strict_ranked_opportunities_v76 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=78
    order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc
    limit 5
  ) x;
  perform customer_workspace.refresh_notifications_v74(uid);
  select count(*) into unread from customer_workspace.notifications_v74
    where user_id=uid and read_at is null;
  return jsonb_build_object(
    'complete',true,'engine_version',76,'generated_at',now(),
    'display_name',display,'is_owner',accounts.is_platform_admin(),
    'overnight',jsonb_build_object(
      'new_signals',new_signals,'refreshed_sources',refreshed_sources,
      'strict_opportunity_updates',strict_changes,'follow_ups_due',due_count),
    'top_opportunities',top_rows,'unread_notifications',unread,
    'summary',format('%s new evidence signals and %s evidence-qualified opportunity updates were processed in the last 24 hours.',
      new_signals,strict_changes));
end $$;

revoke all on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text)
  from public,anon;
revoke all on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer)
  from public,anon;
grant execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text)
  to authenticated,service_role;
grant execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer)
  to authenticated,service_role;

comment on materialized view opportunity_engine.strict_ranked_opportunities_v76 is
  'V76 absolute evidence-depth ranking. Direct matched_signal_count is not used because current opportunity definitions use property-linked evidence signals plus compound pattern corroboration.';
