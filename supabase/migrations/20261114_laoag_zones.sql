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
  ('Z01', 'Public Market & Commercial Complex', 18.1972, 120.5925, 'market,public market,commercial'),
  ('Z02', 'MMSU CIT / CTE P. Gomez Campus', 18.1950, 120.5970, 'mmsu,cit,cte,p. gomez,gomez'),
  ('Z03', 'Laoag Sinking Bell Tower & Plaza', 18.1975, 120.5940, 'bell tower,plaza,aurora'),
  ('Z04', 'Laoag City General Hospital (LCGH)', 18.1920, 120.5890, 'lcgh,general hospital'),
  ('Z05', 'Gov. Roque B. Ablan Sr. Memorial Hospital', 18.1985, 120.6005, 'roque,ablan,memorial hospital'),
  ('Z06', 'Provincial Capitol & Aurora Park', 18.1985, 120.5915, 'capitol,provincial'),
  ('Z07', 'Northwestern University (NWU Corridor)', 18.2020, 120.5870, 'northwestern,nwu'),
  ('Z08', 'Robinsons Place / San Nicolas Boundary', 18.1885, 120.5935, 'robinsons,san nicolas'),
  ('Z09', 'Gilbert Bridge North Approach', 18.1945, 120.5905, 'gilbert,bridge'),
  ('Z10', 'Laoag International Airport / Gabu', 18.1905, 120.5760, 'airport,gabu')
ON CONFLICT (zone_code) DO NOTHING;
