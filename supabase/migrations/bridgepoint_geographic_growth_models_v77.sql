-- BridgePoint V77
-- Geographic growth entitlements, expansion bundles, demand capture, and plain-language model catalog.

create table if not exists product.geographic_markets_v77 (
  state_code text primary key check(state_code ~ '^[A-Z]{2}$'),
  state_name text not null,
  region_name text not null,
  data_status text not null default 'PLANNED'
    check(data_status in ('PLANNED','BUILDING','LIVE','PAUSED')),
  included_with_base boolean not null default false,
  customer_visible boolean not null default true,
  available_for_purchase boolean not null default false,
  monthly_price numeric(10,2) not null default 149,
  yearly_price numeric(10,2) not null default 1490,
  stripe_product_id text,
  stripe_monthly_price_id text,
  stripe_yearly_price_id text,
  canonical_property_count bigint,
  activated_at timestamptz,
  configuration jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into product.geographic_markets_v77(state_code,state_name,region_name)
values
 ('AL','Alabama','South'),('AK','Alaska','West'),('AZ','Arizona','West'),
 ('AR','Arkansas','South'),('CA','California','West'),('CO','Colorado','West'),
 ('CT','Connecticut','Northeast'),('DE','Delaware','South'),('FL','Florida','South'),
 ('GA','Georgia','South'),('HI','Hawaii','West'),('ID','Idaho','West'),
 ('IL','Illinois','Midwest'),('IN','Indiana','Midwest'),('IA','Iowa','Midwest'),
 ('KS','Kansas','Midwest'),('KY','Kentucky','South'),('LA','Louisiana','South'),
 ('ME','Maine','Northeast'),('MD','Maryland','South'),('MA','Massachusetts','Northeast'),
 ('MI','Michigan','Midwest'),('MN','Minnesota','Midwest'),('MS','Mississippi','South'),
 ('MO','Missouri','Midwest'),('MT','Montana','West'),('NE','Nebraska','Midwest'),
 ('NV','Nevada','West'),('NH','New Hampshire','Northeast'),('NJ','New Jersey','Northeast'),
 ('NM','New Mexico','West'),('NY','New York','Northeast'),('NC','North Carolina','South'),
 ('ND','North Dakota','Midwest'),('OH','Ohio','Midwest'),('OK','Oklahoma','South'),
 ('OR','Oregon','West'),('PA','Pennsylvania','Northeast'),('RI','Rhode Island','Northeast'),
 ('SC','South Carolina','South'),('SD','South Dakota','Midwest'),('TN','Tennessee','South'),
 ('TX','Texas','South'),('UT','Utah','West'),('VT','Vermont','Northeast'),
 ('VA','Virginia','South'),('WA','Washington','West'),('WV','West Virginia','South'),
 ('WI','Wisconsin','Midwest'),('WY','Wyoming','West')
on conflict(state_code) do update set
  state_name=excluded.state_name,region_name=excluded.region_name,updated_at=now();

update product.geographic_markets_v77 set
  data_status='LIVE',included_with_base=true,available_for_purchase=false,
  canonical_property_count=(select count(*) from core.properties where active and state_code='CT'),
  activated_at=coalesce(activated_at,now()),
  configuration=configuration||jsonb_build_object(
    'coverage_label','Included with every BridgePoint package',
    'canonical_inventory',true,'version',77),updated_at=now()
where state_code='CT';

create table if not exists product.geographic_bundles_v77 (
  bundle_key text primary key,
  bundle_name text not null,
  description text not null,
  monthly_price numeric(10,2),
  yearly_price numeric(10,2),
  customer_visible boolean not null default true,
  available_for_purchase boolean not null default false,
  stripe_product_id text,
  stripe_monthly_price_id text,
  stripe_yearly_price_id text,
  display_order integer not null default 100,
  configuration jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into product.geographic_bundles_v77(
  bundle_key,bundle_name,description,monthly_price,yearly_price,display_order,configuration)
values
 ('new_england','New England Expansion',
  'Connecticut, Massachusetts, Rhode Island, New Hampshire, Vermont, and Maine.',
  599,5990,10,jsonb_build_object('individual_equivalent_monthly',894,'savings_percent',33)),
 ('northeast','Northeast Expansion',
  'New England plus New York, New Jersey, and Pennsylvania.',
  849,8490,20,jsonb_build_object('individual_equivalent_monthly',1341,'savings_percent',37)),
 ('national','National Expansion',
  'All activated BridgePoint state markets with one geographic entitlement.',
  1499,14990,30,jsonb_build_object('pricing_review_required_before_activation',true))
on conflict(bundle_key) do update set
  bundle_name=excluded.bundle_name,description=excluded.description,
  monthly_price=excluded.monthly_price,yearly_price=excluded.yearly_price,
  display_order=excluded.display_order,
  configuration=product.geographic_bundles_v77.configuration||excluded.configuration,
  updated_at=now();

create table if not exists product.geographic_bundle_members_v77 (
  bundle_key text not null references product.geographic_bundles_v77(bundle_key) on delete cascade,
  state_code text not null references product.geographic_markets_v77(state_code) on delete cascade,
  primary key(bundle_key,state_code)
);

insert into product.geographic_bundle_members_v77(bundle_key,state_code)
select 'new_england',v from unnest(array['CT','MA','RI','NH','VT','ME']) v
on conflict do nothing;
insert into product.geographic_bundle_members_v77(bundle_key,state_code)
select 'northeast',v from unnest(array['CT','MA','RI','NH','VT','ME','NY','NJ','PA']) v
on conflict do nothing;
insert into product.geographic_bundle_members_v77(bundle_key,state_code)
select 'national',state_code from product.geographic_markets_v77
on conflict do nothing;

create table if not exists product.geographic_entitlements_v77 (
  geographic_entitlement_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement_type text not null check(entitlement_type in ('STATE','BUNDLE')),
  item_key text not null,
  status text not null default 'active'
    check(status in ('trialing','active','past_due','cancelled','expired')),
  external_customer_id text,
  external_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,entitlement_type,item_key)
);
create index if not exists geographic_entitlements_v77_subscription_idx
  on product.geographic_entitlements_v77(external_subscription_id)
  where external_subscription_id is not null;

create table if not exists customer_workspace.geographic_interest_v77 (
  geographic_interest_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  state_code text references product.geographic_markets_v77(state_code),
  bundle_key text references product.geographic_bundles_v77(bundle_key),
  created_at timestamptz not null default now(),
  check((state_code is not null)::integer+(bundle_key is not null)::integer=1)
);
create unique index if not exists geographic_interest_v77_state_uidx
  on customer_workspace.geographic_interest_v77(user_id,state_code)
  where state_code is not null;
create unique index if not exists geographic_interest_v77_bundle_uidx
  on customer_workspace.geographic_interest_v77(user_id,bundle_key)
  where bundle_key is not null;

alter table product.geographic_markets_v77 enable row level security;
alter table product.geographic_bundles_v77 enable row level security;
alter table product.geographic_bundle_members_v77 enable row level security;
alter table product.geographic_entitlements_v77 enable row level security;
alter table customer_workspace.geographic_interest_v77 enable row level security;
revoke all on product.geographic_markets_v77 from anon,authenticated;
revoke all on product.geographic_bundles_v77 from anon,authenticated;
revoke all on product.geographic_bundle_members_v77 from anon,authenticated;
revoke all on product.geographic_entitlements_v77 from anon,authenticated;
revoke all on customer_workspace.geographic_interest_v77 from anon,authenticated;

create or replace function product.user_has_state_access_v77(p_user_id uuid,p_state_code text)
returns boolean language sql stable security definer
set search_path='pg_catalog','product' as $$
  select
    exists(select 1 from product.platform_access_overrides o
      where o.user_id=p_user_id and o.bypass_subscriptions)
    or exists(select 1 from product.geographic_markets_v77 m
      where m.state_code=upper(p_state_code) and m.included_with_base and m.data_status='LIVE')
    or exists(
      select 1 from product.geographic_entitlements_v77 e
      where e.user_id=p_user_id and e.status in ('trialing','active')
        and (e.current_period_end is null or e.current_period_end>now())
        and ((e.entitlement_type='STATE' and e.item_key=upper(p_state_code))
          or (e.entitlement_type='BUNDLE' and exists(
            select 1 from product.geographic_bundle_members_v77 bm
            where bm.bundle_key=e.item_key and bm.state_code=upper(p_state_code)))));
$$;
revoke all on function product.user_has_state_access_v77(uuid,text)
  from public,anon,authenticated;

create or replace function public.bridgepoint_flutter_geographic_catalog_v77()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','accounts','product','customer_workspace' as $$
declare uid uuid:=api.require_user(); markets jsonb; bundles jsonb;
  owner_access boolean:=accounts.is_platform_admin();
begin
  select coalesce(jsonb_agg(to_jsonb(x) order by x.live_sort,x.state_name),'[]'::jsonb)
    into markets from (
    select m.state_code,m.state_name,m.region_name,m.data_status,
      m.included_with_base,m.monthly_price,m.yearly_price,
      m.canonical_property_count,
      product.user_has_state_access_v77(uid,m.state_code) has_access,
      (m.available_for_purchase and m.data_status='LIVE' and
        m.stripe_monthly_price_id is not null) can_purchase,
      exists(select 1 from customer_workspace.geographic_interest_v77 i
        where i.user_id=uid and i.state_code=m.state_code) interest_registered,
      case when m.data_status='LIVE' then 0 else 1 end live_sort
    from product.geographic_markets_v77 m where m.customer_visible
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.display_order),'[]'::jsonb)
    into bundles from (
    select b.bundle_key,b.bundle_name,b.description,b.monthly_price,b.yearly_price,
      b.display_order,b.configuration,
      count(bm.state_code)::integer state_count,
      count(*) filter(where m.data_status='LIVE')::integer live_state_count,
      (owner_access or exists(select 1 from product.geographic_entitlements_v77 e
        where e.user_id=uid and e.entitlement_type='BUNDLE' and e.item_key=b.bundle_key
          and e.status in ('trialing','active')
          and (e.current_period_end is null or e.current_period_end>now()))) has_access,
      (b.available_for_purchase and b.stripe_monthly_price_id is not null
        and bool_and(m.data_status='LIVE')) can_purchase,
      exists(select 1 from customer_workspace.geographic_interest_v77 i
        where i.user_id=uid and i.bundle_key=b.bundle_key) interest_registered
    from product.geographic_bundles_v77 b
    join product.geographic_bundle_members_v77 bm on bm.bundle_key=b.bundle_key
    join product.geographic_markets_v77 m on m.state_code=bm.state_code
    where b.customer_visible
    group by b.bundle_key,b.bundle_name,b.description,b.monthly_price,b.yearly_price,
      b.display_order,b.configuration,b.available_for_purchase,b.stripe_monthly_price_id
  ) x;
  return jsonb_build_object(
    'complete',true,'version',77,'generated_at',now(),'is_owner',owner_access,
    'base_market','CT','state_add_on_monthly_from',149,
    'policy','Customers are charged only after a state is live and its Stripe price is activated.',
    'markets',markets,'bundles',bundles);
