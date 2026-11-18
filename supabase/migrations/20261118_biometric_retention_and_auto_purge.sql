-- ============================================================================
-- PASADANORTE: BIOMETRIC RETENTION & AUTOMATED PURGE SCHEDULE
-- RA 10173 (Data Privacy Act of 2012) • NPC Circular No. 2023-03
-- Targets:
--   1. Immediate raw-image purge on auto-approval / admin decision
--   2. <= 72-hour automated purge for unresolved manual-review staging images
--   3. <= 24-hour purge on account closure / consent withdrawal
--   4. 12-month inactivity purge for stored facial templates
-- ============================================================================

-- 1. Ensure retention & activity tracking columns exist on public.users
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    ADD COLUMN IF NOT EXISTS consent_withdrawn_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS account_closed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verification_images_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS id_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

-- 2. Scheduled Retention & Purge Function (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.purge_expired_biometric_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
    v_72h_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '72 hours';
    v_24h_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '24 hours';
    v_12m_cutoff TIMESTAMPTZ := timezone('utc'::text, now()) - INTERVAL '12 months';
    v_purged_staging_objects INT := 0;
    v_purged_user_media INT := 0;
    v_purged_inactive_templates INT := 0;
BEGIN
    -- A. Purge unresolved manual-review raw images older than 72 hours
    --    from private staging buckets ('biometric-vault', 'id-documents')
    WITH deleted_objects AS (
        DELETE FROM storage.objects
        WHERE bucket_id IN ('biometric-vault', 'id-documents')
          AND created_at < v_72h_cutoff
        RETURNING id
    )
    SELECT COUNT(*) INTO v_purged_staging_objects FROM deleted_objects;

    -- Mark staging media URLs cleared on users whose raw images exceeded 72h
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

    -- B. Purge templates & records for closed accounts / consent withdrawals (> 24h)
    --    or accounts inactive for > 12 months
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

    -- C. Record automated purge execution in biometric_access_logs if present
    IF to_regclass('public.biometric_access_logs') IS NOT NULL THEN
        INSERT INTO public.biometric_access_logs (target_user_id, action_type, logged_at)
        VALUES (
            'SYSTEM_RETENTION_SCHEDULER',
            format(
                'AUTO_PURGE_COMPLETED (staging_objects=%s, user_media=%s, inactive_templates=%s)',
                v_purged_staging_objects,
                v_purged_user_media,
                v_purged_inactive_templates
            ),
            timezone('utc'::text, now())
        );
    END IF;

    RETURN jsonb_build_object(
        'purged_staging_objects', v_purged_staging_objects,
        'purged_user_media', v_purged_user_media,
        'purged_inactive_templates', v_purged_inactive_templates,
        'executed_at', timezone('utc'::text, now())
    );
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_biometric_data() FROM PUBLIC;

-- 3. Schedule via pg_cron when available in the Supabase instance
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Unschedule prior jobs with the same names to keep migration idempotent
        PERFORM cron.unschedule(jobid)
        FROM cron.job
        WHERE jobname IN (
            'pasadanorte-72h-raw-image-purge',
            'pasadanorte-daily-retention-purge'
        );

        -- Hourly check to guarantee <= 72-hour staging raw-image purge SLA
        PERFORM cron.schedule(
            'pasadanorte-72h-raw-image-purge',
            '0 * * * *',
            'SELECT public.purge_expired_biometric_data();'
        );

        -- Daily 03:00 UTC check for 24h closure/consent & 12-month inactivity purge
        PERFORM cron.schedule(
            'pasadanorte-daily-retention-purge',
            '0 3 * * *',
            'SELECT public.purge_expired_biometric_data();'
        );
    END IF;
END $$;
