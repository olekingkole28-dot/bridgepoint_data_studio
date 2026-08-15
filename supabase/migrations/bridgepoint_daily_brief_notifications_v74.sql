-- BridgePoint V74: personalized Daily Brief and private notification center.

alter table customer_workspace.profiles_v70
  add column if not exists display_name text;

create table if not exists customer_workspace.notification_preferences_v74 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  in_app_enabled boolean not null default true,
  device_push_enabled boolean not null default false,
  critical_opportunities boolean not null default true,
  saved_follow_ups boolean not null default true,
  source_health boolean not null default true,
  daily_brief boolean not null default true,
  quiet_hours_start time,
  quiet_hours_end time,
  updated_at timestamptz not null default now()
);

create table if not exists customer_workspace.notifications_v74 (
  notification_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null check(notification_type in
    ('DAILY_BRIEF','CRITICAL_OPPORTUNITY','FOLLOW_UP','SOURCE_HEALTH','SYSTEM')),
  title text not null,
  message text not null,
  action_page text,
  action_id uuid,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id,dedupe_key)
);
create index if not exists notifications_v74_user_created_idx
  on customer_workspace.notifications_v74(user_id,created_at desc);
create index if not exists notifications_v74_unread_idx
  on customer_workspace.notifications_v74(user_id,created_at desc) where read_at is null;

create table if not exists customer_workspace.push_devices_v74 (
  push_device_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_name text not null,
  platform text not null,
  endpoint text not null,
  public_key text,
  auth_token text,
  active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(user_id,endpoint)
);

alter table customer_workspace.notification_preferences_v74 enable row level security;
alter table customer_workspace.notifications_v74 enable row level security;
alter table customer_workspace.push_devices_v74 enable row level security;
revoke all on customer_workspace.notification_preferences_v74 from anon,authenticated;
revoke all on customer_workspace.notifications_v74 from anon,authenticated;
revoke all on customer_workspace.push_devices_v74 from anon,authenticated;

create or replace function customer_workspace.refresh_notifications_v74(p_user_id uuid)
returns void language plpgsql security definer
set search_path='pg_catalog','customer_workspace','opportunity_engine','core','automation' as $$
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
  select count(*) into strict_changes from opportunity_engine.strict_ranked_opportunities_v68
    where strict_score>=90 and updated_at>=now()-interval '24 hours';

  insert into customer_workspace.notifications_v74(
    user_id,notification_type,title,message,action_page,dedupe_key)
  select p_user_id,'DAILY_BRIEF','Your Daily Brief is ready',
    format('%s new evidence signals, %s refreshed sources, and %s strict opportunity updates in the last 24 hours.',
      new_signals,refreshed_sources,strict_changes),'daily_brief','daily-brief:'||day_key
  where (select daily_brief and in_app_enabled from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
  on conflict(user_id,dedupe_key) do update set message=excluded.message;

  select o.opportunity_id,o.opportunity_name,o.strict_score,a.full_address
    into top_item
  from opportunity_engine.strict_ranked_opportunities_v68 o
  join core.properties p on p.property_id=o.property_id
  left join core.addresses a on a.address_id=p.primary_address_id
  where o.strict_score>=90
  order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc limit 1;
  if top_item.opportunity_id is not null then
    insert into customer_workspace.notifications_v74(
      user_id,notification_type,title,message,action_page,action_id,dedupe_key)
    select p_user_id,'CRITICAL_OPPORTUNITY','Top opportunity to review',
      format('%s at %s is currently scored %s.',top_item.opportunity_name,
        coalesce(top_item.full_address,'a Connecticut property'),round(top_item.strict_score,1)),
      'opportunities',top_item.opportunity_id,'top-opportunity:'||day_key
    where (select critical_opportunities and in_app_enabled from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
    on conflict(user_id,dedupe_key) do update set message=excluded.message,action_id=excluded.action_id;
  end if;

  for due_item in
    select saved_opportunity_id,title,next_action_at from customer_workspace.saved_opportunities_v70
    where user_id=p_user_id and lead_stage not in('WON','LOST')
      and next_action_at is not null and next_action_at<=now()+interval '24 hours'
    order by next_action_at limit 20
  loop
    insert into customer_workspace.notifications_v74(
      user_id,notification_type,title,message,action_page,action_id,dedupe_key)
    select p_user_id,'FOLLOW_UP','Follow-up due: '||due_item.title,
      case when due_item.next_action_at<now() then 'This saved opportunity is overdue.' else 'This saved opportunity is due within 24 hours.' end,
      'my_work',due_item.saved_opportunity_id,'follow-up:'||due_item.saved_opportunity_id::text||':'||day_key
    where (select saved_follow_ups and in_app_enabled from customer_workspace.notification_preferences_v74 where user_id=p_user_id)
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
  select coalesce(nullif(btrim(p.display_name),''),nullif(btrim(u.raw_user_meta_data->>'display_name'),''),
    initcap(split_part(u.email,'@',1)),'there') into display
  from auth.users u left join customer_workspace.profiles_v70 p on p.user_id=u.id where u.id=uid;
  select count(*) into new_signals from intelligence.signals where created_at>=now()-interval '24 hours';
  select count(*) into refreshed_sources from automation.source_registry where last_successful_import_at>=now()-interval '24 hours';
  select count(*) into strict_changes from opportunity_engine.strict_ranked_opportunities_v68
    where strict_score>=90 and updated_at>=now()-interval '24 hours';
  select count(*) into due_count from customer_workspace.saved_opportunities_v70
    where user_id=uid and lead_stage not in('WON','LOST') and next_action_at is not null
      and next_action_at<=now()+interval '24 hours';
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc),'[]'::jsonb) into top_rows from (
    select o.opportunity_id,o.property_id,o.opportunity_name title,o.strict_score score,
      round(o.confidence_score*100,0) confidence,o.strict_tier priority,o.reason,
      o.recommended_action,o.vertical_key,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code)) full_address
    from opportunity_engine.strict_ranked_opportunities_v68 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=90 order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc limit 5
  ) x;
  perform customer_workspace.refresh_notifications_v74(uid);
  select count(*) into unread from customer_workspace.notifications_v74 where user_id=uid and read_at is null;
  return jsonb_build_object('complete',true,'generated_at',now(),'display_name',display,
    'is_owner',accounts.is_platform_admin(),'overnight',jsonb_build_object(
      'new_signals',new_signals,'refreshed_sources',refreshed_sources,
      'strict_opportunity_updates',strict_changes,'follow_ups_due',due_count),
    'top_opportunities',top_rows,'unread_notifications',unread,
    'summary',format('%s new evidence signals and %s strict opportunity updates were processed in the last 24 hours.',new_signals,strict_changes));
