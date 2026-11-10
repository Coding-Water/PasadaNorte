# PasadaNorte — Security & Backend Hardening Architecture

**Laoag City Paratransit Dispatch, Digital Pila, and Municipal Regulation Ecosystem**  
**Compliance Standards:** Republic Act No. 10173 (Data Privacy Act of 2012) • Laoag City Ordinance No. 2023-005 • ISO/IEC 25010:2023 • ISO/IEC 19795-1:2021 • NPC Circulars 2016-01 & 2023-03

---

## Executive Summary

The **PasadaNorte** security architecture enforces municipal regulatory integrity, commuter travel privacy, hardware sensor authenticity, and operational fault tolerance across three tightly integrated tiers:
1. **Flutter Mobile Client** (Commuter & Driver cockpits)
2. **Flutter Web Admin Command Center** (Laoag City MINC & TODA regulators)
3. **Supabase Cloud PostGIS Engine** (PostgreSQL RLS, spatial geofences, and immutable audit logs)

The system is fortified across **Five Core Security & Hardening Pillars**:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   PASADANORTE 5-PILLAR HARDENING ARCHITECTURE                    │
├───────────────────┬───────────────────┬───────────────────┬──────────────────────┤
│     PILLAR 1      │     PILLAR 2      │     PILLAR 3      │      PILLAR 4        │
│  Database & RLS   │ Anti-GPS Spoofing │ Commuter Privacy  │    RBAC & Security   │
│                   │                   │   & Private Vault │                      │
│ • RLS on 8 tables │ • isMocked sensor │ • k >= 5 anonym-  │ • 4-tier RBAC guard  │
│ • Immutable MINC  │   interception    │   ization heatmap │ • Anti-privilege     │
│   audit logs      │ • FIFO Pila queue │ • Private Storage │   escalation trigger │
│ • ST_DWithin RLS  │   tamper defense  │   buckets (5m URL)│ • 3-attempt OTP rate │
│ • City Ord. 2023  │ • Interactive test│ • NPC 72h auto-   │   limit & 60s cooldown│
│   compliance      │   simulation chips│   purge routine   │ • Web role switcher  │
├───────────────────┴───────────────────┴───────────────────┴──────────────────────┤
│                                     PILLAR 5                                     │
│                 Backend Resilience & Velocity Sanity Sentinel                    │
│ • GPS Velocity Sanity (80 km/h physical ceiling for Laoag tricycles)             │
│ • PostGIS Teleportation Anomaly Trigger (ST_Distance delta calculation)          │
│ • Filtered valid_driver_telemetry View (suppresses mock & anomalous pings)       │
│ • Exponential Backoff Retry Loop (intermittent cellular recovery)                │
│ • ISO/IEC 25010:2023 Non-Freezing Operational Offline Fail-Safe                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Breakdown of the Five Pillars

### Pillar 1: Database & Row Level Security (RLS) Hardening
* **Migration File:** [`supabase/migrations/20261110_pillar1_rls_and_security_hardening.sql`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261110_pillar1_rls_and_security_hardening.sql)
* **Standards Enforced:** Laoag City Ordinance No. 2023-005 • ISO/IEC 25010 Integrity
* **Implementation Details:**
  1. **Comprehensive RLS Activation:** Explicitly enabled `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` across all 8 core relations:
     - `fare_guide_table`
     - `emergency_sos_alerts`
     - `toda_terminals`
     - `driver_completed_trips`
     - `completed_trips`
     - `driver_telemetry`
     - `users`
     - `minc_trip_audit_logs`
  2. **Security Definer RBAC Helper Functions:** Created `public.is_minc_admin()` and `public.is_driver()` to verify caller authorization at the database engine level.
  3. **Legally Tamper-Proof Audit Trail:** Applied PostgreSQL trigger `trg_immutable_audit_logs` to `minc_trip_audit_logs`. The trigger rejects any `UPDATE` or `DELETE` statements (`RAISE EXCEPTION`), creating a legally admissible, immutable record for municipal overcharging hearings.
  4. **Emergency SOS Broadcast Rules:** Allows drivers to insert distress beacons while restricting status updates and PNP dispatch actions to authenticated MINC administrators.

---

