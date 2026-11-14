-- ============================================================================
-- Fix Supabase Security Advisor Warnings:
-- 1. Convert SECURITY DEFINER views to security_invoker = true (Postgres 15+)
-- 2. Revoke public PostgREST access to PostGIS system table spatial_ref_sys
-- ============================================================================

ALTER VIEW IF EXISTS public.valid_driver_telemetry
  SET (security_invoker = true);

ALTER VIEW IF EXISTS public.anonymized_zone_demand
  SET (security_invoker = true);

DO $$
BEGIN
  REVOKE ALL ON TABLE public.spatial_ref_sys FROM anon, authenticated;
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'Skipping REVOKE on public.spatial_ref_sys (owned by supabase_admin).';
END $$;
