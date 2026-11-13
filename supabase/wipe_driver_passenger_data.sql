-- Wipe all Driver & Passenger test data while preserving Laoag Zones, TODA Terminals, Fare Matrix, and ML Forecasts.
-- Run this in the Supabase Dashboard -> SQL Editor before hot restarting.

DO $$
DECLARE
  tbl TEXT;
  tables_to_wipe TEXT[] := ARRAY[
    'public.incident_reports',
    'public.emergency_sos_alerts',
    'public.minc_trip_audit_logs',
    'public.driver_telemetry',
    'public.driver_completed_trips',
    'public.completed_trips',
    'public.otp_dispatch_logs',
    'public.driver_applications',
    'public.users'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables_to_wipe LOOP
    IF to_regclass(tbl) IS NOT NULL THEN
      EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE;', tbl);
    END IF;
  END LOOP;
END $$;

-- Optional: Also remove uploaded driver/passenger documents & selfies from Storage
DELETE FROM storage.objects WHERE bucket_id = 'driver-documents';
