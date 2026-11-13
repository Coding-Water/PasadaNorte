# PasadaNorte — Production Deployment, Transition & Go-Live Readiness Guide

> **Document Type:** Production Readiness Checklist & Deployment Runbook  
> **Target Date:** Next Month Launch  
> **Jurisdiction:** Laoag City, Ilocos Norte, Philippines  
> **Regulatory Standard:** Laoag City Ordinance No. 2023-005 & LTFRB MC 2025-10  
> **Technical Standards:** ISO/IEC 25010 (Software Quality) & ISO/IEC 19795-1 (Biometrics)

---

## 📑 Table of Contents
1. [Transitioning from Static Data to Real Passengers & Drivers](#1-transitioning-from-static-data-to-real-passengers--drivers)
2. [How the ML Demand Forecasting Adapts in Production](#2-how-the-ml-demand-forecasting-adapts-in-production)
3. [Pre-Deployment Master Checklist (Ready for Launch)](#3-pre-deployment-master-checklist-ready-for-launch)
   - [Phase 1: Database & Cloud Infrastructure (Supabase PostGIS)](#phase-1-database--cloud-infrastructure-supabase-postgis)
   - [Phase 2: Real Philippine SMS OTP Integration](#phase-2-real-philippine-sms-otp-integration)
   - [Phase 3: Backend API & AI Inference Deployment](#phase-3-backend-api--ai-inference-deployment)
   - [Phase 4: Mobile App Store Build & Release (`mobile_client`)](#phase-4-mobile-app-store-build--release-mobile_client)
   - [Phase 5: Web Admin Portal Hosting (`web_client`)](#phase-5-web-admin-portal-hosting-web_client)
   - [Phase 6: MINC (City Hall) & TODA Stakeholder Rollout](#phase-6-minc-city-hall--toda-stakeholder-rollout)
4. [Day-1 Go-Live Operational Runbook](#4-day-1-go-live-operational-runbook)
5. [Emergency Fail-Safe & Rollback Procedures](#5-emergency-fail-safe--rollback-procedures)

---

## 1. Transitioning from Static Data to Real Passengers & Drivers

### Live-First Architecture (Zero Fake Red/Green Zones)
When the app has zero live users, the **Live (1h)** heatmap accurately displays `0.0 req/h` in neutral slate (`#94A3B8`) instead of hardcoded red/green hotspots. Meanwhile, the **6,720 zone-hour calibration dataset** (`pasada_norte_zone_hour_dataset_6720.csv`) serves as the cold-start baseline for the **ML Forecast** mode until real trip volume accumulates.

### What Happens in Production?
1. **Dynamic TODA Pilas:** All static/mock TODA Pilas are wiped. Admins create, name, pin, and calibrate each TODA Pila (`10–150 m` geofence radius, join speed, min dwell time) directly on the Web Admin map, synced in real time to driver mobile maps via Supabase `toda_terminals`.
2. **Configurable 10 Laoag Zones:** Admins can rename, set drop-off match keywords, and re-pin any of `Z01–Z10` in Supabase `laoag_zones`.
3. **Passenger & Driver Verification:** Passengers (with profile photo or illustration avatar) undergo ID + 1:1 face scan review (`<= 1 hour` SLA), while drivers undergo full clearances + 4-angle tricycle photos + Pila assignment, both with native Android status notifications.
4. **Data Privacy ($k \ge 5$ PIA Rule):** Any zone with fewer than 5 requests per hour is automatically flagged/suppressed under RA 10173 to prevent de-anonymizing individual commuters.

---

## 2. How the ML Demand Forecasting Adapts in Production

```mermaid
flowchart TD
    A[Real Commuter Completes Ride] --> B[Supabase Logs completed_trips with Dropoff & Timestamp]
    B --> C[GitHub Actions Hourly Cron Runs sync_ml_to_supabase.py]
    C --> D[Reads Configured laoag_zones + Live Open-Meteo Weather]
    D --> E[Blends Historical Baseline + Live 1h Requests & Computes MASE/RMSE/WMAPE]
    E --> F[Upserts zone_demand_forecasts & ml_model_metrics in Supabase]
    F --> G{Zone Count >= 5?}
    G -- Yes --> H[Broadcast High-Confidence Hotspot on Web & Mobile Maps]
    G -- No --> I[Suppress / Mask per k=5 PIA Privacy Rule]
```

### The Continuous Learning Cycle
* **Hourly Auto-Refresh (GitHub Actions):** [.github/workflows/ml_demand_refresh.yml](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/.github/workflows/ml_demand_refresh.yml) runs `ml_forecasting/sync_ml_to_supabase.py` every hour (`cron: '0 * * * *'`) using only Python stdlib, pulling live `completed_trips`, `laoag_zones`, and Laoag City rainfall/temperature from Open-Meteo.
* **Live vs. Forecast Toggle:** Web admins can switch between **Live (1h)** (actual recent `completed_trips`) and **ML Forecast** (hourly predictions + evaluation metrics from `ml_model_metrics`).

---

## 3. Pre-Deployment Master Checklist (Ready for Launch)

### Phase 1: Database & Cloud Infrastructure (Supabase PostGIS)
- [x] **Deploy ML & Zone Configuration Tables:**
  Execute [20261114_ml_demand_forecasts.sql](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261114_ml_demand_forecasts.sql) (`zone_demand_forecasts`, `ml_model_metrics`) and [20261114_laoag_zones.sql](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261114_laoag_zones.sql) (`laoag_zones`) in the Supabase SQL Editor.
- [ ] **Purge Prototype Records:**
  Execute the database cleanup script in the Supabase SQL Editor:
  ```sql
  -- Remove all mock/test records while keeping the table structure intact
  TRUNCATE TABLE biometric_access_logs CASCADE;
  TRUNCATE TABLE encrypted_face_templates CASCADE;
  DELETE FROM users WHERE phone_number LIKE '%000%' OR phone_number LIKE '%123%';
  DELETE FROM zone_hourly_demand WHERE observation_date < CURRENT_DATE - INTERVAL '60 days';
  ```
- [ ] **Verify PostGIS Extensions & Indexes:**
  Ensure spatial queries are accelerated for Laoag City:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_toda_terminals_center ON toda_terminals USING GIST (center_point);
  CREATE INDEX IF NOT EXISTS idx_zone_demand_centroid ON zone_hourly_demand USING GIST (zone_centroid);
  ```
- [ ] **Enable Row Level Security (RLS):**
  Ensure passengers can only see their own active trips, and drivers cannot access other drivers' earnings or passenger contact details.
- [ ] **Set Up Daily Automated Cloud Backups:**
  Turn on Supabase Automated Daily Backups and Point-in-Time Recovery (PITR).

---

### Phase 2: Real Philippine SMS OTP Integration *(Deferred: Post-MVP / Pre-Launch)*
> **Status:** ⏸️ **On Hold / Deferred to Pre-Launch Phase.**  
> During development and testing, the application utilizes the built-in test OTP simulator mode with 60-second cooldowns and 3-attempt lockout defense. Dedicated SMS provider onboarding will be executed right before public pilot release.

- [ ] **Select a Philippine Telco SMS Gateway:**
  - **Option A (Recommended Local):** [Semaphore.co](https://semaphore.co) (Fast delivery to Globe, SMART, DITO, TNT, TM via simple HTTP API).
  - **Option B (Enterprise):** [PhilSMS](https://philsms.com) or [Twilio](https://twilio.com).
- [ ] **Configure Supabase Auth Custom SMS Hook:**
  Add the SMS API key in `Supabase Dashboard` $\rightarrow$ `Authentication` $\rightarrow$ `Providers` $\rightarrow$ `Phone`.
- [ ] **Set Rate Limiting:**
  Configure a maximum of 3 OTP requests per phone number per 10 minutes to prevent SMS spam billing.
- [ ] **Whitelist Emergency Numbers:**
  Ensure Laoag City Central Terminal Dispatch and MINC Hotlines can log in without SMS delays.

---

### Phase 3: Serverless AI & ML Architecture *(Implemented — $0.00/mo, No Separate Server Needed)*
> **Status:** ✅ **Implemented & Active.**  
> **Chosen Architecture (100% Serverless):**
> 1. **1:1 Face Biometrics (On-Device ML Kit):** `mobile_client` runs `google_mlkit_face_detection` (`FaceDetectorMode.accurate`) directly on the phone in `FaceVerificationService` (`< 1s` latency, `$0` hosting, no `127.0.0.1:8000` FastAPI dependency), computing normalized landmark cosine similarity (`>= 85.0%` target) before syncing verification records to Supabase.
> 2. **Hourly ML Demand Forecasting (GitHub Actions + Supabase):** `.github/workflows/ml_demand_refresh.yml` runs `ml_forecasting/sync_ml_to_supabase.py` every hour (`cron: '0 * * * *'`), blending `completed_trips`, `laoag_zones`, and live Laoag City weather (Open-Meteo) and upserting `zone_demand_forecasts` + `ml_model_metrics`.

- [x] **Configure GitHub Actions Repository Secrets:**
  `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` added under **Settings → Secrets and variables → Actions**.
- [x] **Verify Automated Hourly ML Sync:**
  `Hourly ML Demand Forecast Refresh` workflow tested and succeeding (`sync-ml-forecasts`).
- [ ] **Final Production Hardening (Before Public Launch):**
  - Remove testing bypasses (`_skipFaceScan`, `_skipTricyclePhotos`, static OTP `123456`) per `DEPLOYMENT_CHECKLIST.md`.
  - Enforce name input sanitization (`user_details_input_screen.dart`).
  - Re-enable PNP Emergency Dispatch when field testing is ready (`_isPnpDispatchPaused = false` in `web_client/lib/main.dart`).

---

### Phase 4: Mobile App Store Build & Release (`mobile_client`)
- [ ] **Create Production Android Keystore:**
  Generate the release signing key in PowerShell:
  ```powershell
  keytool -genkey -v -keystore c:\Users\MSI\Desktop\Flutter\PasadaNorte\mobile_client\android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] **Configure `android/key.properties`:**
  Store the keystore path and passwords securely (never commit to GitHub).
- [ ] **Update Package Name & Versioning:**
  In `mobile_client/pubspec.yaml`:
  ```yaml
  version: 1.0.0+1
  ```
- [ ] **Verify Required Android Permissions (`AndroidManifest.xml`):**
  - `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` (GPS road navigation)
  - `CAMERA` (1:1 Face Verification & ID Upload)
  - `FOREGROUND_SERVICE_LOCATION` (Active trip tracking when screen is turned off)
  - `INTERNET` (Cloud communication)
- [ ] **Compile Android App Bundle (AAB):**
  ```powershell
  cd c:\Users\MSI\Desktop\Flutter\PasadaNorte\mobile_client
  flutter clean
  flutter pub get
  flutter build appbundle --release --no-tree-shake-icons
  ```
  The production file is generated at `mobile_client/build/app/outputs/bundle/release/app-release.aab`.
- [ ] **Google Play Console Submission:**
  Upload `.aab`, app screenshots, and privacy policy URL describing RA 10173 compliance.

---

### Phase 5: Web Admin Portal Hosting (`web_client`)
- [ ] **Compile Production Web Artifacts:**
  ```powershell
  cd c:\Users\MSI\Desktop\Flutter\PasadaNorte\web_client
  flutter clean
  flutter pub get
  flutter build web --release --no-tree-shake-icons
  ```
  The compiled production web bundle is created in `web_client/build/web/`.
- [ ] **Deploy to Production Web Hosting:**
  - **Option A (Zero-Cost & CDN Fast):** [Cloudflare Pages](https://pages.cloudflare.com) or [Vercel](https://vercel.com) (drag and drop `build/web`).
  - **Option B (Municipal Domain):** Upload to Laoag City LGU Server at `https://admin.pasadanorte.laoagcity.gov.ph`.
- [ ] **Verify Admin Login & Session Protection:**
  Ensure only authorized MINC Officers and TODA Presidents with authenticated email/password or admin phone credentials can access the dashboard.

---

### Phase 6: MINC (City Hall) & TODA Stakeholder Rollout
- [ ] **Import Authorized Tricycle Franchise Master List:**
  Gather the official Excel/CSV list of active **Motorized Tricycle Operator's Permits (MTOP)** from the Laoag City Tricycle Regulation Office (Body # `0001` to `#2500`).
- [ ] **Driver Onboarding & Biometric Verification Week:**
  1. Set up a physical verification booth at Laoag Central Terminal.
  2. Assist drivers in downloading the app.
  3. Upload their driver's license and take their baseline selfie.
  4. MINC admins approve the cards in the **Web Admin Portal**.
- [ ] **TODA Terminal Standees & Signage:**
  Install laminated QR code signs at the main terminals:
  - *Laoag Public Market & Commercial Complex TODA*
  - *MMSU Laoag Campus (Gate 2 / CTE)*
  - *Robinsons Place Ilocos Boundary TODA*
  - *Laoag City General Hospital (LCGH) TODA*
  - *Partas Bus Terminal TODA*
- [ ] **Student & Senior Citizen Information Campaign:**
  Distribute flyers at MMSU, NWU, and City Hall informing commuters that they receive the 20% statutory discount under Ordinance 2023-005 by scanning their student or OSCA/PWD ID once.

---

## 4. Day-1 Go-Live Operational Runbook

```
┌─────────────────────────────────────────────────────────────┐
│                 DAY 1 GO-LIVE SCHEDULE                      │
├─────────────┬───────────────────────────────────────────────┤
│ 05:00 AM    │ Supabase database check & PostGIS verification │
│ 05:30 AM    │ Web Admin Portal live at MINC Office          │
│ 06:00 AM    │ First wave of TODA drivers go ONLINE          │
│ 07:00 AM    │ Morning school rush: Monitor Z01 & Z02 demand │
│ 12:00 PM    │ Midday Fare Compliance audit check            │
│ 05:00 PM    │ University dismissal rush: Check queue dwell  │
│ 08:00 PM    │ Review Day 1 trips & export training dataset  │
└─────────────┴───────────────────────────────────────────────┘
```

---

## 5. Emergency Fail-Safe & Rollback Procedures

### Scenario A: Sudden Mobile Internet Drop in Outer Barangays
* **Engineered Fail-Safe:** The app includes local caching (`offline_queue_state.json`). 
* If a driver loses connection between Laoag and San Nicolas or Gabu, their TODA queue position and active trip fare calculation continue running locally using GPS satellite data. The record automatically syncs to Supabase as soon as 4G/LTE reconnects.

### Scenario B: Road Closures (Fiesta / Procession along J.P. Rizal St.)
* Open the **Web Admin Portal** $\rightarrow$ **TODA Stations**.
* Adjust the geofence radius or temporarily route bookings to the secondary arterial (Gen. Antonio Luna St.).

### Scenario C: Commuter Overcharging Report
* Go to **Web Admin Portal** $\rightarrow$ **Live Dispatch Audit**.
* Filter by **"Overcharged"**.
* Click **"Issue MINC Notice ➔"** to generate the formal summons with the exact trip distance and fare discrepancy.

---

## 6. Official Fare Formula Quick Reference (Laoag City Ord. 2023-005)

$$\text{Regular Upfront Fare} = ₱20.00 + \max\left(0, \text{Distance (km)} - 1.0\right) \times ₱5.00$$

$$\text{Discounted Fare (Student / Senior / PWD)} = ₱16.00 + \max\left(0, \text{Distance (km)} - 1.0\right) \times ₱4.00$$

*(All discounts are 20% statutory shares under RA 11314 and RA 9994).*

---

*Keep this guide accessible for your deployment milestone next month.*
