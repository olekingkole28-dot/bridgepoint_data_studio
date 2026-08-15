-- BridgePoint Intelligence v63
-- First-ten founding-customer offer, founder access, and private owner dashboard.

begin;

create table if not exists product.launch_promotions_v63 (
    promotion_id uuid primary key default gen_random_uuid(),
    promotion_key text not null unique,
    promotion_name text not null,
    percent_off numeric(5,2) not null check (percent_off > 0 and percent_off <= 100),
    max_assignments integer not null check (max_assignments > 0),
    duration text not null default 'months' check (duration in ('once','months','lifetime')),
    duration_months integer null check (duration_months is null or duration_months > 0),
    active boolean not null default true,
    starts_at timestamptz not null default now(),
    ends_at timestamptz null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists product.launch_promotion_assignments_v63 (
    assignment_id uuid primary key default gen_random_uuid(),
    promotion_id uuid not null references product.launch_promotions_v63(promotion_id) on delete restrict,
    user_id uuid not null references auth.users(id) on delete cascade,
    reservation_number integer not null check (reservation_number > 0),
    percent_off numeric(5,2) not null check (percent_off > 0 and percent_off <= 100),
    status text not null default 'reserved'
        check (status in ('reserved','selected','applied','expired','revoked')),
    selected_package_id uuid null references product.packages(package_id) on delete set null,
    assigned_at timestamptz not null default now(),
    selected_at timestamptz null,
    applied_at timestamptz null,
    metadata jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    unique (promotion_id, user_id),
    unique (promotion_id, reservation_number)
);

alter table product.launch_promotions_v63 enable row level security;
alter table product.launch_promotion_assignments_v63 enable row level security;
revoke all on product.launch_promotions_v63 from public,anon,authenticated;
revoke all on product.launch_promotion_assignments_v63 from public,anon,authenticated;

insert into product.launch_promotions_v63(
    promotion_key,promotion_name,percent_off,max_assignments,duration,duration_months,metadata
) values (
    'FIRST10_50_6MONTHS',
    'First 10 Founding Customers — 50% for 6 Months',
    50,10,'months',6,
    jsonb_build_object(
        'applies_after_trial',true,
        'trial_days',7,
        'discounted_paid_months',6,
        'applies_to','customer_selected_package',
        'payment_method_required_for_trial',false,
        'version',63
    )
)
on conflict (promotion_key) do update set
    promotion_name=excluded.promotion_name,
    percent_off=excluded.percent_off,
    max_assignments=excluded.max_assignments,
    duration=excluded.duration,
    duration_months=excluded.duration_months,
    active=true,
    metadata=excluded.metadata,
    updated_at=now();

create or replace function product.assign_first_ten_offer_v63()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, product
as $function$
declare
    v_promo product.launch_promotions_v63%rowtype;
    v_slot integer;
begin
    select * into v_promo
    from product.launch_promotions_v63 p
    where p.promotion_key='FIRST10_50_6MONTHS'
      and p.active
      and p.starts_at <= now()
      and (p.ends_at is null or p.ends_at > now())
    for update;

    if not found then return new; end if;

    select s into v_slot
    from generate_series(1,v_promo.max_assignments) s
    where not exists (
        select 1 from product.launch_promotion_assignments_v63 a
        where a.promotion_id=v_promo.promotion_id
          and a.reservation_number=s
          and a.status <> 'revoked'
    )
    order by s limit 1;

    if v_slot is null then return new; end if;

    insert into product.launch_promotion_assignments_v63(
        promotion_id,user_id,reservation_number,percent_off,status,metadata
    ) values (
        v_promo.promotion_id,new.id,v_slot,v_promo.percent_off,'reserved',
        jsonb_build_object('automatic_assignment',true,'assigned_after_signup',true)
    ) on conflict (promotion_id,user_id) do nothing;

    return new;
end;
$function$;

drop trigger if exists bridgepoint_assign_first_ten_offer_v63 on auth.users;
create trigger bridgepoint_assign_first_ten_offer_v63
after insert on auth.users
for each row execute function product.assign_first_ten_offer_v63();

create or replace function public.bridgepoint_flutter_pricing_v63()
returns jsonb
language sql
stable security definer
set search_path = pg_catalog, product
as $function$
    with promo as (
        select p.*,
               count(a.assignment_id) filter(where a.status <> 'revoked') assigned
        from product.launch_promotions_v63 p
        left join product.launch_promotion_assignments_v63 a using(promotion_id)
        where p.promotion_key='FIRST10_50_6MONTHS'
        group by p.promotion_id
    )
    select jsonb_build_object(
        'complete',true,
        'generated_at',now(),
        'trial_days',7,
        'packages',coalesce((
            select jsonb_agg(jsonb_build_object(
                'package_id',pk.package_id,
                'package_key',pk.package_key,
                'package_name',pk.package_name,
                'description',pk.description,
                'monthly_price',pk.monthly_price,
                'yearly_price',pk.yearly_price,
                'trial_days',pk.trial_days,
                'featured',pk.featured,
                'display_order',pk.display_order
            ) order by pk.display_order)
            from product.packages pk where pk.active
        ),'[]'::jsonb),
        'founding_offer',coalesce((
            select jsonb_build_object(
                'promotion_name',p.promotion_name,
                'percent_off',p.percent_off,
                'duration',p.duration,
                'duration_months',p.duration_months,
                'max_assignments',p.max_assignments,
                'assigned',p.assigned,
                'remaining',greatest(p.max_assignments-p.assigned,0),
                'active',p.active and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now()),
                'applies_after_trial',true
            ) from promo p
        ),'{}'::jsonb)
    );
