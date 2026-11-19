-- Stores short-lived hashed SMS OTP codes dispatched via Android SMS Gateway.
-- RLS is enabled with NO public policies: only service_role (Edge Functions) can access.

CREATE TABLE IF NOT EXISTS public.sms_otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts int NOT NULL DEFAULT 0,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sms_otp_codes_phone_created
  ON public.sms_otp_codes (phone_number, created_at DESC);

ALTER TABLE public.sms_otp_codes ENABLE ROW LEVEL SECURITY;
