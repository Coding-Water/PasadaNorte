-- Allow authenticated MINC Admins (and service_role) to permanently delete rejected users
-- and their staging files from the driver-documents storage bucket.

DROP POLICY IF EXISTS "Only MINC Admin can delete users" ON public.users;
CREATE POLICY "Only MINC Admin can delete users"
ON public.users FOR DELETE
USING (public.is_minc_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "driver_documents_delete_policy" ON storage.objects;
CREATE POLICY "driver_documents_delete_policy"
ON storage.objects FOR DELETE
USING (bucket_id = 'driver-documents' AND (public.is_minc_admin() OR auth.role() = 'service_role'));
