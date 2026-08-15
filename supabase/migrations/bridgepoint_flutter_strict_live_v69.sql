-- BridgePoint V69: Flutter consumes strict, evidence-qualified rankings.

create or replace function public.bridgepoint_flutter_opportunities_v57(
  p_model_key text default 'all', p_limit integer default 50, p_offset integer default 0,
  p_priority text default null, p_stage text default null)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','opportunity_engine','core' set statement_timeout='25s' as $$
declare
  v_model_key text:=lower(btrim(coalesce(p_model_key,'all')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),500);
  v_offset integer:=greatest(coalesce(p_offset,0),0);
  v_priority text:=nullif(lower(btrim(coalesce(p_priority,''))),'');
  v_stage text:=nullif(lower(btrim(coalesce(p_stage,''))),'');
  v_total bigint:=0; v_rows jsonb:='[]'::jsonb;
begin
  select count(*) into v_total from opportunity_engine.strict_ranked_opportunities_v68 o
  where o.strict_score>=90
    and public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
    and (v_priority is null or o.strict_tier=v_priority)
    and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.rank_value),'[]'::jsonb) into v_rows
  from (
    select o.opportunity_id,o.property_id,o.vertical_key model_key,o.opportunity_name model_name,
      case when v_model_key='all' then o.global_rank else o.vertical_rank end rank_value,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.postal_code,p.state_code)) full_address,
      p.parcel_number,p.municipality,p.county,p.postal_code,p.latitude,p.longitude,
      p.property_type,p.property_subtype,p.land_use_description,p.year_built,p.assessed_total_value,
      o.strict_score score,o.strict_tier priority,round(o.confidence_score*100,2) confidence_score,
      coalesce(o.signal_count,0) event_count,coalesce(o.signal_count,0) distinct_signal_count,
      o.opportunity_name top_signal_type,o.opportunity_name title,o.reason explanation,
      o.intelligence_stage stage,o.first_detected_at detected_at,o.updated_at last_detected_at,
      o.recommended_action,o.pattern_count,o.source_count,o.opportunity_family,o.opportunity_key,
      o.vertical_key,o.urgency_score,o.relevance_score,o.property_intelligence_score,
      round(o.quality_value,2) evidence_quality_score,o.vertical_percentile
    from opportunity_engine.strict_ranked_opportunities_v68 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=90
      and public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (v_priority is null or o.strict_tier=v_priority)
      and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
    order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc,o.opportunity_id
    limit v_limit offset v_offset
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',69,
    'ranking_mode','STRICT_EVIDENCE_PERCENTILE','minimum_score',90,
    'requested_model_key',v_model_key,'total_results',v_total,
    'returned_results',jsonb_array_length(v_rows),'limit',v_limit,'offset',v_offset,
    'has_more',v_offset+jsonb_array_length(v_rows)<v_total,'opportunities',v_rows);
end $$;

create or replace function public.bridgepoint_flutter_intelligence_map_v57(
  p_model_key text default 'all',p_min_lat double precision default null,
  p_max_lat double precision default null,p_min_lng double precision default null,
  p_max_lng double precision default null,p_min_score numeric default null,p_limit integer default 500)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','opportunity_engine','core' set statement_timeout='25s' as $$
declare v_limit integer:=least(greatest(coalesce(p_limit,500),1),1000); v_rows jsonb:='[]'::jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(x) order by x.opportunity_score desc),'[]'::jsonb) into v_rows
  from (
    select 'STRICT_OPPORTUNITY_V69'::text intelligence_type,o.opportunity_id,o.property_id,
      o.opportunity_name title,o.reason explanation,o.intelligence_stage stage,o.strict_tier priority,
      o.strict_score opportunity_score,round(o.confidence_score*100,2) opportunity_confidence_percent,
      o.first_detected_at detected_at,o.updated_at last_detected_at,o.vertical_key model_key,
      o.opportunity_name model_name,p.latitude,p.longitude,p.parcel_number,p.municipality,p.county,
      p.postal_code,p.property_type,p.property_subtype,p.land_use_description,p.year_built,
      p.assessed_total_value,a.full_address,o.strict_score final_score,
      o.property_intelligence_score overall_score,o.strict_score rank_value,o.strict_tier score_status,
      o.confidence_score*100 confidence_score,o.signal_count event_count,
      o.signal_count distinct_signal_count,o.source_count verified_event_count,
      o.opportunity_name top_signal_type,o.recommended_action,o.quality_value evidence_quality_score
    from opportunity_engine.strict_ranked_opportunities_v68 o
    join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.strict_score>=greatest(coalesce(p_min_score,90),90)
      and p.latitude is not null and p.longitude is not null
      and public.bridgepoint_flutter_v38_matches(p_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (p_min_lat is null or p.latitude>=p_min_lat) and (p_max_lat is null or p.latitude<=p_max_lat)
      and (p_min_lng is null or p.longitude>=p_min_lng) and (p_max_lng is null or p.longitude<=p_max_lng)
    order by o.strict_score desc,o.quality_value desc,o.latest_evidence_at desc
    limit v_limit+1
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',69,
    'ranking_mode','STRICT_EVIDENCE_PERCENTILE','requested_model_key',lower(coalesce(p_model_key,'all')),
    'limit',v_limit,'returned_points',least(jsonb_array_length(v_rows),v_limit),
    'has_more',jsonb_array_length(v_rows)>v_limit,'point_type','STRICT_OPPORTUNITY_V69',
    'points',(select coalesce(jsonb_agg(value),'[]'::jsonb) from
      (select value from jsonb_array_elements(v_rows) limit v_limit) q));
end $$;

revoke execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) from anon;
revoke execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) from anon;
grant execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) to authenticated;
grant execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) to authenticated;
