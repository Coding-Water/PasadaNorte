import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'live_ride_tracking_screen.dart';

class BillSummaryCheckoutScreen extends StatefulWidget {
  final String fullName;
  final LocationPoint pickupPoint;
  final LocationPoint dropoffPoint;
  final List<LatLng> routePolyline;
  final int durationMinutes;
  final FareBreakdown fareBreakdown;
  final String deliveryNotes;
  final String pickupLandmarkNote;

  const BillSummaryCheckoutScreen({
    super.key,
    required this.fullName,
    required this.pickupPoint,
    required this.dropoffPoint,
    required this.routePolyline,
    required this.durationMinutes,
    required this.fareBreakdown,
    this.deliveryNotes = '',
    this.pickupLandmarkNote = '',
  });

  @override
  State<BillSummaryCheckoutScreen> createState() =>
      _BillSummaryCheckoutScreenState();
}

class _BillSummaryCheckoutScreenState extends State<BillSummaryCheckoutScreen> {
  String _selectedPaymentMethod = 'Cash (Pay Driver Directly)';

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Cash (Pay Driver Directly)',
      'subtitle': 'Exact ordinance amount paid upon arrival',
      'icon': Icons.payments_rounded,
      'color': AppTheme.accentEmerald,
    },
    {
      'name': 'GCash e-Wallet',
      'subtitle': 'Instant QR / mobile number transfer to driver',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF007DFE),
    },
    {
      'name': 'Maya',
      'subtitle': 'Digital wallet checkout',
      'icon': Icons.credit_card_rounded,
      'color': const Color(0xFF16A34A),
    },
    {
      'name': 'QR Ph (InstaPay)',
      'subtitle': 'Scan TODA sidecar QR Ph code',
      'icon': Icons.qr_code_scanner_rounded,
      'color': AppTheme.primarySlate,
    },
  ];

  void _confirmAndDispatch() {
    final landmark = widget.pickupLandmarkNote.trim();
    final effectivePickup = landmark.isEmpty
        ? widget.pickupPoint
        : LocationPoint(
            latitude: widget.pickupPoint.latitude,
            longitude: widget.pickupPoint.longitude,
            name: '${widget.pickupPoint.name} • Landmark: $landmark',
            zoneCode: widget.pickupPoint.zoneCode,
          );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRideTrackingScreen(
          passengerName: widget.fullName,
          pickupPoint: effectivePickup,
          dropoffPoint: widget.dropoffPoint,
          routePolyline: widget.routePolyline,
          fareBreakdown: widget.fareBreakdown,
          paymentMethod: _selectedPaymentMethod,
          deliveryNotes: widget.deliveryNotes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.fareBreakdown;
    final isDelivery = fb.tripType == TripType.pabiliPadala;
    final cfg = FareCalculatorService.activeConfig;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDelivery ? 'Pa-Deliver Bill Summary' : 'Ride Bill Summary'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Route & Service Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDelivery
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isDelivery ? 'PA-DELIVER (PADALA / PABILI)' : 'STANDARD RIDE BOOKING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDelivery ? const Color(0xFFD97706) : AppTheme.accentEmeraldDark,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${fb.distanceKm} km (~${widget.durationMinutes} mins)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked, color: AppTheme.accentEmerald, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.pickupPoint.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.dropoffPoint.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    if (widget.pickupLandmarkNote.trim().isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded, color: AppTheme.accentEmerald, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pickup Landmark: ${widget.pickupLandmarkNote.trim()}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.deliveryNotes.trim().isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Item / Instructions: ${widget.deliveryNotes.trim()}',
                              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Itemized Bill Breakdown Card (Locked Fare Tier)
              Semantics(
                header: true,
                child: const Text(
                  'Itemized Bill Summary',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              MergeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildBillRow(
                        'Verified Account Fare Tier',
                        '${fb.category.name.toUpperCase()} (Locked at Registration)',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildBillRow(
                        'Base First ${fb.baseDistanceKm.toStringAsFixed(1)} km Rate',
                        '₱${fb.baseFare.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _buildBillRow(
                        fb.usedBracketAddOns
                            ? 'Succeeding Distance Bracket Add-On (₱3/₱5 SP Oct 2026)'
                            : 'Succeeding Distance (${fb.distanceKm > fb.baseDistanceKm ? (fb.distanceKm - fb.baseDistanceKm).toStringAsFixed(2) : "0.00"} km × ₱${cfg.succeedingKmRate.toStringAsFixed(2)})',
                        '₱${fb.distanceFare.toStringAsFixed(2)}',
                      ),
                      if (fb.discountAmount > 0) ...[
                        const SizedBox(height: 8),
                        _buildBillRow(
                          'Verified Municipal Discount (Flat ₱5.00 Base + Succeeding)',
                          '-₱${fb.discountAmount.toStringAsFixed(2)}',
                          valueColor: AppTheme.accentEmerald,
                          isBold: true,
                        ),
                        const SizedBox(height: 4),
                        _buildBillRow(
                          'LTFRB MC 2025-10 50%-50% Schema Accounting',
                          'TNC ₱${fb.platformDiscountShare.toStringAsFixed(2)} / Operator ₱${fb.operatorDiscountShare.toStringAsFixed(2)}',
                        ),
                      ],
                      if (isDelivery) ...[
                        const SizedBox(height: 8),
                        _buildBillRow(
                          'Pa-Deliver Handling Multiplier',
                          '1.25x (Errand / Parcel Service)',
                          valueColor: const Color(0xFFD97706),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(thickness: 1.2),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount Due',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          Text(
                            '₱${fb.finalFare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // 3. Payment Method Selection
              Semantics(
                header: true,
                child: const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              ..._paymentMethods.map((pm) {
                final name = pm['name'] as String;
                final selected = _selectedPaymentMethod == name;
                final color = pm['color'] as Color;

                return Semantics(
                  button: true,
                  selected: selected,
                  label: '$name. ${pm['subtitle']}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedPaymentMethod = name),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppTheme.accentEmerald : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildPaymentBrandIcon(name, color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.primarySlate,
                                  ),
                                ),
                                Text(
                                  pm['subtitle'] as String,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? AppTheme.accentEmerald : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: _confirmAndDispatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDelivery ? const Color(0xFFD97706) : AppTheme.accentEmerald,
                ),
                icon: Icon(isDelivery ? Icons.local_shipping_rounded : Icons.electric_rickshaw_rounded),
                label: Text(
                  isDelivery
                      ? 'Confirm Pa-Deliver • ₱${fb.finalFare.toStringAsFixed(2)}'
                      : 'Confirm & Dispatch Ride • ₱${fb.finalFare.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppTheme.primarySlate,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBrandIcon(String methodName, Color fallbackColor) {
    if (methodName.startsWith('GCash')) {
      // Official GCash Blue (#007DFE) with stylized white "G" + signal arcs
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF007DFE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          painter: _GCashLogoPainter(),
        ),
      );
    }

    if (methodName.startsWith('Maya')) {
      // Official Maya Dark Slate + vibrant Emerald "maya" brand mark
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'maya',
            style: TextStyle(
              color: Color(0xFF00E070),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      );
    }

    if (methodName.startsWith('QR Ph')) {
      // Official QR Ph tri-color (PH Blue, Red, Sun Yellow) QR matrix badge
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: CustomPaint(
          painter: _QrPhLogoPainter(),
        ),
      );
    }

    // Cash (Philippine Peso ₱ banknote badge)
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '₱',
          style: TextStyle(
            color: fallbackColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GCashLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.44;
    final cy = size.height * 0.52;

    // White "G" ring
    final gPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.24);
    canvas.drawArc(rect, -0.45, 5.2, false, gPaint);

    // Horizontal bar of "G"
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + size.width * 0.24, cy),
      gPaint,
    );

    // Signal arcs to the top-right of the G
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 4, cy - 4), radius: size.width * 0.28),
      -1.1,
      0.85,
      false,
      wavePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 4, cy - 4), radius: size.width * 0.38),
      -1.1,
      0.85,
      false,
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QrPhLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = size.width * 0.18;
    final box = size.width * 0.24;

    void drawFinder(double x, double y, Color color) {
      final outer = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, box, box), const Radius.circular(2)),
        outer,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + box * 0.3, y + box * 0.3, box * 0.4, box * 0.4),
        Paint()..color = color,
      );
    }

    // PH Flag colors for the 3 QR Ph finder squares + sun yellow center
    drawFinder(p, p, const Color(0xFF0038A8)); // Royal Blue
    drawFinder(size.width - p - box, p, const Color(0xFFCE1126)); // Red
    drawFinder(p, size.height - p - box, const Color(0xFF0038A8)); // Royal Blue

    // Sun yellow accent + dark QR dots in bottom-right
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      2.6,
      Paint()..color = const Color(0xFFFCD116),
    );
    final dark = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(
      Rect.fromLTWH(size.width - p - box, size.height - p - box, 4, 4),
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - p - 4, size.height - p - 4, 4, 4),
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - p - box, size.height - p - 4, 4, 4),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
