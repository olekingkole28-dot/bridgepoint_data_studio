-- BridgePoint V84
-- Privacy-limited app activity, owner growth metrics, signup alerts, secure email
-- outbox, and signed rotating founder notes.

create table if not exists bp_system.app_sessions_v84(
  session_key text primary key check(length(session_key) between 12 and 128),
  user_id uuid not null references auth.users(id) on delete cascade,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  ended_at timestamptz,
  platform text not null default 'unknown' check(length(platform)<=40),
  app_version text check(app_version is null or length(app_version)<=40),
  current_page text check(current_page is null or length(current_page)<=80),
  heartbeat_count bigint not null default 1 check(heartbeat_count>=0)
);
create index if not exists app_sessions_v84_user_seen_idx
  on bp_system.app_sessions_v84(user_id,last_seen_at desc);
create index if not exists app_sessions_v84_seen_idx
  on bp_system.app_sessions_v84(last_seen_at desc);

create table if not exists bp_system.app_activity_events_v84(
  activity_event_id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_key text not null references bp_system.app_sessions_v84(session_key) on delete cascade,
  event_type text not null check(event_type in('SESSION_START','PAGE_VIEW','HEARTBEAT','SESSION_END')),
  page_name text check(page_name is null or length(page_name)<=80),
  metadata jsonb not null default '{}'::jsonb check(jsonb_typeof(metadata)='object' and pg_column_size(metadata)<=4096),
  created_at timestamptz not null default now()
);
create index if not exists app_activity_events_v84_user_time_idx
  on bp_system.app_activity_events_v84(user_id,created_at desc);
create index if not exists app_activity_events_v84_type_time_idx
  on bp_system.app_activity_events_v84(event_type,created_at desc);

create table if not exists bp_system.transactional_email_outbox_v84(
  email_outbox_id bigint generated always as identity primary key,
  recipient_email text not null check(length(recipient_email) between 3 and 320),
  template_key text not null check(length(template_key)<=80),
  subject text not null check(length(subject)<=180),
  payload jsonb not null default '{}'::jsonb check(jsonb_typeof(payload)='object' and pg_column_size(payload)<=8192),
  dedupe_key text not null check(length(dedupe_key)<=180),
  delivery_status text not null default 'PENDING_PROVIDER' check(delivery_status in('PENDING_PROVIDER','PENDING','PROCESSING','SENT','FAILED','CANCELED')),
  attempts integer not null default 0 check(attempts between 0 and 20),
  last_error text,
  next_attempt_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(template_key,dedupe_key,recipient_email)
);
create index if not exists transactional_email_outbox_v84_status_idx
  on bp_system.transactional_email_outbox_v84(delivery_status,coalesce(next_attempt_at,created_at));

alter table bp_system.app_sessions_v84 enable row level security;
alter table bp_system.app_activity_events_v84 enable row level security;
alter table bp_system.transactional_email_outbox_v84 enable row level security;
revoke all on bp_system.app_sessions_v84 from public,anon,authenticated;
revoke all on bp_system.app_activity_events_v84 from public,anon,authenticated;
revoke all on bp_system.transactional_email_outbox_v84 from public,anon,authenticated;

