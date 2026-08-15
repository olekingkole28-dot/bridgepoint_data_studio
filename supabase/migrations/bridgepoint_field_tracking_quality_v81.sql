-- BridgePoint V81
-- Consent-based company field tracking, owner/co-owner controls, rotating field
-- notes, and a finite opportunity leaderboard with explicit negative scoring.

alter table product.organization_seat_entitlements_v80
  add column if not exists location_tracking_enabled boolean not null default true;

create table if not exists product.organization_preferences_v81(
  organization_id uuid primary key references core.organizations(organization_id) on delete cascade,
  field_note_enabled boolean not null default true,
  location_retention_days integer not null default 7 check(location_retention_days between 1 and 30),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists product.field_notes_v81(
  field_note_id uuid primary key default gen_random_uuid(),
  note_category text not null check(note_category in('SAFETY','ENCOURAGEMENT','DOCUMENTATION','CUSTOMER_CARE','ETHICS')),
  title text not null,
  message text not null,
  active boolean not null default true,
  display_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into product.field_notes_v81(note_category,title,message,display_order)
values
 ('SAFETY','Look up before you step out','Park legally, watch traffic, check the weather, and keep your attention on the property only after you are safely stopped.',10),
 ('CUSTOMER_CARE','Lead with help','A good conversation begins with listening. Understand the owner’s concern before explaining what you can offer.',20),
 ('DOCUMENTATION','Write it while it is fresh','A short factual note after every visit protects the customer, your teammate, and tomorrow’s follow-up.',30),
 ('ETHICS','Evidence is a starting point','BridgePoint identifies reasons to investigate. Verify conditions respectfully and never present a score as proof of damage or need.',40),
 ('ENCOURAGEMENT','Quality beats volume','One well-researched, well-timed conversation is worth more than a list of names nobody understands.',50),
 ('SAFETY','Respect the boundary','Stay on public walkways or invited areas. Never enter a roof, yard, structure, or restricted area without clear permission.',60),
 ('CUSTOMER_CARE','Make the next step easy','Leave every customer knowing what happens next, who owns the action, and when they should expect an update.',70),
 ('DOCUMENTATION','Photograph with permission','Ask first, avoid private details, capture only what supports the work, and label the location and time accurately.',80),
 ('ETHICS','No pressure required','Clear evidence, honest limits, and a useful explanation create trust better than urgency that the facts do not support.',90),
 ('ENCOURAGEMENT','Small follow-ups compound','A promised call made on time can be the most valuable action in today’s route.',100),
 ('SAFETY','Weather changes the plan','Radar is context, not permission to take risks. Pause field work for lightning, dangerous wind, flooding, or poor visibility.',110),
 ('CUSTOMER_CARE','Use plain language','Explain what changed, why it may matter, and what you still do not know. Customers should never need your software vocabulary.',120)
on conflict do nothing;

create table if not exists customer_workspace.field_shifts_v81(
  field_shift_id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references core.organizations(organization_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  shift_label text,
  status text not null default 'ACTIVE' check(status in('ACTIVE','ENDED')),
  consent_version text not null default 'FIELD_LOCATION_V1',
  consented_at timestamptz not null default now(),
  started_at timestamptz not null default now(),
  last_location_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists field_shifts_v81_one_active_user_idx
  on customer_workspace.field_shifts_v81(user_id) where status='ACTIVE';
create index if not exists field_shifts_v81_team_active_idx
  on customer_workspace.field_shifts_v81(organization_id,status,last_location_at desc);

create table if not exists customer_workspace.field_locations_v81(
  field_location_id bigint generated always as identity primary key,
  field_shift_id uuid not null references customer_workspace.field_shifts_v81(field_shift_id) on delete cascade,
  organization_id uuid not null references core.organizations(organization_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  latitude double precision not null check(latitude between -90 and 90),
  longitude double precision not null check(longitude between -180 and 180),
  accuracy_m double precision check(accuracy_m is null or accuracy_m between 0 and 500),
  heading_degrees double precision check(heading_degrees is null or heading_degrees between 0 and 360),
  speed_mps double precision check(speed_mps is null or speed_mps between 0 and 100),
  captured_at timestamptz not null,
  received_at timestamptz not null default now()
);
create index if not exists field_locations_v81_shift_time_idx
  on customer_workspace.field_locations_v81(field_shift_id,captured_at desc);
create index if not exists field_locations_v81_team_time_idx
  on customer_workspace.field_locations_v81(organization_id,captured_at desc);

alter table product.organization_preferences_v81 enable row level security;
alter table product.field_notes_v81 enable row level security;
alter table customer_workspace.field_shifts_v81 enable row level security;
alter table customer_workspace.field_locations_v81 enable row level security;
revoke all on product.organization_preferences_v81 from public,anon,authenticated;
revoke all on product.field_notes_v81 from public,anon,authenticated;
revoke all on customer_workspace.field_shifts_v81 from public,anon,authenticated;
revoke all on customer_workspace.field_locations_v81 from public,anon,authenticated;

create or replace function public.bridgepoint_field_note_of_day_v81()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); org uuid; enabled boolean:=true; note_row record; note_count integer:=0; note_offset integer:=0;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is not null then
    select p.field_note_enabled into enabled from product.organization_preferences_v81 p where p.organization_id=org;
    enabled:=coalesce(enabled,true);
  end if;
  if not enabled then return jsonb_build_object('complete',true,'enabled',false); end if;
  select count(*) into note_count from product.field_notes_v81 where active;
  if note_count=0 then return jsonb_build_object('complete',true,'enabled',false); end if;
  note_offset:=mod(extract(doy from current_date)::integer-1,note_count);
  select * into note_row from product.field_notes_v81 where active order by display_order,field_note_id offset note_offset limit 1;
  return jsonb_build_object('complete',true,'enabled',true,'date',current_date,
    'category',note_row.note_category,'title',note_row.title,'message',note_row.message);
end $$;

create or replace function public.bridgepoint_set_field_note_enabled_v81(p_enabled boolean)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product' as $$
declare uid uuid:=api.require_user(); org uuid; role text;
begin
  select organization_id,member_role into org,role from product.organization_members_v80 where user_id=uid and active limit 1;
  if org is null or role not in('OWNER','CO_OWNER') then raise exception 'Owner or co-owner access required'; end if;
  insert into product.organization_preferences_v81(organization_id,field_note_enabled,updated_by)
  values(org,coalesce(p_enabled,true),uid)
  on conflict(organization_id) do update set field_note_enabled=excluded.field_note_enabled,updated_by=uid,updated_at=now();
  return jsonb_build_object('complete',true,'field_note_enabled',coalesce(p_enabled,true));
end $$;

create or replace function public.bridgepoint_start_field_shift_v81(p_shift_label text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','customer_workspace' as $$
declare uid uuid:=api.require_user(); org uuid; shift_id uuid; tracking_allowed boolean:=false;
begin
  select m.organization_id,coalesce(e.location_tracking_enabled,false) into org,tracking_allowed
  from product.organization_members_v80 m
  join product.organization_seat_entitlements_v80 e on e.organization_id=m.organization_id
  where m.user_id=uid and m.active and e.status in('TRIALING','ACTIVE') limit 1;
  if org is null or not tracking_allowed then raise exception 'Live Field Assist is available on an active BridgePoint Company plan'; end if;
  select field_shift_id into shift_id from customer_workspace.field_shifts_v81 where user_id=uid and status='ACTIVE' limit 1;
  if shift_id is null then
    insert into customer_workspace.field_shifts_v81(organization_id,user_id,shift_label)
    values(org,uid,nullif(btrim(coalesce(p_shift_label,'')),'')) returning field_shift_id into shift_id;
  end if;
  return jsonb_build_object('complete',true,'field_shift_id',shift_id,'status','ACTIVE',
    'privacy','Location is shared only while this field shift is active and retained for seven days.');
end $$;

create or replace function public.bridgepoint_record_field_location_v81(
  p_field_shift_id uuid,p_latitude double precision,p_longitude double precision,
  p_accuracy_m double precision default null,p_heading_degrees double precision default null,
  p_speed_mps double precision default null,p_captured_at timestamptz default now())
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); shift_row customer_workspace.field_shifts_v81%rowtype; accepted boolean:=true;
begin
  select * into shift_row from customer_workspace.field_shifts_v81
  where field_shift_id=p_field_shift_id and user_id=uid and status='ACTIVE' for update;
  if not found then raise exception 'Active field shift not found'; end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'Invalid location'; end if;
  if p_captured_at<now()-interval '10 minutes' or p_captured_at>now()+interval '2 minutes' then raise exception 'Location timestamp is outside the accepted window'; end if;
  if p_accuracy_m is not null and (p_accuracy_m<0 or p_accuracy_m>500) then raise exception 'Location accuracy is too low'; end if;
  if exists(select 1 from customer_workspace.field_locations_v81 where field_shift_id=p_field_shift_id and received_at>now()-interval '8 seconds') then
    accepted:=false;
  else
    insert into customer_workspace.field_locations_v81(
      field_shift_id,organization_id,user_id,latitude,longitude,accuracy_m,heading_degrees,speed_mps,captured_at)
    values(p_field_shift_id,shift_row.organization_id,uid,p_latitude,p_longitude,p_accuracy_m,
      case when p_heading_degrees is not null and p_heading_degrees between 0 and 360 then p_heading_degrees end,
      case when p_speed_mps is not null and p_speed_mps between 0 and 100 then p_speed_mps end,p_captured_at);
    update customer_workspace.field_shifts_v81 set last_location_at=p_captured_at,updated_at=now()
      where field_shift_id=p_field_shift_id;
  end if;
  return jsonb_build_object('complete',true,'accepted',accepted,'field_shift_id',p_field_shift_id,'received_at',now());
end $$;

create or replace function public.bridgepoint_stop_field_shift_v81(p_field_shift_id uuid)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user();
begin
  update customer_workspace.field_shifts_v81 set status='ENDED',ended_at=now(),updated_at=now()
  where field_shift_id=p_field_shift_id and user_id=uid and status='ACTIVE';
  if not found then raise exception 'Active field shift not found'; end if;
  return jsonb_build_object('complete',true,'status','ENDED','field_shift_id',p_field_shift_id);
end $$;

create or replace function public.bridgepoint_field_team_v81()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product','customer_workspace','auth' as $$
declare uid uuid:=api.require_user(); org uuid; v_role text; eligible boolean:=false; team_rows jsonb:='[]'::jsonb; own_shift uuid;
begin
  select m.organization_id,m.member_role,
    coalesce(e.location_tracking_enabled,false) and e.status in('TRIALING','ACTIVE')
  into org,v_role,eligible from product.organization_members_v80 m
  left join product.organization_seat_entitlements_v80 e on e.organization_id=m.organization_id
  where m.user_id=uid and m.active limit 1;
  if org is null then return jsonb_build_object('complete',true,'eligible',false,'company_plan_required',true,'team',team_rows); end if;
  select field_shift_id into own_shift from customer_workspace.field_shifts_v81 where user_id=uid and status='ACTIVE' limit 1;
  if eligible then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name),'[]'::jsonb) into team_rows from (
      select m.user_id,coalesce(p.display_name,u.raw_user_meta_data->>'display_name',split_part(u.email,'@',1)) display_name,
        m.member_role,s.field_shift_id,s.started_at,s.last_location_at,
        l.latitude,l.longitude,l.accuracy_m,l.heading_degrees,l.speed_mps,l.captured_at,
        case when l.captured_at>=now()-interval '90 seconds' then 'LIVE'
             when l.captured_at>=now()-interval '15 minutes' then 'RECENT' else 'STALE' end location_status
      from product.organization_members_v80 m
      join auth.users u on u.id=m.user_id
      left join product.user_profiles p on p.user_id=m.user_id
      left join customer_workspace.field_shifts_v81 s on s.user_id=m.user_id and s.organization_id=org and s.status='ACTIVE'
      left join lateral(
        select fl.latitude,fl.longitude,fl.accuracy_m,fl.heading_degrees,fl.speed_mps,fl.captured_at
        from customer_workspace.field_locations_v81 fl where fl.field_shift_id=s.field_shift_id
        order by fl.captured_at desc limit 1
      ) l on true
      where m.organization_id=org and m.active and s.field_shift_id is not null
        and (v_role in('OWNER','CO_OWNER','MANAGER') or m.user_id=uid)
        and (l.captured_at is null or l.captured_at>=now()-interval '15 minutes')
    ) x;
  end if;
  return jsonb_build_object('complete',true,'eligible',eligible,'company_plan_required',not eligible,
    'current_role',v_role,'can_view_team',v_role in('OWNER','CO_OWNER','MANAGER'),
    'own_active_shift_id',own_shift,'retention_days',7,'team',team_rows,
    'privacy','Only active field shifts are visible. Team locations disappear from the live view after 15 minutes and are deleted after seven days.');
end $$;

create or replace function automation.purge_field_locations_v81()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','customer_workspace' as $$
declare removed bigint:=0;
begin
  delete from customer_workspace.field_locations_v81 where received_at<now()-interval '7 days';
  get diagnostics removed=row_count;
  update customer_workspace.field_shifts_v81 set status='ENDED',ended_at=coalesce(ended_at,now()),updated_at=now()
    where status='ACTIVE' and coalesce(last_location_at,started_at)<now()-interval '12 hours';
  return jsonb_build_object('complete',true,'locations_removed',removed,'finished_at',now());
end $$;
revoke all on function automation.purge_field_locations_v81() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-field-location-retention-v81') then
    perform cron.unschedule('bridgepoint-field-location-retention-v81');
  end if;
  perform cron.schedule('bridgepoint-field-location-retention-v81','17 4 * * *','select automation.purge_field_locations_v81();');
end $$;

-- Explicit penalties prevent pattern volume from hiding missing direct matches.
create materialized view opportunity_engine.quality_ranked_opportunities_v81 as
with adjusted as (
  select o.*,
    (case when coalesce(o.matched_signal_count,0)=0 then 6 else 0 end)::numeric direct_match_penalty,
    (case when coalesce(o.matched_pattern_count,0)=0 then 8 else 0 end)::numeric corroboration_penalty,
    (case when coalesce(o.source_count,0)<4 then (4-coalesce(o.source_count,0)) else 0 end)::numeric source_penalty,
    (case when o.latest_evidence_at<now()-interval '365 days' then 12
          when o.latest_evidence_at<now()-interval '180 days' then 8
          when o.latest_evidence_at<now()-interval '90 days' then 4
          when o.latest_evidence_at<now()-interval '30 days' then 2 else 0 end)::numeric freshness_penalty,
    (case when coalesce(o.confidence_score,0)<.90 then 3 else 0 end)::numeric confidence_penalty
  from opportunity_engine.strict_ranked_opportunities_v76 o
), scored as (
  select a.*,
    round(a.direct_match_penalty+a.corroboration_penalty+a.source_penalty+a.freshness_penalty+a.confidence_penalty,2) negative_score,
    round(greatest(0,a.strict_score-a.direct_match_penalty-a.corroboration_penalty-a.source_penalty-a.freshness_penalty-a.confidence_penalty),2) quality_score
  from adjusted a
), ranked as (
  select s.*,
    row_number() over(partition by s.property_id order by s.quality_score desc,s.latest_evidence_at desc,s.opportunity_id) property_choice,
    row_number() over(partition by s.vertical_key order by s.quality_score desc,s.latest_evidence_at desc,s.opportunity_id) vertical_rank_v81,
    row_number() over(order by s.quality_score desc,s.latest_evidence_at desc,s.opportunity_id) global_rank_v81
  from scored s where s.quality_score>=76
)
select r.*,
  case when r.quality_score>=80 then 'elite' when r.quality_score>=78 then 'high' else 'qualified' end quality_tier,
  jsonb_build_object(
    'missing_direct_match',r.direct_match_penalty,'missing_corroboration',r.corroboration_penalty,
    'source_diversity',r.source_penalty,'stale_evidence',r.freshness_penalty,'lower_confidence',r.confidence_penalty
  ) negative_breakdown
from ranked r
where r.vertical_rank_v81<=500;

create unique index quality_ranked_opportunities_v81_id_idx on opportunity_engine.quality_ranked_opportunities_v81(opportunity_id);
create index quality_ranked_opportunities_v81_global_idx on opportunity_engine.quality_ranked_opportunities_v81(quality_score desc,property_choice);
create index quality_ranked_opportunities_v81_vertical_idx on opportunity_engine.quality_ranked_opportunities_v81(vertical_key,quality_score desc);
revoke all on opportunity_engine.quality_ranked_opportunities_v81 from public,anon,authenticated;

create or replace function automation.refresh_quality_rankings_v81()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','opportunity_engine' as $$
begin
  refresh materialized view concurrently opportunity_engine.quality_ranked_opportunities_v81;
  return jsonb_build_object('complete',true,'engine_version',81,'ranking_mode','FINITE_NEGATIVE_SCORING','refreshed_at',now());
end $$;
revoke all on function automation.refresh_quality_rankings_v81() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-quality-ranking-v81') then
    perform cron.unschedule('bridgepoint-quality-ranking-v81');
  end if;
  perform cron.schedule('bridgepoint-quality-ranking-v81','*/5 * * * *','select automation.refresh_quality_rankings_v81();');
end $$;

create or replace function public.bridgepoint_flutter_opportunities_v57(
  p_model_key text default 'all',p_limit integer default 50,p_offset integer default 0,
  p_priority text default null,p_stage text default null)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','opportunity_engine','core','customer_workspace','product'
set statement_timeout='25s' as $$
declare uid uuid:=api.require_user(); org uuid; v_model_key text:=lower(btrim(coalesce(p_model_key,'all')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),500); v_offset integer:=greatest(coalesce(p_offset,0),0);
  v_priority text:=nullif(lower(btrim(coalesce(p_priority,''))),''); v_stage text:=nullif(lower(btrim(coalesce(p_stage,''))),'');
  v_total bigint:=0; v_rows jsonb:='[]'::jsonb;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select count(*) into v_total from opportunity_engine.quality_ranked_opportunities_v81 o
  where (v_model_key<>'all' or o.property_choice=1)
    and public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
    and (v_priority is null or o.quality_tier=v_priority)
    and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
    and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
      where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
        and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)));
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc,x.rank_value),'[]'::jsonb) into v_rows from (
    select o.opportunity_id,o.property_id,o.vertical_key model_key,o.opportunity_name model_name,
      case when v_model_key='all' then o.global_rank_v81 else o.vertical_rank_v81 end rank_value,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.postal_code,p.state_code)) full_address,
      p.parcel_number,p.municipality,p.county,p.postal_code,p.latitude,p.longitude,p.property_type,p.property_subtype,
      p.land_use_description,p.year_built,p.assessed_total_value,o.quality_score score,o.quality_tier priority,
      round(o.confidence_score*100,2) confidence_score,o.signal_count event_count,o.signal_count distinct_signal_count,
      o.opportunity_name top_signal_type,o.opportunity_name title,
      format('%s ranks at %s/100 after subtracting %s negative points. It has %s direct model matches, %s property-linked signals, %s corroborating patterns, and %s source families. Patterns add context but cannot hide missing direct evidence.',
        o.opportunity_name,o.quality_score,o.negative_score,o.matched_signal_count,o.signal_count,o.matched_pattern_count,o.source_count) explanation,
      o.intelligence_stage stage,o.first_detected_at detected_at,o.updated_at last_detected_at,o.recommended_action,
      o.pattern_count,o.matched_pattern_count,o.matched_signal_count,o.source_count,o.signal_count,o.opportunity_family,o.opportunity_key,
      o.vertical_key,o.urgency_score,o.relevance_score,o.property_intelligence_score,o.strict_score raw_positive_score,
      o.negative_score,o.negative_breakdown,o.latest_evidence_at,
      jsonb_build_object('positive_score',o.strict_score,'negative_adjustment',o.negative_score,'final_score',o.quality_score,
        'direct_matches',o.matched_signal_count,'signals',o.signal_count,'corroborating_patterns',o.matched_pattern_count,
        'independent_sources',o.source_count,'freshness_at',o.latest_evidence_at,'penalties',o.negative_breakdown) score_components
    from opportunity_engine.quality_ranked_opportunities_v81 o
    join core.properties p on p.property_id=o.property_id left join core.addresses a on a.address_id=p.primary_address_id
    where (v_model_key<>'all' or o.property_choice=1)
      and public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (v_priority is null or o.quality_tier=v_priority)
      and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
      and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
        where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
          and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
    order by o.quality_score desc,case when v_model_key='all' then o.global_rank_v81 else o.vertical_rank_v81 end
    limit v_limit offset v_offset
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',81,
    'ranking_mode','FINITE_NEGATIVE_SCORING','minimum_score',76,
    'score_definition','Positive evidence minus explicit quality penalties; one best opportunity per property in All Intelligence.',
    'requested_model_key',v_model_key,'total_results',v_total,'returned_results',jsonb_array_length(v_rows),
    'limit',v_limit,'offset',v_offset,'has_more',v_offset+jsonb_array_length(v_rows)<v_total,'opportunities',v_rows);
