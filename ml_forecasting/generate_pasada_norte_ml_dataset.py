import csv
import math
import os
import random
from datetime import datetime, timedelta

random.seed(42)

ZONES = [
    ("Z01", "Laoag Central Terminal & Public Market", 18.194096, 120.595856, "commercial_terminal"),
    ("Z02", "Mariano Marcos State University (MMSU CIT/CTE)", 18.203595, 120.593643, "university"),
    ("Z03", "Laoag Sinking Bell Tower & City Plaza", 18.194837, 120.593428, "civic_plaza"),
    ("Z04", "Laoag City General Hospital (LCGH)", 18.188288, 120.577282, "hospital"),
    ("Z05", "GRBASMH & INCAT School Gate", 18.199532, 120.601269, "school_hospital"),
    ("Z06", "Ilocos Norte Provincial Capitol & Aurora Park", 18.196379, 120.593120, "civic_capitol"),
    ("Z07", "Northwestern University (NWU) Corridor", 18.186885, 120.570424, "university"),
    ("Z08", "Robinsons Place Ilocos Commercial Hub", 18.179153, 120.592467, "mall_commercial"),
    ("Z09", "Partas Bus Terminal & Gilbert Bridge North", 18.199593, 120.584575, "transit_terminal"),
    ("Z10", "Laoag International Airport (LAO) Corridor", 18.182039, 120.533831, "airport"),
]

# 56 days (8 weeks) x 12 operating hours (6:00 AM to 6:00 PM) x 10 zones = 6,720 zone-hours
START_DATE = datetime(2026, 9, 7)  # Monday, Week 1
OPERATING_HOURS = list(range(6, 18))  # Hours 6..17 (12 operating hours per day)


def calibrated_zone_demand(zone_code: str, hour: int, day_of_week: int, rain_mm: float, is_holiday_event: int) -> float:
    is_weekday = day_of_week < 5
    is_morning_rush = 7 <= hour <= 9
    is_lunch_dismissal = 11 <= hour <= 13
    is_afternoon_dismissal = 16 <= hour <= 17

    if zone_code == "Z01":  # Laoag Central Terminal & Public Market
        base = 36 if is_morning_rush else (28 if is_lunch_dismissal else (38 if is_afternoon_dismissal else 22))
        if day_of_week in (2, 5, 6):  # Market days (Wed/Sat/Sun)
            base += 4
    elif zone_code == "Z02":  # MMSU Laoag Campus
        if not is_weekday:
            base = 4  # < 5 requests on weekends -> suppressed by k=5 privacy rule
        else:
            base = 31 if is_morning_rush else (26 if is_lunch_dismissal else (34 if is_afternoon_dismissal else 14))
    elif zone_code == "Z03":  # Laoag City Plaza & Sinking Bell Tower
        base = 24 if is_afternoon_dismissal else (19 if is_lunch_dismissal else 15)
    elif zone_code == "Z04":  # Laoag City General Hospital (LCGH)
        base = 18 if is_morning_rush else 12
    elif zone_code == "Z05":  # GRBASMH & INCAT School Gate
        if not is_weekday:
            base = 0  # Zero-demand hour on weekends (y_t = 0)
        else:
            base = 29 if is_morning_rush else (33 if is_lunch_dismissal else (35 if is_afternoon_dismissal else 11))
    elif zone_code == "Z06":  # Provincial Capitol & Aurora Park
        if not is_weekday:
            base = 8
        else:
            base = 25 if (is_morning_rush or is_afternoon_dismissal) else 14
    elif zone_code == "Z07":  # Northwestern University Corridor
        if not is_weekday:
            base = 3
        else:
            base = 23 if (is_morning_rush or is_afternoon_dismissal) else 10
    elif zone_code == "Z08":  # Robinsons Place Commercial Hub
        base = 32 if is_afternoon_dismissal else (24 if is_lunch_dismissal else 16)
        if not is_weekday:
            base += 5
    elif zone_code == "Z09":  # Partas Bus Terminal & Gilbert Bridge North
        base = 20 if (is_morning_rush or is_afternoon_dismissal) else 9
    elif zone_code == "Z10":  # Laoag International Airport (LAO) Corridor
        if hour in (8, 15):
            base = 14
        elif hour in (11, 17):
            base = 0  # Zero-demand hour between flights (y_t = 0)
        else:
            base = 3  # < 5 requests -> suppressed on heatmap
    else:
        base = 6

    if rain_mm > 2.0 and base > 0:
        base = base * 1.15 + 2.0
    if is_holiday_event and base > 0:
        base = base * 1.12
    return float(base)


