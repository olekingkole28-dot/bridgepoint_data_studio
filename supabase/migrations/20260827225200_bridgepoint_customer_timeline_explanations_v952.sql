-- Customer-readable Property DNA timeline v952.
-- Preserves entitlement gates and the v78 evidence engine while enriching the
-- existing v857 customer response with plain-language interpretation.

create or replace function public.bridgepoint_property_timeline_v857(p_property_id uuid, p_limit integer default 120)
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog','public','api','product','core'
set statement_timeout to '8s'
as $function$
declare
  uid uuid:=api.require_user();
  v_state text;
  v_owner boolean:=product.has_platform_override(uid);
  v_allowed boolean;
  result jsonb;
  enriched jsonb;
begin
  select upper(btrim(p.state_code)) into v_state
  from core.properties p
  where p.property_id=p_property_id and p.active
  limit 1;

  if v_state is null then
    return jsonb_build_object('complete',false,'version',952,'error','PROPERTY_NOT_FOUND','property_id',p_property_id);
  end if;

  if not v_owner and not product.user_has_state_access_v77(uid,v_state) then
    return jsonb_build_object(
      'complete',true,'version',952,'property_id',p_property_id,'state_code',v_state,
      'locked',true,'required_geography',v_state,'item_count',0,'timeline','[]'::jsonb,
      'explanation','This property is outside the account’s active geography.'
    );
  end if;

  v_allowed:=v_owner or (
    product.user_has_feature_access_v204('signals',uid)
    and product.user_has_feature_access_v204('patterns',uid)
    and product.user_has_feature_access_v204('opportunity_rankings',uid)
  );

  if not v_allowed then
    return jsonb_build_object(
      'complete',true,'version',952,'property_id',p_property_id,'state_code',v_state,
      'locked',true,
      'required_features',jsonb_build_array('signals','patterns','opportunity_rankings'),
      'item_count',0,'timeline','[]'::jsonb,
      'explanation','The full Property DNA timeline is available to packages that include signals, patterns, and ranked opportunities.'
    );
  end if;

  result:=public.bridgepoint_property_timeline_v78(p_property_id,p_limit);

  select coalesce(jsonb_agg(
    item || jsonb_build_object(
      'description',
        case upper(coalesce(item->>'timeline_type','SIGNAL'))
          when 'SIGNAL' then
            coalesce(nullif(item->>'description',''),'BridgePoint linked a dated source observation to this property.') ||
            ' Source: ' || coalesce(nullif(item->>'source_label',''),'source unavailable') || '.' ||
            ' Evidence level: ' ||
              case upper(coalesce(item->>'support_level',''))
                when 'AREA_CONTEXT' then 'area context — relevant to the location, not proof that the event happened to this exact structure'
                when 'DIRECT_MODEL_EVIDENCE' then 'direct model evidence — allowed to contribute directly to one or more BridgePoint opportunity models'
                when 'SUPPORTING_CONTEXT' then 'supporting context — useful property history, but not necessarily direct model evidence'
                else lower(replace(coalesce(item->>'support_level','supporting context'),'_',' '))
              end || '.' ||
            ' How it matched: ' ||
              case
                when upper(coalesce(item->>'match_method','')) like '%AREA%' then 'area-level geographic match'
                when upper(coalesce(item->>'match_method','')) like '%ADDRESS%' then 'address/property identity match'
                when upper(coalesce(item->>'match_method','')) like '%PARCEL%' then 'parcel/property identity match'
                when upper(coalesce(item->>'match_method',''))='PROPERTY_RECORD_LINK' then 'canonical property record link'
                else lower(replace(coalesce(nullif(item->>'match_method',''),'property record link'),'_',' '))
              end || '.' ||
            case when item ? 'confidence' and item->>'confidence' is not null then
              ' Confidence is the quality of the source/match; it is not the probability that the property is damaged or that a sale will happen.'
            else '' end
          when 'PATTERN' then
            coalesce(nullif(item->>'description',''),'Multiple property observations formed a corroborating sequence.') ||
            ' Read this as corroborating context: a pattern can strengthen the property story, but it is not proof by itself.'
          when 'OPPORTUNITY' then
            coalesce(nullif(item->>'description',''),'BridgePoint ranked this property after its evidence gate passed.') ||
            ' Read this as a prioritized review candidate, not a guaranteed project, claim, loss, or sale.'
          when 'CLAIM' then
            coalesce(nullif(item->>'description',''),'An authorized claim-workflow event is associated with this property.') ||
            ' This is private workflow data for this account.'
          when 'NOTE' then
            coalesce(nullif(item->>'description',''),'A note was saved in this BridgePoint workspace.')
          else coalesce(nullif(item->>'description',''),'A dated BridgePoint intelligence event is connected to this property.')
        end,
      'match_method',
        case
          when upper(coalesce(item->>'match_method','')) like '%AREA%' then 'Area-level geographic match'
          when upper(coalesce(item->>'match_method','')) like '%ADDRESS%' then 'Address/property identity match'
          when upper(coalesce(item->>'match_method','')) like '%PARCEL%' then 'Parcel/property identity match'
          when upper(coalesce(item->>'match_method',''))='PROPERTY_RECORD_LINK' then 'Canonical property record link'
          when nullif(item->>'match_method','') is not null then initcap(replace(item->>'match_method','_',' '))
          else null
        end,
      'customer_reading_guide', jsonb_build_object(
        'signal','One dated source observation.',
        'pattern','Multiple observations that line up; corroborating context, not proof by itself.',
        'opportunity','Evidence gate passed for prioritization; not a guaranteed project or sale.',
        'confidence','Source/match quality, not probability of damage or conversion.',
        'limitation','Read the limitation before making any customer-facing claim.'
      )
    ) order by ord
  ),'[]'::jsonb)
  into enriched
  from jsonb_array_elements(coalesce(result->'timeline','[]'::jsonb)) with ordinality as t(item,ord);

  result:=jsonb_set(result,'{timeline}',enriched,true);

  return result || jsonb_build_object(
    'version',952,
    'state_code',v_state,
    'state_access_enforced',true,
    'feature_access_enforced',true,
    'explanation','Tap an event to read what happened, why it matters, how BridgePoint matched it, the evidence level, confidence, and the limitation. Signal = one source observation. Pattern = corroborating sequence. Verified opportunity = evidence gate passed for prioritization, not a guaranteed outcome.'
  );
end
$function$;

grant execute on function public.bridgepoint_property_timeline_v857(uuid,integer) to authenticated;
