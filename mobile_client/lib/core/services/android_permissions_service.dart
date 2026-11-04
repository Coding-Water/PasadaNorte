import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class AndroidPermissionsState {
  final bool locationGranted;
  final bool isPreciseLocation;
  final bool notificationsGranted;
  final bool cameraGranted;
  final bool galleryGranted;

  const AndroidPermissionsState({
    required this.locationGranted,
    required this.isPreciseLocation,
    required this.notificationsGranted,
    required this.cameraGranted,
    required this.galleryGranted,
  });

  bool get allGranted =>
      locationGranted && notificationsGranted && cameraGranted && galleryGranted;
}

class AndroidPermissionsService {
  static const String _kLocGranted = 'pn_perm_location_granted';
  static const String _kLocPrecise = 'pn_perm_location_precise';
  static const String _kNotifGranted = 'pn_perm_notif_granted';
  static const String _kCameraGranted = 'pn_perm_camera_granted';
  static const String _kGalleryGranted = 'pn_perm_gallery_granted';
  static const String _kFlowPrompted = 'pn_perm_v4_sequence_prompted';

  static Future<AndroidPermissionsState> getSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    return AndroidPermissionsState(
      locationGranted: prefs.getBool(_kLocGranted) ?? false,
      isPreciseLocation: prefs.getBool(_kLocPrecise) ?? true,
      notificationsGranted: prefs.getBool(_kNotifGranted) ?? false,
      cameraGranted: prefs.getBool(_kCameraGranted) ?? false,
      galleryGranted: prefs.getBool(_kGalleryGranted) ?? false,
    );
  }

  /// Runs the 4 separate native-style Android permission prompts sequentially:
  /// 1. Location (Precise vs. Approximate circular map selector)
  /// 2. Notifications (Ride acceptance & arrival alerts)
  /// 3. Camera (1:1 live face verification & ID/tricycle capture)
  /// 4. Photos & Media / Gallery (ID card & driver 4-angle tricycle documentation upload)
  static Future<AndroidPermissionsState> ensureAllPermissionsSequential(
    BuildContext context, {
    bool forceShowAll = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_kFlowPrompted) ?? false;
    final current = await getSavedState();

    if (!forceShowAll && alreadyPrompted && current.allGranted) {
      LocationService.warmUpDeviceGpsLocation();
      return current;
    }

    if (!context.mounted) return current;

    // 1. Separate Location Permission Dialog (Precise vs. Approximate circular maps)
    bool locGranted = current.locationGranted;
    bool isPrecise = current.isPreciseLocation;
    if (forceShowAll || !locGranted) {
      final locRes = await showLocationPermissionDialog(context);
      locGranted = locRes['granted'] as bool;
      isPrecise = locRes['precise'] as bool;
      await prefs.setBool(_kLocGranted, locGranted);
      await prefs.setBool(_kLocPrecise, isPrecise);
      if (locGranted) {
        try {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            await Geolocator.requestPermission();
          }
        } catch (_) {}
        LocationService.warmUpDeviceGpsLocation();
      }
    }

    if (!context.mounted) return getSavedState();

    // 2. Separate Notification Permission Dialog
    bool notifGranted = current.notificationsGranted;
    if (forceShowAll || !notifGranted) {
      notifGranted = await showNotificationPermissionDialog(context);
      await prefs.setBool(_kNotifGranted, notifGranted);
    }

    if (!context.mounted) return getSavedState();

    // 3. Separate Camera Permission Dialog (for 1:1 Face Verification & Photo Capture)
    bool camGranted = current.cameraGranted;
    if (forceShowAll || !camGranted) {
      camGranted = await showCameraPermissionDialog(context);
      await prefs.setBool(_kCameraGranted, camGranted);
    }

    if (!context.mounted) return getSavedState();

    // 4. Separate Gallery / Photos & Media Permission Dialog (for ID & 4-Angle Tricycle Upload)
    bool galGranted = current.galleryGranted;
    if (forceShowAll || !galGranted) {
      galGranted = await showGalleryPermissionDialog(context);
      await prefs.setBool(_kGalleryGranted, galGranted);
    }

    await prefs.setBool(_kFlowPrompted, true);
    return AndroidPermissionsState(
      locationGranted: locGranted,
      isPreciseLocation: isPrecise,
      notificationsGranted: notifGranted,
      cameraGranted: camGranted,
      galleryGranted: galGranted,
    );
  }

  /// Ensures Camera permission is granted before capturing ID, 4-angle tricycle, or 1:1 live face scan
  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getBool(_kCameraGranted) ?? false;
    if (granted) return true;
    if (!context.mounted) return false;
    final res = await showCameraPermissionDialog(context);
    await prefs.setBool(_kCameraGranted, res);
    return res;
  }

  /// Ensures Gallery / Photos permission is granted before picking ID or 4-angle tricycle photos
  static Future<bool> ensureGalleryPermission(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getBool(_kGalleryGranted) ?? false;
    if (granted) return true;
    if (!context.mounted) return false;
    final res = await showGalleryPermissionDialog(context);
    await prefs.setBool(_kGalleryGranted, res);
    return res;
  }

  // ===========================================================================
  // 1. LOCATION PERMISSION DIALOG (Matches Uploaded Android Screenshot)
  // ===========================================================================
  static Future<Map<String, dynamic>> showLocationPermissionDialog(
    BuildContext context,
  ) async {
    bool isPreciseSelected = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFFEEF1F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF335599),
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF1E1F24),
                          height: 1.32,
                        ),
                        children: [
                          TextSpan(text: 'Allow '),
                          TextSpan(
                            text: 'PasadaNorte',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' to access this device’s location?'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Precise vs. Approximate Circular Map Selector (Matches Screenshot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Precise Option
                        GestureDetector(
                          onTap: () => setDialogState(() => isPreciseSelected = true),
                          child: Column(
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isPreciseSelected
                                        ? const Color(0xFF1A4B9C)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child: CustomPaint(
                                    painter: _PreciseMapCirclePainter(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Precise',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isPreciseSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: const Color(0xFF1E1F24),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Approximate Option
                        GestureDetector(
                          onTap: () => setDialogState(() => isPreciseSelected = false),
                          child: Column(
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: !isPreciseSelected
                                        ? const Color(0xFF1A4B9C)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child: CustomPaint(
                                    painter: _ApproximateMapCirclePainter(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Approximate',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: !isPreciseSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: const Color(0xFF1E1F24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Stacked Android Action Buttons
                    _buildAndroidStackedButton(
                      label: 'While using the app',
                      isTop: true,
                      onTap: () => Navigator.pop(ctx, {
                        'granted': true,
                        'precise': isPreciseSelected,
                      }),
                    ),
                    const SizedBox(height: 4),
                    _buildAndroidStackedButton(
                      label: 'Only this time',
                      onTap: () => Navigator.pop(ctx, {
                        'granted': true,
                        'precise': isPreciseSelected,
                      }),
                    ),
                    const SizedBox(height: 4),
                    _buildAndroidStackedButton(
                      label: 'Don’t allow',
                      isBottom: true,
                      onTap: () => Navigator.pop(ctx, {
                        'granted': false,
                        'precise': isPreciseSelected,
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result ?? {'granted': true, 'precise': true};
  }

  // ===========================================================================
  // 2. NOTIFICATION PERMISSION DIALOG (Separate Android Prompt)
  // ===========================================================================
  static Future<bool> showNotificationPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFEEF1F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF335599),
                size: 32,
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1E1F24),
                    height: 1.32,
                  ),
                  children: [
                    TextSpan(text: 'Allow '),
                    TextSpan(
                      text: 'PasadaNorte',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' to send you notifications?'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Used for real-time tricycle dispatch acceptance alerts, live arrival updates, and TODA queue status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 22),
              _buildAndroidStackedButton(
                label: 'Allow',
                isTop: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              _buildAndroidStackedButton(
                label: 'Don’t allow',
                isBottom: true,
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? true;
  }

  // ===========================================================================
  // 3. CAMERA PERMISSION DIALOG (Separate Android Prompt for 1:1 Face & Tricycle Capture)
  // ===========================================================================
  static Future<bool> showCameraPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFEEF1F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: Color(0xFF335599),
                size: 32,
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1E1F24),
                    height: 1.32,
                  ),
                  children: [
                    TextSpan(text: 'Allow '),
                    TextSpan(
                      text: 'PasadaNorte',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' to take pictures and record video?'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Required for 1:1 live face verification and photographing your ID card or 4-angle tricycle vehicle documentation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 22),
              _buildAndroidStackedButton(
                label: 'While using the app',
                isTop: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              _buildAndroidStackedButton(
                label: 'Only this time',
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              _buildAndroidStackedButton(
                label: 'Don’t allow',
                isBottom: true,
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? true;
  }

  // ===========================================================================
  // 4. GALLERY / PHOTOS & MEDIA PERMISSION DIALOG (Separate Android Prompt)
  // ===========================================================================
  static Future<bool> showGalleryPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFEEF1F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF335599),
                size: 32,
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1E1F24),
                    height: 1.32,
                  ),
                  children: [
                    TextSpan(text: 'Allow '),
                    TextSpan(
                      text: 'PasadaNorte',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' to access photos and media on your device?'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Used to upload Student/Senior/PWD ID images and Driver 4-angle tricycle photos (Front, Back, Left, Right) from your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 22),
              _buildAndroidStackedButton(
                label: 'Allow all',
                isTop: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              _buildAndroidStackedButton(
                label: 'Select photos',
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              _buildAndroidStackedButton(
                label: 'Don’t allow',
                isBottom: true,
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? true;
  }

  static Widget _buildAndroidStackedButton({
    required String label,
    required VoidCallback onTap,
    bool isTop = false,
    bool isBottom = false,
  }) {
    final BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(isTop ? 16 : 6),
      topRight: Radius.circular(isTop ? 16 : 6),
      bottomLeft: Radius.circular(isBottom ? 16 : 6),
      bottomRight: Radius.circular(isBottom ? 16 : 6),
    );

    return Material(
      color: const Color(0xFFD6E2FF),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B2436),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter that draws the exact Android "Precise" Location Map Circle
/// (angled street grid, green park patch, orange/blue POI dots, and central blue pin)
class _PreciseMapCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Park patch
    final parkPaint = Paint()..color = const Color(0xFFD8EBD4);
    final parkPath = Path()
      ..moveTo(size.width * 0.62, size.height * 0.08)
      ..lineTo(size.width * 0.80, size.height * 0.16)
      ..lineTo(size.width * 0.72, size.height * 0.30)
      ..lineTo(size.width * 0.56, size.height * 0.20)
      ..close();
    canvas.drawPath(parkPath, parkPaint);

    // Diagonal street grid
    final gridPaint = Paint()
      ..color = const Color(0xFFBDC3CE)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (double i = -0.4; i <= 1.4; i += 0.22) {
      canvas.drawLine(
        Offset(size.width * i, 0),
        Offset(size.width * (i - 0.5), size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, size.height * i),
        Offset(size.width, size.height * (i + 0.45)),
        gridPaint,
      );
    }

    // Small POI dots
    canvas.drawCircle(
      Offset(size.width * 0.31, size.height * 0.38),
      2.6,
      Paint()..color = const Color(0xFFEA8600),
    );
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.66),
      2.6,
      Paint()..color = const Color(0xFF1A4B9C),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.35),
      2.6,
      Paint()..color = const Color(0xFF1A4B9C),
    );

    // Pin base ring
    final center = Offset(size.width * 0.5, size.height * 0.54);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 14), width: 14, height: 6),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 14), width: 14, height: 6),
      Paint()
        ..color = const Color(0xFF1A4B9C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Blue Location Pin
    final pinPaint = Paint()..color = const Color(0xFF1A4B9C);
    canvas.drawCircle(Offset(center.dx, center.dy - 4), 12, pinPaint);
    final triPath = Path()
      ..moveTo(center.dx - 10, center.dy)
      ..lineTo(center.dx, center.dy + 14)
      ..lineTo(center.dx + 10, center.dy)
      ..close();
    canvas.drawPath(triPath, pinPaint);

    // White inner dot of pin
    canvas.drawCircle(Offset(center.dx, center.dy - 4), 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Painter that draws the exact Android "Approximate" Location Map Circle
/// (wider regional roads, yellow highways, and blue highway shield badges)
class _ApproximateMapCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Secondary grey roads
    final roadPaint = Paint()
      ..color = const Color(0xFFC4C9D4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.72), roadPaint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.75, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.78), Offset(size.width * 0.9, size.height * 0.25), roadPaint);

    // Yellow regional highways
    final highwayPaint = Paint()
      ..color = const Color(0xFFF4A800)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final h1 = Path()
      ..moveTo(size.width * 0.28, 0)
      ..lineTo(size.width * 0.34, size.height * 0.42)
      ..lineTo(size.width * 0.18, size.height);
    canvas.drawPath(h1, highwayPaint);

    final h2 = Path()
      ..moveTo(0, size.height * 0.30)
      ..lineTo(size.width * 0.55, size.height * 0.22)
      ..lineTo(size.width * 0.85, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.45);
    canvas.drawPath(h2, highwayPaint);

    final h3 = Path()
      ..moveTo(size.width * 0.32, size.height * 0.42)
      ..lineTo(size.width * 0.52, size.height * 0.88)
      ..lineTo(size.width * 0.92, size.height * 0.72);
    canvas.drawPath(h3, highwayPaint);

    // Blue highway shields
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.68),
      5.5,
      Paint()..color = const Color(0xFF3B78E7),
    );
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.91),
      5.5,
      Paint()..color = const Color(0xFF3B78E7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
