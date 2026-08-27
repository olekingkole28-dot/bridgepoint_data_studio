-- BridgePoint V944: customer-safe core plan chooser; technology engines stay out of normal purchase UX.

create or replace function public.bridgepoint_customer_plans_v944()
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog','public','api','accounts','product'
set statement_timeout to '10s'
as $function$
declare
  uid uuid:=api.require_user();
  v_packages jsonb;
begin
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'package_key',p.package_key,'package_name',p.package_name,'description',p.description,
      'monthly_price',p.monthly_price,'yearly_price',p.yearly_price,'trial_days',p.trial_days,
      'featured',p.featured,'display_order',p.display_order,
      'best_for',p.configuration->>'best_for','includes',coalesce(p.configuration->'includes','[]'::jsonb),
      'delivery_status',coalesce(p.configuration->>'delivery_status','READY'),
      'purchase_mode',coalesce(p.configuration->>'purchase_mode','IMMEDIATE'),
      'checkout_ready',coalesce((p.configuration->>'checkout_ready')::boolean,false),
      'available_for_self_checkout',coalesce((p.configuration->>'available_for_self_checkout')::boolean,false),
      'customer_delivery_disclosure',p.configuration->>'customer_delivery_disclosure')
      order by p.display_order,p.package_name),'[]'::jsonb)
  into v_packages
  from product.packages p
  where coalesce(p.active,true)
    and p.package_key in ('homeowner','home','investor','commercial','company','all_intelligence')
    and upper(coalesce(p.configuration->>'delivery_status','READY')) in ('READY','LIMITED');

  return jsonb_build_object(
    'complete',true,'version',944,'generated_at',now(),'trial_days_default',7,
    'catalog_scope','CUSTOMER_CORE_PLANS','technology_products_hidden',true,
    'packages',v_packages,
    'disclosure','Technology engines, roadmap products and internal platform components are intentionally excluded from the normal customer plan chooser.');
end
$function$;

revoke all on function public.bridgepoint_customer_plans_v944() from public,anon;
grant execute on function public.bridgepoint_customer_plans_v944() to authenticated,service_role;
