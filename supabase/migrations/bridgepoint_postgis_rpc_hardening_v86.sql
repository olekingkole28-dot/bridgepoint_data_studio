-- BridgePoint V86: re-close extension helper RPCs that are not part of the
-- customer API surface. public.spatial_ref_sys remains owned and managed by
-- the Supabase PostGIS extension; the migration role cannot alter that table.

revoke execute on function public.st_estimatedextent(text,text)
  from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text)
  from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text,text,text,boolean)
  from public, anon, authenticated;