end $$;

create or replace function public.bridgepoint_profile_v74()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','auth','customer_workspace' as $$
declare uid uuid:=api.require_user(); result jsonb;
begin
  select jsonb_build_object('display_name',coalesce(nullif(btrim(p.display_name),''),
    nullif(btrim(u.raw_user_meta_data->>'display_name'),''),initcap(split_part(u.email,'@',1))),
    'email',u.email,'profile',coalesce(to_jsonb(p)-'user_id','{}'::jsonb)) into result
  from auth.users u left join customer_workspace.profiles_v70 p on p.user_id=u.id where u.id=uid;
  return jsonb_build_object('complete',true,'account',result);
end $$;

create or replace function public.bridgepoint_update_profile_v74(p_display_name text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); cleaned text:=btrim(coalesce(p_display_name,''));
begin
  if length(cleaned)<2 or length(cleaned)>80 then raise exception 'Profile name must be between 2 and 80 characters'; end if;
  update customer_workspace.profiles_v70 set display_name=cleaned,updated_at=now() where user_id=uid;
  if not found then raise exception 'Complete onboarding before editing your profile'; end if;
  return jsonb_build_object('complete',true,'display_name',cleaned);
end $$;

create or replace function public.bridgepoint_notifications_v74(p_limit integer default 50)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); rows jsonb; prefs jsonb; unread bigint;
begin
  perform customer_workspace.refresh_notifications_v74(uid);
  select to_jsonb(p)-'user_id' into prefs from customer_workspace.notification_preferences_v74 p where user_id=uid;
  select count(*) into unread from customer_workspace.notifications_v74 where user_id=uid and read_at is null;
  select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc),'[]'::jsonb) into rows from (
    select notification_id,notification_type,title,message,action_page,action_id,read_at,created_at
    from customer_workspace.notifications_v74 where user_id=uid
    order by created_at desc limit least(greatest(coalesce(p_limit,50),1),200)
  ) n;
  return jsonb_build_object('complete',true,'unread_count',unread,'preferences',coalesce(prefs,'{}'::jsonb),'notifications',rows);
end $$;

create or replace function public.bridgepoint_update_notification_preferences_v74(
  p_in_app_enabled boolean,p_device_push_enabled boolean,p_critical_opportunities boolean,
  p_saved_follow_ups boolean,p_source_health boolean,p_daily_brief boolean)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user();
begin
  insert into customer_workspace.notification_preferences_v74(user_id,in_app_enabled,device_push_enabled,
    critical_opportunities,saved_follow_ups,source_health,daily_brief)
  values(uid,p_in_app_enabled,p_device_push_enabled,p_critical_opportunities,p_saved_follow_ups,p_source_health,p_daily_brief)
  on conflict(user_id) do update set in_app_enabled=excluded.in_app_enabled,
    device_push_enabled=excluded.device_push_enabled,critical_opportunities=excluded.critical_opportunities,
    saved_follow_ups=excluded.saved_follow_ups,source_health=excluded.source_health,
    daily_brief=excluded.daily_brief,updated_at=now();
  return jsonb_build_object('complete',true,'status','saved');
end $$;

create or replace function public.bridgepoint_mark_notifications_read_v74(p_notification_id uuid default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); changed integer;
begin
  update customer_workspace.notifications_v74 set read_at=coalesce(read_at,now())
  where user_id=uid and (p_notification_id is null or notification_id=p_notification_id);
  get diagnostics changed=row_count;
  return jsonb_build_object('complete',true,'marked_read',changed);
end $$;

revoke all on function customer_workspace.refresh_notifications_v74(uuid) from public,anon,authenticated;
revoke all on function public.bridgepoint_daily_brief_v74() from public,anon;
revoke all on function public.bridgepoint_profile_v74() from public,anon;
revoke all on function public.bridgepoint_update_profile_v74(text) from public,anon;
revoke all on function public.bridgepoint_notifications_v74(integer) from public,anon;
revoke all on function public.bridgepoint_update_notification_preferences_v74(boolean,boolean,boolean,boolean,boolean,boolean) from public,anon;
revoke all on function public.bridgepoint_mark_notifications_read_v74(uuid) from public,anon;
grant execute on function public.bridgepoint_daily_brief_v74() to authenticated,service_role;
grant execute on function public.bridgepoint_profile_v74() to authenticated,service_role;
grant execute on function public.bridgepoint_update_profile_v74(text) to authenticated,service_role;
grant execute on function public.bridgepoint_notifications_v74(integer) to authenticated,service_role;
grant execute on function public.bridgepoint_update_notification_preferences_v74(boolean,boolean,boolean,boolean,boolean,boolean) to authenticated,service_role;
grant execute on function public.bridgepoint_mark_notifications_read_v74(uuid) to authenticated,service_role;
