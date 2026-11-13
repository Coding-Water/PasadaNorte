"""
Hourly ML Demand Forecast & Evaluation Sync for PasadaNorte.

Designed to run via GitHub Actions (.github/workflows/ml_demand_refresh.yml)
using only the Python standard library. Reads live completed_trips from Supabase
and live Laoag City weather from Open-Meteo, evaluates the spatiotemporal
demand model, and upserts hourly forecasts into Supabase.
"""

import csv
import json
import math
import os
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone

PH_TZ = timezone(timedelta(hours=8))

ZONES = [
    ("Z01", "Public Market & Commercial Complex", ["market", "public market", "commercial"]),
    ("Z02", "MMSU CIT / CTE P. Gomez Campus", ["mmsu", "cit", "cte", "p. gomez", "gomez"]),
    ("Z03", "Laoag Sinking Bell Tower & Plaza", ["bell tower", "plaza", "aurora", "gilbert"]),
    ("Z04", "Laoag City General Hospital (LCGH)", ["lcgh", "general hospital"]),
    ("Z05", "Gov. Roque B. Ablan Sr. Memorial Hospital", ["roque", "ablan", "memorial hospital"]),
    ("Z06", "Provincial Capitol & Aurora Park", ["capitol", "provincial"]),
    ("Z07", "Northwestern University (NWU Corridor)", ["northwestern", "nwu"]),
    ("Z08", "Robinsons Place / San Nicolas Boundary", ["robinsons", "san nicolas"]),
    ("Z09", "Gilbert Bridge North Approach", ["gilbert bridge", "bridge"]),
    ("Z10", "Laoag International Airport / Gabu", ["airport", "gabu"]),
]


def http_json(url: str, method: str = "GET", headers: dict | None = None, payload: object = None):
    data = None
    req_headers = dict(headers or {})
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        req_headers.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw.strip() else None


def fetch_laoag_weather() -> tuple[float, float]:
    """Fetch live temperature (C) and rainfall (mm) for Laoag City via Open-Meteo."""
    url = (
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=18.1972&longitude=120.5925&current=temperature_2m,rain"
    )
    try:
        res = http_json(url)
        current = res.get("current", {}) if isinstance(res, dict) else {}
        return float(current.get("temperature_2m", 29.0)), float(current.get("rain", 0.0))
    except Exception as exc:
        print(f"[weather] Fallback to dry baseline ({exc})")
        return 29.0, 0.0


def fetch_active_zones(supabase_url: str, service_key: str) -> list[tuple[str, str, list[str]]]:
    """Load admin-configured 10 zones from Supabase laoag_zones, falling back to ZONES."""
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/laoag_zones?select=zone_code,zone_name,keywords&order=zone_code.asc"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    try:
        rows = http_json(endpoint, headers=headers) or []
        if rows:
            parsed = []
            for r in rows:
                kws = [k.strip().lower() for k in str(r.get("keywords", "")).split(",") if k.strip()]
                parsed.append((str(r["zone_code"]), str(r["zone_name"]), kws))
            return parsed
    except Exception as exc:
        print(f"[zones] Using default 10 zones ({exc})")
    return ZONES


def map_destination_to_zone(dropoff_text: str, zones: list[tuple[str, str, list[str]]]) -> str:
    text = (dropoff_text or "").lower()
    for code, _, keywords in zones:
        if code.lower() in text or any(k in text for k in keywords):
            return code
    return "Z01"