def generate_datasets(out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    zone_history = {z[0]: [] for z in ZONES}
    zone_hour_rows = []
    raw_trip_rows = []
    trip_counter = 1

    for day_idx in range(56):
        current_date = START_DATE + timedelta(days=day_idx)
        week_num = (day_idx // 7) + 1
        split = "train" if week_num <= 6 else "test"
        day_of_week = current_date.weekday()  # 0=Mon .. 6=Sun
        is_weekday = 1 if day_of_week < 5 else 0
        is_market_day = 1 if day_of_week in (2, 5, 6) else 0

        for hour in OPERATING_HOURS:
            temp_c = round(26.5 + 5.2 * math.sin((hour - 6) * math.pi / 12.0) + random.uniform(-0.7, 0.7), 1)
            rain_mm = round(random.choice([0.0, 0.0, 0.0, 0.0, 1.5, 4.2, 7.5]), 1) if hour >= 13 else 0.0

            for z_code, z_name, z_lat, z_lon, z_type in ZONES:
                hist = zone_history[z_code]
                expected = calibrated_zone_demand(z_code, hour, day_of_week, rain_mm, is_market_day)

                # Realistic stochastic fluctuation around expected demand
                if expected == 0.0:
                    y_requests = 0
                else:
                    y_requests = max(0, int(round(expected + random.gauss(0, max(0.8, expected * 0.075)))))

                lag_1h = hist[-1] if len(hist) >= 1 else y_requests
                lag_prev_day = hist[-12] if len(hist) >= 12 else y_requests
                # Add realistic week-to-week weather/event variance so seasonal naive baseline has realistic error
                lag_prev_week = hist[-84] if len(hist) >= 84 else max(0, int(round(y_requests + random.gauss(0, 3.2))))
                rolling_3h = round(sum(hist[-3:]) / len(hist[-3:]), 2) if len(hist) >= 1 else float(y_requests)

                hist.append(y_requests)

                # Sample ~3.8% of total citywide demand as logged pilot fleet trips so total logged trips = ~4,300 (within 3,500-5,000 range)
                logged_trips_in_cell = 0
                for _ in range(y_requests):
                    if random.random() < 0.039:
                        logged_trips_in_cell += 1

                zone_hour_rows.append({
                    "record_id": len(zone_hour_rows) + 1,
                    "date": current_date.strftime("%Y-%m-%d"),
                    "week_number": week_num,
                    "split": split,
                    "zone_code": z_code,
                    "zone_name": z_name,
                    "zone_type": z_type,
                    "latitude": z_lat,
                    "longitude": z_lon,
                    "day_of_week": day_of_week,
                    "is_weekday": is_weekday,
                    "is_market_day": is_market_day,
                    "hour_of_day": hour,
                    "is_morning_rush": 1 if 7 <= hour <= 9 else 0,
                    "is_lunch_dismissal": 1 if 11 <= hour <= 13 else 0,
                    "is_afternoon_dismissal": 1 if 16 <= hour <= 17 else 0,
                    "temperature_c": temp_c,
                    "rain_mm": rain_mm,
                    "lag_1h_requests": lag_1h,
                    "lag_prev_day_same_hour": lag_prev_day,
                    "lag_prev_week_same_hour": lag_prev_week,
                    "rolling_3h_mean": rolling_3h,
                    "hourly_passenger_requests_y": y_requests,
                    "k_anonymity_visible": 1 if y_requests >= 5 else 0,
                    "logged_pilot_trips": logged_trips_in_cell,
                })

                for _ in range(logged_trips_in_cell):
                    dest_zone = random.choice([z for z in ZONES if z[0] != z_code])
                    minute = random.randint(0, 59)
                    sec = random.randint(0, 59)
                    ts_str = f"{current_date.strftime('%Y-%m-%d')} {hour:02d}:{minute:02d}:{sec:02d}"
                    dist_km = round(random.uniform(0.8, 4.8), 2)
                    category = random.choices(["Regular", "Student", "Senior Citizen", "PWD"], weights=[0.58, 0.26, 0.11, 0.05])[0]
                    gross_fare = 15.0 + max(0.0, dist_km - 1.0) * 5.0
                    final_fare = round(gross_fare * (0.80 if category != "Regular" else 1.0), 2)
                    source = "Month-1 Digital Logger (v0.1)" if week_num <= 4 and random.random() < 0.65 else "TODA Paper Logbook (3-Point Verified)"
                    raw_trip_rows.append({
                        "trip_id": f"PN-2026-{trip_counter:05d}",
                        "timestamp": ts_str,
                        "week_number": week_num,
                        "origin_zone_code": z_code,
                        "origin_zone_name": z_name,
                        "destination_zone_code": dest_zone[0],
                        "destination_zone_name": dest_zone[1],
                        "passenger_count": random.choices([1, 2, 3], weights=[0.55, 0.35, 0.10])[0],
                        "passenger_category": category,
                        "distance_km": dist_km,
                        "fare_php": final_fare,
                        "source_type": source,
                    })
                    trip_counter += 1

    zone_hour_csv = os.path.join(out_dir, "pasada_norte_zone_hour_dataset_6720.csv")
    with open(zone_hour_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(zone_hour_rows[0].keys()))
        writer.writeheader()
        writer.writerows(zone_hour_rows)

    raw_trips_csv = os.path.join(out_dir, "pasada_norte_trip_logs_raw.csv")
    with open(raw_trips_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(raw_trip_rows[0].keys()))
        writer.writeheader()
        writer.writerows(raw_trip_rows)

    print(f"Generated {len(zone_hour_rows)} zone-hour rows -> {zone_hour_csv}")
    print(f"  Train rows (Weeks 1-6): {sum(1 for r in zone_hour_rows if r['split'] == 'train')}")
    print(f"  Test rows  (Weeks 7-8): {sum(1 for r in zone_hour_rows if r['split'] == 'test')}")
    print(f"Generated {len(raw_trip_rows)} individual logged pilot trips (target 3,500-5,000) -> {raw_trips_csv}")


if __name__ == "__main__":
    out_dir = os.path.dirname(os.path.abspath(__file__))
    generate_datasets(out_dir)
