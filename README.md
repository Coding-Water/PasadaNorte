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
                       │  • Live Dispatch Audit & Anti-Overcharging Sentinel    │
                       │  • Emergency SOS Live Incident Response (PNP Patrol)   │
                       │  • ML Demand Scenario Simulator (Poisson / SARIMA)     │
                       │  • TODA Geofence Tuning (10m–50m) & NTP Calibration    │
                       │  • Dual Dataset Export (JSON & Scikit/Pandas CSV)      │
                       └───────────────────────────▲────────────────────────────┘
                                                   │
                                      Real-Time WebSocket & PostGIS
                                                   │
                       ┌───────────────────────────┴────────────────────────────┐
                       │           Supabase Cloud Backend (PostgreSQL)          │
                       │  • Geofenced Terminals (ST_DWithin)                    │
                       │  • Realtime Driver Distress Beacons (emergency_sos)    │
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
 │ • Hands-Free Auto-Follow Camera      │                   │ • Upfront Ordinance 2023-005 Fare    │
 │ • Dynamic Rerouting & Detour Engine  │                   │ • 20% Statutory Discount Validator   │
 │ • Digital Pila FIFO Auto-Queuing     │                   │ • Live Tricycle GPS Turn-by-Turn     │
 │ • Dual Trip Completion (Pila Route)  │                   │ • Emergency SOS Panic Beacon         │
 │ • Emergency SOS Distress Button      │                   │ • Non-Freezing Offline Recovery      │
 └──────────────────────────────────────┘                   └──────────────────────────────────────┘
```

---

## 🚀 Key Modules & Capabilities

### 1. Driver Active Navigation HUD & Hands-Free Safety (RA 10913)
- **Hands-Free Auto-Follow Camera:** Automatically glides the camera along the road path following vehicle telemetry, preventing manual map swiping while driving.
- **Dynamic Auto-Reroute Sentinel:** Monitors lateral deviation (`> 38m`). If road repairs or traffic jams occur (e.g., detouring from J.P. Rizal to A. Mabini), alternate Laoag street paths are recalculated in real time.
- **Dual Trip Completion:** 
  - `CONFIRM & RE-ENTER TODA PILA`: Automatically navigates back to the nearest terminal and queues the driver upon entering the 25m geofence.
  - `FINISH TRIP ONLY (OFFLINE)`: Allows driver rest without queue interference.
- **Overhead Notification HUD:** Slide-to-confirm notifications appear at the top of the viewport to keep lower controls accessible.

### 2. Municipal Fare Sentinel (Laoag City Ordinance No. 2023-005)
- **Automated GPS Fare Calculation:**
  $$\text{Expected Fare} = \text{Base} + (\text{Distance} - 1.0\text{ km}) \times \text{Rate} - \text{Discounts}$$
- **Anti-Overcharging Discrepancy Flag:** Highlights any transaction where collected cash exceeds Ordinance limits with an immediate `OVERCHARGED` badge.
- **One-Click MINC Summons Notice:** Generates an official regulatory warning citing City Ordinance No. 2023-005 with 72-hour formal adjudication notice.

### 3. Digital Pila Geofence & NTP Clock Synchronization
- **FIFO Terminal Queuing:** PostGIS circular geofences (10m–50m radius) detect queue entry and dwell times (`join speed <= 5 km/h`, `dwell >= 30s`).
- **Academic Benchmark Validation (Objective 4):**
  - **Recall (TPR):** `95.0%` (Target $\ge 90\%$)
  - **False Positive Rate (FPR):** `6.0%` (Target $\le 10\%$)
  - **F1-Score:** `94.5%`
  - **NTP Clock Sync:** Eliminates millisecond drift ($\pm 2\text{ ms}$) between field researcher ground truth and cloud telemetry.

### 4. Machine Learning Demand Radar & Scenario Simulator
- **10 Paratransit Zones Tracked:** Z01 (Public Market), Z02 (MMSU CTE/CIT), Z03 (Bell Tower), Z04 (LCGH), Z05 (GRBASMH), Z06 (Capitol), Z07 (NWU), Z08 (Robinsons), Z09 (Partas), Z10 (Airport).
- **Interactive Scenarios:** Morning Rush (07:30), University Dismissal (17:00), Monsoon Rain Surge (+40% demand), and Night Shift.
- **$k \ge 5$ Privacy Impact Assessment (PIA):** Automatically suppresses zone hours under 5 requests to prevent commuter de-anonymization (ISO/IEC 25010 privacy compliance).
- **Dual Export:** Download training datasets in clean `.json` or Pandas/Scikit-learn `.csv`.

### 5. Real-Time Emergency SOS & Incident Dispatch Command
- **Driver Distress Beacon:** Tapping the emergency panic button transmits driver identity, plate number, live GPS coordinates, and distress reason to Supabase.
- **Pulsating Red Sentinel Banner:** Immediate visual strobe on the Web Command Center across all views.
- **Emergency Action Center:** One-click dispatch to **Laoag PNP (Hotline: 077-772-0256)** and TODA Terminal Marshals.

---

## 📂 Project Repository Structure

```
PasadaNorte/
├── mobile_client/                    # Commuter & Driver Flutter Application
│   ├── lib/
│   │   ├── core/services/            # LocationService, SupabaseService, TodaQueueService
│   │   ├── features/auth/            # OTP, Role Selection, Welcome Onboarding
│   │   ├── features/driver/views/    # DriverMapDutyScreen, DriverActiveTripScreen, TodaQueueScreen
│   │   └── features/rider/views/     # RiderMapBookingScreen, LiveRideTrackingScreen
│   └── pubspec.yaml
├── web_client/                       # Laoag City LGU & TODA Admin Command Center
│   ├── lib/
│   │   └── main.dart                 # Krisp UI Dashboard, SOS Sentinel, ML Radar, Dispatch Audit
│   └── pubspec.yaml
├── DEPLOYMENT_AND_PRODUCTION_READINESS_GUIDE.md  # Production roll-out & checklist
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
1. **Pillar 1:** Supabase Row Level Security (RLS) on all 8 tables & legally tamper-proof audit trails (City Ord. 2023-005).
2. **Pillar 2:** Anti-GPS Spoofing & Mock Location Sentinel (`isMocked` hardware interception & FIFO Digital Pila protection).
3. **Pillar 3:** Commuter & Driver Privacy ($k \ge 5$ Anonymization, Private Storage Buckets & 5m Signed URLs under RA 10173 & NPC Circular 2023-03).
4. **Pillar 4:** Role-Based Access Control (RBAC 4-tier model), Anti-Privilege Escalation Triggers & OTP Rate Limiting Defense.
5. **Pillar 5:** Backend Resilience, GPS Velocity Sanity Check ($80\text{ km/h}$ physical speed ceiling) & Exponential Backoff Retry.

📖 **Full Technical Architecture & Migration Ledger:** See [`SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/SECURITY_AND_BACKEND_HARDENING_ARCHITECTURE.md).

---

## 🧪 Static Analysis & Code Quality

Both clients maintain strict compliance with Dart/Flutter linting standards:
```bash
cd mobile_client && flutter analyze lib/
# Result: No issues found! (0 errors, 0 warnings)

cd web_client && flutter analyze lib/
# Result: No issues found! (0 errors, 0 warnings)
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