create or replace function public.bridgepoint_record_app_activity_v84(
  p_session_key text,
  p_event_type text default 'HEARTBEAT',
  p_page_name text default null,
  p_platform text default 'unknown',
  p_app_version text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','bp_system' as $$
declare
  uid uuid:=api.require_user();
  v_session text:=nullif(btrim(coalesce(p_session_key,'')),'');
  v_event text:=upper(btrim(coalesce(p_event_type,'HEARTBEAT')));
  v_page text:=left(nullif(btrim(coalesce(p_page_name,'')),''),80);
  v_platform text:=left(coalesce(nullif(btrim(coalesce(p_platform,'')),''),'unknown'),40);
  v_version text:=left(nullif(btrim(coalesce(p_app_version,'')),''),40);
  v_metadata jsonb:=coalesce(p_metadata,'{}'::jsonb);
begin
  if v_session is null or length(v_session) not between 12 and 128 or v_session !~ '^[A-Za-z0-9._:-]+$' then
    raise exception 'Invalid app session key';
  end if;
  if v_event not in('SESSION_START','PAGE_VIEW','HEARTBEAT','SESSION_END') then
    raise exception 'Unsupported app activity event';
  end if;
  if jsonb_typeof(v_metadata)<>'object' or pg_column_size(v_metadata)>4096 then
    raise exception 'Activity metadata is invalid';
  end if;

  insert into bp_system.app_sessions_v84(
    session_key,user_id,platform,app_version,current_page,ended_at)
  values(v_session,uid,v_platform,v_version,v_page,case when v_event='SESSION_END' then now() end)
  on conflict(session_key) do update set
    last_seen_at=now(),
    platform=excluded.platform,
    app_version=coalesce(excluded.app_version,bp_system.app_sessions_v84.app_version),
    current_page=coalesce(excluded.current_page,bp_system.app_sessions_v84.current_page),
    ended_at=case when v_event='SESSION_END' then now() else null end,
    heartbeat_count=bp_system.app_sessions_v84.heartbeat_count+1
  where bp_system.app_sessions_v84.user_id=uid;
  if not found then raise exception 'App session belongs to another user'; end if;

  if v_event<>'HEARTBEAT' then
    insert into bp_system.app_activity_events_v84(user_id,session_key,event_type,page_name,metadata)
    values(uid,v_session,v_event,v_page,v_metadata);
  end if;
  return jsonb_build_object('complete',true,'recorded_at',now(),'event_type',v_event);
end $$;

create or replace function bp_system.notify_platform_owners_on_signup_v84()
returns trigger language plpgsql security definer
set search_path='pg_catalog','auth','accounts','customer_workspace','bp_system' as $$
declare admin_row record; display_label text;
begin
  display_label:=coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(coalesce(new.email,'New customer'),'@',1),'New customer');
  for admin_row in
    select up.auth_user_id,u.email
    from accounts.user_profiles up join auth.users u on u.id=up.auth_user_id
    where up.platform_role in('platform_owner','platform_admin') and up.is_active
  loop
    begin
      insert into customer_workspace.notifications_v74(
        user_id,notification_type,title,message,action_page,action_id,dedupe_key)
      values(admin_row.auth_user_id,'SYSTEM','New BridgePoint signup',
        display_label||' created a BridgePoint account. Open Owner Center to review account activity.',
        'Owner Center',new.id::text,'signup:'||new.id::text)
      on conflict(user_id,dedupe_key) do nothing;

      if admin_row.email is not null then
        insert into bp_system.transactional_email_outbox_v84(
          recipient_email,template_key,subject,payload,dedupe_key)
        values(lower(admin_row.email),'OWNER_NEW_SIGNUP','New BridgePoint signup: '||display_label,
          jsonb_build_object('new_user_id',new.id,'new_user_email',new.email,'display_name',display_label,
            'signed_up_at',new.created_at,'owner_dashboard_page','Owner Center'),new.id::text)
        on conflict(template_key,dedupe_key,recipient_email) do nothing;
      end if;
    exception when others then
      -- Signup must never fail because an owner alert could not be recorded.
      null;
    end;
  end loop;
  return new;
end $$;
revoke all on function bp_system.notify_platform_owners_on_signup_v84() from public,anon,authenticated;

drop trigger if exists bridgepoint_notify_platform_owners_signup_v84 on auth.users;
create trigger bridgepoint_notify_platform_owners_signup_v84
after insert on auth.users for each row execute function bp_system.notify_platform_owners_on_signup_v84();

-- Expand the rotating note collection to a full month and sign every note.
insert into product.field_notes_v81(note_category,title,message,display_order)
select x.note_category,x.title,x.message,x.display_order
from (values
 ('ENCOURAGEMENT','Earn the next conversation','Prepare well enough that the first question is useful, respectful, and worth the owner’s time.',130),
 ('DOCUMENTATION','Separate fact from inference','Record what the source says, what BridgePoint inferred, and what still needs human verification.',140),
 ('CUSTOMER_CARE','Clarity is a service','If a customer cannot explain the next step after you leave, simplify it before you move on.',150),
 ('SAFETY','Slow down at the threshold','Before entering any property, confirm permission, conditions, protective equipment, and a safe exit.',160),
 ('ETHICS','The score opens a question','Use intelligence to decide what to verify—not to pressure someone or promise an outcome.',170),
 ('ENCOURAGEMENT','Build trust one promise at a time','Return the call, send the update, and arrive when you said you would. Reliability compounds.',180),
 ('DOCUMENTATION','Name the source and date','A useful note tells the next teammate where the fact came from and when it was current.',190),
 ('CUSTOMER_CARE','Ask before advising','Learn what the owner has already seen, tried, and needs before offering a solution.',200),
 ('SAFETY','Never inspect from the road','Park first, secure the vehicle, check surroundings, and only then use the app.',210),
 ('ETHICS','Respect every no','A declined conversation is the end of the contact unless the person clearly asks for a follow-up.',220),
 ('ENCOURAGEMENT','Make today measurable','Choose one route, one follow-up block, and one customer outcome you can complete with care.',230),
 ('DOCUMENTATION','Close the loop','When a task is done, record the outcome and the next owner so work does not disappear between people.',240),
 ('CUSTOMER_CARE','Explain the limitation too','Trust grows when you clearly say what the data can show and what requires inspection or professional review.',250),
 ('SAFETY','Conditions outrank the schedule','Delay the appointment when weather, traffic, equipment, or site conditions make the plan unsafe.',260),
 ('ETHICS','Protect private details','Collect only what the workflow needs, share it only with authorized teammates, and keep it out of casual notes.',270),
 ('ENCOURAGEMENT','Useful beats impressive','A simple verified answer that helps a customer is better than a complicated claim the evidence cannot support.',280),
 ('DOCUMENTATION','Update the property story','Add the signal, conversation, visit, note, and next action so the timeline remains understandable.',290),
 ('CUSTOMER_CARE','Leave room for questions','Pause after explaining the evidence. Understanding matters more than finishing the script.',300),
 ('ENCOURAGEMENT','Finish strong and hand off cleanly','Review today’s promises, schedule the next actions, and make tomorrow easier for the whole team.',310)
) as x(note_category,title,message,display_order)
where not exists(select 1 from product.field_notes_v81 n where n.title=x.title);

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
    'category',note_row.note_category,'title',note_row.title,'message',note_row.message,
    'signed_by','Kole Johnson, Founder');
