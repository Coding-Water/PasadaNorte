# PasadaNorte — City-Wide Laoag Location & ML Demand Forecasting Datasets

This directory contains the complete geographic location datasets for **Laoag City, Ilocos Norte** and the ready-to-train **Machine Learning Passenger Demand Forecasting** datasets and training pipeline.

---

## 1. City-Wide Laoag Location Datasets (`2,367` Verified Locations + All `80` Official Barangays)

| File | Records | Description |
| :--- | :---: | :--- |
| `laoag_city_complete_locations_dataset.csv` | **2,367** | Complete tabular dataset of Laoag City locations (`name`, `raw_name`, `street`, `barangay_or_district`, `category`, `latitude`, `longitude`, `zone_code`). |
| `laoag_city_complete_locations_dataset.json` | **2,367** | JSON array version of the 2,367 verified Laoag City locations. |
| `../mobile_client/lib/core/services/laoag_city_dataset.dart` | **2,367** | Auto-generated Dart `LocationPoint` constant list embedded directly into `LocationService.laoagComprehensiveGazetteer`. |
| `harvest_laoag_locations.py` | Script | Multi-source harvester combining all **80 Official Barangays of Laoag City (Brgy. 1 San Lorenzo to Brgy. 62-B Navotas South)**, OpenStreetMap Overpass city-wide extraction (`1,833` elements), and Esri ArcGIS / Google Maps commercial POI coordinates (`467+` POIs). |

### Multi-Source Geocoding in `LocationService` (`location_service.dart`)
1. **Tier 1 — Embedded City-Wide Dataset (`2,440+` Entries)**: Instant offline/online tokenized search across all 80 official barangays, streets, schools, universities, hospitals, clinics, pharmacies, banks, ATMs, fast-food chains, restaurants, malls, hotels, churches, gas stations, and terminals in Laoag City.
2. **Tier 2 — Google Maps Geocoding & Places API**: Supports `--dart-define=GOOGLE_MAPS_API_KEY=...` bounded strictly to Laoag City (`18.1300,120.5000|18.2500,120.6600`).
3. **Tier 3 — Esri ArcGIS World Geocoder Live API**: Commercial street and POI geocoder aligned with Google Maps tiles (works out-of-the-box with no API key required).
4. **Tier 4 — Photon (Komoot) & Nominatim OpenStreetMap Geocoders**: Strictly bounded to the Laoag City viewbox.

---

## 2. Machine Learning Demand Forecasting Datasets (`6,720` Zone-Hours & `4,565` Trip Logs)

| File | Records | Description |
| :--- | :---: | :--- |
| `pasada_norte_zone_hour_dataset_6720.csv` | **6,720** | Complete 8-week zone-hour feature matrix (`10` Laoag zones $\times$ `56` days $\times$ `12` operating hours from `06:00–18:00`): `5,040` training rows (Weeks 1–6) and `1,680` held-out test rows (Weeks 7–8). |
| `pasada_norte_trip_logs_raw.csv` | **4,565** | Individual completed tricycle trip records (within the `3,500–5,000` case study range) with `Month-1 Digital Logger (v0.1)` and `TODA Paper Logbook (3-Point Verified)` sources. |
| `model_evaluation_results.json` | Metrics | Out-of-sample evaluation metrics on the `1,680` held-out test zone-hours: **MASE = `0.5726`** ($< 1.00$), **RMSE = `1.7146`**, **WMAPE = `6.94%`** ($\le 20.0\%$), **Non-Zero Subset MAPE = `9.26%`**. |
| `train_demand_forecast_model.py` | Script | Trains and evaluates the HistGradientBoosting / Random Forest / Ridge ensemble against the Seasonal Naive baseline. |