### Pillar 2: Anti-GPS Spoofing & Mock Location Sentinel
* **Migration File:** [`supabase/migrations/20261110_pillar2_anti_spoofing_telemetry.sql`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261110_pillar2_anti_spoofing_telemetry.sql)
* **Code Implementation:** [`LocationService`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/core/services/location_service.dart) • [`TodaQueueService`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/core/services/toda_queue_service.dart) • [`TodaQueueScreen`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/toda_queue_screen.dart) • [`DriverMapDutyScreen`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart)
* **Implementation Details:**
  1. **Hardware Sensor Interception:** Captures `pos.isMocked` directly from Android `LocationManager.isFromMockProvider()` and iOS simulated location providers.
  2. **FIFO Digital Pila Tamper Defense:** If mock location is active (`isMockGps || LocationService.hasMockLocationViolation`), `TodaQueueService.evaluateQueueStatus()` returns `QueueStatus.mockGpsBlocked`. Drivers cannot spoof their location to jump to **Pila Rank #1** over physically present operators.
  3. **Visual Cockpit Warning:** The floating Pila badge turns red (`SPOOF BLOCKED - Mock GPS Violation Detected`), and an alert card explains the violation under Laoag City Ordinance No. 2023-005.
  4. **Cloud Telemetry Flag & Audit Trigger:** Telemetry records include `is_mocked`. Trigger `trg_driver_telemetry_mock_audit` automatically registers spoofing incidents in `minc_trip_audit_logs`.
  5. **Academic & Field Testing Chip:** Added interactive **"Simulate Mock GPS Spoofing Alert"** chips so thesis defense panels and testers can demonstrate spoof rejection without rooting physical devices.

---

### Pillar 3: Commuter & Driver Privacy Hardening
* **Migration File:** [`supabase/migrations/20261110_pillar3_commuter_privacy_and_storage.sql`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261110_pillar3_commuter_privacy_and_storage.sql)
* **Standards Enforced:** Republic Act No. 10173 (Data Privacy Act of 2012) • NPC Circular 2023-03 / 2016-01
* **Implementation Details:**
  1. **$k \ge 5$ Anonymization & Disclosure Control:** On the **Laoag City 10-Zone Corridor Heatmap**, zones with fewer than $k = 5$ trips per hour are masked (`<5 req/hr (Suppressed)`) with an amber privacy badge to prevent re-identification of isolated commuter travel corridors.
  2. **SQL-Level Privacy View (`anonymized_zone_demand`):** Employs `CASE WHEN predicted_trip_count >= 5 THEN ... ELSE NULL END` at the database level.
  3. **Private Storage Buckets (`public = false`):** Created private storage buckets `id-documents` and `biometric-vault`. Direct public CDN links are disabled.
  4. **Time-Expiring 5-Minute Signed URLs:** Reviewers inspect driver licenses, student IDs, and OSCA senior cards using short-lived HMAC tokens (valid 300s) generated via [`SupabaseService.createPrivateDocumentSignedUrl`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/core/services/supabase_service.dart).
  5. **Mandatory Auto-Purge Routine:** Added stored procedure `purge_expired_biometric_staging_records()` to zero raw facial staging images older than 7 days, retaining only encrypted 512-d mathematical vector embeddings (`encrypted_face_templates`).
  6. **Phone Number Masking:** Administrative inspection lists mask contact details (e.g. `+63 917 *** *029`).

---

### Pillar 4: Role-Based Access Control (RBAC) & Rate Limiting
* **Migration File:** [`supabase/migrations/20261110_pillar4_rbac_and_rate_limiting.sql`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261110_pillar4_rbac_and_rate_limiting.sql)
* **Code Implementation:** [`UserModel`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/auth/models/user_model.dart) • [`OtpVerificationScreen`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/auth/views/otp_verification_screen.dart) • [`web_client/lib/main.dart`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/web_client/lib/main.dart)
* **Implementation Details:**
  1. **4-Tier Paratransit Governance Hierarchy:**
     - `rider`: Commuters (booking, upfront fare calculation, statutory discounts)
     - `driver`: Tricycle drivers (duty map, Pila queue, telemetry broadcast, distress beacon)
     - `toda_admin`: Terminal marshals (geofence tuning, terminal driver directory)
     - `minc_admin`: City regulatory board (fare guide updates, summons generation, audit review)
  2. **Anti-Privilege Escalation Trigger:** Trigger `trg_prevent_role_escalation` prohibits non-admin callers from executing `UPDATE users SET role = 'minc_admin'`.
  3. **OTP Rate Limiting & Cooldown Protection:**
     - **60-Second Cooldown Timer:** Locks resend button with live countdown.
     - **3-Attempt Lockout Defense:** Prevents brute-forcing and protects against SMS toll-fraud.
     - **Dedicated SMS Gateway Hold:** Provides test mode banner (`Demo OTP: 202601` with one-tap auto-fill) while maintaining production rate-limiting logic.
  4. **Web Portal RBAC Session Switcher:** Allows toggling between `MINC Super-Admin` and `TODA Dispatcher` on the fly to inspect permission boundaries:
     - `TODA Dispatcher`: City Ordinance No. 2023-005 Fare Matrix editing is locked with a warning badge; cloud save button is disabled.
     - `MINC Super-Admin`: Full editing unlocked with cryptographic logging.