end $$;

create or replace function api.owner_dashboard_v84()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','api','accounts','product','cron','opportunity_engine','scoring_engine','pattern_engine','bp_system','auth'
as $$
declare v_user_id uuid:=api.require_user(); v_result jsonb;
begin
  if not accounts.is_platform_admin() then raise exception 'Owner access required'; end if;
  select jsonb_build_object(
    'complete',true,'generated_at',now(),'owner_user_id',v_user_id,'dashboard_version',84,
    'usage',jsonb_build_object(
      'active_now',(select count(distinct user_id) from bp_system.app_sessions_v84 where last_seen_at>=now()-interval '5 minutes' and ended_at is null),
      'daily_active',(select count(distinct user_id) from bp_system.app_sessions_v84 where last_seen_at>=now()-interval '1 day'),
      'weekly_active',(select count(distinct user_id) from bp_system.app_sessions_v84 where last_seen_at>=now()-interval '7 days'),
      'monthly_active',(select count(distinct user_id) from bp_system.app_sessions_v84 where last_seen_at>=now()-interval '30 days'),
      'sessions_24h',(select count(*) from bp_system.app_sessions_v84 where first_seen_at>=now()-interval '1 day'),
      'page_views_7d',(select count(*) from bp_system.app_activity_events_v84 where event_type='PAGE_VIEW' and created_at>=now()-interval '7 days'),
      'top_pages_7d',coalesce((select jsonb_agg(to_jsonb(x) order by x.views desc) from (
        select page_name,count(*) views from bp_system.app_activity_events_v84
        where event_type='PAGE_VIEW' and created_at>=now()-interval '7 days' and page_name is not null
        group by page_name order by count(*) desc limit 8
      ) x),'[]'::jsonb)
    ),
    'system',jsonb_build_object(
      'active_jobs',(select count(*) from cron.job where active),
      'failed_runs_15m',(select count(*) from cron.job_run_details where start_time>now()-interval '15 minutes' and status='failed'),
      'successful_runs_15m',(select count(*) from cron.job_run_details where start_time>now()-interval '15 minutes' and status='succeeded'),
      'last_success_at',(select max(end_time) from cron.job_run_details where status='succeeded'),
      'signup_email_queue',jsonb_build_object(
        'provider_connected',exists(select 1 from bp_system.transactional_email_outbox_v84 where delivery_status in('PENDING','PROCESSING','SENT')),
        'awaiting_provider',(select count(*) from bp_system.transactional_email_outbox_v84 where delivery_status='PENDING_PROVIDER'),
        'failed',(select count(*) from bp_system.transactional_email_outbox_v84 where delivery_status='FAILED')
      )
    ),
    'customers',jsonb_build_object(
      'total_accounts',(select count(*) from auth.users),
      'new_24h',(select count(*) from auth.users where created_at>now()-interval '1 day'),
      'new_7d',(select count(*) from auth.users where created_at>now()-interval '7 days'),
      'new_30d',(select count(*) from auth.users where created_at>now()-interval '30 days'),
      'active_trials',(select count(*) from product.subscriptions where status='trialing' and trial_ends_at>now()),
      'trials_ending_72h',(select count(*) from product.subscriptions where status='trialing' and trial_ends_at between now() and now()+interval '72 hours'),
      'active_paid',(select count(*) from product.subscriptions where status='active'),
      'past_due',(select count(*) from product.subscriptions where status='past_due'),
      'recent_signups',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
        select u.id user_id,u.email,coalesce(nullif(u.raw_user_meta_data->>'display_name',''),split_part(u.email,'@',1)) display_name,
          u.created_at,u.last_sign_in_at
        from auth.users u order by u.created_at desc limit 10
      ) x),'[]'::jsonb)
    ),
    'revenue',jsonb_build_object(
      'active_mrr',coalesce((select sum(p.monthly_price) from product.subscriptions s join product.packages p using(package_id) where s.status='active'),0),
      'trial_pipeline_mrr',coalesce((select sum(p.monthly_price) from product.subscriptions s join product.packages p using(package_id) where s.status='trialing' and s.trial_ends_at>now()),0),
      'checkout_connected',exists(select 1 from product.subscriptions where external_provider is not null or billing_provider is not null)
    ),
    'founding_offer',(select jsonb_build_object(
      'assigned',count(*) filter(where a.status<>'revoked'),'selected',count(*) filter(where a.status='selected'),
      'applied',count(*) filter(where a.status='applied'),'remaining',greatest(10-count(*) filter(where a.status<>'revoked'),0)
    ) from product.launch_promotion_assignments_v63 a),
    'intelligence',jsonb_build_object(
      'verified_unique_opportunities',(select count(*) from opportunity_engine.verified_ranked_opportunities_v83 where global_property_choice=1),
      'elite_opportunities',(select count(*) from opportunity_engine.verified_ranked_opportunities_v83 where global_property_choice=1 and quality_tier='elite'),
      'property_scores_v37',(select greatest(reltuples,0)::bigint from pg_class where oid='scoring_engine.property_scores_v37'::regclass),
      'patterns_v36',(select greatest(reltuples,0)::bigint from pg_class where oid='pattern_engine.patterns_v36'::regclass),
      'minimum_direct_signals',(select min(direct_signal_count) from opportunity_engine.verified_ranked_opportunities_v83 where global_property_choice=1)
    ),
    'top_opportunity_verticals',coalesce((select jsonb_agg(to_jsonb(x) order by x.opportunity_count desc) from (
      select vertical_key,count(*) opportunity_count,round(avg(quality_score),2) average_score
      from opportunity_engine.verified_ranked_opportunities_v83
      group by vertical_key order by count(*) desc limit 10
    ) x),'[]'::jsonb),
    'recent_failures',coalesce((select jsonb_agg(to_jsonb(x) order by x.start_time desc) from (
      select jobid,status,start_time,end_time,left(return_message,300) message
      from cron.job_run_details where status='failed' and start_time>now()-interval '7 days'
      order by start_time desc limit 10
    ) x),'[]'::jsonb)
  ) into v_result;
  return v_result;