end $$;

create or replace function public.bridgepoint_register_geographic_interest_v77(
  p_state_code text default null,p_bundle_key text default null)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','product','customer_workspace' as $$
declare uid uuid:=api.require_user(); s text:=upper(nullif(btrim(coalesce(p_state_code,'')),''));
  b text:=lower(nullif(btrim(coalesce(p_bundle_key,'')),''));
begin
  if (s is null)::integer+(b is null)::integer<>1 then
    raise exception 'Choose exactly one state or bundle';
  end if;
  if s is not null then
    if not exists(select 1 from product.geographic_markets_v77 where state_code=s) then
      raise exception 'Unknown state'; end if;
    insert into customer_workspace.geographic_interest_v77(user_id,state_code)
    values(uid,s) on conflict(user_id,state_code) where state_code is not null do nothing;
  else
    if not exists(select 1 from product.geographic_bundles_v77 where bundle_key=b) then
      raise exception 'Unknown bundle'; end if;
    insert into customer_workspace.geographic_interest_v77(user_id,bundle_key)
    values(uid,b) on conflict(user_id,bundle_key) where bundle_key is not null do nothing;
  end if;
  return jsonb_build_object('complete',true,'status','registered',
    'message','We saved your expansion request. You will not be charged until coverage is live and you choose to purchase it.');
