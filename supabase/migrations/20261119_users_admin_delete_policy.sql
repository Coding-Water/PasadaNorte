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

-- Allow deleting rejected users cleanly even when referenced by biometric_access_logs
ALTER TABLE public.biometric_access_logs
  DROP CONSTRAINT IF EXISTS biometric_access_logs_target_user_id_fkey;
ALTER TABLE public.biometric_access_logs
  ADD CONSTRAINT biometric_access_logs_target_user_id_fkey
  FOREIGN KEY (target_user_id)
  REFERENCES public.users(id)
  ON DELETE CASCADE;