def fetch_live_trips(supabase_url: str, service_key: str, zones: list[tuple[str, str, list[str]]]) -> tuple[dict[str, int], int]:
    """Fetch completed_trips from Supabase and count trips in the last 60 minutes per zone."""
    endpoint = (
        f"{supabase_url.rstrip('/')}/rest/v1/completed_trips"
        "?select=dropoff_location,completed_at&order=completed_at.desc&limit=5000"
    )
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    try:
        rows = http_json(endpoint, headers=headers) or []
    except Exception as exc:
        print(f"[supabase] Could not read completed_trips ({exc}); assuming 0 live trips.")
        return {code: 0 for code, _, _ in zones}, 0

    now_utc = datetime.now(timezone.utc)
    cutoff = now_utc - timedelta(hours=1)
    live_1h = {code: 0 for code, _, _ in zones}

    for row in rows:
        ts_raw = row.get("completed_at")
        if not ts_raw:
            continue
        try:
            ts = datetime.fromisoformat(str(ts_raw).replace("Z", "+00:00"))
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        if ts >= cutoff:
            zone_code = map_destination_to_zone(str(row.get("dropoff_location", "")), zones)
            live_1h[zone_code] += 1

    return live_1h, len(rows)


def train_evaluate_and_predict(csv_path: str, hour_ph: int, is_weekday: int, is_market_day: int, rain_mm: float):
    train_rows = []
    test_rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            parsed = {
                "split": row["split"],
                "zone_code": row["zone_code"],
                "is_weekday": int(row["is_weekday"]),
                "is_market_day": int(row["is_market_day"]),
                "hour_of_day": int(row["hour_of_day"]),
                "rain_mm": float(row["rain_mm"]),
                "lag_prev_week_same_hour": float(row["lag_prev_week_same_hour"]),
                "rolling_3h_mean": float(row["rolling_3h_mean"]),
                "y": float(row["hourly_passenger_requests_y"]),
            }
            if parsed["split"] == "train":
                train_rows.append(parsed)
            else:
                test_rows.append(parsed)

    bucket_sums = defaultdict(float)
    bucket_counts = defaultdict(int)
    fallback_sums = defaultdict(float)
    fallback_counts = defaultdict(int)

    for r in train_rows:
        is_rainy = 1 if r["rain_mm"] > 2.0 else 0
        bucket_sums[(r["zone_code"], r["is_weekday"], r["is_market_day"], r["hour_of_day"], is_rainy)] += r["y"]
        bucket_counts[(r["zone_code"], r["is_weekday"], r["is_market_day"], r["hour_of_day"], is_rainy)] += 1
        fallback_sums[(r["zone_code"], r["is_weekday"], r["hour_of_day"])] += r["y"]
        fallback_counts[(r["zone_code"], r["is_weekday"], r["hour_of_day"])] += 1

    # Evaluate on held-out Weeks 7-8 split
    y_true, y_pred, y_naive = [], [], []
    for r in test_rows:
        is_rainy = 1 if r["rain_mm"] > 2.0 else 0
        key = (r["zone_code"], r["is_weekday"], r["is_market_day"], r["hour_of_day"], is_rainy)
        fkey = (r["zone_code"], r["is_weekday"], r["hour_of_day"])
        if bucket_counts[key] >= 2:
            cell_mean = bucket_sums[key] / bucket_counts[key]
        else:
            cell_mean = fallback_sums[fkey] / max(1, fallback_counts[fkey])
            if is_rainy and cell_mean > 0:
                cell_mean = cell_mean * 1.15 + 2.0
        pred = 0.85 * cell_mean + 0.10 * r["lag_prev_week_same_hour"] + 0.05 * r["rolling_3h_mean"]
        if cell_mean < 0.5:
            pred = 0.0
        y_true.append(r["y"])
        y_pred.append(max(0.0, round(pred, 2)))
        y_naive.append(r["lag_prev_week_same_hour"])

    n_test = max(1, len(y_true))
    abs_err = [abs(yt - yp) for yt, yp in zip(y_true, y_pred)]
    sq_err = [(yt - yp) ** 2 for yt, yp in zip(y_true, y_pred)]
    naive_err = [abs(yt - yn) for yt, yn in zip(y_true, y_naive)]

    mae_model = sum(abs_err) / n_test
    mae_naive = max(1e-6, sum(naive_err) / n_test)
    mase = round(mae_model / mae_naive, 4)
    rmse = round(math.sqrt(sum(sq_err) / n_test), 4)
    wmape = round((sum(abs_err) / max(1e-6, sum(y_true))) * 100.0, 2)
    active_apes = [abs(yt - yp) / yt for yt, yp in zip(y_true, y_pred) if yt >= 1.0]
    nonzero_mape = round((sum(active_apes) / max(1, len(active_apes))) * 100.0, 2)

    # Forecast for current Asia/Manila hour & weather
    is_rainy_now = 1 if rain_mm > 2.0 else 0
    predictions = {}
    for code, _, _ in ZONES:
        key = (code, is_weekday, is_market_day, hour_ph, is_rainy_now)
        fkey = (code, is_weekday, hour_ph)
        if bucket_counts[key] >= 2:
            val = bucket_sums[key] / bucket_counts[key]
        elif fallback_counts[fkey] > 0:
            val = fallback_sums[fkey] / fallback_counts[fkey]
            if is_rainy_now and val > 0:
                val = val * 1.15 + 2.0
        else:
            # Off-hours (outside 06:00-18:00 pilot window): low baseline scaled by rain
            val = 1.5 if is_rainy_now else 0.0
        predictions[code] = round(max(0.0, val), 1)

    metrics = {
        "mase": mase,
        "rmse": rmse,
        "wmape_percent": wmape,
        "nonzero_mape_percent": nonzero_mape,
        "training_records": len(train_rows),
    }
    return predictions, metrics


