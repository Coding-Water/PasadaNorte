-- ============================================================================
-- PasadaNorte Security Hardening Migration (2026-11-14)
-- Tightens overly permissive RLS policies on laoag_zones, incident_reports,
-- driver_applications, and driver-documents storage bucket.
--
-- Prerequisites:
-- 1. Create a Supabase Auth admin user with app_metadata: {"role": "minc_admin"}
--    before applying this migration so the Web Command Center can authenticate.
-- ============================================================================

-- 1. public.laoag_zones: public read, MINC Admin / service_role write only
DROP POLICY IF EXISTS "Allow write laoag_zones" ON public.laoag_zones;
DROP POLICY IF EXISTS "Only MINC Admin can write laoag_zones" ON public.laoag_zones;
CREATE POLICY "Only MINC Admin can write laoag_zones"
ON public.laoag_zones FOR ALL
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

-- 2. public.incident_reports: allow SOS/incident submission, restrict read/update to MINC Admin
DROP POLICY IF EXISTS "Allow read incident_reports" ON public.incident_reports;
CREATE POLICY "Allow read incident_reports"
ON public.incident_reports FOR SELECT
USING (public.is_minc_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow update incident_reports" ON public.incident_reports;
CREATE POLICY "Allow update incident_reports"
ON public.incident_reports FOR UPDATE
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

-- 3. public.driver_applications: keep onboarding insert & read, restrict admin updates/deletes
DROP POLICY IF EXISTS "driver_applications_owner_policy" ON public.driver_applications;

DROP POLICY IF EXISTS "driver_applications_insert_policy" ON public.driver_applications;
CREATE POLICY "driver_applications_insert_policy"
ON public.driver_applications FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "driver_applications_select_policy" ON public.driver_applications;
CREATE POLICY "driver_applications_select_policy"
ON public.driver_applications FOR SELECT
USING (true);

DROP POLICY IF EXISTS "driver_applications_admin_update_policy" ON public.driver_applications;
CREATE POLICY "driver_applications_admin_update_policy"
ON public.driver_applications FOR UPDATE
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "driver_applications_admin_delete_policy" ON public.driver_applications;
CREATE POLICY "driver_applications_admin_delete_policy"
ON public.driver_applications FOR DELETE
USING (public.is_minc_admin() OR auth.role() = 'service_role');

-- 4. storage.objects (driver-documents): keep onboarding upload, restrict read/update/delete
DROP POLICY IF EXISTS "driver_documents_update_policy" ON storage.objects;
CREATE POLICY "driver_documents_update_policy"
ON storage.objects FOR UPDATE
USING (bucket_id = 'driver-documents' AND (public.is_minc_admin() OR auth.role() = 'service_role'))
WITH CHECK (bucket_id = 'driver-documents' AND (public.is_minc_admin() OR auth.role() = 'service_role'));

DROP POLICY IF EXISTS "driver_documents_select_policy" ON storage.objects;
CREATE POLICY "driver_documents_select_policy"
ON storage.objects FOR SELECT
USING (bucket_id = 'driver-documents' AND (public.is_minc_admin() OR auth.role() = 'service_role' OR auth.role() = 'authenticated'));
