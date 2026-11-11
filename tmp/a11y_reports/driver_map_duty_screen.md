# Accessibility (a11y) & Full QA Audit Report
**Target Component:** [`DriverMapDutyScreen`](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart)  
**File Path:** `mobile_client/lib/features/driver/views/driver_map_duty_screen.dart`  
**Audit Standard:** WCAG 2.1 / 2.2 Levels A & AA, ISO/IEC 25010:2023, Flutter Accessibility Guidelines  
**Auditor Mode:** Isolated Page Auditor  

---

## 1. Executive Summary & Audit Scorecard

The `DriverMapDutyScreen` is the primary operational workspace for tricycle paratransit drivers in Laoag City (PasadaNorte). It renders a full-bleed interactive map (`FlutterMap`), floating duty controls, active queue ranks, quick shift metrics, an emergency SOS trigger, and an incoming dispatch offer dialog.

While the screen implements strong domain ergonomics (such as audio chimes, heavy haptic feedback, and ISO/IEC 25010 offline fail-safe handling), it has several **critical and high-severity accessibility defects** regarding screen reader semantics, tap target dimensions, color contrast ratios, keyboard/switch navigation, and dynamic text scaling.

| Category | Status | Summary Findings |
| :--- | :---: | :--- |
| **1. Semantics & Screen Readers** | ⚠️ Needs Immediate Fix | Multiple interactive controls use unlabelled `GestureDetector` widgets; SOS button lacks semantic label; 15-second dispatch countdown lacks `liveRegion`. |
| **2. Tap Targets** | ❌ Failing (Android 48x48) | Circular header buttons are 44x44 dp (fails Android minimum 48x48); Emergency SOS button is only 40x40 dp; dialog Accept button height is 46 dp. |
| **3. Visual & Color Contrast** | ❌ Failing (WCAG AA 4.5:1) | Mint text `#00B14F` on mint background `#E8F8EF` yields **2.57:1** (fails 4.5:1); `grey.shade500` yields **2.32:1**; 9sp text size on metadata badges. |
| **4. Text Scaling** | ⚠️ Risk of Overflow | Modal buttons use rigid `SizedBox(height: 50)`; header metrics row has fixed horizontal layout; map landmark pins have fixed 32dp bounds. |
| **5. Focus & Keyboard Traversal** | ❌ Non-Navigable | 5 key controls (`GestureDetector`) cannot receive focus via external hardware keyboards, switch devices, or motorcycle D-pad controllers. |
| **6. Automated A11y Testing** | ❌ Missing | No widget tests validate `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `textContrastGuideline`, or `labeledTapTargetGuideline`. |

---

## 2. Findings Grouped by Severity

### Critical Severity (Must Fix Immediately)

#### [CRIT-01] Emergency SOS Panic Button Lacks Semantics and Is Severely Undersized (40x40 dp)
* **Category:** Semantics and Screen Readers / Tap Targets / Motor Accessibility
* **WCAG Criteria:** WCAG 2.5.5 Target Size (AAA), WCAG 2.5.8 Target Size (Minimum, AA), WCAG 4.1.2 Name, Role, Value (A)
* **Location:** [driver_map_duty_screen.dart#L1327-L1345](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1327-L1345)
* **Defect Explanation:**
  The Emergency SOS button is constructed as:
  ```dart
  GestureDetector(
    onTap: _showSosEmergencyDialog,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
    ),
  )
  ```
  1. **Semantics:** It has no `Semantics` widget, no `semanticLabel` on the icon, and no button trait. TalkBack / VoiceOver announces it as an unlabelled element or completely ignores it. In an emergency, a visually impaired driver or driver in distress cannot find or activate the panic beacon.
  2. **Hit Target Bounds:** Total dimensions are `20 + (10 * 2) = 40x40 dp`. This violates the Android 48x48 dp minimum and iOS 44x44 dp minimum. For an emergency panic button, this creates an acute safety hazard.
  3. **Focusability:** A raw `GestureDetector` cannot receive keyboard, D-pad, or switch device focus.
* **Concrete Code Fix:**
  ```dart
  Semantics(
    button: true,
    label: 'Emergency SOS Panic Beacon',
    hint: 'Double tap to broadcast high-priority distress alert with live GPS coordinates to Laoag PNP and TODA dispatch',
    child: Tooltip(
      message: 'Emergency SOS',
      child: Material(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showSosEmergencyDialog,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: const Center(
              child: Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    ),
  )
  ```

---

#### [CRIT-02] Severe WCAG Contrast Failure (2.57:1) on Accent Mint Badges & Text
* **Category:** Visual and Color Contrast
* **WCAG Criteria:** WCAG 1.4.3 Contrast (Minimum) (AA)
* **Location:** [driver_map_duty_screen.dart#L163-L167](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L163-L167), [L334-L346](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L334-L346), [L547-L557](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L547-L557), [L658-L678](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L658-L678)
* **Defect Explanation:**
  The screen frequently pairs text with `AppTheme.accentEmerald` (`#00B14F`) over `AppTheme.accentEmeraldLight` (`#E8F8EF`):
  - Line 163-167 (Incoming Dispatch dialog dialect announcement):
    ```dart
    Container(
      decoration: BoxDecoration(color: AppTheme.accentEmeraldLight),
      child: const Text('🔊 "Adda sakay dita Laoag Central Market!"', style: TextStyle(color: AppTheme.accentEmerald, ...)),
    )
    ```
  - Line 341: `ACTIVE SHIFT` badge in shift earnings (`fontSize: 10.5`).
  - Line 551: `CASH` badge in trip list (`fontSize: 9`).
  - Line 671: `LAOAG CITY MINC FRANCHISE ACTIVE & VERIFIED` banner (`fontSize: 11`).
  
  **Mathematical Contrast Analysis:**
  - Foreground (`#00B14F`): Relative luminance $L_1 \approx 0.32$
  - Background (`#E8F8EF`): Relative luminance $L_2 \approx 0.89$
  - Contrast Ratio: $(0.89 + 0.05) / (0.32 + 0.05) \approx \mathbf{2.57:1}$
  - **Threshold required by WCAG AA for normal text (< 18pt / < 14pt bold): 4.5:1.**
  - At 2.57:1, this text is unreadable for drivers in direct outdoor sunlight or with moderate low vision.
* **Concrete Code Fix:**
  Introduce an accessible high-contrast green token (e.g. `Color(0xFF047857)` or `Color(0xFF065F46)` with contrast ratio $\mathbf{6.2:1}$ on `#E8F8EF`):
  ```dart
  // Replace AppTheme.accentEmerald with Color(0xFF065F46) or AppTheme.accentEmeraldDark for text on light backgrounds
  static const Color accentEmeraldDark = Color(0xFF065F46); // WCAG AA 6.2:1 contrast against #E8F8EF

  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.accentEmeraldLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '🔊 "Adda sakay dita Laoag Central Market!"',
      style: TextStyle(
        color: Color(0xFF065F46), // Complies with WCAG AA (6.2:1)
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  )
  ```

---

#### [CRIT-03] 15-Second Ride Dispatch Auto-Pass Countdown Has No Live Region for Screen Readers
* **Category:** Semantics and Screen Readers / Dynamic Content
* **WCAG Criteria:** WCAG 4.1.3 Status Messages (AA), WCAG 2.2.1 Timing Adjustable (A)
* **Location:** [driver_map_duty_screen.dart#L97-L117](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L97-L117), [L139-L150](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L139-L150)
* **Defect Explanation:**
  When a ride request arrives, an `AlertDialog` pops up with a 15-second countdown timer. While `SoundAlertService.playDispatchOfferChime()` chimes once, the ticking visual timer (`${remainingSeconds}s`) updates silently inside `StatefulBuilder`. Screen reader users are not notified of the remaining seconds or that the offer will auto-pass at 0 seconds.
* **Concrete Code Fix:**
  Add a live region on the countdown container:
  ```dart
  Semantics(
    container: true,
    liveRegion: true,
    label: '$remainingSeconds seconds remaining to accept dispatch',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        '${remainingSeconds}s',
        style: const TextStyle(
          color: Color(0xFF9A3412), // Improved contrast: 5.6:1
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    ),
  )
  ```

---

### High Severity

#### [HIGH-01] Floating Header Action Buttons Violate Android 48x48 dp Tap Target Minimum
* **Category:** Tap Targets & Hit Bounds
* **WCAG Criteria:** WCAG 2.5.5 Target Size (AAA), WCAG 2.5.8 Target Size (Minimum, AA)
* **Location:** [driver_map_duty_screen.dart#L1014-L1048](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1014-L1048), [L1414-L1454](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1414-L1454), [L1491-L1509](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1491-L1509)
* **Defect Explanation:**
  The `_buildCircleAction` helper creates circular buttons for:
  1. Home button (`Icons.home_rounded`)
  2. Map type toggle (`Icons.map_rounded` / `Icons.satellite_alt_rounded`)
  3. Fail-safe toggle (`Icons.wifi_off_rounded` / `Icons.wifi_tethering_rounded`)
  4. Hotspots toggle (`Icons.local_fire_department_rounded`)
  5. Recenter location button (`Icons.my_location_rounded`)
  
  Implementation:
  ```dart
  Padding(
    padding: const EdgeInsets.all(11.0),
    child: Icon(icon, size: 22, color: color ?? AppTheme.primarySlate),
  )
  ```
  Total size is `22 + (11 * 2) = 44x44 dp`.
  While 44x44 meets Apple HIG / iOS guidelines, Android's Material Design and Flutter's `androidTapTargetGuideline` strictly enforce a **48x48 dp** touch target. On a vibrating motorcycle dashboard mount, 44x44 dp causes high mis-tap rates.
  Furthermore, `_buildCircleAction` lacks `semanticLabel`, `tooltip`, and focus styling.
* **Concrete Code Fix:**
  ```dart
  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Icon(icon, size: 24, color: color ?? AppTheme.primarySlate),
              ),
            ),
          ),
        ),
      ),
    );
  }
  ```

---

#### [HIGH-02] Primary Interactive Controls Implemented via `GestureDetector` Without Keyboard/Switch Focus
* **Category:** Focus and Keyboard Navigation / Screen Readers
* **WCAG Criteria:** WCAG 2.1.1 Keyboard (A), WCAG 2.4.3 Focus Order (A), WCAG 4.1.2 Name, Role, Value (A)
* **Location:** [driver_map_duty_screen.dart#L1052-L1090](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1052-L1090), [L1121-L1221](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1121-L1221), [L1229-L1273](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1229-L1273), [L1278-L1324](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1278-L1324)
* **Defect Explanation:**
  The following key interactive controls are implemented as `GestureDetector` widgets with no `FocusNode`, no `Semantics(button: true)`, and no keyboard activation handling:
  1. **Duty Status Pill (Online/Offline):** Toggling duty is the driver's primary function. Screen readers cannot tell it is a toggle button or what state it is in.
  2. **Digital Pila Rank Card:** Opens the queue screen; unannounced as a navigation button.
  3. **Earnings Quick Card:** Opens the shift earnings bottom sheet; fragmented text readouts.
  4. **TODA Unit Card:** Opens the franchise profile bottom sheet; fragmented text readouts.
  
  Users navigating with external directional switches, accessibility remotes, or physical keyboards cannot tab to or activate any of these controls.
* **Concrete Code Fix (for Duty Status Pill):**
  ```dart
  Semantics(
    button: true,
    toggled: _isOnline,
    label: _isOnline ? 'Duty Status: Online' : 'Duty Status: Offline',
    hint: _isOnline ? 'Double tap to go offline' : 'Double tap to go online',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _toggleDutyStatus,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isOnline ? AppTheme.accentEmerald : AppTheme.primarySlate,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOnline ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isOnline ? 'ONLINE • DUTY ACTIVE' : 'OFFLINE • TAP TO GO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  )
  ```

---

#### [HIGH-03] Low Contrast Text (`grey.shade500` = 2.32:1) in Trip History
* **Category:** Visual and Color Contrast
* **WCAG Criteria:** WCAG 1.4.3 Contrast (Minimum) (AA)
* **Location:** [driver_map_duty_screen.dart#L528](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L528)
* **Defect Explanation:**
  In the Shift Earnings bottom sheet:
  ```dart
  Text(
    '${t.passengerName} • ${_formatTimeAgo(t.timestamp)}',
    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
  )
  ```
  `Colors.grey.shade500` (`#9E9E9E`) on `#FFFFFF` background has a contrast ratio of **2.32:1**, well below the 4.5:1 minimum.
* **Concrete Code Fix:**
  Change `Colors.grey.shade500` to `Color(0xFF4B5563)` (`grey.shade700` / slate-600), which yields **5.91:1** contrast.

---

### Medium Severity

#### [MED-01] Hardcoded `SizedBox(height: 50)` on Modal Bottom Sheet Dismiss Buttons
* **Category:** Text Scaling / Dynamic Type
* **WCAG Criteria:** WCAG 1.4.4 Resize Text (AA)
* **Location:** [driver_map_duty_screen.dart#L568-L579](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L568-L579), [L709-L720](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L709-L720)
* **Defect Explanation:**
  The Dismiss buttons in both the Shift Earnings and Franchise Profile sheets wrap `ElevatedButton` in `SizedBox(height: 50)`. When system font scaling is set to 1.5x or 2.0x, this rigid box prevents the button height from growing, causing the text (`DISMISS`, `CLOSE PROFILE`) to overflow vertically or be clipped.
* **Concrete Code Fix:**
  Remove `SizedBox(height: 50)` and set `minimumSize` on `ElevatedButton.styleFrom`:
  ```dart
  ElevatedButton(
    onPressed: () => Navigator.pop(ctx),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.accentEmerald,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w800)),
  )
  ```

---

#### [MED-02] Invisible Edge Swipe Detectors Lack Semantic Role and Alternative Navigation
* **Category:** Semantics & Screen Readers / Motor Interaction
* **WCAG Criteria:** WCAG 2.5.1 Pointer Gestures (A), WCAG 2.5.2 Pointer Cancellation (A)
* **Location:** [driver_map_duty_screen.dart#L1457-L1484](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1457-L1484)
* **Defect Explanation:**
  Two 26dp-wide invisible gesture detectors sit on the left and right screen borders to navigate back to PasadaNorte Home on horizontal drag (`onHorizontalDragEnd`).
  1. They can accidentally capture map pan gestures when the driver is panning near the edges.
  2. They are completely invisible and lack `Semantics`.
  3. Screen reader and switch users cannot use or discover this gesture (although the home icon button exists in the header, these translucent layers intercept pointer events).
* **Concrete Code Fix:**
  Wrap both detectors in `ExcludeSemantics(excluding: true)` so they do not confuse accessibility trees, or better, rely on standard navigation gestures and the top-left Home button.

---

#### [MED-03] Dispatch Offer Dialog "ACCEPT RIDE" Button Height Under Android 48dp Minimum
* **Category:** Tap Targets
* **WCAG Criteria:** WCAG 2.5.8 Target Size (Minimum, AA)
* **Location:** [driver_map_duty_screen.dart#L274](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L274)
* **Defect Explanation:**
  The `ACCEPT RIDE` button specifies `minimumSize: const Size(130, 46)`.
  The height of 46 dp is 2 dp below Android's required 48 dp hit test boundary.
* **Concrete Code Fix:**
  Change `minimumSize: const Size(130, 46)` to `minimumSize: const Size(130, 48)`.

---

#### [MED-04] Micro-Typography (9sp Font Size) on Quick Metrics & History Badges
* **Category:** Text Scaling / Legibility
* **WCAG Criteria:** WCAG 1.4.4 Resize Text (AA)
* **Location:** [driver_map_duty_screen.dart#L1262](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1262), [L1310](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L1310), [L554](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L554)
* **Defect Explanation:**
  Labels like `'EARNINGS'` and `'TODA UNIT'` use `fontSize: 9`. For paratransit drivers operating outdoors on mobile devices, fonts below 11sp are extremely difficult to read and degrade quickly under glare.
* **Concrete Code Fix:**
  Increase font size to at least 11sp with appropriate letter spacing:
  ```dart
  Text(
    'EARNINGS',
    style: TextStyle(
      color: Color(0xFF4B5563), // 5.9:1 contrast
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  )
  ```

---

### Low Severity

#### [LOW-01] Missing `MergeSemantics` on Profile Rows and Shift History Items
* **Category:** Semantics and Screen Readers
* **WCAG Criteria:** WCAG 1.3.1 Info and Relationships (A)
* **Location:** [driver_map_duty_screen.dart#L507-L563](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L507-L563), [L728-L750](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L728-L750)
* **Defect Explanation:**
  In `_buildProfileRow`, the label ("LTO Plate Number") and value ("IN-4829") are two separate text nodes. A screen reader user must swipe twice to hear the field name and its value.
* **Concrete Code Fix:**
  Wrap each row in `MergeSemantics()`:
  ```dart
  Widget _buildProfileRow(String label, String value) {
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
  ```

#### [LOW-02] Decorative Rickshaw Emoji in Profile Sheet Announces Inconsistently
* **Category:** Semantics and Screen Readers
* **WCAG Criteria:** WCAG 1.1.1 Non-text Content (A)
* **Location:** [driver_map_duty_screen.dart#L625](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/mobile_client/lib/features/driver/views/driver_map_duty_screen.dart#L625)
* **Defect Explanation:**
  The `'🛺'` emoji is decorative avatar art, but TalkBack will pronounce "auto rickshaw" or "rickshaw" awkwardly before announcing the driver's name.
* **Concrete Code Fix:**
  Wrap the emoji container in `ExcludeSemantics()`.

---

## 3. Automated Accessibility Test Suite Implementation

To satisfy Category 6 (`meetsGuideline`), the following widget test file should be added to `mobile_client/test/driver_map_duty_screen_a11y_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/driver/views/driver_map_duty_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableDutyScreen() {
    return const MaterialApp(
      home: DriverMapDutyScreen(fullName: 'Juan Dela Cruz'),
    );
  }

  group('DriverMapDutyScreen WCAG / Flutter Accessibility Tests', () {
    testWidgets('Validates Android tap target bounds (48x48 dp)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableDutyScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('Validates iOS tap target bounds (44x44 dp)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableDutyScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('Validates text contrast ratios (WCAG AA 4.5:1 / 3:1)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableDutyScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('Validates labeled tap targets (screen reader labels)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableDutyScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });
}
```

---

## 4. Remediation Action Plan

1. **Step 1 (Emergency SOS & Tap Targets):** Refactor `_buildCircleAction` and the SOS button to guarantee 48x48 dp minimum hit bounds and wrap them with descriptive `Semantics` and `Tooltip` widgets.
2. **Step 2 (Color Contrast):** Replace `#00B14F` text on `#E8F8EF` backgrounds with `#065F46` (6.2:1 contrast) across all status badges and banners. Replace `grey.shade500` with `Color(0xFF4B5563)`.
3. **Step 3 (Screen Reader Live Regions):** Add `liveRegion: true` on the 15-second dispatch countdown timer.
4. **Step 4 (Keyboard & Switch Navigation):** Convert the 4 `GestureDetector` cards (Duty status, Pila rank, Earnings, TODA Unit) into focusable `InkWell` or `FocusTraversalGroup` elements.
5. **Step 5 (Dynamic Text Scaling):** Replace fixed `SizedBox(height: 50)` on modal buttons with `minimumSize: const Size(double.infinity, 50)` and bump minimum font sizes from 9sp to 11sp.
