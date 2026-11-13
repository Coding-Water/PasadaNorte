# PasadaNorte Pre-Deployment Priority Checklist

> [!IMPORTANT]
> **Strict Pre-Production Audit:** The following features have temporary testing bypasses enabled to facilitate rapid development and testing on computer emulators without camera hardware. Every item in this checklist **MUST** be restored, enforced, and verified before deploying to production on physical Android devices.

---

## 🚨 High-Priority Deployment Tasks (Fix Before Deploy)

### 1. 1:1 Live Face Verification (Real Phone Camera)
- [ ] **Remove Skip Face Scan Button**: Delete `_skipFaceScan()` and the "Skip (Testing)" buttons from both the `AppBar` and the bottom action column in `mobile_client/lib/features/auth/views/face_scan_screen.dart`.
- [ ] **Enforce Physical Camera Permissions**: Ensure `AndroidPermissionsService.ensureCameraPermission` strictly blocks proceeding without active camera permission on physical devices.
- [ ] **Live Facial Match Enforcement**: Ensure 1:1 facial embedding matching (target cosine similarity >= 85%) runs with live camera selfie against the government ID portrait per RA 10173 & NPC Circular No. 2023-03.

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
- [ ] **Activate Production SMS Gateway**: Connect live Philippine telco SMS API (Semaphore / Twilio) to dispatch 6-digit one-time PINs via real cellular SMS with 60-second cooldown and 3-attempt lockout.

### 5. Input Validation & Name Sanitization
- [ ] **Reject Numbers & Special Symbols in Name Fields**: Update `Last Name`, `First Name`, and `Middle Name` inputs in `mobile_client/lib/features/auth/views/user_details_input_screen.dart` to reject numeric digits (`0-9`) and invalid symbols (`!`, `>`, `?`, `@`, `#`, `$`, `%`, etc.) using `FilteringTextInputFormatter` and form `validator` rules (allowing only letters including `ñ`/`Ñ`, spaces, hyphens `-`, and apostrophes `'`).
- [ ] **Add Name Validation Tests**: Add widget tests verifying that numeric and symbol inputs in name fields are blocked or trigger clear validation errors.

### 6. Automated 1:1 Face Bio Scan Pass & Passenger Reuse
- [ ] **Auto-Pass `1:1 Face Bio Scan` on High-Confidence AI/Python Match**: In `web_client/lib/main.dart`, automatically mark `1:1 Face Bio Scan` as **Pass** when the Python/AI ID-to-selfie verification achieves `>= 85.0%` similarity (while keeping manual `Inspect` / `Resubmit` override available, and requiring manual admin review if `< 85.0%` or skipped).
- [ ] **Reuse 1:1 Face Bio Scan Review Flow for Passengers**: Apply the same `1:1 Face Bio Scan` auto-pass, manual admin review (`Inspect`, `Resubmit` with reason combo box, `Pass`), and mobile redo flow to **Passenger (Rider)** ID verification.

### 7. Application Decision Notifications (Android + SMS)
- [x] **Native Android Notification Center Alerts**: Dispatch local Android notifications for Driver Application decisions (Approved, Resubmission Requested, Rejected).
- [ ] **Production SMS Decision Alerts**: Add SMS notifications alongside Android Notification Center alerts for Approved, Resubmission Requested, and Rejected decisions.

---

## 📋 Status Tracking Table

| Item | Component | Current Development State | Production Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Face Scan** | `face_scan_screen.dart` | Skip button enabled for computer emulator testing | Mandatory real camera 1:1 match | 🟡 Ready to Enforce |
| **Tricycle Photos** | `id_upload_screen.dart` | Skip button enabled for rapid testing | Mandatory 4-angle physical photos | 🟡 Ready to Enforce |
| **Driver ID Type** | `id_upload_screen.dart` | Professional Driver's License only | Professional Driver's License only | 🟢 Completed |
| **SMS OTP** | `otp_verification_screen.dart` | Static OTP `123456` enabled for testing | Live Philippine cellular SMS gateway | 🟡 Testing Enabled |
| **Name Validation** | `user_details_input_screen.dart` | Accepts free-text input without blocking digits/symbols | Block numbers & invalid symbols (`!`, `>`, `?`, etc.) | 🔴 Pending Fix |
| **Face Bio Auto-Pass & Passenger Reuse** | `web_client/lib/main.dart`, `face_verification_service.dart` | Manual `Pass` required for Driver `1:1 Face Bio Scan` | Auto-pass `>= 85%` Python/AI match & reuse flow for Passengers | 🔴 Pending Implementation |
| **Decision Notifications** | `system_notification_service.dart` | Native Android Notification Center alerts active | Add SMS notifications for Approved / Resubmit / Rejected | 🟡 Android Done / SMS Pending |
