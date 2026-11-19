-- Enforce unique phone_number across driver_applications (public.users already has UNIQUE on phone_number).
-- Deduplicates any older duplicate rows keeping the most recently updated entry first.

DELETE FROM public.driver_applications a
USING public.driver_applications b
WHERE a.phone_number = b.phone_number
  AND (
    COALESCE(a.updated_at, a.created_at) < COALESCE(b.updated_at, b.created_at)
    OR (COALESCE(a.updated_at, a.created_at) = COALESCE(b.updated_at, b.created_at) AND a.id::text < b.id::text)
  );

CREATE UNIQUE INDEX IF NOT EXISTS uq_driver_applications_phone_number
  ON public.driver_applications (phone_number);
