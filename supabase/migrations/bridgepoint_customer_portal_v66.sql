-- BridgePoint Intelligence v66 -- service-only Stripe customer lookup.
begin;
create or replace function public.bridgepoint_billing_customer_v66(p_user_id uuid)
returns jsonb language sql stable security definer
set search_path=pg_catalog,product
as $function$
 select jsonb_build_object('user_id',s.user_id,'stripe_customer_id',s.stripe_customer_id)
 from product.stripe_customers_v64 s where s.user_id=p_user_id;
$function$;
revoke execute on function public.bridgepoint_billing_customer_v66(uuid) from public,anon,authenticated;
grant execute on function public.bridgepoint_billing_customer_v66(uuid) to service_role;
commit;
