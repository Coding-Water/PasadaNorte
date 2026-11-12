import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

    // Copy to clipboard for instant pasting on native intent
    await Clipboard.setData(ClipboardData(text: receiptText));

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    // If WhatsApp is tapped, attempt deep-link
    if (platformName == 'WhatsApp') {
      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(receiptText)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Receipt copied & shared to $platformName!'),
        backgroundColor: AppTheme.accentEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = 'IMG-${trip.transactionId}-${trip.bookingId}.jpg';

    final recentPeople = [
      {'name': 'Charlotte\nHanlin', 'color': const Color(0xFFE11D48), 'app': 'WhatsApp', 'badgeColor': const Color(0xFF22C55E)},
      {'name': 'Kristin\nWatson', 'color': const Color(0xFF6366F1), 'app': 'Facebook', 'badgeColor': const Color(0xFF1877F2)},
      {'name': 'Clinton\nMcClure', 'color': const Color(0xFF06B6D4), 'app': 'Instagram', 'badgeColor': const Color(0xFFE1306C)},
      {'name': 'Maryland\nWinkles', 'color': const Color(0xFFF59E0B), 'app': 'WhatsApp', 'badgeColor': const Color(0xFF22C55E)},
      {'name': 'Alex\nHern', 'color': const Color(0xFF10B981), 'app': 'Telegram', 'badgeColor': const Color(0xFF0088CC)},
    ];

    final socialApps = [
      {'name': 'WhatsApp', 'color': const Color(0xFF25D366), 'icon': Icons.chat_bubble_outline_rounded},
      {'name': 'Facebook', 'color': const Color(0xFF1877F2), 'icon': Icons.facebook_rounded},
      {'name': 'Instagram', 'color': const Color(0xFFE1306C), 'icon': Icons.camera_alt_outlined},
      {'name': 'Telegram', 'color': const Color(0xFF0088CC), 'icon': Icons.send_rounded},
      {'name': 'X (Twitter)', 'color': Colors.black87, 'icon': Icons.close_rounded},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

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

              // File Attachment Card (Image 4)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        color: AppTheme.accentEmerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent people section
              Text(
                'Recent people',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentPeople.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                  itemBuilder: (context, idx) {
                    final person = recentPeople[idx];
                    final personName = person['name'] as String;
                    return GestureDetector(
                      onTap: () => _shareToNativePlatform(context, personName.replaceAll('\n', ' ')),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: (person['color'] as Color).withValues(alpha: 0.18),
                                child: Text(
                                  personName.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: person['color'] as Color,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: person['badgeColor'] as Color,
                                  child: const Icon(
                                    Icons.check,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            person['name'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.primarySlate,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Social media section
              Text(
                'Social media',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: socialApps.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                  itemBuilder: (context, idx) {
                    final app = socialApps[idx];
                    return GestureDetector(
                      onTap: () => _shareToNativePlatform(context, app['name'] as String),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (app['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              app['icon'] as IconData,
                              color: app['color'] as Color,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            app['name'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