end $$;

create or replace function public.bridgepoint_flutter_intelligence_map_v57(
  p_model_key text default 'all',p_min_lat double precision default null,p_max_lat double precision default null,
  p_min_lng double precision default null,p_max_lng double precision default null,p_min_score numeric default null,p_limit integer default 500)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','opportunity_engine','core','customer_workspace','product'
set statement_timeout='25s' as $$
declare uid uuid:=api.require_user(); org uuid; v_limit integer:=least(greatest(coalesce(p_limit,500),1),1000); v_rows jsonb:='[]'::jsonb;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.opportunity_score desc),'[]'::jsonb) into v_rows from (
    select 'QUALITY_OPPORTUNITY_V81'::text intelligence_type,o.opportunity_id,o.property_id,o.opportunity_name title,
      format('%s/100 after %s negative points. %s direct matches, %s signals, %s corroborating patterns, %s sources.',
        o.quality_score,o.negative_score,o.matched_signal_count,o.signal_count,o.matched_pattern_count,o.source_count) explanation,
      o.intelligence_stage stage,o.quality_tier priority,o.quality_score opportunity_score,
      round(o.confidence_score*100,2) opportunity_confidence_percent,o.first_detected_at detected_at,o.updated_at last_detected_at,
      o.vertical_key model_key,o.opportunity_name model_name,p.latitude,p.longitude,p.parcel_number,p.municipality,p.county,p.postal_code,
      p.property_type,p.property_subtype,p.land_use_description,p.year_built,p.assessed_total_value,a.full_address,
      o.quality_score final_score,o.property_intelligence_score overall_score,o.quality_score rank_value,o.quality_tier score_status,
      o.confidence_score*100 confidence_score,o.signal_count event_count,o.signal_count distinct_signal_count,o.source_count verified_event_count,
      o.source_count,o.pattern_count,o.matched_pattern_count,o.matched_signal_count,o.opportunity_name top_signal_type,o.recommended_action,
      o.strict_score raw_positive_score,o.negative_score,o.negative_breakdown,o.latest_evidence_at
    from opportunity_engine.quality_ranked_opportunities_v81 o
    join core.properties p on p.property_id=o.property_id left join core.addresses a on a.address_id=p.primary_address_id
    where (lower(coalesce(p_model_key,'all'))<>'all' or o.property_choice=1)
      and o.quality_score>=greatest(coalesce(p_min_score,76),76)
      and p.latitude is not null and p.longitude is not null
      and public.bridgepoint_flutter_v38_matches(p_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (p_min_lat is null or p.latitude>=p_min_lat) and (p_max_lat is null or p.latitude<=p_max_lat)
      and (p_min_lng is null or p.longitude>=p_min_lng) and (p_max_lng is null or p.longitude<=p_max_lng)
      and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
        where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
          and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
    order by o.quality_score desc,o.latest_evidence_at desc limit v_limit
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',81,'ranking_mode','FINITE_NEGATIVE_SCORING',
    'minimum_score',76,'requested_model_key',lower(coalesce(p_model_key,'all')),'limit',v_limit,
    'returned_points',jsonb_array_length(v_rows),'has_more',false,'point_type','QUALITY_OPPORTUNITY_V81','points',v_rows);
end $$;

create or replace function public.bridgepoint_daily_brief_v74()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','accounts','auth','customer_workspace','opportunity_engine','core','automation','intelligence','product' as $$
declare uid uuid:=api.require_user(); org uuid; display text; new_signals bigint:=0; refreshed_sources bigint:=0;
  strict_changes bigint:=0; due_count bigint:=0; top_rows jsonb:='[]'::jsonb; unread bigint:=0;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select coalesce(nullif(btrim(p.display_name),''),nullif(btrim(u.raw_user_meta_data->>'display_name'),''),initcap(split_part(u.email,'@',1)),'there')
    into display from auth.users u left join customer_workspace.profiles_v70 p on p.user_id=u.id where u.id=uid;
  select count(*) into new_signals from intelligence.signals where created_at>=now()-interval '24 hours';
  select count(*) into refreshed_sources from automation.source_registry where last_successful_import_at>=now()-interval '24 hours';
  select count(*) into strict_changes from opportunity_engine.quality_ranked_opportunities_v81 where quality_score>=76 and updated_at>=now()-interval '24 hours';
  select count(*) into due_count from customer_workspace.saved_opportunities_v70 s
    where ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org))
      and s.lead_stage not in('WON','LOST','CLOSED_LOST') and s.next_action_at is not null and s.next_action_at<=now()+interval '24 hours';
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc),'[]'::jsonb) into top_rows from (
    select o.opportunity_id,o.property_id,o.opportunity_name title,o.quality_score score,
      round(o.confidence_score*100,0) confidence,o.quality_tier priority,
      format('%s direct matches, %s signals, %s patterns, and %s sources; %s negative points were applied.',
        o.matched_signal_count,o.signal_count,o.matched_pattern_count,o.source_count,o.negative_score) reason,
      o.recommended_action,o.vertical_key,coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code)) full_address
    from opportunity_engine.quality_ranked_opportunities_v81 o join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.property_choice=1 and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
      where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
        and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
    order by o.quality_score desc,o.latest_evidence_at desc limit 5
  ) x;
  perform customer_workspace.refresh_notifications_v74(uid);
  select count(*) into unread from customer_workspace.notifications_v74 where user_id=uid and read_at is null;
  return jsonb_build_object('complete',true,'engine_version',81,'generated_at',now(),'display_name',display,
    'is_owner',accounts.is_platform_admin(),'overnight',jsonb_build_object('new_signals',new_signals,
      'refreshed_sources',refreshed_sources,'strict_opportunity_updates',strict_changes,'follow_ups_due',due_count),
    'top_opportunities',top_rows,'unread_notifications',unread,
    'summary',format('%s new evidence signals and %s finite, quality-adjusted opportunity updates were processed in the last 24 hours.',new_signals,strict_changes));