end $$;

create or replace function automation.purge_app_activity_v84()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','bp_system' as $$
declare removed_events bigint:=0;removed_sessions bigint:=0;
begin
  delete from bp_system.app_activity_events_v84 where created_at<now()-interval '90 days';
  get diagnostics removed_events=row_count;
  delete from bp_system.app_sessions_v84 where last_seen_at<now()-interval '365 days';
  get diagnostics removed_sessions=row_count;
  return jsonb_build_object('complete',true,'events_removed',removed_events,'sessions_removed',removed_sessions,'finished_at',now());
end $$;
revoke all on function automation.purge_app_activity_v84() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-app-activity-retention-v84') then
    perform cron.unschedule('bridgepoint-app-activity-retention-v84');
  end if;
  perform cron.schedule('bridgepoint-app-activity-retention-v84','29 4 * * *','select automation.purge_app_activity_v84();');
end $$;

revoke execute on function public.bridgepoint_record_app_activity_v84(text,text,text,text,text,jsonb) from public,anon;
revoke execute on function public.bridgepoint_field_note_of_day_v81() from public,anon;
revoke execute on function api.owner_dashboard_v84() from public,anon;
grant execute on function public.bridgepoint_record_app_activity_v84(text,text,text,text,text,jsonb) to authenticated,service_role;
grant execute on function public.bridgepoint_field_note_of_day_v81() to authenticated,service_role;
grant execute on function api.owner_dashboard_v84() to authenticated,service_role;

comment on table bp_system.app_sessions_v84 is
  'Privacy-limited operational usage counters. Does not collect property search terms, note contents, precise location, or customer payloads.';
comment on table bp_system.transactional_email_outbox_v84 is
  'Secure transactional email queue. Rows remain PENDING_PROVIDER until an approved email provider and sending domain are configured.';
