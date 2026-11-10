-- ============================================================================
-- PASADANORTE: PILLAR 4 — ROLE-BASED ACCESS CONTROL (RBAC) & RATE-LIMITING SENTINEL
-- Laoag City Paratransit Dispatch & Municipal Regulation Ecosystem
-- Standards: ISO/IEC 25010:2023 Security & Integrity • Laoag City Ord. 2023-005
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ROLE-BASED ACCESS CONTROL (RBAC) FUNCTIONS
-- ----------------------------------------------------------------------------

-- Check if current authenticated actor is a TODA Admin
CREATE OR REPLACE FUNCTION public.is_toda_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()::text
          AND role = 'toda_admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Check if current authenticated actor has a specific role
CREATE OR REPLACE FUNCTION public.has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()::text
          AND role = required_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- 2. PRIVILEGE ESCALATION PREVENTION TRIGGER
-- Prohibits riders/drivers from elevating their own account role to admin
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_self_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
    -- If role is being changed to an administrative tier
    IF NEW.role IN ('minc_admin', 'toda_admin') AND OLD.role NOT IN ('minc_admin', 'toda_admin') THEN
        -- Only an existing MINC admin can grant admin privileges
        IF NOT public.is_minc_admin() THEN
            RAISE EXCEPTION 'RBAC ACCESS DENIED: Unauthorized attempt to elevate account role to % without MINC Super-Admin authorization.', NEW.role;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_escalation
BEFORE UPDATE OF role ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_self_role_escalation();

-- ----------------------------------------------------------------------------
-- 3. OTP RATE-LIMITING & TOLL-FRAUD DEFENSE TABLE
-- Ready for Dedicated Philippine SMS Gateway integration
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.otp_dispatch_logs (
    id BIGSERIAL PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    ip_address TEXT,
    gateway_provider TEXT DEFAULT 'SIMULATED_GATEWAY',
    status TEXT NOT NULL DEFAULT 'DELIVERED'
);

CREATE INDEX IF NOT EXISTS idx_otp_dispatch_phone_time 
ON public.otp_dispatch_logs (phone_number, dispatched_at);

ALTER TABLE public.otp_dispatch_logs ENABLE ROW LEVEL SECURITY;

-- Rate Limit Evaluation Function:
-- Max 3 OTP requests per phone number within a rolling 10-minute window.
-- Returns: allowed (boolean), attempts_used (int), and cooldown_seconds (int).
CREATE OR REPLACE FUNCTION public.check_otp_rate_limit(phone_input TEXT)
RETURNS JSON AS $$
DECLARE
    recent_count INT := 0;
    last_dispatched TIMESTAMPTZ;
    cooldown_rem INT := 0;
    max_allowed INT := 3;
    window_minutes INT := 10;
BEGIN
    SELECT COUNT(*), MAX(dispatched_at)
    INTO recent_count, last_dispatched
    FROM public.otp_dispatch_logs
    WHERE phone_number = phone_input
      AND dispatched_at > (timezone('utc'::text, now()) - (window_minutes || ' minutes')::interval);

    -- Calculate 60-second cooldown from last dispatch
    IF last_dispatched IS NOT NULL THEN
        cooldown_rem := GREATEST(0, 60 - EXTRACT(EPOCH FROM (timezone('utc'::text, now()) - last_dispatched))::INT);
    END IF;

    IF recent_count >= max_allowed THEN
        RETURN json_build_object(
            'allowed', false,
            'reason', 'RATE_LIMIT_EXCEEDED',
            'message', 'Maximum 3 OTP requests reached. Please wait 10 minutes before requesting again.',
            'recent_attempts', recent_count,
            'cooldown_seconds', cooldown_rem
        );
    ELSIF cooldown_rem > 0 THEN
        RETURN json_build_object(
            'allowed', false,
            'reason', 'COOLDOWN_ACTIVE',
            'message', CONCAT('Please wait ', cooldown_rem, ' seconds before requesting another code.'),
            'recent_attempts', recent_count,
            'cooldown_seconds', cooldown_rem
        );
    END IF;

    -- Record dispatch
    INSERT INTO public.otp_dispatch_logs (phone_number, status)
    VALUES (phone_input, 'DELIVERED');

    RETURN json_build_object(
        'allowed', true,
        'recent_attempts', recent_count + 1,
        'cooldown_seconds', 60
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.check_otp_rate_limit IS 
'Enforces strict rate-limiting on OTP dispatches (max 3 per 10m, 60s cooldown) to prevent toll fraud.';
