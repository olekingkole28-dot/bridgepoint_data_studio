-- BridgePoint V79
-- Fast type-ahead search plus plain-language timeline and expanded lead-stage support.

create index if not exists addresses_full_address_lower_prefix_v79_idx
  on core.addresses (lower(full_address) text_pattern_ops);
create index if not exists properties_state_parcel_lower_prefix_v79_idx
  on core.properties (state_code,lower(parcel_number) text_pattern_ops)
  where active and parcel_number is not null;
create index if not exists properties_state_municipality_lower_prefix_v79_idx
  on core.properties (state_code,lower(municipality) text_pattern_ops)
  where active and municipality is not null;

create or replace function public.bridgepoint_flutter_property_suggestions_v77(
  p_query text,p_state_code text default 'CT',p_limit integer default 8)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','product','core','opportunity_engine'
set statement_timeout='8s' as $$
declare uid uuid:=api.require_user(); q text:=lower(btrim(coalesce(p_query,'')));
  state text:=upper(btrim(coalesce(p_state_code,'CT')));
  lim integer:=least(greatest(coalesce(p_limit,8),1),12); rows jsonb;
begin
  if length(q)<2 then
    return jsonb_build_object('complete',true,'query',q,'suggestions','[]'::jsonb);
  end if;
  if not product.user_has_state_access_v77(uid,state) then
    raise exception 'State coverage is locked for this account';
  end if;
  with candidates as materialized (
    (select p.property_id,p.state_code,p.municipality,p.postal_code,p.parcel_number,
      p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
      a.full_address,1 match_rank
     from core.addresses a join core.properties p on p.primary_address_id=a.address_id
     where p.active and p.state_code=state and lower(a.full_address) like q||'%'
     order by a.full_address limit lim*4)
    union all
    (select p.property_id,p.state_code,p.municipality,p.postal_code,p.parcel_number,
      p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code,p.postal_code)),2
     from core.properties p left join core.addresses a on a.address_id=p.primary_address_id
     where p.active and p.state_code=state and lower(p.parcel_number) like q||'%'
     order by p.parcel_number limit lim*2)
    union all
    (select p.property_id,p.state_code,p.municipality,p.postal_code,p.parcel_number,
      p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code,p.postal_code)),3
     from core.properties p left join core.addresses a on a.address_id=p.primary_address_id
     where p.active and p.state_code=state and lower(p.municipality) like q||'%'
     order by p.municipality,p.property_id limit lim*2)
  ), dedup as (
    select distinct on(c.property_id) c.* from candidates c
    order by c.property_id,c.match_rank
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.match_rank,x.top_score desc nulls last,x.full_address),'[]'::jsonb)
    into rows from (
    select d.*,so.opportunity_name top_opportunity,so.strict_score top_score
    from dedup d left join lateral(
      select o.opportunity_name,o.strict_score
      from opportunity_engine.strict_ranked_opportunities_v76 o
      where o.property_id=d.property_id and o.strict_score>=78
      order by o.strict_score desc,o.latest_evidence_at desc limit 1
    ) so on true
    order by d.match_rank,so.strict_score desc nulls last,d.full_address limit lim
  ) x;
  return jsonb_build_object('complete',true,'query',q,'state_code',state,
    'returned_results',jsonb_array_length(rows),'suggestions',rows);
end $$;

