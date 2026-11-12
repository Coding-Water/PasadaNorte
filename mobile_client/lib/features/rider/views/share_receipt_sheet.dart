import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../models/activity_trip_model.dart';

class ShareReceiptSheet extends StatelessWidget {
  final ActivityTrip trip;

  const ShareReceiptSheet({super.key, required this.trip});

  static Future<void> show(BuildContext context, ActivityTrip trip) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareReceiptSheet(trip: trip),
    );
  }

  Future<void> _shareToNativePlatform(BuildContext context, String platformName) async {
    final receiptText = 'PasadaNorte Official Ride Receipt\n'
        'Booking ID: ${trip.bookingId}\n'
        'Transaction ID: ${trip.transactionId}\n'
        'Route: ${trip.pickupLocation} -> ${trip.dropoffLocation}\n'
        'Total Paid: ₱${trip.totalPaid.toStringAsFixed(2)}\n'
        'Date: ${trip.dateTime.month}/${trip.dateTime.day}/${trip.dateTime.year}\n'
        'Driver: ${trip.driverName} (${trip.driverVehicle})';

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    try {
      await Clipboard.setData(ClipboardData(text: receiptText));
    } catch (_) {}

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: receiptText,
          subject: 'PasadaNorte Official Receipt - ${trip.bookingId}',
          title: 'Share PasadaNorte Receipt',
        ),
      );
    } catch (_) {}

    messenger.showSnackBar(
      SnackBar(
        content: Text('Receipt shared to $platformName!'),
        backgroundColor: AppTheme.accentEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = 'IMG-${trip.transactionId}-${trip.bookingId}.jpg';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Center(
                child: Text(
                  'Share Receipt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // File Attachment Card (Exact layout as image 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        color: AppTheme.accentEmerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primarySlate,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent people section title
              Text(
                'Recent people',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),

              // 5 Recent people columns (evenly spaced across width)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRecentPerson(
                      context: context,
                      firstName: 'Charlotte',
                      lastName: 'Hanlin',
                      letter: 'C',
                      bgCircleColor: const Color(0xFFFFDDE2),
                      letterColor: const Color(0xFFE11D48),
                      badgeColor: const Color(0xFF22C55E),
                    ),
                  ),
                  Expanded(
                    child: _buildRecentPerson(
                      context: context,
                      firstName: 'Kristin',
                      lastName: 'Watson',
                      letter: 'K',
                      bgCircleColor: const Color(0xFFE0E7FF),
                      letterColor: const Color(0xFF4F46E5),
                      badgeColor: const Color(0xFF2563EB),
                    ),
                  ),
                  Expanded(
                    child: _buildRecentPerson(
                      context: context,
                      firstName: 'Clinton',
                      lastName: 'McClure',
                      letter: 'C',
                      bgCircleColor: const Color(0xFFCFFAFE),
                      letterColor: const Color(0xFF0891B2),
                      badgeColor: const Color(0xFFE11D48),
                    ),
                  ),
                  Expanded(
                    child: _buildRecentPerson(
                      context: context,
                      firstName: 'Maryland',
                      lastName: 'Winkles',
                      letter: 'M',
                      bgCircleColor: const Color(0xFFFEF3C7),
                      letterColor: const Color(0xFFD97706),
                      badgeColor: const Color(0xFF22C55E),
                    ),
                  ),
                  Expanded(
                    child: _buildRecentPerson(
                      context: context,
                      firstName: 'Alex',
                      lastName: 'Hern',
                      letter: 'A',
                      bgCircleColor: const Color(0xFFD1FAE5),
                      letterColor: const Color(0xFF059669),
                      badgeColor: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
              const SizedBox(height: 16),

              // Social media section title
              Text(
                'Social media',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),

              // 5 Social media app columns (evenly spaced across width)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSocialApp(
                      context: context,
                      name: 'WhatsApp',
                      bgColor: const Color(0xFFE8F8EF),
                      iconColor: const Color(0xFF22C55E),
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSocialApp(
                      context: context,
                      name: 'Facebook',
                      bgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF1877F2),
                      icon: Icons.facebook_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSocialApp(
                      context: context,
                      name: 'Instagram',
                      bgColor: const Color(0xFFFDF2F8),
                      iconColor: const Color(0xFFE1306C),
                      icon: Icons.camera_alt_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildSocialApp(
                      context: context,
                      name: 'Telegram',
                      bgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      icon: Icons.send_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSocialApp(
                      context: context,
                      name: 'X (Twitter)',
                      bgColor: const Color(0xFFF1F5F9),
                      iconColor: const Color(0xFF0F172A),
                      icon: Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPerson({
    required BuildContext context,
    required String firstName,
    required String lastName,
    required String letter,
    required Color bgCircleColor,
    required Color letterColor,
    required Color badgeColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _shareToNativePlatform(context, '$firstName $lastName'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: bgCircleColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: letterColor,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      size: 9.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$firstName\n$lastName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.primarySlate,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialApp({
    required BuildContext context,
    required String name,
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _shareToNativePlatform(context, name),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primarySlate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