$function$;

create or replace function api.my_launch_offer_v63()
returns jsonb
language plpgsql
stable security definer
set search_path = pg_catalog, api, product
as $function$
declare v_user_id uuid := api.require_user(); v_result jsonb;
begin
    select jsonb_build_object(
        'eligible',true,
        'assignment_id',a.assignment_id,
        'reservation_number',a.reservation_number,
        'percent_off',a.percent_off,
        'status',a.status,
        'selected_package_id',a.selected_package_id,
        'selected_package_name',pk.package_name,
        'monthly_price',pk.monthly_price,
        'discounted_monthly_price',round(pk.monthly_price*(1-a.percent_off/100),2),
        'yearly_price',pk.yearly_price,
        'discounted_yearly_price',round(pk.yearly_price*(1-a.percent_off/100),2),
        'duration','months',
        'duration_months',6,
        'applies_after_trial',true
    ) into v_result
    from product.launch_promotion_assignments_v63 a
    join product.launch_promotions_v63 p using(promotion_id)
    left join product.packages pk on pk.package_id=a.selected_package_id
    where a.user_id=v_user_id and p.promotion_key='FIRST10_50_6MONTHS'
      and a.status <> 'revoked';
    return coalesce(v_result,jsonb_build_object('eligible',false));
end;
$function$;

