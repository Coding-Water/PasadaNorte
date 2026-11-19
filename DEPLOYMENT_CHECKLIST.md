# PasadaNorte Pre-Deployment Priority Checklist

> [!IMPORTANT]
> **Strict Pre-Production Audit:** The following features have temporary testing bypasses enabled to facilitate rapid development and testing on computer emulators without camera hardware. Every item in this checklist **MUST** be restored, enforced, and verified before deploying to production on physical Android devices.

---

## 🚨 High-Priority Deployment Tasks (Fix Before Deploy)

### 1. 1:1 Live Face Verification (Real Phone Camera)
- [x] **Remove Skip Face Scan Button**: Delete `_skipFaceScan()` and the "Skip (Testing)" buttons from both the `AppBar` and the bottom action column in `mobile_client/lib/features/auth/views/face_scan_screen.dart`.
- [x] **Enforce Physical Camera Permissions**: Ensure `AndroidPermissionsService.ensureCameraPermission` strictly blocks proceeding without active camera permission on physical devices.
- [x] **Live Facial Match Enforcement**: On-device Google ML Kit 1:1 facial landmark & cosine similarity (`>= 85.0%`) is active in `mobile_client/lib/core/services/face_verification_service.dart` per RA 10173 & NPC Circular No. 2023-03.

### 2. Service Area Geofence & Inter-Municipality Tricycle Fare Matrix (Priority #2 — Fixed)
- [x] **Enforce Hard Service-Area Geofence (Block Outside Ilocos Norte / Outside PH)**:
  - Validate pickup & dropoff coordinates in `mobile_client/lib/features/rider/views/rider_map_booking_screen.dart` (`_onMapTapped`, search selection, and booking CTA) so locations outside the Philippines / Ilocos Norte (e.g., Hong Kong, Manila, Vigan / Ilocos Sur) are blocked with a clear *"Outside PasadaNorte Service Area"* alert.
  - Constrain `FlutterMap` camera bounds (`CameraConstraint.contain`) to Ilocos Norte and enforce `countrycodes=ph` + Ilocos Norte viewbox filtering in `mobile_client/lib/core/services/location_service.dart`.
- [x] **Two-Tier Distance Pricing & Other Ilocos Norte Municipalities Support**:
  - Keep **Laoag City Ordinance No. 2023-005** (`₱20` Regular / `₱15` Discounted 1st km + `₱2/km`) for intra-city / metro rides (`<= 8 km`, Laoag City & San Nicolas).
  - Add an **Inter-Municipality / Out-of-Town Tricycle Tier** in `mobile_client/lib/features/fare/services/fare_calculator_service.dart` for trips `> 8 km` to neighboring Ilocos Norte towns (e.g., Bacarra, Sarrat, Paoay, Batac, Dingras, Pasuquin, Burgos, Bangui, Pagudpud) with a realistic highway / special pakyaw per-km rate (instead of flat `₱2/km`), and expand suggested places/geocoding across approved Ilocos Norte municipalities.

