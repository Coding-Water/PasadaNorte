import csv
import json
import math
import os
from collections import defaultdict


def load_dataset(csv_path: str):
    train_rows = []
    test_rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            parsed = {
                "record_id": int(row["record_id"]),
                "week_number": int(row["week_number"]),
                "split": row["split"],
                "zone_code": row["zone_code"],
                "zone_name": row["zone_name"],
                "day_of_week": int(row["day_of_week"]),
                "is_weekday": int(row["is_weekday"]),
                "is_market_day": int(row["is_market_day"]),
                "hour_of_day": int(row["hour_of_day"]),
                "is_morning_rush": int(row["is_morning_rush"]),
                "is_lunch_dismissal": int(row["is_lunch_dismissal"]),
                "is_afternoon_dismissal": int(row["is_afternoon_dismissal"]),
                "temperature_c": float(row["temperature_c"]),
                "rain_mm": float(row["rain_mm"]),
                "lag_1h_requests": float(row["lag_1h_requests"]),
                "lag_prev_day_same_hour": float(row["lag_prev_day_same_hour"]),
                "lag_prev_week_same_hour": float(row["lag_prev_week_same_hour"]),
                "rolling_3h_mean": float(row["rolling_3h_mean"]),
                "y": float(row["hourly_passenger_requests_y"]),
                "logged_pilot_trips": int(row["logged_pilot_trips"]),
            }
            if parsed["split"] == "train":
                train_rows.append(parsed)
            else:
                test_rows.append(parsed)
    return train_rows, test_rows


def train_and_evaluate(csv_path: str, out_json_path: str):
    train_rows, test_rows = load_dataset(csv_path)

    # Fit spatiotemporal cell profile on Weeks 1-6 training split (5,040 zone-hours)
    bucket_sums = defaultdict(float)
    bucket_counts = defaultdict(int)

    for r in train_rows:
        is_rainy = 1 if r["rain_mm"] > 2.0 else 0
        key = (r["zone_code"], r["is_weekday"], r["is_market_day"], r["hour_of_day"], is_rainy)
        bucket_sums[key] += r["y"]
        bucket_counts[key] += 1

    # Fallback key without rain/market split if a specific combination was rare
    fallback_sums = defaultdict(float)
    fallback_counts = defaultdict(int)
    for r in train_rows:
        fkey = (r["zone_code"], r["is_weekday"], r["hour_of_day"])
        fallback_sums[fkey] += r["y"]
        fallback_counts[fkey] += 1

    # Evaluate on held-out Test Split (Weeks 7-8 = 1,680 zone-hours)
    y_true = []
    y_pred = []
    y_naive = []

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

        # Blend learned spatiotemporal profile with short-term rolling & seasonal lags
        pred = 0.85 * cell_mean + 0.10 * r["lag_prev_week_same_hour"] + 0.05 * r["rolling_3h_mean"]
        if cell_mean < 0.5:
            pred = 0.0

        y_true.append(r["y"])
        y_pred.append(max(0.0, round(pred, 2)))
        y_naive.append(r["lag_prev_week_same_hour"])

    n_test = len(y_true)
    abs_errors = [abs(yt - yp) for yt, yp in zip(y_true, y_pred)]
    sq_errors = [(yt - yp) ** 2 for yt, yp in zip(y_true, y_pred)]
    naive_abs_errors = [abs(yt - yn) for yt, yn in zip(y_true, y_naive)]

    mae_model = sum(abs_errors) / n_test
    mae_naive = max(1e-6, sum(naive_abs_errors) / n_test)

    # 1. MASE (Target < 1.00)
    mase = round(mae_model / mae_naive, 4)

    # 2. RMSE
    rmse = round(math.sqrt(sum(sq_errors) / n_test), 4)

    # 3. Volume-Weighted MAPE across all 1,680 test hours including y_t = 0 (Target <= 20.0%)
    wmape_percent = round((sum(abs_errors) / max(1e-6, sum(y_true))) * 100.0, 2)

    # 4. Non-Zero Subset MAPE (active hours with y_t >= 1)
    active_apes = [abs(yt - yp) / yt for yt, yp in zip(y_true, y_pred) if yt >= 1.0]
    nonzero_mape_percent = round((sum(active_apes) / max(1, len(active_apes))) * 100.0, 2)

    total_logged_trips = sum(r["logged_pilot_trips"] for r in train_rows) + sum(r["logged_pilot_trips"] for r in test_rows)

    results = {
        "dataset_summary": {
            "total_zones": 10,
            "operating_hours_per_day": 12,
            "total_days": 56,
            "total_zone_hour_records": len(train_rows) + len(test_rows),
            "training_zone_hour_records_weeks_1_to_6": len(train_rows),
            "test_zone_hour_records_weeks_7_to_8": len(test_rows),
            "logged_pilot_completed_trips": total_logged_trips,
        },
        "test_set_metrics_weeks_7_to_8": {
            "MASE": mase,
            "MASE_target": "< 1.00 (Outperforms Seasonal Naive Baseline)",
            "RMSE": rmse,
            "WMAPE_percent": wmape_percent,
            "WMAPE_target": "<= 20.0%",
            "NonZero_Subset_MAPE_percent": nonzero_mape_percent,
        },
    }

    with open(out_json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    print("=== PasadaNorte Objective 3 Demand Forecasting Evaluation (Weeks 7-8 Held-Out Test Set) ===")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(base_dir, "pasada_norte_zone_hour_dataset_6720.csv")
    out_json = os.path.join(base_dir, "model_evaluation_results.json")
    train_and_evaluate(csv_file, out_json)
