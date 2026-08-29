-- BridgePoint V1001: make priority foundation sharding understand offset-based sources.
-- Required for NC OneMap recovery and any future ArcGIS source that uses deterministic resultOffset pagination.
create or replace function public.bridgepoint_priority_foundation_runs_v754(p_lane integer, p_limit integer default 1)
returns jsonb
language sql
stable security definer
set search_path to 'pg_catalog','automation','public'
as $function$
with eligible as (
  select distinct on (r.state_code)
         r.run_id,r.state_code,r.run_status,r.current_phase,r.updated_at,
         d.expected_rows,d.canonical_property_count,
         greatest(coalesce(d.expected_rows,0)-coalesce(d.canonical_property_count,0),0)::bigint as known_missing_rows,
         t.source_task_id,t.updated_at as task_updated_at,
         coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,
                  nullif(t.cursor->>'estimated_total_rows','')::bigint,0)::bigint as source_total_rows,
         coalesce(nullif(t.result->>'offset_to','')::bigint,
                  nullif(t.cursor->>'offset','')::bigint,
                  nullif(t.result->>'keyset_rows_seen','')::bigint,
                  nullif(t.result->>'progress_to','')::bigint,
                  nullif(t.cursor->>'keyset_rows_seen','')::bigint,
                  nullif(t.cursor->>'progress_to','')::bigint,0)::bigint as source_seen_rows,
         coalesce((t.result->>'effective_done')::boolean,false) as source_effective_done
  from automation.geographic_expansion_runs_v86 r
  join automation.geographic_source_tasks_v90 t
    on t.run_id=r.run_id and t.task_type='ACQUIRE_PROPERTY_FOUNDATION'
   and t.task_status='QUEUED' and (t.next_retry_at is null or t.next_retry_at<=now())
  join automation.geographic_source_candidates_v86 c
    on c.candidate_id=t.candidate_id and c.decision_status='ACCEPTED'
  left join automation.state_foundation_denominators_v403 d on d.state_code=r.state_code
  where (r.current_phase='PROPERTY_FOUNDATION' or (d.state_code is not null and not d.foundation_reconciled))
    and r.state_code is not null
    and automation.expansion_candidate_scope_v197(c.state_code,c.candidate_name,c.provider,c.source_url,c.metadata) in('TARGET','NATIONAL')
    and automation.expansion_adapter_mode_v197(c.source_category,c.access_method)='ROW_INGEST'
    and not (
      coalesce((t.result->>'effective_done')::boolean,false)
      and coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)>0
      and coalesce(nullif(t.result->>'offset_to','')::bigint,nullif(t.cursor->>'offset','')::bigint,
                   nullif(t.result->>'keyset_rows_seen','')::bigint,nullif(t.result->>'progress_to','')::bigint,
                   nullif(t.cursor->>'keyset_rows_seen','')::bigint,nullif(t.cursor->>'progress_to','')::bigint,0)
          >= floor(coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)*0.995)
    )
  order by r.state_code,
           greatest(
             coalesce(nullif(t.result->>'estimated_total_rows','')::bigint,nullif(t.cursor->>'estimated_total_rows','')::bigint,0)
             - coalesce(nullif(t.result->>'offset_to','')::bigint,nullif(t.cursor->>'offset','')::bigint,
                        nullif(t.result->>'keyset_rows_seen','')::bigint,nullif(t.result->>'progress_to','')::bigint,
                        nullif(t.cursor->>'keyset_rows_seen','')::bigint,nullif(t.cursor->>'progress_to','')::bigint,0),0
           ) desc,
           greatest(coalesce(d.expected_rows,0)-coalesce(d.canonical_property_count,0),0) desc,
           t.updated_at
), ordered as (
  select eligible.*,
         greatest(source_total_rows-source_seen_rows,0)::bigint as source_remaining_rows,
         row_number() over(order by
           case when source_total_rows>0 and source_seen_rows<source_total_rows then 0 else 1 end,
           greatest(source_total_rows-source_seen_rows,0) desc,
           known_missing_rows desc,
           task_updated_at,
           state_code) as rn
  from eligible
), picked as (
  select * from ordered
  where mod((rn-1)::int,6)=least(greatest(coalesce(p_lane,0),0),5)
  order by rn
  limit least(greatest(coalesce(p_limit,1),1),3)
)
select jsonb_build_object(
  'complete',true,'version',1001,'lane',least(greatest(coalesce(p_lane,0),0),5),
  'selection_policy','UNREAD_SOURCE_ROWS_FIRST__OFFSET_AND_KEYSET__6_SHARDS',
  'runs',coalesce(jsonb_agg(to_jsonb(p)-'rn' order by p.rn),'[]'::jsonb)
)
from picked p;
$function$;
