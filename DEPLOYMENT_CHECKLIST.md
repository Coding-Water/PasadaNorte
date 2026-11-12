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

---

## 📋 Status Tracking Table

| Item | Component | Current Development State | Production Requirement | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Face Scan** | `face_scan_screen.dart` | Skip button enabled for computer emulator testing | Mandatory real camera 1:1 match | 🟡 Ready to Enforce |
| **Tricycle Photos** | `id_upload_screen.dart` | Skip button enabled for rapid testing | Mandatory 4-angle physical photos | 🟡 Ready to Enforce |
| **Driver ID Type** | `id_upload_screen.dart` | Professional Driver's License only | Professional Driver's License only | 🟢 Completed |
| **SMS OTP** | `otp_verification_screen.dart` | Static OTP `123456` enabled for testing | Live Philippine cellular SMS gateway | 🟡 Testing Enabled |
