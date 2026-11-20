-- 1. Fix purge_expired_biometric_data() SQL 42501 error (Storage deletion is done by Edge Function REST API).
-- 2. Add resubmit_rider_verification() RPC so riders can submit re-uploaded IDs / face scans under strict RLS.
-- 3. Add BEFORE INSERT trigger blocking forged pre-approved onboarding rows from anon clients.

CREATE OR REPLACE FUNCTION public.purge_expired_biometric_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_72h_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '72 hours';
    v_24h_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '24 hours';
    v_12m_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '12 months';
    v_purged_user_media INT := 0;
    v_purged_inactive_templates INT := 0;
BEGIN
    WITH cleared_media AS (
        UPDATE public.users
        SET id_photo_url = NULL,
            verification_images_deleted = TRUE
        WHERE verification_images_deleted = FALSE
          AND created_at < v_72h_cutoff
          AND (id_photo_url IS NOT NULL OR verification_status IN ('approved', 'rejected'))
        RETURNING id
    )
    SELECT COUNT(*) INTO v_purged_user_media FROM cleared_media;

    IF to_regclass('public.facial_embeddings') IS NOT NULL THEN
        WITH deleted_templates AS (
            DELETE FROM public.facial_embeddings fe
            USING public.users u
            WHERE fe.user_id = u.id
              AND (
                  (u.account_closed_at IS NOT NULL AND u.account_closed_at < v_24h_cutoff)
                  OR (u.consent_withdrawn_at IS NOT NULL AND u.consent_withdrawn_at < v_24h_cutoff)
                  OR (u.last_active_at < v_12m_cutoff)
              )
            RETURNING fe.user_id
        )
        SELECT COUNT(*) INTO v_purged_inactive_templates FROM deleted_templates;
    END IF;

    IF to_regclass('public.biometric_access_logs') IS NOT NULL THEN
        BEGIN
            INSERT INTO public.biometric_access_logs (target_user_id, action_type, logged_at)
            VALUES (
                NULL,
                format(
                    'AUTO_PURGE_COMPLETED (user_media=%s, inactive_templates=%s)',
                    v_purged_user_media,
                    v_purged_inactive_templates
                ),
                timezone('utc'::text, now())
            );
        EXCEPTION WHEN others THEN
            NULL;
        END;
    END IF;

    RETURN jsonb_build_object(
        'purged_staging_objects', 0,
        'purged_user_media', v_purged_user_media,
        'purged_inactive_templates', v_purged_inactive_templates,
        'executed_at', timezone('utc'::text, now())
    );
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_biometric_data() FROM PUBLIC;

-- shortcut: phone-scoped RPC instead of full Supabase Auth JWT per rider until Phase 2 Auth upgrade
CREATE OR REPLACE FUNCTION public.resubmit_rider_verification(
    p_phone TEXT,
    p_id_photo_url TEXT DEFAULT NULL,
    p_ai_similarity NUMERIC DEFAULT NULL,
    p_latency_ms INT DEFAULT NULL,
    p_mark_pending BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated INT := 0;
BEGIN
    UPDATE public.users
    SET id_photo_url = COALESCE(NULLIF(p_id_photo_url, ''), id_photo_url),
        ai_similarity_percent = COALESCE(p_ai_similarity, ai_similarity_percent),
        verification_latency_ms = COALESCE(p_latency_ms, verification_latency_ms),
        verification_status = CASE WHEN p_mark_pending THEN 'pending' ELSE verification_status END,
        admin_review_note = CASE
            WHEN p_mark_pending THEN 'Passenger completed requested resubmission for admin re-review.'
            ELSE admin_review_note
        END
    WHERE phone_number = p_phone
      AND role = 'rider'
      AND verification_status IN ('re_upload_requested', 'resubmission_requested', 'pending');

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resubmit_rider_verification(TEXT, TEXT, NUMERIC, INT, BOOLEAN) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_onboarding_pending_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT (public.is_minc_admin() OR auth.role() = 'service_role') THEN
        IF TG_TABLE_NAME = 'users' AND NEW.role = 'rider' THEN
            NEW.verification_status := 'pending';
        ELSIF TG_TABLE_NAME = 'driver_applications' THEN
            NEW.application_status := 'submitted';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_enforce_pending ON public.users;
CREATE TRIGGER trg_users_enforce_pending
BEFORE INSERT ON public.users
FOR EACH ROW EXECUTE FUNCTION public.enforce_onboarding_pending_status();

DROP TRIGGER IF EXISTS trg_driver_apps_enforce_submitted ON public.driver_applications;
CREATE TRIGGER trg_driver_apps_enforce_submitted
BEFORE INSERT ON public.driver_applications
FOR EACH ROW EXECUTE FUNCTION public.enforce_onboarding_pending_status();
