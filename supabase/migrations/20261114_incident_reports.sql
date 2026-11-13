-- Incident Reports & Resolution History for Resolved SOS & Dispatch Incidents
ALTER TABLE public.emergency_sos_alerts
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.incident_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sos_alert_id UUID REFERENCES public.emergency_sos_alerts(id) ON DELETE SET NULL,
  report_code TEXT NOT NULL,
  driver_name TEXT NOT NULL,
  body_number TEXT NOT NULL DEFAULT '',
  plate_number TEXT NOT NULL DEFAULT '',
  toda TEXT NOT NULL DEFAULT '',
  contact TEXT NOT NULL DEFAULT '',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location_name TEXT NOT NULL DEFAULT 'Laoag City Paratransit Route',
  alert_reason TEXT NOT NULL DEFAULT 'DRIVER_TRIGGERED_EMERGENCY_SOS',
  incident_category TEXT NOT NULL DEFAULT 'False Alarm / Accidental Trigger',
  severity TEXT NOT NULL DEFAULT 'LOW',
  outcome TEXT NOT NULL DEFAULT 'Driver Safe — Stand Down',
  action_taken TEXT NOT NULL DEFAULT '',
  resolution_notes TEXT NOT NULL DEFAULT '',
  resolved_by TEXT NOT NULL DEFAULT 'MINC Emergency Dispatcher',
  triggered_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_incident_reports_resolved_at
  ON public.incident_reports (resolved_at DESC);

CREATE INDEX IF NOT EXISTS idx_incident_reports_sos_alert_id
  ON public.incident_reports (sos_alert_id);

ALTER TABLE public.incident_reports ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'incident_reports' AND policyname = 'Allow read incident_reports'
  ) THEN
    CREATE POLICY "Allow read incident_reports"
      ON public.incident_reports FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'incident_reports' AND policyname = 'Allow insert incident_reports'
  ) THEN
    CREATE POLICY "Allow insert incident_reports"
      ON public.incident_reports FOR INSERT WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'incident_reports' AND policyname = 'Allow update incident_reports'
  ) THEN
    CREATE POLICY "Allow update incident_reports"
      ON public.incident_reports FOR UPDATE USING (true) WITH CHECK (true);
  END IF;
END $$;
