-- Allow mobile_client uploads and web_client signed URL inspection for driver-documents bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-documents', 'driver-documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "driver_documents_insert_policy" ON storage.objects;
CREATE POLICY "driver_documents_insert_policy"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "driver_documents_update_policy" ON storage.objects;
CREATE POLICY "driver_documents_update_policy"
ON storage.objects FOR UPDATE
USING (bucket_id = 'driver-documents')
WITH CHECK (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "driver_documents_select_policy" ON storage.objects;
CREATE POLICY "driver_documents_select_policy"
ON storage.objects FOR SELECT
USING (bucket_id = 'driver-documents');