---

### Pillar 5: Backend Resilience & GPS Velocity Sanity Check
* **Migration File:** [`supabase/migrations/20261110_pillar5_velocity_sanity_and_resilience.sql`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations/20261110_pillar5_velocity_sanity_and_resilience.sql)
* **Code Implementation:** [`LocationService`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/core/services/location_service.dart) • [`SupabaseService`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/core/services/supabase_service.dart)
* **Standards Enforced:** ISO/IEC 25010:2023 Reliability & Fault Tolerance
* **Implementation Details:**
  1. **GPS Velocity Sanity Filter:** Evaluates vehicle speed between successive GPS pings:
     $$\text{Velocity} = \frac{\Delta \text{Distance (km)}}{\Delta \text{Time (hours)}}$$
     Sets an $80\text{ km/h}$ physical ceiling (maximum motorized tricycle speed in Laoag City). Any sensor teleportation spike or corrupt GPS jump is rejected client-side before broadcast.
  2. **PostGIS Velocity Sanity Trigger:** Trigger `trg_driver_telemetry_velocity` uses PostGIS `ST_Distance` on `driver_telemetry`. If speed exceeds $80\text{ km/h}$, sets `velocity_anomalous = TRUE` and logs the teleportation attempt to `minc_trip_audit_logs`.
  3. **Filtered View (`valid_driver_telemetry`):** Excludes both mock GPS coordinates (`is_mocked = TRUE`) and velocity spikes (`velocity_anomalous = TRUE`), ensuring commuters and dispatchers see clean, authentic positions.
  4. **Exponential Backoff Network Resilience:** Cloud telemetry sync retries up to 3 times (with backoff intervals of 250ms, 500ms, 750ms), preventing transient 4G/LTE drops along rural corridors (e.g. Gabu airport road) from disconnecting active drivers.
  5. **ISO/IEC 25010 Non-Freezing Operational Fail-Safe:** Driver cockpits maintain local route caching, Pila rank, and trip records without freezing the UI when cellular connectivity is lost.

---

## Database Migration Ledger

All five migration files are located in [`supabase/migrations/`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/supabase/migrations):

| Migration File | Description | Execution Target |
| :--- | :--- | :--- |
| `20261110_pillar1_rls_and_security_hardening.sql` | RLS on all 8 tables, RBAC functions, and immutable audit logs | Supabase SQL Editor |
| `20261110_pillar2_anti_spoofing_telemetry.sql` | `is_mocked` column, mock detection trigger, and initial view | Supabase SQL Editor |
| `20261110_pillar3_commuter_privacy_and_storage.sql` | $k \ge 5$ secure view, private storage buckets, and retention purge | Supabase SQL Editor |
| `20261110_pillar4_rbac_and_rate_limiting.sql` | RBAC functions, anti-privilege escalation trigger, OTP rate limits | Supabase SQL Editor |
| `20261110_pillar5_velocity_sanity_and_resilience.sql` | PostGIS velocity sanity trigger, DROP VIEW CASCADE, and clean view | Supabase SQL Editor |

---

## Comprehensive Security & Codebase Audit Results

A full multi-phase security scan and static analysis was performed on **November 10, 2026**:

### 1. Static Analysis & Compilation Check
* **`mobile_client`:** `flutter analyze lib/` &rarr; **`No issues found!`** (0 errors, 0 warnings, 0 infos)
* **`web_client`:** `flutter analyze lib/` &rarr; **`No issues found!`** (0 errors, 0 warnings, 0 infos)

### 2. Secret & Credential Leak Scan
* **Service Role Key:** **0 found.** The high-privilege `service_role` key is **not** present in client source code or version control.
* **Database Password:** **0 found.** Direct PostgreSQL connection strings are not exposed.
* **SMS Gateway Secrets:** **0 found.** Dedicated provider keys held; zero billing credentials exposed.
* **Google Maps API Key:** **0 hardcoded.** Passed securely via compile-time environment defines (`String.fromEnvironment('GOOGLE_MAPS_API_KEY')`).

### 3. Open-Source Civic API Safety
* **Photon, Nominatim, Valhalla, and OSRM:** Free public civic services. Zero financial exposure or billing risk.
