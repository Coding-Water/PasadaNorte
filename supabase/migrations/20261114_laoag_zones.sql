-- Configurable 10 Laoag City Zones for Heatmap & ML Demand Forecasting
CREATE TABLE IF NOT EXISTS public.laoag_zones (
  zone_code TEXT PRIMARY KEY,
  zone_name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  radius_meters DOUBLE PRECISION NOT NULL DEFAULT 320.0,
  keywords TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.laoag_zones
  ADD COLUMN IF NOT EXISTS radius_meters DOUBLE PRECISION NOT NULL DEFAULT 320.0;

ALTER TABLE public.laoag_zones ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'laoag_zones' AND policyname = 'Allow read laoag_zones'
  ) THEN
    CREATE POLICY "Allow read laoag_zones"
      ON public.laoag_zones FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'laoag_zones' AND policyname = 'Allow write laoag_zones'
  ) THEN
    CREATE POLICY "Allow write laoag_zones"
      ON public.laoag_zones FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

INSERT INTO public.laoag_zones (zone_code, zone_name, lat, lng, keywords)
VALUES
  ('Z01', 'Public Market', 18.19454, 120.59597, 'market,public market,commercial'),
  ('Z02', 'MMSU CIT / CTE P. Gomez Campus', 18.20754, 120.59425, 'mmsu,cit,cte,p. gomez,gomez'),
  ('Z03', 'Ilocos Norte National Highschool', 18.20422, 120.59175, 'innhs,ilocos norte national highschool,highschool'),
  ('Z04', 'Laoag City General Hospital (LCGH)', 18.18838, 120.57720, 'lcgh,general hospital'),
  ('Z05', 'Gov. Roque B. Ablan Sr. Memorial Hospital', 18.19971, 120.60168, 'roque,ablan,memorial hospital'),
  ('Z06', 'Provincial Capitol & Aurora Park', 18.19574, 120.59356, 'capitol,provincial,aurora park'),
  ('Z07', 'Northwestern University', 18.18529, 120.56619, 'northwestern,nwu'),
  ('Z08', 'SM City Laoag', 18.18808, 120.58552, 'sm,sm city laoag,robinsons,san nicolas'),
  ('Z09', 'Maharlika', 18.20106, 120.58155, 'maharlika,gilbert,bridge'),
  ('Z10', 'Laoag International Airport / Gabu', 18.18268, 120.53405, 'airport,gabu')
ON CONFLICT (zone_code) DO UPDATE SET
  zone_name = EXCLUDED.zone_name,
  lat = EXCLUDED.lat,
  lng = EXCLUDED.lng,
  keywords = EXCLUDED.keywords,
  updated_at = NOW();
