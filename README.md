# PasadaNorte — Laoag City Paratransit Dispatch & Regulation Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Supabase PostGIS](https://img.shields.io/badge/Supabase-PostGIS-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/License-Academic%20%2F%20LGU-blue.svg)](#)
[![ISO/IEC 25010](https://img.shields.io/badge/Standard-ISO%2FIEC%2025010-orange)](#)
[![Compliance](https://img.shields.io/badge/Ordinance-Laoag%20City%202023--005-green)](#)

> **PasadaNorte** is an intelligent paratransit dispatch, digital terminal queue (Digital Pila), and municipal fare regulation ecosystem developed specifically for Laoag City, Ilocos Norte. The platform comprises a **Mobile Client** (for Commuters and Tricycle Drivers) and a **Web Command Center** (for the Laoag City Motorized Tricycle Franchising and Regulatory Board / MINC and TODA Administrators).

---

## 🏛️ System Architecture

```
                       ┌────────────────────────────────────────────────────────┐
                       │          Laoag City MINC & TODA Command Center         │
                       │            (web_client — Flutter Web / PC)             │
                       │                                                        │
                       │  • Driver & Passenger Applications Review Portals      │
                       │  • TODA Pila Map Builder & Per-Station Calibration     │
                       │  • Laoag 10-Zone Interactive FlutterMap & Heatmap      │
                       │  • Live Dispatch Audit & Anti-Overcharging Sentinel    │
                       │  • Emergency SOS Live Sentinel (Dispatch Paused: Test) │
                       │  • ML Demand Scenario Simulator & Dataset Export       │
                       └───────────────────────────▲────────────────────────────┘
                                                   │
                                      Real-Time WebSocket & PostGIS
                                                   │
                       ┌───────────────────────────┴────────────────────────────┐
                       │           Supabase Cloud Backend (PostgreSQL)          │
                       │  • Dynamic TODA Pilas (toda_terminals + Realtime)      │
                       │  • Driver & Passenger Applications + Storage Buckets   │
                       │  • Realtime Distress Beacons (emergency_sos_alerts)    │
                       │  • City Ordinance 2023-005 Fare Matrix Table           │
                       │  • 1:1 Face Verification Biometrics (ISO/IEC 19795-1)  │
                       └───────────────────────────▲────────────────────────────┘
                                                   │
                                   Mobile Clients (Flutter Mobile)
                                                   │
             ┌─────────────────────────────────────┴─────────────────────────────────────┐
             ▼                                                                           ▼
 ┌──────────────────────────────────────┐                   ┌──────────────────────────────────────┐
 │       Mobile Driver Experience       │                   │       Mobile Rider Experience        │
 │                                      │                   │                                      │
 │ • Requirements Checklist & Status    │                   │ • Avatar or Photo Profile Selection  │
 │ • Live Admin-Pinned TODA Pilas Map   │                   │ • <= 1hr Passenger Review Status     │
 │ • Hands-Free Auto-Follow Camera      │                   │ • Upfront Ordinance 2023-005 Fare    │
 │ • Dynamic Rerouting & Detour Engine  │                   │ • 20% Statutory Discount Validator   │
 │ • Digital Pila FIFO Auto-Queuing     │                   │ • Live Tricycle GPS Turn-by-Turn     │
 │ • Emergency SOS Distress Button      │                   │ • Emergency SOS Panic Beacon         │
 └──────────────────────────────────────┘                   └──────────────────────────────────────┘
```

---

## 🚀 Key Modules & Capabilities

### 1. Driver & Passenger Onboarding + Web Admin Review Portals
- **Driver Applications (`DriverRequirementsChecklistScreen` -> `DriverApplicationStatusScreen`):**
  - Collects real profile photo, Professional Driver's License, NBI/Police/Barangay clearances, Fit-to-Work (age 50–55), LTO OR/CR, 4-angle tricycle photos, and 1:1 Face Bio Scan.
  - Web Admin reviews each document (`Inspect`, `Resubmit` with reason selector, `Pass` persisted in `SharedPreferences`), assigns **TODA Pila** on approval, or moves to **Rejected (Trash)** with permanent delete.
- **Passenger Applications (`PassengerApplicationStatusScreen`):**
  - Accepts either illustration avatars or real profile photos and skips driver requirements.
  - Web Admin verifies **Submitted ID** and **1:1 Face Bio Scan** (`<= 1 hour` SLA).
  - Mobile app polls/streams live status and dispatches native Android Notification Center alerts for **Approved**, **Resubmission Required** (with inline ID re-upload and 1:1 Face Bio Scan redo), or **Rejected**.

### 2. TODA Stations & Digital Pila Map Builder (Live Driver Sync)
- **Interactive Map Pin-Picker (`web_client`):** Administrators click anywhere on the Laoag City `FlutterMap` (Streets or Satellite) or use **Create TODA Pila** to name a station, set its TODA code, pin its coordinates, and calibrate individual geofence radius (`10m–150m`), join speed (`2–15 km/h`), and dwell time (`10–120s`).
- **Live Driver Map Sync (`mobile_client`):** `DriverMapDutyScreen` streams `toda_terminals` in real time from Supabase, rendering every admin-pinned Pila name, marker, and calibrated geofence circle directly on the driver's map.
- **Academic Benchmark Validation (Objective 4):**
  - **Recall (TPR):** `95.0%` (Target $\ge 90\%$)
  - **False Positive Rate (FPR):** `6.0%` (Target $\le 10\%$)
  - **F1-Score:** `94.5%`
  - **NTP Clock Sync:** Eliminates millisecond drift ($\pm 2\text{ ms}$) between field researcher ground truth and cloud telemetry.

### 3. Driver Active Navigation HUD & Hands-Free Safety (RA 10913)
- **Hands-Free Auto-Follow Camera:** Automatically glides the camera along the road path following vehicle telemetry, preventing manual map swiping while driving.
- **Dynamic Auto-Reroute Sentinel:** Monitors lateral deviation (`> 38m`). If road repairs or traffic jams occur, alternate Laoag street paths are recalculated in real time.
- **Dual Trip Completion:**
  - `CONFIRM & RE-ENTER TODA PILA`: Navigates back to the terminal and queues the driver upon entering the calibrated geofence.
  - `FINISH TRIP ONLY (OFFLINE)`: Allows driver rest without queue interference.

### 4. Municipal Fare Sentinel (Laoag City Ordinance No. 2023-005)
- **Automated GPS Fare Calculation:**
  $$\text{Expected Fare} = \text{Base} + (\text{Distance} - 1.0\text{ km}) \times \text{Rate} - \text{Discounts}$$
- **Anti-Overcharging Discrepancy Flag:** Highlights any transaction where collected cash exceeds Ordinance limits with an immediate `OVERCHARGED` badge and one-click MINC Summons Notice.

### 5. Interactive Laoag 10-Zone Spatial Map & ML Demand Radar
- **Real Interactive `FlutterMap` (`web_client`):** Replaces static schematics with live Google Streets/Satellite map tiles, zoom controls, geofence demand circles, and clickable `Z01`–`Z10` markers across Laoag City.
- **Interactive Scenarios:** Morning Rush (07:30), University Dismissal (17:00), Monsoon Rain Surge (+40% demand), and Night Shift.
- **$k \ge 5$ Privacy Impact Assessment (PIA):** Automatically suppresses zone hours under 5 requests to prevent commuter de-anonymization (ISO/IEC 25010 / RA 10173).
- **Dual Export:** Download training datasets in clean `.json` or Pandas/Scikit-learn `.csv`.

### 6. Real-Time Emergency SOS Sentinel (Testing Mode)
- **Live SOS Telemetry:** Real user accounts can trigger SOS distress beacons (`emergency_sos_alerts`), appearing in the Web Command Center's red sentinel banner with GPS coordinates and incident inspection modal.
- **PNP Dispatch Calling Paused:** External PNP dispatch calling (`077-772-0256`) is currently paused (`_isPnpDispatchPaused = true`) for safe end-to-end testing; admins can still inspect telemetry and mark alerts resolved.

---

## 📋 Case Study & Thesis Alignment Check

| Case Study / Research Objective | Current Implementation Status | Notes |
| :--- | :--- | :--- |
| **Obj. 1: Ordinance 2023-005 Fare Matrix & 20% Discounts** | 🟢 Aligned | Dynamic Supabase `fare_guide_table` synced to mobile & web audit. |
| **Obj. 2: 1:1 Face Verification (ISO/IEC 19795-1 & RA 10173)** | 🟢 Aligned + Extended | Added Web Admin Driver & Passenger Application portals with resubmission loops and Android notifications. |
| **Obj. 3: ML Demand Radar & $k \ge 5$ Privacy Masking** | 🟢 Aligned + Upgraded | Now overlaid on an interactive `FlutterMap` of Laoag City (`Z01`–`Z10`). |
| **Obj. 4: Digital Pila Geofencing & NTP Calibration** | 🟢 Aligned + Upgraded | Expanded from static `10m–50m` presets to dynamic map-pinned TODA Pilas (`10m–150m`) synced live to Driver Maps. |
| **Obj. 5: Emergency SOS & Dispatch Sentinel** | 🟡 Testing Mode | Live SOS beacons active; static seeded alert removed; PNP dispatch call button paused for testing. |

---

## 📂 Project Repository Structure

```
PasadaNorte/
├── mobile_client/                    # Commuter & Driver Flutter Application
│   ├── lib/
│   │   ├── core/services/            # LocationService, SupabaseService, TodaQueueService, SessionCacheService, SystemNotificationService
│   │   ├── features/auth/views/      # PhoneInput, OTP, RoleSelection, UserDetails, IdUpload, FaceScan, DriverChecklist, Driver/Passenger Status
│   │   ├── features/driver/views/    # DriverMapDutyScreen, DriverActiveTripScreen, TodaQueueScreen
│   │   └── features/rider/views/     # PassengerServiceHubScreen, RiderMapBookingScreen, LiveRideTrackingScreen
│   ├── test/                         # 41 unit & widget tests
│   └── pubspec.yaml
├── web_client/                       # Laoag City LGU & TODA Admin Command Center
│   ├── lib/
│   │   └── main.dart                 # Analytics, Laoag FlutterMap, TODA Pila Map Builder, Driver/Passenger Applications, SOS Sentinel
│   └── pubspec.yaml
├── ml_forecasting/                   # Python demand forecasting scripts & experiments
├── DEPLOYMENT_CHECKLIST.md           # Pre-production bypass removal & hardening checklist
├── DEPLOYMENT_AND_PRODUCTION_READINESS_GUIDE.md
├── SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md
└── README.md
```

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.3.0`)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter extension
- Google Chrome (for Web Admin Dashboard)

### 1. Running the Mobile Client (Driver & Passenger)
```bash
cd mobile_client
flutter pub get
flutter run
```

### 2. Running the Web Command Center (LGU Admin & Dispatch)
```bash
cd web_client
flutter pub get
flutter run -d chrome
```

---

## 🛡️ Security & Backend Hardening (The 5 Pillars)

The PasadaNorte ecosystem is fortified against spoofing, privilege escalation, and data privacy leaks across **Five Pillars of Security**:
1. **Pillar 1:** Supabase Row Level Security (RLS) & legally tamper-proof audit trails (City Ord. 2023-005).
2. **Pillar 2:** Anti-GPS Spoofing & Mock Location Sentinel (`isMocked` hardware interception & FIFO Digital Pila protection).
3. **Pillar 3:** Commuter & Driver Privacy ($k \ge 5$ Anonymization, Private Storage Buckets & 5m Signed URLs under RA 10173 & NPC Circular 2023-03).
4. **Pillar 4:** Role-Based Access Control (RBAC 4-tier model), Anti-Privilege Escalation Triggers & OTP Rate Limiting Defense.
5. **Pillar 5:** Backend Resilience, GPS Velocity Sanity Check ($80\text{ km/h}$ physical speed ceiling) & Exponential Backoff Retry.

📖 **Full Technical Architecture & Migration Ledger:** See [`SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md).

---

## 🧪 Static Analysis & Tests

```bash
cd mobile_client && dart analyze
# Result: No issues found!

cd web_client && dart analyze
# Result: No issues found!

cd mobile_client && flutter test
# Result: 41/41 tests passed!
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