end $$;

create or replace function public.bridgepoint_flutter_dashboard_v57(p_model_key text default 'all',p_limit integer default 10)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','pattern_engine','scoring_engine','opportunity_engine','core'
set statement_timeout='25s' as $$
declare v_base jsonb; v_feed jsonb; v_pattern jsonb; v_score jsonb; v_opportunity jsonb; v_property_count bigint; v_quality_count bigint;
begin
  v_base:=public.bridgepoint_flutter_live_status_v56(p_model_key,p_limit);
  select count(*) into v_property_count from core.properties where active and state_code='CT';
  select count(*) into v_quality_count from opportunity_engine.quality_ranked_opportunities_v81 where property_choice=1;
  v_feed:=public.bridgepoint_flutter_opportunities_v57(p_model_key,least(greatest(coalesce(p_limit,10),1),50),0,null,null);
  v_pattern:=pattern_engine.readiness_v36(); v_score:=scoring_engine.readiness_v37(); v_opportunity:=opportunity_engine.readiness_v38();
  return v_base||jsonb_build_object('live_contract_version',81,'property_count_estimate',v_property_count,
    'property_count_kind','CANONICAL_ACTIVE_CT_PROPERTIES','active_opportunities',v_quality_count,
    'raw_engine_opportunities',coalesce((v_opportunity->>'active_opportunities')::bigint,0),
    'opportunity_count_kind','FINITE_NEGATIVE_SCORED_PROPERTIES','active_patterns',coalesce((v_pattern->>'active_patterns')::bigint,0),
    'property_scores',coalesce((v_score->>'property_scores')::bigint,0),'ranked_opportunities',coalesce(v_feed->'opportunities','[]'::jsonb));