create or replace function public.bridgepoint_update_lead_stage_v70(
  p_saved_opportunity_id uuid,p_lead_stage text,p_next_action_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid:=api.require_user(); stage text:=upper(btrim(coalesce(p_lead_stage,'')));
begin
  if stage not in ('NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM',
    'INSPECTION_SCHEDULED','INSPECTED','CLAIM_FILED','ADJUSTER_ASSIGNED','ESTIMATE_IN_PROGRESS',
    'ESTIMATE_SUBMITTED','NEGOTIATION','APPROVED','WORK_SCHEDULED','IN_PROGRESS','COMPLETED',
    'PAID','CLOSED_LOST','WON','LOST') then raise exception 'Unsupported lead stage'; end if;
  update customer_workspace.saved_opportunities_v70 set lead_stage=stage,
    next_action_at=p_next_action_at,updated_at=now()
  where saved_opportunity_id=p_saved_opportunity_id and user_id=uid;
  if not found then raise exception 'Saved opportunity not found'; end if;
  return jsonb_build_object('complete',true,'status','updated','lead_stage',stage);
end $$;

create or replace function public.bridgepoint_property_timeline_v78(
  p_property_id uuid,p_limit integer default 120)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace','intelligence','pattern_engine','opportunity_engine' as $$
declare uid uuid:=api.require_user(); items jsonb; lim integer:=least(greatest(coalesce(p_limit,120),10),300);
begin
  if not exists(select 1 from core.properties where property_id=p_property_id and active) then
    raise exception 'Property not found'; end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.timeline_at desc),'[]'::jsonb) into items from (
    select * from (
      select 'SIGNAL'::text timeline_type,coalesce(s.effective_at,s.detected_at,s.created_at) timeline_at,
        s.title,coalesce(s.description,'Evidence detected by '||s.detector_key) description,
        s.detector_key source_label,s.confidence,s.severity,null::text stage,s.signal_id item_id
      from intelligence.signals s where s.entity_type='PROPERTY' and s.entity_id=p_property_id
      union all
      select 'PATTERN',coalesce(p.latest_signal_at,p.detected_at,p.updated_at),p.pattern_name,
        format('%s property signals across %s source families formed a corroborating evidence sequence.',
          p.signal_count,p.distinct_sources),p.pattern_family,p.pattern_confidence,null,p.intelligence_stage,p.detected_pattern_id
      from pattern_engine.patterns_v36 p where p.entity_type='PROPERTY' and p.entity_id=p_property_id
        and p.pattern_status='ACTIVE'
      union all
      select 'OPPORTUNITY',coalesce(o.latest_evidence_at,o.updated_at),o.opportunity_name,
        format('%s property-linked signals, %s corroborating patterns and %s independent source families qualified this property at a strict evidence score of %s.',
          o.signal_count,o.matched_pattern_count,o.source_count,round(o.strict_score,1)),o.vertical_key,
        o.confidence_score,null,o.strict_tier,o.opportunity_id
      from opportunity_engine.strict_ranked_opportunities_v76 o
      where o.property_id=p_property_id and o.strict_score>=78
      union all
      select 'NOTE',n.created_at,initcap(replace(n.preset_key,'_',' '))||' note',n.note_text,
        'Your workspace',null,null,n.status,n.note_id
      from customer_workspace.notes_v70 n where n.user_id=uid and n.property_id=p_property_id
      union all
      select 'CLAIM',e.event_at,e.title,e.description,
        case e.source_kind when 'AUTHORIZED_INTEGRATION' then 'Authorized integration'
          when 'AUTOMATION' then 'BridgePoint workflow' else 'Your claims workspace' end,
        null,null,e.claim_stage,e.claim_event_id
      from customer_workspace.claim_events_v78 e where e.user_id=uid and e.property_id=p_property_id
    ) all_items order by timeline_at desc limit lim
  ) t;
  return jsonb_build_object('complete',true,'version',79,'property_id',p_property_id,
    'generated_at',now(),'item_count',jsonb_array_length(items),'timeline',items,
    'explanation','One chronological property history: automatic public evidence, detected patterns, strict opportunities, your notes, and your claim events.');
end $$;

revoke all on function public.bridgepoint_flutter_property_suggestions_v77(text,text,integer) from public,anon;
revoke all on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) from public,anon;
revoke all on function public.bridgepoint_property_timeline_v78(uuid,integer) from public,anon;
grant execute on function public.bridgepoint_flutter_property_suggestions_v77(text,text,integer) to authenticated,service_role;
grant execute on function public.bridgepoint_update_lead_stage_v70(uuid,text,timestamptz) to authenticated,service_role;
grant execute on function public.bridgepoint_property_timeline_v78(uuid,integer) to authenticated,service_role;
