create or replace function public.bridgepoint_public_system_pulse_v957()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_parcels jsonb;
  v_metrics jsonb;
  v_opportunities bigint;
  v_sources bigint;
  v_latest timestamptz;
  v_target bigint;
  v_total bigint;
  v_scored bigint;
  v_match_done int;
  v_match_total int;
begin
  v_parcels := public.bridgepoint_public_parcel_progress_v956();
  select coalesce(jsonb_object_agg(metric_key, metric_value), '{}'::jsonb), max(updated_at)
  into v_metrics, v_latest from product.public_system_metric_v957;
  select count(*)::bigint into v_opportunities from opportunities.opportunities where stage='qualified';
  select count(*)::bigint into v_sources from automation.source_registry;
  select minimum_canonical_parcels into v_target from automation.us_parcel_coverage_policy_v960 where singleton is true limit 1;
  v_total := coalesce((v_parcels->>'total_parcels')::bigint,0);
  v_scored := coalesce((v_metrics->>'scored_properties')::bigint,0);
  with latest as (
    select distinct on (state_code) state_code,run_status,current_phase
    from automation.geographic_expansion_runs_v86
    where state_code not in ('AS','GU','MP','PR','VI')
    order by state_code,created_at desc
  )
  select count(*)::int,
         count(*) filter(where current_phase in ('SIGNALS_EVIDENCE','SCORE_OPPORTUNITIES','REFRESH_AUTOMATION','SECURITY_ENTITLEMENTS','CUSTOMER_QA') or run_status='ACTIVATED')::int
  into v_match_total,v_match_done from latest;
  return jsonb_build_object(
    'available',true,
    'total_parcels',v_total,
    'national_target_parcels',coalesce(v_target,0),
    'parcel_completion_pct',case when coalesce(v_target,0)>0 then round(100.0*v_total/v_target,2) else 0 end,
    'states_present',coalesce((v_parcels->>'states_present')::int,0),
    'parcel_states',coalesce(v_parcels->'states','[]'::jsonb),
    'matching_states_complete',coalesce(v_match_done,0),
    'matching_states_total',coalesce(v_match_total,51),
    'matching_completion_pct',case when coalesce(v_match_total,0)>0 then round(100.0*v_match_done/v_match_total,2) else 0 end,
    'ingested_source_records',coalesce((v_metrics->>'ingested_source_records')::bigint,0),
    'scored_properties',v_scored,
    'scoring_coverage_pct',case when v_total>0 then round(100.0*v_scored/v_total,2) else 0 end,
    'detected_patterns',coalesce((v_metrics->>'detected_patterns')::bigint,0),
    'signals',coalesce((v_metrics->>'signals')::bigint,0),
    'active_opportunities',v_opportunities,
    'registered_sources',v_sources,
    'updated_at',greatest(coalesce((v_parcels->>'updated_at')::timestamptz,'-infinity'::timestamptz),coalesce(v_latest,'-infinity'::timestamptz)),
    'refresh_hint_seconds',5,
    'scope','United States + District of Columbia',
    'truth_note','Parcel completion uses the strict nationwide parcel floor; scoring coverage is scored properties divided by currently ingested parcels; matching completion is jurisdictions that cleared the normalize/match phase.'
  );
end;
$function$;
revoke all on function public.bridgepoint_public_system_pulse_v957() from public;
grant execute on function public.bridgepoint_public_system_pulse_v957() to anon,authenticated,service_role;

create or replace function public.bridgepoint_owner_live_activity_v958()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','accounts','growth','auth'
as $function$
declare
  v_total_users bigint; v_confirmed_users bigint; v_signups_24h bigint; v_signins_24h bigint; v_active_users bigint;
  v_regions jsonb; v_recent_signups jsonb; v_recent_signins jsonb;
begin
  if auth.uid() is null or not accounts.is_platform_admin() then raise exception 'Owner access required'; end if;
  select count(*) filter(where deleted_at is null and coalesce(is_anonymous,false)=false),
         count(*) filter(where deleted_at is null and coalesce(is_anonymous,false)=false and email_confirmed_at is not null),
         count(*) filter(where deleted_at is null and coalesce(is_anonymous,false)=false and created_at>=now()-interval '24 hours'),
         count(*) filter(where deleted_at is null and coalesce(is_anonymous,false)=false and last_sign_in_at>=now()-interval '24 hours')
  into v_total_users,v_confirmed_users,v_signups_24h,v_signins_24h from auth.users;
  select count(distinct user_id)::bigint into v_active_users from auth.sessions where updated_at>=now()-interval '15 minutes' and (not_after is null or not_after>now());
  select coalesce(jsonb_agg(to_jsonb(x) order by x.visitors desc,x.country_code,x.region_code),'[]'::jsonb) into v_regions from (
    select coalesce(nullif(metadata->>'country_code',''),'UNKNOWN') country_code,
           coalesce(nullif(metadata->>'region_code',''),'UNKNOWN') region_code,
           count(distinct visitor_id)::bigint visitors,max(occurred_at) last_seen_at
    from growth.acquisition_funnel_events_v400
    where occurred_at>=now()-interval '24 hours'
      and (metadata->>'account_mode'='signin' or page_path ilike '%mode=signin%' or event_type in ('SIGNUP_VIEW','CREATE_ACCOUNT_CLICK'))
      and (metadata ? 'country_code' or metadata ? 'region_code')
    group by 1,2 order by visitors desc,1,2 limit 20
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_recent_signups from (
    select id user_id,email,created_at,email_confirmed_at,last_sign_in_at from auth.users
    where deleted_at is null and coalesce(is_anonymous,false)=false order by created_at desc limit 10
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.last_sign_in_at desc),'[]'::jsonb) into v_recent_signins from (
    select id user_id,email,last_sign_in_at,created_at from auth.users
    where deleted_at is null and coalesce(is_anonymous,false)=false and last_sign_in_at is not null
    order by last_sign_in_at desc limit 12
  ) x;
  return jsonb_build_object('available',true,'total_users',v_total_users,'confirmed_users',v_confirmed_users,'signups_24h',v_signups_24h,'signins_24h',v_signins_24h,'active_users_15m',v_active_users,'signin_flow_regions_24h',v_regions,'recent_signups',v_recent_signups,'recent_signins',v_recent_signins,'geography_note','Geography is coarse browser region telemetry around sign-in/account flows, not exact verified user location.','updated_at',now());
end;
$function$;
revoke all on function public.bridgepoint_owner_live_activity_v958() from public,anon;
grant execute on function public.bridgepoint_owner_live_activity_v958() to authenticated,service_role;
