-- BridgePoint V75: all customer surfaces use the deduplicated canonical CT inventory.

create or replace function public.bridgepoint_flutter_dashboard_v57(
  p_model_key text default 'all', p_limit integer default 10)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','pattern_engine','scoring_engine','opportunity_engine','core'
set statement_timeout='25s' as $$
declare
  v_base jsonb;
  v_feed jsonb;
  v_pattern jsonb;
  v_score jsonb;
  v_opportunity jsonb;
  v_property_count bigint;
begin
  v_base:=public.bridgepoint_flutter_live_status_v56(p_model_key,p_limit);
  select count(*) into v_property_count from core.properties
    where active and state_code='CT';
  v_base:=jsonb_set(v_base,'{property_count_estimate}',to_jsonb(v_property_count),true);
  v_feed:=public.bridgepoint_flutter_opportunities_v57(
    p_model_key,least(greatest(coalesce(p_limit,10),1),50),0,null,null);
  v_pattern:=pattern_engine.readiness_v36();
  v_score:=scoring_engine.readiness_v37();
  v_opportunity:=opportunity_engine.readiness_v38();
  return v_base||jsonb_build_object(
    'live_contract_version',75,
    'property_count_estimate',v_property_count,
    'property_count_kind','CANONICAL_ACTIVE_CT_PROPERTIES',
    'modern_engines',jsonb_build_object(
      'patterns_v36',v_pattern,'scoring_v37',v_score,'opportunities_v38',v_opportunity),
    'active_opportunities',coalesce((v_opportunity->>'active_opportunities')::bigint,0),
    'active_patterns',coalesce((v_pattern->>'active_patterns')::bigint,0),
    'property_scores',coalesce((v_score->>'property_scores')::bigint,0),
    'ranked_opportunities',coalesce(v_feed->'opportunities','[]'::jsonb));
end $$;

revoke all on function public.bridgepoint_flutter_dashboard_v57(text,integer) from public,anon;
grant execute on function public.bridgepoint_flutter_dashboard_v57(text,integer) to authenticated,service_role;
