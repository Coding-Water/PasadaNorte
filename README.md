# PasadaNorte — Laoag City Paratransit Dispatch & Regulation Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Supabase PostGIS](https://img.shields.io/badge/Supabase-PostGIS-3ECF8E?logo=supabase)](https://supabase.com)
[![Web Command Center](https://img.shields.io/badge/Web%20Portal-GitHub%20Pages-16A34A?logo=githubpages)](https://coding-water.github.io/PasadaNorte/)
[![Android APK](https://img.shields.io/badge/Android%20APK-GitHub%20Releases-2563EB?logo=android)](https://github.com/Coding-Water/PasadaNorte/releases)
[![ISO/IEC 25010](https://img.shields.io/badge/Standard-ISO%2FIEC%2025010-orange)](#)
[![Compliance](https://img.shields.io/badge/Ordinance-Laoag%20City%202023--005-green)](#)

> **PasadaNorte** is an intelligent paratransit dispatch, digital terminal queue (**Digital Pila**), on-device biometric verification, and municipal fare regulation ecosystem developed for **Laoag City, Ilocos Norte**. It connects a **Flutter Mobile Client** (for Commuters and Tricycle Drivers) with a **Flutter Web Command Center** (for Laoag City MINC and TODA Administrators), backed by **Supabase PostgreSQL/PostGIS**, **Deno Edge Functions**, **Android SMS Gateway**, and **GitHub Actions CI/CD**.

- **Live Web Admin Portal:** https://coding-water.github.io/PasadaNorte/
- **Versioned Production Android APKs:** https://github.com/Coding-Water/PasadaNorte/releases

---

## 📊 Implementation Progress Overview

**Production Readiness:** `100%` (All core production milestones completed on a 100% zero-fee stack: OpenStreetMap + Valhalla/OSRM + Supabase + Android SMS Gateway)

| Module / Subsystem | Progress | Status | Key Highlights |
| :--- | :--- | :--- | :--- |
| **1. Mobile Onboarding & Phone Uniqueness** | `██████████ 100%` | 🟢 Production Ready | Unique `phone_number` across `users` & `driver_applications`, OTP login for existing accounts, review-locked status screens (`PopScope`), multi-item resubmission tracking |
| **2. On-Device 1:1 Face Biometrics & Liveness** | `██████████ 100%` | 🟢 Production Ready | Google ML Kit (`FaceDetectorMode.accurate`) + **MobileFaceNet TFLite (192D)** embeddings, anti-spoofing blink/head-turn liveness, `0.0%` blank-photo detection, R8 keep rules |
| **3. Android SMS Gateway & Edge Functions** | `██████████ 100%` | 🟢 Production Ready | Live OTP (`send-otp-sms`, `verify-otp-sms`), admin decision notices (`send-sms-notice`), and 60s `lastSeen` gateway health monitor (`sms-gate-status`) |
| **4. Web Command Center (MINC & TODA)** | `██████████ 100%` | 🟢 Production Ready | Zero mock/demo rows, side-by-side Submitted ID + Live 1:1 Selfie inspection, Trash-only cascading delete, live GitHub Pages deployment |
| **5. TODA Stations & Digital Pila Queue** | `██████████ 100%` | 🟢 Production Ready | Interactive map pin-picker, per-station geofence/speed/dwell calibration, real-time driver map sync (`toda_terminals`), FIFO queue enforcement |
| **6. Service Geofence & Two-Tier Fare Matrix** | `██████████ 100%` | 🟢 Production Ready | Hard Ilocos Norte geofence + Ordinance 2023-005 intra-city fares (`<= 8 km`) + inter-municipality tricycle tier (`> 8 km`) + 20% Student/Senior/PWD discounts |
| **7. Driver Navigation HUD & Emergency SOS** | `██████████ 100%` | 🟢 Production Ready | Hands-free auto-follow camera (RA 10913), dynamic auto-reroute (`> 38m`), real-time `emergency_sos_alerts` telemetry sentinel |
| **8. 10-Zone Spatial Map & Hourly ML Forecast** | `██████████ 100%` | 🟢 Production Ready | Dual-mode heatmap (`Live 1h` vs `ML Forecast`), configurable `laoag_zones`, hourly GitHub Actions sync (`ml_demand_refresh.yml`), $k \ge 5$ PIA anonymization |
| **9. CI/CD, Security Hardening & Automated Tests** | `██████████ 100%` | 🟢 Production Ready | 18 Supabase SQL migrations (5 Security Pillars), 3 GitHub Actions workflows, `0` analyzer issues, **55/55** unit & widget tests passing |
| **10. Zero-Fee OpenStreetMap Geocoding & Routing** | `██████████ 100%` | 🟢 Zero-Fee Active | `flutter_map` (OSM + Satellite), Valhalla/OSRM road routing, curated `laoag_locations` DB (no paid Google Maps API fees) |

---

## 🏛️ System Architecture

```
                       ┌────────────────────────────────────────────────────────┐
                       │          Laoag City MINC & TODA Command Center         │
                       │    (web_client — Flutter Web / GitHub Pages Live)      │
                       │                                                        │
                       │  • Driver & Passenger Applications (Side-by-Side 1:1)  │
                       │  • SMS-Gate Active/Offline Heartbeat Pill (60s poll)   │
                       │  • TODA Pila Map Builder & Per-Station Calibration     │
                       │  • Laoag 10-Zone Interactive FlutterMap & Heatmap      │
                       │  • Live Dispatch Audit & Anti-Overcharging Sentinel    │
                       │  • Emergency SOS Live Sentinel (Dispatch Paused: Test) │
                       │  • Live (1h) & Hourly GitHub ML Demand Forecasts       │
                       └───────────────────────────▲────────────────────────────┘
                                                   │
                                  Real-Time WebSocket, RLS & PostGIS
                                                   │
                       ┌───────────────────────────┴────────────────────────────┐
                       │           Supabase Cloud Backend (PostgreSQL)          │
                       │  • 18 SQL Migrations (5 Security Pillars + Unique Tel) │
                       │  • 5 Deno Edge Functions:                              │
                       │      send-otp-sms · verify-otp-sms · send-sms-notice   │
                       │      sms-gate-status · purge-expired-biometrics        │
                       │  • Private Storage Buckets + 5-min Signed URLs         │
                       │  • Dynamic TODA Pilas, 10 Zones & Ordinance 2023-005   │
                       └─────────────▲───────────────────────────▲──────────────┘
                                     │                           │
                        Android SMS Gateway                Flutter Mobile Client
                      (api.sms-gate.app Cloud)             (Android Production APK)
                                     │                           │
              ┌──────────────────────┴──────┐    ┌───────────────┴───────────────────────┐
              ▼                             ▼    ▼                                       ▼
 ┌─────────────────────────┐  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐
 │   Spare Android Phone   │  │     Mobile Driver Experience     │  │    Mobile Passenger Experience   │
 │                         │  │                                  │  │                                  │
 │ • Real PH SIM OTP SMS   │  │ • Mandatory 4-Angle Vehicle Docs │  │ • Avatar or Real Photo Selection │
 │ • Approval/Resubmit SMS │  │ • On-Device ML Kit + MobileFace  │  │ • On-Device ML Kit + MobileFace  │
 │ • Ping Heartbeat Status │  │ • Locked Review & Multi-Resubmit │  │ • <= 1hr Review & Multi-Resubmit │
 └─────────────────────────┘  │ • Live Admin-Pinned TODA Pilas   │  │ • Two-Tier Ordinance Fare Matrix │
                              │ • Hands-Free HUD & Auto-Reroute  │  │ • 20% Statutory Discount Engine  │
                              │ • Digital Pila FIFO + SOS Beacon │  │ • Live GPS Tracking + SOS Beacon │
                              └──────────────────────────────────┘  └──────────────────────────────────┘
```

---

## 🚀 Key Modules & Capabilities

### 1. Live SMS OTP, Phone Uniqueness & Locked Onboarding
- **Real SMS OTP Verification (`send-otp-sms` / `verify-otp-sms`):** Dispatches 6-digit OTP codes via Android SMS Gateway (`capcom6/android-sms-gateway`), stored SHA-256 hashed in `sms_otp_codes` with expiry and attempt lockouts. All static/local test bypasses have been removed.
- **Strict Phone Number Uniqueness:** Enforced across both `public.users` and `public.driver_applications` (`20261119_unique_phone_constraints.sql`). Re-registering an existing number prompts the user to log in via OTP and resumes their real account or review status.
- **Review-Locked Status & Multi-Item Resubmission:** Both `PassengerApplicationStatusScreen` and `DriverApplicationStatusScreen` lock back-navigation (`PopScope(canPop: false)`) while under review and track each flagged item independently (e.g., ID re-upload **and** 1:1 Face Bio Scan redo) so completing one never skips the other.

### 2. On-Device 1:1 Face Biometrics & Anti-Spoofing Liveness
- **Two-Stage On-Device Biometrics (`face_verification_service.dart`):**
  1. **Active Liveness Challenge (`face_scan_screen.dart`):** Real-time front-camera Google ML Kit verification requiring blink and mirror-aware head movement with 2/3-plane YUV-to-NV21 conversion and JPEG snapshot fallback (no manual capture bypass).
  2. **192D Embedding Comparison:** Runs **MobileFaceNet TFLite** (`assets/models/mobilefacenet.tflite`) with horizontal-flip normalization and EXIF bounds handling (auto-approves `>= 85.0%`, routes `< 85.0%` to admin review, and scores blank/undetectable faces at **`0.0% (No Face Detected)`**).
- **Release Build Stability:** Protected against AGP 9.1 / R8 stripping via [`mobile_client/android/app/proguard-rules.pro`](mobile_client/android/app/proguard-rules.pro).

### 3. Live-Only Web Admin Command Center (MINC & TODA)
- **Live Data Only:** Zero hardcoded demo drivers, mock trips, or mock verification queues; hosted continuously on [GitHub Pages](https://coding-water.github.io/PasadaNorte/).
- **Side-by-Side 1:1 Inspection:** Admin modal renders **Submitted ID** and **Live 1:1 Selfie** side-by-side with exact role labels (**Driver**, **Regular Passenger**, **Student Passenger**, **Senior / PWD Passenger**) and red `0.0% (No Face Detected)` alerts.
- **SMS-Gate Health Sentinel:** Top-bar status pill polls `sms-gate-status` every 60 seconds using each gateway phone's `lastSeen` heartbeat timestamp (`SMS-Gate Active` vs `SMS-Gate Offline`).
- **Safe Trash Purge:** Permanent deletion is restricted strictly to **Rejected (Trash)** cards, backed by `minc_admin` `DELETE` RLS policies, `ON DELETE CASCADE` on `biometric_access_logs`, and Storage object cleanup.

### 4. TODA Stations & Digital Pila Map Builder (Live Driver Sync)
- **Interactive Map Pin-Picker (`web_client`):** Click anywhere on the Laoag City `FlutterMap` (`maxZoom: 21.0`, Streets or Satellite) to create a TODA Pila and calibrate geofence radius (`10m–150m`), join speed (`2–15 km/h`), and dwell time (`10–120s`).
- **Live Driver Map Sync (`mobile_client`):** `DriverMapDutyScreen` streams `toda_terminals` in real time from Supabase, rendering every admin-pinned Pila marker and calibrated geofence circle.
- **Academic Benchmark Validation (Objective 4):** Recall `95.0%` ($\ge 90\%$ target), FPR `6.0%` ($\le 10\%$ target), F1-Score `94.5%`, NTP sync ($\pm 2\text{ ms}$).

### 5. Service Area Geofence, Fare Matrix & Hands-Free HUD
- **Hard Ilocos Norte Geofence:** Blocks pickups/dropoffs outside Ilocos Norte and constrains map navigation with `CameraConstraint.contain`.
- **Two-Tier Municipal Fare Engine:**
  - **Intra-City (`<= 8 km`, Laoag City Ord. 2023-005):** $\text{Expected Fare} = \text{Base} + (\text{Distance} - 1.0\text{ km}) \times \text{Rate} - \text{Discounts}$ (with 20% Student / Senior / PWD discounts).
  - **Inter-Municipality (`> 8 km`):** Dedicated out-of-town tricycle pricing tier across Ilocos Norte municipalities.
- **Hands-Free Driver HUD (RA 10913):** Auto-follow camera, dynamic auto-reroute (`> 38m` lateral deviation), dual trip completion (`CONFIRM & RE-ENTER TODA PILA` vs `FINISH TRIP ONLY`), and live SOS distress sentinel.

### 6. Interactive Laoag 10-Zone Spatial Map & Hourly ML Demand Sync
- **Dual-Mode Heatmap:** Defaults to **Live (1h)** from `completed_trips` with one-click toggle to **ML Forecast**, plus editable `Z01`–`Z10` zones (`laoag_zones`).
- **Hourly GitHub Actions Sync:** [`.github/workflows/ml_demand_refresh.yml`](.github/workflows/ml_demand_refresh.yml) runs `ml_forecasting/sync_ml_to_supabase.py` hourly with Open-Meteo weather data to update `zone_demand_forecasts` and `ml_model_metrics` (`MASE`, `RMSE`, `WMAPE %`, `Non-Zero MAPE`).
- **$k \ge 5$ Privacy Impact Assessment (PIA):** Automatically suppresses zone-hours with fewer than 5 requests (RA 10173 / ISO/IEC 25010) and supports `.csv` / `.json` export.

---

## 📂 Project Repository Structure

```
PasadaNorte/
├── mobile_client/                    # Commuter & Driver Flutter Application (AGP 9.1.1 / Gradle 9.5.0)
│   ├── android/app/proguard-rules.pro# ML Kit & Firebase ComponentRegistrar R8 keep rules
│   ├── assets/models/                # mobilefacenet.tflite (192D on-device face embeddings)
│   ├── lib/
│   │   ├── core/services/            # FaceVerificationService, SupabaseService, LocationService, TodaQueueService, SessionCacheService, SystemNotificationService
│   │   ├── features/auth/views/      # PhoneInput, OTP, RoleSelection, UserDetails, IdUpload, FaceScan, DriverChecklist, Driver/Passenger Status
│   │   ├── features/driver/views/    # DriverMapDutyScreen, DriverActiveTripScreen, TodaQueueScreen
│   │   └── features/rider/views/     # PassengerServiceHubScreen, RiderMapBookingScreen, LiveRideTrackingScreen
│   ├── test/                         # 11 test suites (55 unit & widget tests)
│   └── pubspec.yaml
├── web_client/                       # Laoag City MINC & TODA Admin Command Center (Flutter Web)
│   ├── lib/main.dart                 # Analytics, Laoag FlutterMap, TODA Pila Builder, Driver/Passenger Verification, SOS & SMS-Gate Monitor
│   └── pubspec.yaml
├── supabase/
│   ├── functions/                    # send-otp-sms, verify-otp-sms, send-sms-notice, sms-gate-status, purge-expired-biometrics, _shared/sms_gate.ts
│   └── migrations/                   # 18 PostgreSQL/PostGIS & RLS migrations (5 Security Pillars + SMS OTP + Unique Phones + Admin Delete)
├── ml_forecasting/                   # Hourly Supabase ML sync (sync_ml_to_supabase.py) & zone-hour calibration CSV
├── .github/workflows/
│   ├── build_versioned_apk.yml       # Automated versioned Android APK build & GitHub Releases publisher
│   ├── deploy_web_client.yml         # Automated Flutter Web build & GitHub Pages deployment
│   └── ml_demand_refresh.yml         # Hourly ML demand forecast sync to Supabase
├── DEPLOYMENT_CHECKLIST.md           # Pre-deployment audit & live status tracking table
├── SMS_GATEWAY_SETUP_GUIDE.md        # Android SMS Gateway (Cloud Server + Ping) setup guide
├── DEPLOYMENT_AND_PRODUCTION_READINESS_GUIDE.md
├── SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md
└── README.md
```

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.3.0`) & Dart SDK (`>= 3.x`)
- Java 17 + Android Studio / VS Code (for Android APK builds)
- Supabase CLI (`npx supabase`) for deploying Edge Functions & SQL migrations

### 1. Run Mobile Client (Driver & Passenger)
```bash
cd mobile_client
flutter pub get
flutter run
```

### 2. Run Web Command Center (MINC & TODA Admin)
```bash
cd web_client
flutter pub get
flutter run -d chrome
```

### 3. Deploy Supabase Migrations & Edge Functions
```bash
npx supabase db push --remote
npx supabase functions deploy send-otp-sms verify-otp-sms send-sms-notice sms-gate-status purge-expired-biometrics
```
See [`SMS_GATEWAY_SETUP_GUIDE.md`](SMS_GATEWAY_SETUP_GUIDE.md) for configuring `SMS_GATEWAY_URL`, `SMS_GATEWAY_USERNAME`, `SMS_GATEWAY_PASSWORD`, and Android Ping interval (`60s`).

---

## 🛡️ Security & Backend Hardening (The 5 Pillars)

1. **Pillar 1:** Supabase Row Level Security (RLS), unique phone constraints, and tamper-proof audit trails (City Ord. 2023-005).
2. **Pillar 2:** Anti-GPS Spoofing & Mock Location Sentinel (`isMocked` hardware interception & FIFO Digital Pila protection).
3. **Pillar 3:** Commuter & Driver Privacy ($k \ge 5$ Anonymization, Private Storage Buckets, 5-minute Signed URLs, and automated biometric retention purging under RA 10173 & NPC Circular 2023-03).
4. **Pillar 4:** Role-Based Access Control (4-tier RBAC), Anti-Privilege Escalation Triggers, and SHA-256 Hashed OTP Rate Limiting.
5. **Pillar 5:** Backend Resilience, GPS Velocity Sanity Check ($80\text{ km/h}$ ceiling), and Exponential Backoff Retry.

📖 **Full Architecture & Migration Ledger:** [`SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md`](SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md) | **Pre-Deployment Audit:** [`DEPLOYMENT_CHECKLIST.md`](DEPLOYMENT_CHECKLIST.md)

---

## 🧪 Static Analysis & Automated Tests

```bash
cd mobile_client && flutter analyze
# Result: No issues found!

cd web_client && flutter analyze
# Result: No issues found!

cd mobile_client && flutter test
# Result: 55/55 tests passed!
```

---

## ⚖️ Regulatory & Academic References
- **Laoag City Ordinance No. 2023-005:** Modernized Tricycle Fare Matrix & Student/PWD Discount Guidelines.
- **Republic Act No. 10173:** Data Privacy Act of 2012 (Commuter $k \ge 5$ Anonymization & Biometric Staging Image Deletion).
- **Republic Act No. 10913:** Anti-Distracted Driving Act (Hands-Free Camera Navigation).
- **Republic Act No. 11314:** Student Fare Discount Act (20% Statutory Fare Deduction).
- **NPC Circulars 2016-01 & 2023-03:** National Privacy Commission Guidelines on Data Minimization & Biometric Vaults.
- **ISO/IEC 25010:2023:** Systems and Software Engineering — System and Software Quality Requirements and Evaluation (SQuaRE).
- **ISO/IEC 19795-1:** Biometric Performance Testing and Reporting (1:1 Face Verification).
