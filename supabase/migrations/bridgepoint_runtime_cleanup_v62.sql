-- BridgePoint Intelligence v62
-- Accurate health estimates and retirement of superseded Flutter RPC versions.

begin;

create or replace function public.bridgepoint_flutter_system_health_v59()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, cron
as $function$
    with job_state as (
        select count(*) filter (where active) active_jobs,
               count(*) filter (where not active) inactive_jobs
        from cron.job
    ), recent_runs as (
        select count(*) filter (where status = 'succeeded') recent_successes,
               count(*) filter (where status = 'failed') recent_failures,
               max(end_time) filter (where status = 'succeeded') last_success_at,
               max(end_time) filter (where status = 'failed') last_failure_at
        from cron.job_run_details
        where start_time >= now() - interval '15 minutes'
    ), estimates as (
        select
            coalesce(max(c.reltuples) filter (
                where n.nspname='opportunity_engine' and c.relname='opportunities_v38'
            ),0)::bigint opportunities_v38,
            coalesce(max(c.reltuples) filter (
                where n.nspname='scoring_engine' and c.relname='property_scores_v37'
            ),0)::bigint property_scores_v37,
            coalesce(max(c.reltuples) filter (
                where n.nspname='pattern_engine' and c.relname='patterns_v36'
            ),0)::bigint patterns_v36
        from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where c.relkind in ('r','p')
    )
    select jsonb_build_object(
        'complete',true,'generated_at',now(),
        'status',case when r.recent_failures=0 then 'HEALTHY' else 'ATTENTION' end,
        'cron',jsonb_build_object(
            'active_jobs',j.active_jobs,'inactive_jobs',j.inactive_jobs,
            'recent_successes_15m',r.recent_successes,
            'recent_failures_15m',r.recent_failures,
            'last_success_at',r.last_success_at,'last_failure_at',r.last_failure_at
        ),
        'engine_estimates',jsonb_build_object(
            'opportunities_v38',e.opportunities_v38,
            'property_scores_v37',e.property_scores_v37,
            'patterns_v36',e.patterns_v36
        )
    ) from job_state j cross join recent_runs r cross join estimates e;
$function$;

-- These versions are superseded and are no longer used by Flutter V60.
revoke execute on function public.bridgepoint_flutter_dashboard(text,integer)
from public,anon,authenticated;
revoke execute on function public.bridgepoint_flutter_intelligence_map(text,double precision,double precision,double precision,double precision,numeric,integer)
from public,anon,authenticated;
revoke execute on function public.bridgepoint_flutter_opportunities(text,integer,integer,text,text)
from public,anon,authenticated;
revoke execute on function public.bridgepoint_flutter_property_detail(uuid)
from public,anon,authenticated;
revoke execute on function public.bridgepoint_flutter_property_detail_v56(uuid)
from public,anon,authenticated;
revoke execute on function public.bridgepoint_flutter_live_status_v56(text,integer)
from public,anon,authenticated;

grant execute on function public.bridgepoint_flutter_system_health_v59()
to anon,authenticated,service_role;

commit;
