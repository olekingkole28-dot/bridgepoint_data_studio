-- BridgePoint Intelligence v59
-- Secure Flutter runtime settings, live health, RLS cleanup, and API hardening.

begin;

create table if not exists bp_system.flutter_runtime_settings_v59 (
    singleton boolean primary key default true check (singleton),
    auto_refresh_seconds integer not null default 120
        check (auto_refresh_seconds between 30 and 900),
    default_package text not null default 'All Intelligence',
    default_minimum_score numeric(5,2) not null default 0
        check (default_minimum_score between 0 and 100),
    opportunity_page_size integer not null default 25
        check (opportunity_page_size between 10 and 100),
    map_result_limit integer not null default 500
        check (map_result_limit between 50 and 1000),
    map_auto_rotate boolean not null default true,
    show_live_workers boolean not null default true,
    updated_at timestamptz not null default now()
);

alter table bp_system.flutter_runtime_settings_v59 enable row level security;
revoke all on bp_system.flutter_runtime_settings_v59 from public, anon, authenticated;

insert into bp_system.flutter_runtime_settings_v59(singleton)
values (true)
on conflict (singleton) do nothing;

create or replace function public.bridgepoint_flutter_settings_v59()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, bp_system
as $function$
    select jsonb_build_object(
        'complete', true,
        'generated_at', now(),
        'settings_version', 59,
        'settings', jsonb_build_object(
            'auto_refresh_seconds', s.auto_refresh_seconds,
            'default_package', s.default_package,
            'default_minimum_score', s.default_minimum_score,
            'opportunity_page_size', s.opportunity_page_size,
            'map_result_limit', s.map_result_limit,
            'map_auto_rotate', s.map_auto_rotate,
            'show_live_workers', s.show_live_workers,
            'available_refresh_seconds', jsonb_build_array(30, 60, 120, 300, 600),
            'available_map_styles', jsonb_build_array('standard', 'street', 'satellite'),
            'available_themes', jsonb_build_array('dark')
        ),
        'updated_at', s.updated_at,
        'authentication_configured', exists(select 1 from auth.users)
    )
    from bp_system.flutter_runtime_settings_v59 s
    where s.singleton;
$function$;

create or replace function public.bridgepoint_flutter_system_health_v59()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, cron
as $function$
    with job_state as (
        select
            count(*) filter (where active) as active_jobs,
            count(*) filter (where not active) as inactive_jobs
        from cron.job
    ), recent_runs as (
        select
            count(*) filter (where status = 'succeeded') as recent_successes,
            count(*) filter (where status = 'failed') as recent_failures,
            max(end_time) filter (where status = 'succeeded') as last_success_at,
            max(end_time) filter (where status = 'failed') as last_failure_at
        from cron.job_run_details
        where start_time >= now() - interval '15 minutes'
    ), engine_estimates as (
        select
            coalesce(max(n_live_tup) filter (
                where schemaname = 'opportunity_engine' and relname = 'opportunities_v38'
            ), 0)::bigint as opportunities_v38,
            coalesce(max(n_live_tup) filter (
                where schemaname = 'scoring_engine' and relname = 'property_scores_v37'
            ), 0)::bigint as property_scores_v37,
            coalesce(max(n_live_tup) filter (
                where schemaname = 'pattern_engine' and relname = 'detected_patterns_v36'
            ), 0)::bigint as patterns_v36
        from pg_stat_user_tables
    )
    select jsonb_build_object(
        'complete', true,
        'generated_at', now(),
        'status', case when r.recent_failures = 0 then 'HEALTHY' else 'ATTENTION' end,
        'cron', jsonb_build_object(
            'active_jobs', j.active_jobs,
            'inactive_jobs', j.inactive_jobs,
            'recent_successes_15m', r.recent_successes,
            'recent_failures_15m', r.recent_failures,
            'last_success_at', r.last_success_at,
            'last_failure_at', r.last_failure_at
        ),
        'engine_estimates', jsonb_build_object(
            'opportunities_v38', e.opportunities_v38,
            'property_scores_v37', e.property_scores_v37,
            'patterns_v36', e.patterns_v36
        )
    )
    from job_state j cross join recent_runs r cross join engine_estimates e;
$function$;

-- Auth-ready user settings. These remain unavailable to anonymous callers.
create or replace function api.my_settings_v59()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, api, product
as $function$
declare
    v_user_id uuid := api.require_user();
    v_result jsonb;
