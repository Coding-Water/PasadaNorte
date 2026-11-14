# PasadaNorte Pre-Deployment Priority Checklist

> [!IMPORTANT]
> **Strict Pre-Production Audit:** The following features have temporary testing bypasses enabled to facilitate rapid development and testing on computer emulators without camera hardware. Every item in this checklist **MUST** be restored, enforced, and verified before deploying to production on physical Android devices.

---

## 🚨 High-Priority Deployment Tasks (Fix Before Deploy)

### 1. 1:1 Live Face Verification (Real Phone Camera)
- [x] **Remove Skip Face Scan Button**: Delete `_skipFaceScan()` and the "Skip (Testing)" buttons from both the `AppBar` and the bottom action column in `mobile_client/lib/features/auth/views/face_scan_screen.dart`.
- [x] **Enforce Physical Camera Permissions**: Ensure `AndroidPermissionsService.ensureCameraPermission` strictly blocks proceeding without active camera permission on physical devices.
- [x] **Live Facial Match Enforcement**: On-device Google ML Kit 1:1 facial landmark & cosine similarity (`>= 85.0%`) is active in `mobile_client/lib/core/services/face_verification_service.dart` per RA 10173 & NPC Circular No. 2023-03.

### 2. Service Area Geofence & Inter-Municipality Tricycle Fare Matrix (Priority #2 — Needs Fixing)
- [ ] **Enforce Hard Service-Area Geofence (Block Outside Ilocos Norte / Outside PH)**:
  - Validate pickup & dropoff coordinates in `mobile_client/lib/features/rider/views/rider_map_booking_screen.dart` (`_onMapTapped`, search selection, and booking CTA) so locations outside the Philippines / Ilocos Norte (e.g., Hong Kong, Manila, Vigan / Ilocos Sur) are blocked with a clear *"Outside PasadaNorte Service Area"* alert.
  - Constrain `FlutterMap` camera bounds (`CameraConstraint.contain`) to Ilocos Norte and enforce `countrycodes=ph` + Ilocos Norte viewbox filtering in `mobile_client/lib/core/services/location_service.dart`.
- [ ] **Two-Tier Distance Pricing & Other Ilocos Norte Municipalities Support**:
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
- [x] **Remove Static OTP Bypasses**: Remove `123456` and `202601` static fallback in `mobile_client/lib/features/auth/views/otp_verification_screen.dart`.
- [x] **Remove Auto-Fill Static OTP Buttons**: Remove testing auto-fill widgets and testing banners.
- [ ] **Activate SMS Gateway (Spare Android + SMSGate or PH Gateway)**:
  - **Academic / Low-Cost Option (SMSGate + Unli-Text SIM):** Install [SMSGate](https://github.com/capcom6/android-sms-gateway/releases) on a spare Android phone with a PH Unli-All-Net Text promo, enable Cloud Server, disable Battery Optimization, and store `SMSGATE_USER` / `SMSGATE_PASS` in a Supabase Edge Function (`send-sms`) calling `https://api.sms-gate.app/3rdparty/v1/message`.
  - **Production Gateway Option:** Connect Semaphore / PhilSMS / Twilio via Supabase Edge Function with 60-second cooldown and 3-attempt lockout.

### 6. Input Validation & Name Sanitization
- [x] **Reject Numbers & Special Symbols in Name Fields**: Update `Last Name`, `First Name`, and `Middle Name` inputs in `mobile_client/lib/features/auth/views/user_details_input_screen.dart` to reject numeric digits (`0-9`) and invalid symbols (`!`, `>`, `?`, `@`, `#`, `$`, `%`, etc.) using `FilteringTextInputFormatter` and form `validator` rules (allowing only letters including `ñ`/`Ñ`, spaces, hyphens `-`, and apostrophes `'`).
- [x] **Add Name Validation Tests**: Add widget tests verifying that numeric and symbol inputs in name fields are blocked or trigger clear validation errors.

### 7. Automated 1:1 Face Bio Scan Pass & Passenger Reuse
- [x] **Auto-Pass `1:1 Face Bio Scan` on High-Confidence AI Match**: In `web_client/lib/main.dart`, automatically mark `1:1 Face Bio Scan` as **Pass** when on-device ML Kit ID-to-selfie verification achieves `>= 85.0%` similarity (while keeping manual `Inspect` / `Resubmit` override available, and requiring manual admin review if `< 85.0%` or skipped).
- [x] **Reuse 1:1 Face Bio Scan Review Flow for Passengers**: **Passenger Applications** (`Passenger Applications & ID Verification`) implemented in `web_client/lib/main.dart` with ID + 1:1 Face Bio Scan `Inspect` / `Pass` / `Resubmit`, `<= 1 hour` SLA, and mobile redo flow.

### 8. Application Decision Notifications (Android + SMS)
- [x] **Native Android Notification Center Alerts**: Dispatch local Android notifications for Driver and Passenger Application decisions (Approved, Resubmission Requested, Rejected).
- [ ] **SMS Decision Alerts (SMSGate / PH Gateway)**: Trigger the `send-sms` Edge Function (backed by Spare Android SMSGate or Semaphore) alongside Android Notification Center alerts for Approved, Resubmission Requested, and Rejected decisions.

---

## 📋 Status Tracking Table

| Item | Component | Current Development State | Production Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Face Scan** | `face_scan_screen.dart` | Skip removed & physical camera permission enforced | Mandatory real camera 1:1 match | 🟢 Completed |
| **Service Geofence & Inter-Town Fares** | `rider_map_booking_screen.dart`, `location_service.dart`, `fare_calculator_service.dart` | Map tap allows booking outside PH (e.g., Hong Kong) and applies ₱2/km to long inter-town trips | Hard Ilocos Norte geofence + two-tier intra-city / inter-municipality tricycle fare matrix | 🔴 Priority #2 Needs Fixing |
| **Tricycle Photos** | `id_upload_screen.dart` | Skip removed & 4-angle uploads enforced | Mandatory 4-angle physical photos | 🟢 Completed |
| **Driver ID Type & Duty Gate** | `id_upload_screen.dart`, `driver_map_duty_screen.dart` | Professional Driver's License + MINC approval required before going online | Strict MINC approval before duty active | 🟢 Completed |
| **SMS OTP** | `otp_verification_screen.dart` | Static OTP `123456` / `202601` removed; wired to Supabase Auth | Activate SMSGate (`api.sms-gate.app`) or PH SMS gateway | 🟡 Static Bypass Removed / Gateway Pending |
| **Name Validation** | `user_details_input_screen.dart` | Digits & symbols blocked in Last, First, and Middle Name fields + tests added | Block numbers & invalid symbols (`!`, `>`, `?`, etc.) | 🟢 Completed |
| **Face Bio Auto-Pass & Passenger Reuse** | `web_client/lib/main.dart`, `face_verification_service.dart` | Auto-marks `face_bio_scan` Pass when `>= 85.0%` + Passenger Applications active | Auto-mark `face_bio_scan` Pass in web checklist when `>= 85%` | 🟢 Completed |
| **Decision Notifications** | `system_notification_service.dart` | Native Android Notification Center alerts active for Drivers & Passengers | Add SMS alerts via SMSGate / PH gateway for Approved / Resubmit / Rejected | 🟡 Android Done / SMS Pending |