create or replace function api.select_launch_offer_package_v63(p_package_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, api, product
as $function$
declare v_user_id uuid := api.require_user(); v_assignment uuid;
begin
    if not exists(select 1 from product.packages p where p.package_id=p_package_id and p.active) then
        raise exception 'Package not found or inactive';
    end if;
    update product.launch_promotion_assignments_v63 a set
        selected_package_id=p_package_id,status='selected',selected_at=now(),updated_at=now()
    from product.launch_promotions_v63 p
    where a.promotion_id=p.promotion_id and a.user_id=v_user_id
      and p.promotion_key='FIRST10_50_6MONTHS' and a.status in('reserved','selected')
    returning a.assignment_id into v_assignment;
    if v_assignment is null then raise exception 'No active founding-customer offer'; end if;
    return api.my_launch_offer_v63();
end;
$function$;

create or replace function bp_system.grant_founder_access_v63(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, auth, accounts, product, bp_system
as $function$
declare v_user_id uuid; v_display text;
begin
    select u.id,coalesce(u.raw_user_meta_data->>'display_name',split_part(u.email,'@',1))
    into v_user_id,v_display from auth.users u
    where lower(u.email)=lower(trim(p_email)) limit 1;
    if v_user_id is null then raise exception 'Create the founder account first, then grant access'; end if;

    insert into accounts.user_profiles(auth_user_id,display_name,platform_role,is_active)
    values(v_user_id,v_display,'platform_owner',true)
    on conflict(auth_user_id) do update set
        platform_role='platform_owner',is_active=true,display_name=coalesce(accounts.user_profiles.display_name,excluded.display_name),updated_at=now();

    insert into product.user_profiles(user_id,display_name,onboarding_completed,onboarding_completed_at)
    values(v_user_id,v_display,true,now())
    on conflict(user_id) do update set onboarding_completed=true,onboarding_completed_at=coalesce(product.user_profiles.onboarding_completed_at,now()),updated_at=now();

    insert into product.user_settings(user_id) values(v_user_id) on conflict(user_id) do nothing;
    insert into product.platform_access_overrides(
        user_id,access_level,bypass_subscriptions,access_all_models,
        access_all_features,access_all_geographies,expires_at,notes
    ) values(
        v_user_id,'platform_owner',true,true,true,true,null,'Permanent founder access — BridgePoint All Intelligence'
    ) on conflict(user_id) do update set
        access_level='platform_owner',bypass_subscriptions=true,access_all_models=true,
        access_all_features=true,access_all_geographies=true,expires_at=null,
        notes='Permanent founder access — BridgePoint All Intelligence',updated_at=now();

    update product.launch_promotion_assignments_v63 set status='revoked',
        metadata=metadata||jsonb_build_object('revoked_reason','founder account excluded'),updated_at=now()
    where user_id=v_user_id and status <> 'revoked';

    return jsonb_build_object('complete',true,'user_id',v_user_id,'access','platform_owner','all_intelligence_forever',true);
end;
$function$;

create table if not exists bp_system.founder_allowlist_v63 (
    email text primary key check (email = lower(trim(email))),
    display_name text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table bp_system.founder_allowlist_v63 enable row level security;
revoke all on bp_system.founder_allowlist_v63 from public,anon,authenticated;

insert into bp_system.founder_allowlist_v63(email,display_name,active)
values ('olekingkole28@gmail.com','BridgePoint Founder',true)
on conflict(email) do update set
    display_name=excluded.display_name,
    active=true,
    updated_at=now();

create or replace function bp_system.provision_founder_on_signup_v63()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, auth, accounts, product, bp_system
as $function$
begin
    if exists (
        select 1
        from bp_system.founder_allowlist_v63 f
        where f.email=lower(trim(new.email)) and f.active
    ) then
        perform bp_system.grant_founder_access_v63(new.email);
    end if;
    return new;
end;
$function$;

drop trigger if exists bridgepoint_provision_founder_v63 on auth.users;
create trigger bridgepoint_provision_founder_v63
after insert on auth.users
for each row execute function bp_system.provision_founder_on_signup_v63();

create or replace function api.owner_dashboard_v63()
returns jsonb
language plpgsql
stable security definer
set search_path = pg_catalog, api, accounts, product, cron, opportunity_engine, scoring_engine, pattern_engine
as $function$
declare v_user_id uuid := api.require_user(); v_result jsonb;
begin
    if not accounts.is_platform_admin() then raise exception 'Owner access required'; end if;
    select jsonb_build_object(
        'complete',true,'generated_at',now(),'owner_user_id',v_user_id,
        'system',jsonb_build_object(
            'active_jobs',(select count(*) from cron.job where active),
            'failed_runs_15m',(select count(*) from cron.job_run_details where start_time>now()-interval '15 minutes' and status='failed'),
            'successful_runs_15m',(select count(*) from cron.job_run_details where start_time>now()-interval '15 minutes' and status='succeeded'),
            'last_success_at',(select max(end_time) from cron.job_run_details where status='succeeded')
        ),
        'customers',jsonb_build_object(
            'total_accounts',(select count(*) from auth.users),
            'new_7d',(select count(*) from auth.users where created_at>now()-interval '7 days'),
            'new_30d',(select count(*) from auth.users where created_at>now()-interval '30 days'),
            'active_trials',(select count(*) from product.subscriptions where status='trialing' and trial_ends_at>now()),
            'trials_ending_72h',(select count(*) from product.subscriptions where status='trialing' and trial_ends_at between now() and now()+interval '72 hours'),
            'active_paid',(select count(*) from product.subscriptions where status='active'),
            'past_due',(select count(*) from product.subscriptions where status='past_due')
        ),
        'revenue',jsonb_build_object(
            'active_mrr',coalesce((select sum(p.monthly_price) from product.subscriptions s join product.packages p using(package_id) where s.status='active'),0),
            'trial_pipeline_mrr',coalesce((select sum(p.monthly_price) from product.subscriptions s join product.packages p using(package_id) where s.status='trialing' and s.trial_ends_at>now()),0),
            'checkout_connected',exists(select 1 from product.subscriptions where external_provider is not null or billing_provider is not null)
        ),
        'founding_offer',(select jsonb_build_object(
            'assigned',count(*) filter(where a.status<>'revoked'),
            'selected',count(*) filter(where a.status='selected'),
            'applied',count(*) filter(where a.status='applied'),
            'remaining',greatest(10-count(*) filter(where a.status<>'revoked'),0)
        ) from product.launch_promotion_assignments_v63 a),
        'intelligence',jsonb_build_object(
            'opportunities_v38',(select count(*) from opportunity_engine.opportunities_v38 where lower(coalesce(opportunity_status,'active'))='active'),
            'property_scores_v37',(select count(*) from scoring_engine.property_scores_v37),
            'patterns_v36',(select count(*) from pattern_engine.patterns_v36),
            'critical_opportunities',(select count(*) from opportunity_engine.opportunities_v38 where lower(coalesce(opportunity_status,'active'))='active' and opportunity_tier='CRITICAL')
        ),
        'top_opportunity_verticals',coalesce((select jsonb_agg(to_jsonb(x) order by x.opportunity_count desc) from (
            select vertical_key,count(*) opportunity_count,round(avg(opportunity_score),2) average_score
            from opportunity_engine.opportunities_v38
            where lower(coalesce(opportunity_status,'active'))='active'
            group by vertical_key order by count(*) desc limit 10
        ) x),'[]'::jsonb),
        'recent_failures',coalesce((select jsonb_agg(to_jsonb(x) order by x.start_time desc) from (
            select jobid,status,start_time,end_time,left(return_message,300) message
            from cron.job_run_details where status='failed'
            order by start_time desc limit 10
        ) x),'[]'::jsonb)
    ) into v_result;
    return v_result;
end;
$function$;

revoke execute on function product.assign_first_ten_offer_v63() from public,anon,authenticated;
revoke execute on function bp_system.grant_founder_access_v63(text) from public,anon,authenticated;
revoke execute on function bp_system.provision_founder_on_signup_v63() from public,anon,authenticated;
grant execute on function bp_system.grant_founder_access_v63(text) to service_role;

revoke execute on function public.bridgepoint_flutter_pricing_v63() from public;
grant execute on function public.bridgepoint_flutter_pricing_v63() to anon,authenticated,service_role;

revoke execute on function api.my_launch_offer_v63() from public,anon;
revoke execute on function api.select_launch_offer_package_v63(uuid) from public,anon;
revoke execute on function api.owner_dashboard_v63() from public,anon;
grant execute on function api.my_launch_offer_v63() to authenticated,service_role;
grant execute on function api.select_launch_offer_package_v63(uuid) to authenticated,service_role;
grant execute on function api.owner_dashboard_v63() to authenticated,service_role;

commit;
