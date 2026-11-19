-- Enable public read and MINC Admin CRUD (INSERT/UPDATE/DELETE) on public.laoag_locations
-- so the Web Command Center "Places & Landmarks Pin Editor" can add, reposition, and delete
-- Ilocos Norte landmarks synced live to mobile clients.

ALTER TABLE IF EXISTS public.laoag_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "laoag_locations_public_read" ON public.laoag_locations;
CREATE POLICY "laoag_locations_public_read"
  ON public.laoag_locations
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "laoag_locations_minc_admin_write" ON public.laoag_locations;
CREATE POLICY "laoag_locations_minc_admin_write"
  ON public.laoag_locations
  FOR ALL
  USING (public.is_minc_admin() OR auth.role() = 'service_role')
  WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');