### 3. Tricycle Vehicle Documentation (Driver Registration)
- [x] **Remove Skip Tricycle Photos Button**: Delete `_skipTricyclePhotos()` and the "Skip Tricycle Photos for now (Testing)" button in `mobile_client/lib/features/auth/views/id_upload_screen.dart`.
- [x] **Enforce Mandatory 4-Angle Uploads**: Ensure `_areAllVehiclePhotosUploaded` requires real image files for all 4 angles (Front View with Body #, Back View with LTO Plate, Left Side, and Right Side) before a driver can proceed to face verification.
- [x] **Vehicle Image Cloud Staging**: Verify driver tricycle photos are properly compressed and uploaded to the secure bucket for TODA/MINC franchise records.

### 4. Driver Credential Strictness
- [x] **Professional Driver's License**: Keep Professional Driver's License as the required driver credential in `_currentIdTypes` in `id_upload_screen.dart`.
- [x] **LTO / MINC OCR Validation**: Connect automated license number validation or manual TODA admin verification workflow before enabling driver duty toggle.

### 5. SMS OTP Gateway & Security (Remove Static OTP)
- [x] **Remove Static OTP Bypasses**: Remove `123456`, `202601`, and local `+639123456789` test bypasses from `mobile_client/lib/features/auth/views/phone_input_screen.dart` and `otp_verification_screen.dart`.
- [x] **Remove Auto-Fill Static OTP Buttons**: Remove testing auto-fill widgets and testing banners.
- [x] **Activate SMS Gateway (Spare Android + SMSGate Cloud Server)**:
  - Deployed `send-otp-sms`, `verify-otp-sms`, and `sms-gate-status` (with `lastSeen` heartbeat check) Edge Functions backed by `capcom6/android-sms-gateway` (`api.sms-gate.app`) and `supabase/migrations/20261119_sms_otp_codes.sql` (SHA-256 hashed OTPs, expiry, and attempt limits).
  - Enforced phone number uniqueness across `public.users` and `public.driver_applications` (`20261119_unique_phone_constraints.sql`).

### 6. Input Validation & Name Sanitization
- [x] **Reject Numbers & Special Symbols in Name Fields**: Update `Last Name`, `First Name`, and `Middle Name` inputs in `mobile_client/lib/features/auth/views/user_details_input_screen.dart` to reject numeric digits (`0-9`) and invalid symbols (`!`, `>`, `?`, `@`, `#`, `$`, `%`, etc.) using `FilteringTextInputFormatter` and form `validator` rules (allowing only letters including `ñ`/`Ñ`, spaces, hyphens `-`, and apostrophes `'`).
- [x] **Add Name Validation Tests**: Add widget tests verifying that numeric and symbol inputs in name fields are blocked or trigger clear validation errors.

### 7. Automated 1:1 Face Bio Scan Pass & Passenger Reuse
- [x] **Auto-Pass `1:1 Face Bio Scan` on High-Confidence AI Match**: In `web_client/lib/main.dart`, automatically mark `1:1 Face Bio Scan` as **Pass** when on-device ML Kit ID-to-selfie verification achieves `>= 85.0%` similarity (while keeping manual `Inspect` / `Resubmit` override available, and requiring manual admin review if `< 85.0%` or skipped).
- [x] **Reuse 1:1 Face Bio Scan Review Flow for Passengers**: **Passenger Applications** (`Passenger Applications & ID Verification`) implemented in `web_client/lib/main.dart` with ID + 1:1 Face Bio Scan `Inspect` / `Pass` / `Resubmit`, `<= 1 hour` SLA, and mobile redo flow.

### 8. Application Decision Notifications (Android + SMS)
- [x] **Native Android Notification Center Alerts**: Dispatch local Android notifications for Driver and Passenger Application decisions (Approved, Resubmission Requested, Rejected).
- [x] **SMS Decision Alerts (Android SMS Gateway)**: Deployed `send-sms-notice` Edge Function and wired `web_client` admin actions (Approved, Resubmission Requested, Rejected, and Document Renewal Grace notices) to send live SMS alerts alongside Android Notification Center alerts.

### 9. Multi-Emulator Testing Launch Configuration (Kept Intentionally)
- [x] **Keep Dual-Emulator Compound Launch Profile in `.vscode/launch.json`**:
  - Retained intentionally for local 2-device Driver + Passenger testing (does not affect production APKs or web builds).

### 10. Free OpenStreetMap & Curated Ilocos Norte Geocoding (Zero-Fee Architecture)
- [x] **No Paid Google Maps Platform Dependency**: PasadaNorte stays on `flutter_map` + Valhalla/OSRM road routing + Supabase `laoag_locations` at **\$0/month**.
- [x] **Geocoder Accuracy Fix (`location_service.dart`)**: Filters low-confidence (`score < 70`) and generic `Locality`/`Postal` ArcGIS fallback pins, reads ArcGIS `PlaceName`/`ShortLabel`, checks Supabase `laoag_locations` + `toda_terminals` first on tap/search, and adds `photon.komoot.io/reverse` as a free reverse fallback.
- [x] **Web Admin Places & Landmarks Pin Editor (`web_client/lib/main.dart`)**: Dedicated **Places & Landmarks** screen backed by `public.laoag_locations` + `20261119200000_laoag_locations_admin_rls.sql` so MINC admins can drop/fix rooftop pins visually on Satellite view and sync instantly to mobile apps with no APK rebuild.
- [x] **Passenger Pickup Landmark / Note (`rider_map_booking_screen.dart` & `bill_summary_checkout_screen.dart`)**: Optional landmark note field shown on checkout and forwarded directly to drivers alongside the pickup pin.

### 11. Temporary QA MINC Admin Account (Revoke After QA Testing)
- [ ] **Revoke / Delete QA Web Admin Account in Supabase Auth**:
  - After QA finishes testing on `https://coding-water.github.io/PasadaNorte/`, delete the temporary QA admin user in **Supabase Dashboard → Authentication → Users** (or revoke its `minc_admin` claim via SQL Editor):
    ```sql
    UPDATE auth.users
    SET raw_app_meta_data = raw_app_meta_data - 'role'
    WHERE email = 'qa.admin@pasadanorte.ph';
    ```
  - Verify only authorized production MINC Administrators retain `raw_app_meta_data ->> 'role' = 'minc_admin'`.

---

## 📋 Status Tracking Table

| Item | Component | Current Development State | Production Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Face Scan** | `face_scan_screen.dart`, `face_verification_service.dart` | Live blink/head-turn liveness + MobileFaceNet 192D TFLite embeddings + `0.0%` blank-photo check + R8 keep rules | Mandatory real camera 1:1 match (no manual bypass) | 🟢 Completed |
| **Service Geofence & Inter-Town Fares** | `rider_map_booking_screen.dart`, `location_service.dart`, `fare_calculator_service.dart` | Hard Ilocos Norte geofence, `CameraConstraint.contain`, and two-tier intra-city / inter-municipality fare matrix active | Hard Ilocos Norte geofence + two-tier intra-city / inter-municipality tricycle fare matrix | 🟢 Completed |
| **Tricycle Photos** | `id_upload_screen.dart` | Skip removed & 4-angle uploads enforced | Mandatory 4-angle physical photos | 🟢 Completed |
| **Driver ID Type & Duty Gate** | `id_upload_screen.dart`, `driver_map_duty_screen.dart` | Professional Driver's License + MINC approval required before going online | Strict MINC approval before duty active | 🟢 Completed |
| **SMS OTP & Phone Uniqueness** | `otp_verification_screen.dart`, `phone_input_screen.dart`, `send-otp-sms`, `verify-otp-sms` | Static & test bypasses removed; live Android SMS Gateway OTP + unique `phone_number` enforcement active | Live SMS OTP verification with rate/attempt limits | 🟢 Completed |
| **Name Validation** | `user_details_input_screen.dart` | Digits & symbols blocked in Last, First, and Middle Name fields + tests added | Block numbers & invalid symbols (`!`, `>`, `?`, etc.) | 🟢 Completed |
| **Face Bio Auto-Pass & Passenger Reuse** | `web_client/lib/main.dart`, `face_verification_service.dart` | Auto-marks `face_bio_scan` Pass when `>= 85.0%` + Passenger Applications side-by-side ID/Selfie inspection active | Auto-mark `face_bio_scan` Pass in web checklist when `>= 85%` | 🟢 Completed |
| **Decision Notifications (Android + SMS)** | `system_notification_service.dart`, `send-sms-notice`, `sms-gate-status` | Native Android alerts + live SMS Gateway alerts + 60s `lastSeen` gateway health monitor active | Android + SMS alerts for Approved / Resubmit / Rejected | 🟢 Completed |
| **Dual-Emulator Launch Config** | `.vscode/launch.json` | Kept intentionally for local Driver + Passenger multi-emulator testing (excluded from release builds) | Keep for dev workflow | 🟢 Kept Intentionally |
| **Maps & Geocoding (Zero-Fee)** | `location_service.dart`, `rider_map_booking_screen.dart`, `web_client/lib/main.dart`, `laoag_locations` | Geocoder filters, Supabase landmark priority, Photon reverse backup, Web Admin **Places & Landmarks Pin Editor**, and Passenger Pickup Landmark Note active at \$0/mo | Accurate zero-fee address search, pin curation, and landmark notes | 🟢 Completed |
| **QA MINC Admin Account** | Supabase `auth.users` (`app_metadata.role`) | Temporary QA MINC Admin account created for web portal testing | Delete user or revoke `minc_admin` role after QA sign-off | 🟡 Revoke After QA Test |
