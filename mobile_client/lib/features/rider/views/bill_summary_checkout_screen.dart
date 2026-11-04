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

  const BillSummaryCheckoutScreen({
    super.key,
    required this.fullName,
    required this.pickupPoint,
    required this.dropoffPoint,
    required this.routePolyline,
    required this.durationMinutes,
    required this.fareBreakdown,
    this.deliveryNotes = '',
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRideTrackingScreen(
          passengerName: widget.fullName,
          pickupPoint: widget.pickupPoint,
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
                              color: isDelivery ? const Color(0xFFD97706) : AppTheme.accentEmerald,
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
              const Text(
                'Itemized Bill Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 10),
              Container(
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

              const SizedBox(height: 22),

              // 3. Payment Method Selection
              const Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 10),

              ..._paymentMethods.map((pm) {
                final name = pm['name'] as String;
                final selected = _selectedPaymentMethod == name;
                final color = pm['color'] as Color;

                return GestureDetector(
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(pm['icon'] as IconData, color: color, size: 22),
                        ),
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
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
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
}
