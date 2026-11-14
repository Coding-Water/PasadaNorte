-- ============================================================================
-- PASADANORTE: DOCUMENT EXPIRY TRACKING & RENEWAL GRACE PERIOD
-- Adds structured expiry dates and grace-period notification tracking
-- to driver_applications (RA 10173 data-minimization compliant).
-- ============================================================================

ALTER TABLE public.driver_applications
  ADD COLUMN IF NOT EXISTS orcr_expiry_date DATE,
  ADD COLUMN IF NOT EXISTS mtop_expiry_date DATE,
  ADD COLUMN IF NOT EXISTS nbi_expiry_date DATE,
  ADD COLUMN IF NOT EXISTS renewal_grace_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS renewal_notice_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS renewal_notice_message TEXT;

COMMENT ON COLUMN public.driver_applications.orcr_expiry_date IS
  'Extracted/confirmed LTO OR/CR renewal expiry date.';
COMMENT ON COLUMN public.driver_applications.mtop_expiry_date IS
  'Laoag City MTOP / Tricycle Franchise expiry date.';
COMMENT ON COLUMN public.driver_applications.renewal_grace_until IS
  'Admin-granted renewal grace period deadline before duty suspension.';
