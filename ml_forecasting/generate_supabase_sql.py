import json
import pathlib

data_path = pathlib.Path(r"c:\Users\MSI\Desktop\Flutter\PasadaNorte\ml_forecasting\laoag_city_complete_locations_dataset.json")
places = json.loads(data_path.read_text(encoding="utf-8"))

sql_lines = [
    "-- ==========================================================================",
    "-- PASADANORTE: Laoag City Complete Locations Dataset (2,365 Verified Places)",
    "-- Run this script in the Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)",
    "-- ==========================================================================",
    "",
    "CREATE EXTENSION IF NOT EXISTS pg_trgm;",
    "",
    "-- Reset any previous partial table",
    "DROP TABLE IF EXISTS public.laoag_locations CASCADE;",
    "",
    "CREATE TABLE public.laoag_locations (",
    "    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,",
    "    name TEXT NOT NULL,",
    "    latitude DOUBLE PRECISION NOT NULL,",
    "    longitude DOUBLE PRECISION NOT NULL,",
    "    zone_code VARCHAR(10) NOT NULL DEFAULT 'Z01',",
    "    category VARCHAR(50) DEFAULT 'landmark',",
    "    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()",
    ");",
    "",
    "-- Unique index on (name, latitude, longitude) so multiple locations sharing a common name (e.g. stores/streets) are preserved without conflict",
    "CREATE UNIQUE INDEX idx_laoag_locations_place_unique",
    "    ON public.laoag_locations (name, latitude, longitude);",
    "",
    "-- Enable Row Level Security (RLS)",
    "ALTER TABLE public.laoag_locations ENABLE ROW LEVEL SECURITY;",
    "",
    "-- Allow all authenticated and anonymous riders/drivers to search locations",
    'DROP POLICY IF EXISTS "Allow public read access on laoag_locations" ON public.laoag_locations;',
    'CREATE POLICY "Allow public read access on laoag_locations"',
    "    ON public.laoag_locations FOR SELECT USING (true);",
    "",
    "-- Trigram index for ultra-fast full-text and fuzzy search (<15ms)",
    "CREATE INDEX idx_laoag_locations_name_trgm",
    "    ON public.laoag_locations USING gin (name gin_trgm_ops);",
    "",
    "CREATE INDEX idx_laoag_locations_zone",
    "    ON public.laoag_locations (zone_code);",
    "",
    "-- Insert all 2,365 verified places in clean batches",
]

batch_size = 100
for i in range(0, len(places), batch_size):
    batch = places[i : i + batch_size]
    sql_lines.append("INSERT INTO public.laoag_locations (name, latitude, longitude, zone_code, category) VALUES")
    values = []
    for p in batch:
        name_esc = p["name"].replace("'", "''")
        lat = round(p["latitude"], 6)
        lon = round(p["longitude"], 6)
        zc = p["zone_code"].replace("'", "''")
        cat = (p.get("category") or "landmark").replace("'", "''")
        values.append(f"    ('{name_esc}', {lat}, {lon}, '{zc}', '{cat}')")
    sql_lines.append(",\n".join(values))
    sql_lines.append("ON CONFLICT (name, latitude, longitude) DO NOTHING;")
    sql_lines.append("")

sql_content = "\n".join(sql_lines)

for ws in [
    r"c:\Users\MSI\Desktop\Flutter\PasadaNorte\ml_forecasting\supabase_laoag_locations.sql",
    r"c:\Users\MSI\Desktop\Flutter\trikr\ml_forecasting\supabase_laoag_locations.sql",
]:
    pathlib.Path(ws).write_text(sql_content, encoding="utf-8")

print(f"Generated clean SQL script with {len(places)} locations successfully.")
