-- Live 10-Zone ML Demand Forecasts & Model Evaluation Metrics
-- Populated hourly by GitHub Actions (ml_forecasting/sync_ml_to_supabase.py)

CREATE TABLE IF NOT EXISTS public.zone_demand_forecasts (
  zone_code TEXT PRIMARY KEY,
  zone_name TEXT NOT NULL,
  forecast_hour INT NOT NULL,
  predicted_demand DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  live_1h_requests INT NOT NULL DEFAULT 0,
  weather_rain_mm DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  model_version TEXT NOT NULL DEFAULT 'spatiotemporal-v1',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ml_model_metrics (
  id TEXT PRIMARY KEY,
  mase DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  rmse DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  wmape_percent DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  nonzero_mape_percent DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_live_trips INT NOT NULL DEFAULT 0,
  training_records INT NOT NULL DEFAULT 0,
  data_source TEXT NOT NULL DEFAULT 'pilot_plus_live',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.zone_demand_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ml_model_metrics ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'zone_demand_forecasts' AND policyname = 'Allow public read forecasts'
  ) THEN
    CREATE POLICY "Allow public read forecasts"
      ON public.zone_demand_forecasts
      FOR SELECT
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'ml_model_metrics' AND policyname = 'Allow public read ml metrics'
  ) THEN
    CREATE POLICY "Allow public read ml metrics"
      ON public.ml_model_metrics
      FOR SELECT
      USING (true);
  END IF;
END $$;