end $$;

revoke execute on function public.bridgepoint_field_note_of_day_v81() from public,anon;
revoke execute on function public.bridgepoint_set_field_note_enabled_v81(boolean) from public,anon;
revoke execute on function public.bridgepoint_start_field_shift_v81(text) from public,anon;
revoke execute on function public.bridgepoint_record_field_location_v81(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz) from public,anon;
revoke execute on function public.bridgepoint_stop_field_shift_v81(uuid) from public,anon;
revoke execute on function public.bridgepoint_field_team_v81() from public,anon;
grant execute on function public.bridgepoint_field_note_of_day_v81() to authenticated,service_role;
grant execute on function public.bridgepoint_set_field_note_enabled_v81(boolean) to authenticated,service_role;
grant execute on function public.bridgepoint_start_field_shift_v81(text) to authenticated,service_role;
grant execute on function public.bridgepoint_record_field_location_v81(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz) to authenticated,service_role;
grant execute on function public.bridgepoint_stop_field_shift_v81(uuid) to authenticated,service_role;
grant execute on function public.bridgepoint_field_team_v81() to authenticated,service_role;

revoke execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) from public,anon;
revoke execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) from public,anon;
revoke execute on function public.bridgepoint_daily_brief_v74() from public,anon;
revoke execute on function public.bridgepoint_flutter_dashboard_v57(text,integer) from public,anon;
grant execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) to authenticated,service_role;
grant execute on function public.bridgepoint_daily_brief_v74() to authenticated,service_role;
grant execute on function public.bridgepoint_flutter_dashboard_v57(text,integer) to authenticated,service_role;

comment on table customer_workspace.field_shifts_v81 is 'Explicit-consent foreground field shifts for active Company-plan users.';
comment on table customer_workspace.field_locations_v81 is 'Short-lived field locations. Visible through role-checked RPCs and purged after seven days.';
comment on materialized view opportunity_engine.quality_ranked_opportunities_v81 is 'Finite V81 leaderboard: positive evidence minus explicit penalties; minimum 76 and capped per vertical.';
