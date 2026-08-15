-- BridgePoint Intelligence v60
-- Launch pricing and automatic seven-day All Intelligence trial.

begin;

update product.packages
set trial_days = 7,
    monthly_price = case package_key
        when 'home' then 99
        when 'commercial' then 249
        when 'solar' then 149
        when 'investor' then 199
        when 'infrastructure' then 299
        when 'custom_model' then 199
        when 'all_intelligence' then 499
        else monthly_price
    end,
    yearly_price = case package_key
        when 'home' then 990
        when 'commercial' then 2490
        when 'solar' then 1490
        when 'investor' then 1990
        when 'infrastructure' then 2990
        when 'custom_model' then 1990
        when 'all_intelligence' then 4990
        else yearly_price
    end,
    configuration = coalesce(configuration, '{}'::jsonb) || jsonb_build_object(
        'trial_requires_payment_method', false,
        'annual_savings_months', 2,
        'pricing_version', 60,
        'pricing_label', 'Launch pricing'
    ),
    updated_at = now()
where package_key in (
    'home','commercial','solar','investor','infrastructure','custom_model','all_intelligence'
);

create unique index if not exists subscriptions_user_package_v60_uidx
on product.subscriptions(user_id, package_id)
where user_id is not null;

create unique index if not exists subscriptions_org_package_v60_uidx
on product.subscriptions(organization_id, package_id)
where organization_id is not null;

create or replace function product.start_default_trial_v60()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, product
as $function$
declare
    v_package_id uuid;
    v_trial_days integer;
begin
    select p.package_id, coalesce(p.trial_days, 7)
    into v_package_id, v_trial_days
    from product.packages p
    where p.package_key = 'all_intelligence'
      and p.active
    limit 1;

    if v_package_id is null then
        return new;
    end if;

    insert into product.subscriptions(
        user_id, package_id, status,
        trial_started_at, trial_ends_at,
        current_period_start, current_period_end,
        metadata
    ) values (
        new.id, v_package_id, 'trialing',
        now(), now() + make_interval(days => v_trial_days),
        now(), now() + make_interval(days => v_trial_days),
        jsonb_build_object(
            'automatic_trial', true,
            'trial_version', 60,
            'payment_method_required', false
        )
    )
    on conflict (user_id, package_id) where user_id is not null do nothing;

    return new;
end;
$function$;

drop trigger if exists bridgepoint_start_default_trial_v60 on auth.users;
create trigger bridgepoint_start_default_trial_v60
after insert on auth.users
for each row execute function product.start_default_trial_v60();

revoke execute on function product.start_default_trial_v60() from public, anon, authenticated;
revoke execute on function product.start_trial(uuid,uuid) from public, anon, authenticated;
grant execute on function product.start_trial(uuid,uuid) to service_role;

revoke execute on function api.start_my_trial(uuid) from public, anon;
revoke execute on function api.my_trial_status() from public, anon;
grant execute on function api.start_my_trial(uuid) to authenticated, service_role;
grant execute on function api.my_trial_status() to authenticated, service_role;

commit;