end $$;

create or replace function public.bridgepoint_geographic_checkout_context_v77(
  p_user_id uuid,p_item_type text,p_item_key text,p_interval text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','product','auth' as $$
declare result jsonb; item_type text:=upper(btrim(p_item_type));
  item_key text:=case when upper(btrim(p_item_type))='STATE' then upper(btrim(p_item_key))
    else lower(btrim(p_item_key)) end;
begin
  if p_interval not in ('month','year') then raise exception 'Invalid billing interval'; end if;
  if item_type not in ('STATE','BUNDLE') then raise exception 'Invalid geographic item type'; end if;
  if exists(select 1 from product.platform_access_overrides o
      where o.user_id=p_user_id and o.bypass_subscriptions) then
    raise exception 'This owner account already has permanent geographic access';
  end if;
  if item_type='STATE' then
    select jsonb_build_object('user_id',u.id,'email',u.email,
      'purchase_type','geography','item_type','STATE','item_key',m.state_code,
      'item_name',m.state_name||' State Coverage',
      'stripe_price_id',case when p_interval='year' then m.stripe_yearly_price_id else m.stripe_monthly_price_id end,
      'interval',p_interval,'stripe_customer_id',sc.stripe_customer_id)
      into result from auth.users u cross join product.geographic_markets_v77 m
      left join product.stripe_customers_v64 sc on sc.user_id=u.id
      where u.id=p_user_id and m.state_code=item_key and m.data_status='LIVE'
        and m.available_for_purchase;
  else
    select jsonb_build_object('user_id',u.id,'email',u.email,
      'purchase_type','geography','item_type','BUNDLE','item_key',b.bundle_key,
      'item_name',b.bundle_name,
      'stripe_price_id',case when p_interval='year' then b.stripe_yearly_price_id else b.stripe_monthly_price_id end,
      'interval',p_interval,'stripe_customer_id',sc.stripe_customer_id)
      into result from auth.users u cross join product.geographic_bundles_v77 b
      left join product.stripe_customers_v64 sc on sc.user_id=u.id
      where u.id=p_user_id and b.bundle_key=item_key and b.available_for_purchase
        and not exists(select 1 from product.geographic_bundle_members_v77 bm
          join product.geographic_markets_v77 m on m.state_code=bm.state_code
          where bm.bundle_key=b.bundle_key and m.data_status<>'LIVE');
  end if;
  if result is null or result->>'stripe_price_id' is null then
    raise exception 'This geographic coverage is not ready for purchase';
  end if;
  return result;
end $$;

revoke all on function public.bridgepoint_flutter_geographic_catalog_v77()
  from public,anon;
revoke all on function public.bridgepoint_register_geographic_interest_v77(text,text)
  from public,anon;
revoke all on function public.bridgepoint_geographic_checkout_context_v77(uuid,text,text,text)
  from public,anon,authenticated;
grant execute on function public.bridgepoint_flutter_geographic_catalog_v77()
  to authenticated,service_role;
grant execute on function public.bridgepoint_register_geographic_interest_v77(text,text)
  to authenticated,service_role;
grant execute on function public.bridgepoint_geographic_checkout_context_v77(uuid,text,text,text)
  to service_role;

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
  select coalesce(jsonb_agg(to_jsonb(x) order by x.match_rank,x.full_address),'[]'::jsonb)
    into rows from (
    select p.property_id,p.state_code,p.municipality,p.postal_code,p.parcel_number,
      p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code,p.postal_code)) full_address,
      so.opportunity_name top_opportunity,so.strict_score top_score,
      case when lower(coalesce(a.full_address,''))=q then 0
           when lower(coalesce(a.full_address,'')) like q||'%' then 1
           when lower(coalesce(p.parcel_number,''))=q then 2
           when lower(coalesce(p.municipality,''))=q then 3 else 4 end match_rank
    from core.properties p left join core.addresses a on a.address_id=p.primary_address_id
    left join lateral (
      select o.opportunity_name,o.strict_score
      from opportunity_engine.strict_ranked_opportunities_v76 o
      where o.property_id=p.property_id and o.strict_score>=78
      order by o.strict_score desc,o.latest_evidence_at desc limit 1
    ) so on true
    where p.active and p.state_code=state and (
      p.search_text ilike '%'||q||'%' or a.full_address ilike q||'%'
      or p.parcel_number ilike q||'%' or p.municipality ilike q||'%'
      or p.postal_code=q)
    order by match_rank,so.strict_score desc nulls last,a.full_address,p.property_id
    limit lim
  ) x;
  return jsonb_build_object('complete',true,'query',q,'state_code',state,
    'returned_results',jsonb_array_length(rows),'suggestions',rows);
