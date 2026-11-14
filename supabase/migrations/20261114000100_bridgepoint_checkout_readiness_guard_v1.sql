-- BridgePoint package truth guard v1.
--
-- The customer UI and the server checkout boundary must enforce the same
-- explicit release decision. An active Stripe price row alone is not a
-- permission to sell a package that is managed, in development, or not
-- approved for self-checkout.
begin;

create or replace function public.bridgepoint_billing_checkout_context_v64(
  p_user_id uuid,
  p_package_key text,
  p_interval text
) returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog', 'product', 'auth'
as $function$
declare
  result jsonb;
  package_row product.packages%rowtype;
  assignment product.launch_promotion_assignments_v63%rowtype;
  trial_days_remaining integer := 0;
  purchase_mode text;
  delivery_status text;
  checkout_ready boolean;
  self_checkout boolean;
  owner_approval_required boolean;
  available_now text;
  commercially_requestable text;
begin
  if p_interval is null or p_interval not in ('month', 'year') then
    raise exception 'Invalid billing interval';
  end if;

  if exists (
    select 1
    from product.platform_access_overrides o
    where o.user_id = p_user_id
      and o.bypass_subscriptions
      and (o.expires_at is null or o.expires_at > now())
  ) then
    raise exception 'This account already has permanent platform access';
  end if;

  select *
  into package_row
  from product.packages p
  where p.package_key = p_package_key
    and p.active;

  if package_row.package_id is null then
    raise exception 'Billing package not found';
  end if;

  purchase_mode := upper(btrim(coalesce(
    package_row.configuration->>'purchase_mode', ''
  )));
  delivery_status := upper(btrim(coalesce(
    package_row.configuration->>'delivery_status', ''
  )));
  checkout_ready := lower(btrim(coalesce(
    package_row.configuration->>'checkout_ready', 'false'
  ))) in ('true', '1', 'yes');
  self_checkout := lower(btrim(coalesce(
    package_row.configuration->>'available_for_self_checkout', 'false'
  ))) in ('true', '1', 'yes');
  owner_approval_required := lower(btrim(coalesce(
    package_row.configuration->>'owner_approval_required', 'false'
  ))) in ('true', '1', 'yes');
  available_now := lower(btrim(coalesce(
    package_row.configuration->>'available_now', ''
  )));
  commercially_requestable := lower(btrim(coalesce(
    package_row.configuration->>'commercially_requestable', ''
  )));

  -- Fail closed. Managed activation, founding/early-access and roadmap
  -- products must use their disclosed activation path until the canonical
  -- catalog explicitly marks them as immediate, ready, self-checkout SKUs.
  if purchase_mode <> 'IMMEDIATE'
     or delivery_status <> 'READY'
     or not checkout_ready
     or not self_checkout
     or owner_approval_required
     or available_now in ('false', '0', 'no')
     or commercially_requestable in ('true', '1', 'yes') then
    raise exception
      'Package is not available for self-checkout. Request activation or contact BridgePoint.';
  end if;

  -- Do not reserve a founding offer until the package has passed every
  -- self-checkout gate and the Stripe catalog contains a usable price row.
  if not exists (
    select 1
    from product.stripe_catalog_v64 c
    where c.package_key = package_row.package_key
      and c.active
      and nullif(btrim(c.stripe_product_id), '') is not null
      and nullif(btrim(case
        when p_interval = 'year' then c.stripe_annual_price_id
        else c.stripe_monthly_price_id
      end), '') is not null
  ) then
    raise exception 'Billing package or price is not configured';
  end if;

  assignment := product.claim_launch_offer_v72(
    p_user_id,
    package_row.package_id
  );

  select greatest(
    0,
    ceil(extract(epoch from (s.trial_ends_at - now())) / 86400.0)::integer
  )
  into trial_days_remaining
  from product.subscriptions s
  where s.user_id = p_user_id
    and s.status = 'trialing'
    and s.trial_ends_at > now()
  order by s.trial_ends_at desc
  limit 1;

  trial_days_remaining := coalesce(trial_days_remaining, 0);

  select jsonb_build_object(
    'user_id', u.id,
    'email', u.email,
    'package_id', package_row.package_id,
    'package_key', package_row.package_key,
    'package_name', package_row.package_name,
    'stripe_product_id', c.stripe_product_id,
    'stripe_price_id', case
      when p_interval = 'year' then c.stripe_annual_price_id
      else c.stripe_monthly_price_id
    end,
    'interval', p_interval,
    'trial_days_remaining', trial_days_remaining,
    'coupon_id', case
      when assignment.assignment_id is not null
       and assignment.status <> 'applied'
       and p_interval = 'month'
      then 'BRIDGEPOINT_FIRST10_50_6MO_V63'
    end,
    'promotion_assignment_id', assignment.assignment_id,
    'stripe_customer_id', sc.stripe_customer_id
  )
  into result
  from auth.users u
  join product.stripe_catalog_v64 c
    on c.package_key = package_row.package_key
   and c.active
  left join product.stripe_customers_v64 sc
    on sc.user_id = u.id
  where u.id = p_user_id;

  if result is null then
    raise exception 'Billing package or user not found';
  end if;

  return result;
end;
$function$;

revoke all on function public.bridgepoint_billing_checkout_context_v64(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.bridgepoint_billing_checkout_context_v64(uuid, text, text)
  to service_role;

commit;
