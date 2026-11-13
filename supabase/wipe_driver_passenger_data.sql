-- Wipe all Driver & Passenger test data while preserving Laoag Zones, TODA Terminals, Fare Matrix, and ML Forecasts.
-- Run this in the Supabase Dashboard -> SQL Editor before hot restarting.
-- Note: To clear uploaded files in Storage, use Supabase Dashboard -> Storage -> driver-documents -> Empty bucket.

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