end $$;

revoke all on function public.bridgepoint_flutter_property_suggestions_v77(text,text,integer)
  from public,anon;
grant execute on function public.bridgepoint_flutter_property_suggestions_v77(text,text,integer)
  to authenticated,service_role;

create or replace function public.bridgepoint_flutter_models()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','scoring','product','opportunity_engine'
set statement_timeout='25s' as $$
declare uid uuid:=api.require_user(); models jsonb; active_count integer;
  link_count integer;
begin
  select count(*)::integer into active_count from scoring.models where coalesce(active,true);
  select count(*)::integer into link_count from product.package_models pm
    join product.packages p on p.package_id=pm.package_id
    join scoring.models m on m.model_id=pm.model_id
    where pm.enabled and pm.included and coalesce(p.active,true) and coalesce(m.active,true);
  select coalesce(jsonb_agg(model_row order by model_row->>'model_category',model_row->>'model_name'),'[]'::jsonb)
    into models from (
    select jsonb_build_object(
      'model_id',m.model_id,'model_key',m.model_key,'model_name',m.model_name,
      'description',m.description,'model_category',m.model_category,
      'target_entity_type',m.target_entity_type,'active',m.active,
      'default_threshold',m.default_threshold,'priority_threshold',m.priority_threshold,
      'high_threshold',m.high_threshold,'watch_threshold',m.watch_threshold,
      'customer_outcome',case m.model_key
        when 'roofing_opportunity' then 'Find roof repair and replacement prospects with recent, corroborated property evidence.'
        when 'bridgepoint_home' then 'Prioritize residential properties where a home-service conversation is most defensible now.'
        when 'bridgepoint_commercial' then 'Surface commercial properties with converging business, property, risk, and change intelligence.'
        when 'property_investor' then 'Find acquisition and redevelopment candidates backed by distress, transition, and property evidence.'
        when 'development_opportunity' then 'Highlight sites where construction, land, infrastructure, and change evidence converge.'
        when 'solar_opportunity' then 'Identify properties with solar suitability and adoption context once strict property evidence qualifies.'
        when 'business_growth' then 'Track business expansion and establishment changes for commercial prospecting.'
        when 'infrastructure_opportunity' then 'Track project, repair, procurement, and capital signals tied to infrastructure work.'
        else 'Combine multiple property signals and patterns into a general opportunity review queue.' end,
      'best_for',case m.model_key
        when 'roofing_opportunity' then 'Roofers, exterior contractors, restoration teams'
        when 'bridgepoint_home' then 'Home-service owners and sales teams'
        when 'bridgepoint_commercial' then 'Commercial contractors, brokers, and growth teams'
        when 'property_investor' then 'Investors, wholesalers, and redevelopment teams'
        when 'development_opportunity' then 'Developers, builders, and site-selection teams'
        when 'solar_opportunity' then 'Solar installers and energy sales teams'
        when 'business_growth' then 'B2B sales and commercial service providers'
        when 'infrastructure_opportunity' then 'Civil contractors and infrastructure vendors'
        else 'Teams building a broad property prospecting workflow' end,
      'evidence_requirement','Published opportunities require 85%+ confidence, 3+ sources, 5+ signals, 2+ detected patterns, at least 1 corroborating pattern, and either 4+ sources or 10+ signals.',
      'strict_queue_status',case when coalesce(q.qualified,0)>0 then 'LIVE_RESULTS'
        else 'ACTIVE_AWAITING_STRICT_EVIDENCE' end,
      'strict_qualified_count',coalesce(q.qualified,0),
      'strict_top_score',q.top_score,
      'strict_thresholds',jsonb_build_object(
        'published',78,'high',82,'critical',85,'minimum_confidence_percent',85),
      'package_count',coalesce(pi.package_count,0),
      'packages',coalesce(pi.packages,'[]'::jsonb)) model_row
    from scoring.models m
    left join lateral (
      select count(*)::integer qualified,max(o.strict_score) top_score
      from opportunity_engine.strict_ranked_opportunities_v76 o
      where o.strict_score>=78 and case m.model_key
        when 'roofing_opportunity' then o.vertical_key='roofing'
        when 'property_investor' then o.vertical_key='property_investment'
        when 'development_opportunity' then o.vertical_key='general_contracting'
        when 'bridgepoint_commercial' then o.vertical_key in ('property_investment','general_contracting')
        when 'bridgepoint_home' then o.vertical_key in ('roofing','restoration','public_adjusting')
        when 'bridgepoint_general_v1' then true
        else false end
    ) q on true
    left join lateral (
      select count(*) filter(where pm.enabled and pm.included and coalesce(p.active,true))::integer package_count,
        coalesce(jsonb_agg(jsonb_build_object('package_id',p.package_id,
          'package_key',p.package_key,'package_name',p.package_name,
          'package_type',p.package_type,'featured',p.featured,
          'included',pm.included,'enabled',pm.enabled)
          order by p.display_order,p.package_name)
          filter(where p.package_id is not null),'[]'::jsonb) packages
      from product.package_models pm join product.packages p on p.package_id=pm.package_id
      where pm.model_id=m.model_id
    ) pi on true
    where coalesce(m.active,true)
  ) catalog;
  return jsonb_build_object(
    'complete',true,'generated_at',now(),'catalog_version',77,
    'strict_engine_version',76,'active_model_count',active_count,
    'active_package_model_links',link_count,
    'score_guide',jsonb_build_object(
      'published','78+ absolute evidence score','high','82+','critical','85+',
      'confidence','Reliability of the supporting evidence, separate from opportunity score',
      'important','A model score is a prioritization aid, not a guarantee of a sale or property condition.'),
    'models',models);
end $$;

revoke all on function public.bridgepoint_flutter_models() from public,anon;
grant execute on function public.bridgepoint_flutter_models() to authenticated,service_role;

comment on table product.geographic_markets_v77 is
  'Future-state catalog. A market cannot be sold until data_status is LIVE, available_for_purchase is true, and Stripe prices exist.';
