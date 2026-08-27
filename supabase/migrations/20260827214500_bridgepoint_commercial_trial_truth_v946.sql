-- BridgePoint V946: commercial funnel truth
-- Account previews must never be counted as real Stripe-backed buyer trials.

create or replace view product.commercial_customer_truth_v434 as
select
  s.subscription_id,
  s.user_id,
  s.status,
  s.created_at,
  s.trial_started_at,
  s.trial_ends_at,
  s.current_period_end,
  (s.external_customer_id is not null) as has_external_customer,
  (s.external_subscription_id is not null) as has_external_subscription,
  coalesce((s.metadata ->> 'commercial_lead_excluded')::boolean, false) as commercial_lead_excluded,
  exists (
    select 1
    from product.platform_access_overrides pao
    where pao.user_id = s.user_id
      and pao.bypass_subscriptions = true
      and (pao.expires_at is null or pao.expires_at > now())
  ) as platform_override,
  case
    when coalesce((s.metadata ->> 'commercial_lead_excluded')::boolean, false)
      then 'NON_BUYER_EXCLUDED'
    when exists (
      select 1
      from product.platform_access_overrides pao
      where pao.user_id = s.user_id
        and pao.bypass_subscriptions = true
        and (pao.expires_at is null or pao.expires_at > now())
    ) then 'PLATFORM_OWNER_EXCLUDED'
    when s.status = 'active' and s.external_customer_id is not null
      then 'PAID_CUSTOMER'
    when s.status = 'trialing'
      and coalesce(s.trial_ends_at, now() + interval '1 day') > now()
      and coalesce(
        (s.metadata ->> 'counts_as_real_trial')::boolean,
        (s.external_customer_id is not null and s.external_subscription_id is not null)
      )
      then 'BUYER_TRIAL'
    when s.status = 'trialing'
      and coalesce(s.trial_ends_at, now() + interval '1 day') > now()
      and coalesce((s.metadata ->> 'access_kind') = 'ACCOUNT_PREVIEW', false)
      then 'ACCOUNT_PREVIEW'
    else 'OTHER'
  end as commercial_class
from product.subscriptions s;