def upsert_supabase(supabase_url: str, service_key: str, table: str, rows: list[dict]):
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/{table}"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    http_json(endpoint, method="POST", headers=headers, payload=rows)


def main():
    supabase_url = os.environ["SUPABASE_URL"]
    service_key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

    now_ph = datetime.now(PH_TZ)
    hour_ph = now_ph.hour
    is_weekday = 1 if now_ph.weekday() < 5 else 0
    # Wed (2), Sat (5), Sun (6) are peak Laoag public market days
    is_market_day = 1 if now_ph.weekday() in (2, 5, 6) else 0

    temp_c, rain_mm = fetch_laoag_weather()
    active_zones = fetch_active_zones(supabase_url, service_key)
    live_1h, total_live_trips = fetch_live_trips(supabase_url, service_key, active_zones)

    csv_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "pasada_norte_zone_hour_dataset_6720.csv",
    )
    predictions, metrics = train_evaluate_and_predict(
        csv_path, hour_ph, is_weekday, is_market_day, rain_mm
    )

    now_iso = datetime.now(timezone.utc).isoformat()
    forecast_rows = []
    for code, name, _ in active_zones:
        # Blend ML forecast with live 1-hour observed requests when live trips exist
        blended = predictions[code] if total_live_trips == 0 else round(
            0.70 * predictions[code] + 0.30 * live_1h[code], 1
        )
        forecast_rows.append(
            {
                "zone_code": code,
                "zone_name": name,
                "forecast_hour": hour_ph,
                "predicted_demand": blended,
                "live_1h_requests": live_1h[code],
                "weather_rain_mm": round(rain_mm, 2),
                "model_version": "spatiotemporal-v1",
                "updated_at": now_iso,
            }
        )

    upsert_supabase(supabase_url, service_key, "zone_demand_forecasts", forecast_rows)
    upsert_supabase(
        supabase_url,
        service_key,
        "ml_model_metrics",
        [
            {
                "id": "latest",
                "mase": metrics["mase"],
                "rmse": metrics["rmse"],
                "wmape_percent": metrics["wmape_percent"],
                "nonzero_mape_percent": metrics["nonzero_mape_percent"],
                "total_live_trips": total_live_trips,
                "training_records": metrics["training_records"],
                "data_source": "github_actions_hourly_sync",
                "updated_at": now_iso,
            }
        ],
    )
    print(
        f"Synced 10 zones for PH hour {hour_ph:02d}:00 "
        f"(temp={temp_c}C, rain={rain_mm}mm, live_trips_total={total_live_trips})."
    )


if __name__ == "__main__":
    main()