begin
    insert into product.user_settings(user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    select to_jsonb(s) into v_result
    from product.user_settings s
    where s.user_id = v_user_id;

    return jsonb_build_object(
        'complete', true,
        'settings_version', 59,
        'settings', v_result
    );
end;
$function$;

create or replace function api.save_settings_v59(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, api, product
as $function$
declare
    v_user_id uuid := api.require_user();
    v_theme text;
    v_map_style text;
    v_timezone text;
    v_min_score numeric;
    v_result jsonb;
begin
    p_settings := coalesce(p_settings, '{}'::jsonb);
    insert into product.user_settings(user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    select
        coalesce(nullif(p_settings->>'theme', ''), s.theme),
        coalesce(nullif(p_settings->>'map_style', ''), s.map_style),
        coalesce(nullif(p_settings->>'timezone', ''), s.timezone),
        case when p_settings ? 'minimum_alert_score'
             then (p_settings->>'minimum_alert_score')::numeric
             else s.minimum_alert_score end
    into v_theme, v_map_style, v_timezone, v_min_score
    from product.user_settings s where s.user_id = v_user_id;

    if v_theme not in ('system','light','dark') then raise exception 'Invalid theme'; end if;
    if v_map_style not in ('standard','street','satellite') then raise exception 'Invalid map style'; end if;
    if v_min_score not between 0 and 100 then raise exception 'Minimum alert score must be between 0 and 100'; end if;
    if length(v_timezone) > 64 then raise exception 'Invalid timezone'; end if;

    update product.user_settings s set
        theme = v_theme,
        map_style = v_map_style,
        timezone = v_timezone,
        minimum_alert_score = v_min_score,
        show_score_explanations = case when p_settings ? 'show_score_explanations' then (p_settings->>'show_score_explanations')::boolean else s.show_score_explanations end,
        show_confidence = case when p_settings ? 'show_confidence' then (p_settings->>'show_confidence')::boolean else s.show_confidence end,
        show_raw_signals = case when p_settings ? 'show_raw_signals' then (p_settings->>'show_raw_signals')::boolean else s.show_raw_signals end,
        show_patterns = case when p_settings ? 'show_patterns' then (p_settings->>'show_patterns')::boolean else s.show_patterns end,
        notifications_enabled = case when p_settings ? 'notifications_enabled' then (p_settings->>'notifications_enabled')::boolean else s.notifications_enabled end,
        email_notifications = case when p_settings ? 'email_notifications' then (p_settings->>'email_notifications')::boolean else s.email_notifications end,
        push_notifications = case when p_settings ? 'push_notifications' then (p_settings->>'push_notifications')::boolean else s.push_notifications end,
        preferences = case when p_settings ? 'preferences' then coalesce(p_settings->'preferences','{}'::jsonb) else s.preferences end,
        updated_at = now()
    where s.user_id = v_user_id;

    select to_jsonb(s) into v_result from product.user_settings s where s.user_id = v_user_id;
    return jsonb_build_object('complete', true, 'settings_version', 59, 'settings', v_result);
end;
$function$;

-- Consolidate duplicate user-owned policies and use init-planned auth checks.
drop policy if exists bp_user_settings_self on product.user_settings;
drop policy if exists user_settings_own_all on product.user_settings;
create policy user_settings_v59_own_all on product.user_settings
for all to authenticated
using (user_id = (select auth.uid()) or (select accounts.is_platform_admin()))
with check (user_id = (select auth.uid()) or (select accounts.is_platform_admin()));

drop policy if exists bp_user_profiles_self on product.user_profiles;
drop policy if exists user_profiles_own_read on product.user_profiles;
drop policy if exists user_profiles_own_update on product.user_profiles;
create policy user_profiles_v59_own_all on product.user_profiles
for all to authenticated
using (user_id = (select auth.uid()) or (select accounts.is_platform_admin()))
with check (user_id = (select auth.uid()) or (select accounts.is_platform_admin()));

-- Fast top-opportunity and filtered feed access for Flutter v57+.
create index if not exists bp38_active_rank_v59_idx
on opportunity_engine.opportunities_v38
    (opportunity_score desc, urgency_score desc, updated_at desc, opportunity_id)
where lower(coalesce(opportunity_status, 'active')) = 'active';

create index if not exists bp38_active_tier_rank_v59_idx
on opportunity_engine.opportunities_v38
    (opportunity_tier, opportunity_score desc, updated_at desc)
where lower(coalesce(opportunity_status, 'active')) = 'active';

create index if not exists bp38_active_stage_rank_v59_idx
on opportunity_engine.opportunities_v38
    (intelligence_stage, opportunity_score desc, updated_at desc)
where lower(coalesce(opportunity_status, 'active')) = 'active';

-- Remove public execution from internal write functions. Secret-protected public
-- ingestion wrappers and read-only Flutter RPCs are intentionally preserved.
do $block$
declare r record;
begin
    for r in
        select p.oid::regprocedure as signature
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.prosecdef
          and p.proname like 'bridgepoint_%'
          and p.proname not like 'bridgepoint_flutter_%'
          and p.proname not like '%\_public\_batch' escape '\'
          and p.proname not like '%\_public' escape '\'
          and p.proname not like '%\_status' escape '\'
    loop
        execute format('revoke execute on function %s from public, anon, authenticated', r.signature);
        execute format('grant execute on function %s to service_role', r.signature);
    end loop;
end
$block$;

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- Explicit API surface. PUBLIC inheritance is removed first.
revoke execute on function public.bridgepoint_flutter_settings_v59() from public;
revoke execute on function public.bridgepoint_flutter_system_health_v59() from public;
grant execute on function public.bridgepoint_flutter_settings_v59() to anon, authenticated, service_role;
grant execute on function public.bridgepoint_flutter_system_health_v59() to anon, authenticated, service_role;

revoke execute on function api.my_settings_v59() from public, anon;
revoke execute on function api.save_settings_v59(jsonb) from public, anon;
grant execute on function api.my_settings_v59() to authenticated, service_role;
grant execute on function api.save_settings_v59(jsonb) to authenticated, service_role;

-- New functions are private unless a migration explicitly exposes them.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

commit;
