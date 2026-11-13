# PasadaNorte Pre-Deployment Priority Checklist

> [!IMPORTANT]
> **Strict Pre-Production Audit:** The following features have temporary testing bypasses enabled to facilitate rapid development and testing on computer emulators without camera hardware. Every item in this checklist **MUST** be restored, enforced, and verified before deploying to production on physical Android devices.

---

## 🚨 High-Priority Deployment Tasks (Fix Before Deploy)

### 1. 1:1 Live Face Verification (Real Phone Camera)
- [ ] **Remove Skip Face Scan Button**: Delete `_skipFaceScan()` and the "Skip (Testing)" buttons from both the `AppBar` and the bottom action column in `mobile_client/lib/features/auth/views/face_scan_screen.dart`.
- [ ] **Enforce Physical Camera Permissions**: Ensure `AndroidPermissionsService.ensureCameraPermission` strictly blocks proceeding without active camera permission on physical devices.
- [x] **Live Facial Match Enforcement**: On-device Google ML Kit 1:1 facial landmark & cosine similarity (`>= 85.0%`) is active in `mobile_client/lib/core/services/face_verification_service.dart` per RA 10173 & NPC Circular No. 2023-03.

### 2. Tricycle Vehicle Documentation (Driver Registration)
- [ ] **Remove Skip Tricycle Photos Button**: Delete `_skipTricyclePhotos()` and the "Skip Tricycle Photos for now (Testing)" button in `mobile_client/lib/features/auth/views/id_upload_screen.dart`.
- [ ] **Enforce Mandatory 4-Angle Uploads**: Ensure `_areAllVehiclePhotosUploaded` requires real image files for all 4 angles (Front View with Body #, Back View with LTO Plate, Left Side, and Right Side) before a driver can proceed to face verification.
- [ ] **Vehicle Image Cloud Staging**: Verify driver tricycle photos are properly compressed and uploaded to the secure bucket for TODA/MINC franchise records.

### 3. Driver Credential Strictness
- [ ] **Professional Driver's License**: Keep Professional Driver's License as the required driver credential in `_currentIdTypes` in `id_upload_screen.dart`.
- [ ] **LTO / MINC OCR Validation**: Connect automated license number validation or manual TODA admin verification workflow before enabling driver duty toggle.

### 4. SMS OTP Gateway & Security (Remove Static OTP)
- [ ] **Remove Static OTP Bypasses**: Remove `123456` and `202601` static fallback in `mobile_client/lib/features/auth/views/otp_verification_screen.dart`.
- [ ] **Remove Auto-Fill Static OTP Buttons**: Remove testing auto-fill widgets and testing banners.
- [ ] **Activate SMS Gateway (Spare Android + SMSGate or PH Gateway)**:
  - **Academic / Low-Cost Option (SMSGate + Unli-Text SIM):** Install [SMSGate](https://github.com/capcom6/android-sms-gateway/releases) on a spare Android phone with a PH Unli-All-Net Text promo, enable Cloud Server, disable Battery Optimization, and store `SMSGATE_USER` / `SMSGATE_PASS` in a Supabase Edge Function (`send-sms`) calling `https://api.sms-gate.app/3rdparty/v1/message`.
  - **Production Gateway Option:** Connect Semaphore / PhilSMS / Twilio via Supabase Edge Function with 60-second cooldown and 3-attempt lockout.

### 5. Input Validation & Name Sanitization
- [ ] **Reject Numbers & Special Symbols in Name Fields**: Update `Last Name`, `First Name`, and `Middle Name` inputs in `mobile_client/lib/features/auth/views/user_details_input_screen.dart` to reject numeric digits (`0-9`) and invalid symbols (`!`, `>`, `?`, `@`, `#`, `$`, `%`, etc.) using `FilteringTextInputFormatter` and form `validator` rules (allowing only letters including `ñ`/`Ñ`, spaces, hyphens `-`, and apostrophes `'`).
- [ ] **Add Name Validation Tests**: Add widget tests verifying that numeric and symbol inputs in name fields are blocked or trigger clear validation errors.

### 6. Automated 1:1 Face Bio Scan Pass & Passenger Reuse
- [ ] **Auto-Pass `1:1 Face Bio Scan` on High-Confidence AI Match**: In `web_client/lib/main.dart`, automatically mark `1:1 Face Bio Scan` as **Pass** when on-device ML Kit ID-to-selfie verification achieves `>= 85.0%` similarity (while keeping manual `Inspect` / `Resubmit` override available, and requiring manual admin review if `< 85.0%` or skipped).
- [x] **Reuse 1:1 Face Bio Scan Review Flow for Passengers**: **Passenger Applications** (`Passenger Applications & ID Verification`) implemented in `web_client/lib/main.dart` with ID + 1:1 Face Bio Scan `Inspect` / `Pass` / `Resubmit`, `<= 1 hour` SLA, and mobile redo flow.

### 7. Application Decision Notifications (Android + SMS)
- [x] **Native Android Notification Center Alerts**: Dispatch local Android notifications for Driver and Passenger Application decisions (Approved, Resubmission Requested, Rejected).
- [ ] **SMS Decision Alerts (SMSGate / PH Gateway)**: Trigger the `send-sms` Edge Function (backed by Spare Android SMSGate or Semaphore) alongside Android Notification Center alerts for Approved, Resubmission Requested, and Rejected decisions.

---

## 📋 Status Tracking Table

| Item | Component | Current Development State | Production Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Face Scan** | `face_scan_screen.dart` | Skip button enabled for computer emulator testing | Mandatory real camera 1:1 match | 🟡 Ready to Enforce |
| **Tricycle Photos** | `id_upload_screen.dart` | Skip button enabled for rapid testing | Mandatory 4-angle physical photos | 🟡 Ready to Enforce |
| **Driver ID Type** | `id_upload_screen.dart` | Professional Driver's License only | Professional Driver's License only | 🟢 Completed |
| **SMS OTP** | `otp_verification_screen.dart` | Static OTP `123456` enabled for testing | Spare Android SMSGate (`api.sms-gate.app`) or PH SMS gateway | 🟡 Testing Enabled |
| **Name Validation** | `user_details_input_screen.dart` | Accepts free-text input without blocking digits/symbols | Block numbers & invalid symbols (`!`, `>`, `?`, etc.) | 🔴 Pending Fix |
| **Face Bio Auto-Pass & Passenger Reuse** | `web_client/lib/main.dart`, `face_verification_service.dart` | On-device ML Kit (`>= 85%`) & Passenger Applications active; manual checklist `Pass` in web | Auto-mark `face_bio_scan` Pass in web checklist when `>= 85%` | 🟡 Passenger Done / Auto-Pass Pending |
| **Decision Notifications** | `system_notification_service.dart` | Native Android Notification Center alerts active for Drivers & Passengers | Add SMS alerts via SMSGate / PH gateway for Approved / Resubmit / Rejected | 🟡 Android Done / SMS Pending |
