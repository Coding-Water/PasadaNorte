import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../models/activity_trip_model.dart';
import 'share_receipt_sheet.dart';

class RideDetailsScreen extends StatefulWidget {
  final ActivityTrip trip;

  const RideDetailsScreen({super.key, required this.trip});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late ActivityTrip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
      }

  Future<void> _handleCancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Ride?'),
        content: const Text(
          'Are you sure you want to cancel this booking? '
          'Under Laoag City Ordinance, no cancellation fee will be charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ActivityRepository.cancelTrip(_trip.id);
      setState(() {
        _trip = _trip.copyWith(status: ActivityStatus.canceled);
      });
          }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _trip.status == ActivityStatus.completed;
    final isOngoing = _trip.status == ActivityStatus.ongoing;
    final isPasaDeliver = _trip.status == ActivityStatus.pasaDeliver;
    final isCanceled = _trip.status == ActivityStatus.canceled;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primarySlate),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ride Details',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ongoing / Scheduled Notification Card (Image 3)
            if (isOngoing || isPasaDeliver) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isPasaDeliver ? 'Your Scheduled PasaDeliver' : 'Your Active Ride',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(_trip.dateTime)} - ${_formatTime(_trip.dateTime)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isOngoing
                                  ? 'Driver is en route to pickup location'
                                  : "We'll notify you when a driver's found",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 2. Vehicle Header Card (Image 2 & 3)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _trip.isDelivery
                          ? Icons.local_shipping_rounded
                          : Icons.electric_rickshaw_rounded,
                      color: AppTheme.accentEmerald,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _trip.vehicleType,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: AppTheme.accentEmerald,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _trip.vehicleSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${_trip.totalPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      if (_trip.discount > 0)
                        Text(
                          '₱${_trip.tripFare.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Route Card (Image 2 & 3)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle, size: 12, color: AppTheme.accentEmerald),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trip.pickupLocation,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        height: 20,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trip.dropoffLocation,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Driver Profile Card (Image 2)
            if (!isCanceled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Text(
                        _trip.driverName.substring(0, 1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentEmeraldDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _trip.driverName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                              Text(
                                _trip.driverRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _trip.driverVehicle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        color: AppTheme.primarySlate,
                        tooltip: 'Message Driver',
                        onPressed: () {
                                                  },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 5. Status & Transaction Details Card (Image 2 & 3)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Status',
                    customValue: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFE8F8EF)
                            : isCanceled
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : isCanceled
                                ? 'Canceled'
                                : isPasaDeliver
                                    ? 'Scheduled'
                                    : 'Ongoing',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? AppTheme.accentEmerald
                              : isCanceled
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(label: 'Payment', valueText: _trip.paymentMethod),
                  const SizedBox(height: 12),
                  _buildDetailRow(label: 'Date', valueText: _formatDate(_trip.dateTime)),
                  const SizedBox(height: 12),
                  _buildDetailRow(label: 'Time', valueText: _formatTime(_trip.dateTime)),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    label: 'Transaction ID',
                    valueText: _trip.transactionId,
                    onCopy: () => _copyToClipboard('Transaction ID', _trip.transactionId),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    label: 'Booking ID',
                    valueText: _trip.bookingId,
                    onCopy: () => _copyToClipboard('Booking ID', _trip.bookingId),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 6. Fare Breakdown Card (Image 2 & 3)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildBreakdownRow('Trip Fare', '₱${_trip.tripFare.toStringAsFixed(2)}'),
                  const SizedBox(height: 10),
                  _buildBreakdownRow(
                    'Discounts (20% Student/Senior/PWD)',
                    '- ₱${_trip.discount.toStringAsFixed(2)}',
                    isDiscount: true,
                  ),
                  const SizedBox(height: 10),
                  _buildBreakdownRow('Driver Tip', '₱${_trip.driverTip.toStringAsFixed(2)}'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFF1F5F9), height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Paid',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      Text(
                        '₱${_trip.totalPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Bottom Actions:
            // A. Completed -> "Share Receipt" outline green button (Image 2)
            if (isCompleted)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => ShareReceiptSheet.show(context, _trip),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentEmerald, width: 1.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    foregroundColor: AppTheme.accentEmerald,
                  ),
                  child: const Text(
                    'Share Receipt',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // B. Ongoing / Scheduled -> "Share Receipt" + "Cancel Ride" outline buttons (Image 3)
            if (isOngoing || isPasaDeliver) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => ShareReceiptSheet.show(context, _trip),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentEmerald, width: 1.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    foregroundColor: AppTheme.accentEmerald,
                  ),
                  child: const Text(
                    'Share Receipt',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _handleCancelRide,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text(
                    'Cancel Ride',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],

            // C. Canceled -> "Canceled Ride" notice without share receipt button
            if (isCanceled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Canceled Ride • No fees charged',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    String? valueText,
    Widget? customValue,
    VoidCallback? onCopy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        if (customValue != null)
          customValue
        else
          Row(
            children: [
              Text(
                valueText ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primarySlate,
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onCopy,
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDiscount ? AppTheme.accentEmerald : AppTheme.primarySlate,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}
