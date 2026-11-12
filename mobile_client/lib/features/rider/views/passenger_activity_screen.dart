import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/activity_trip_model.dart';
import 'ride_details_screen.dart';
import 'schedule_pasadeliver_sheet.dart';

class PassengerActivityScreen extends StatefulWidget {
  final String fullName;

  const PassengerActivityScreen({super.key, required this.fullName});

  @override
  State<PassengerActivityScreen> createState() => _PassengerActivityScreenState();
}

class _PassengerActivityScreenState extends State<PassengerActivityScreen> {
  ActivityStatus _selectedFilter = ActivityStatus.ongoing;

  void _onTripTapped(ActivityTrip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDetailsScreen(trip: trip),
      ),
    ).then((_) => setState(() {}));
  }

  void _openSchedulePasaDeliver() {
    SchedulePasaDeliverSheet.show(
      context,
      onScheduled: () {
        setState(() {
          _selectedFilter = ActivityStatus.pasaDeliver;
        });
      },
    );
  }

  List<ActivityTrip> _getCurrentTrips() {
    switch (_selectedFilter) {
      case ActivityStatus.ongoing:
        return ActivityRepository.getOngoing();
      case ActivityStatus.pasaDeliver:
        return ActivityRepository.getPasaDeliver();
      case ActivityStatus.completed:
        return ActivityRepository.getCompleted();
      case ActivityStatus.canceled:
        return ActivityRepository.getCanceled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = _getCurrentTrips();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Activity',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.primarySlate,
          ),
        ),
      ),
      floatingActionButton: _selectedFilter == ActivityStatus.pasaDeliver
          ? FloatingActionButton.extended(
              onPressed: _openSchedulePasaDeliver,
              backgroundColor: AppTheme.accentEmerald,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Schedule',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
      body: Column(
        children: [
          // Fixed-height, fully-bounded 4-tab filter bar (Ongoing, Scheduled, Completed, Canceled)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  _buildFilterPill(
                    label: 'Ongoing',
                    status: ActivityStatus.ongoing,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Scheduled',
                    status: ActivityStatus.pasaDeliver,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Completed',
                    status: ActivityStatus.completed,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Canceled',
                    status: ActivityStatus.canceled,
                  ),
                ],
              ),
            ),
          ),

          // Activity Trip List
          Expanded(
            child: trips.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildEmptyState(),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      return _buildActivityCard(trip);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == ActivityStatus.pasaDeliver
                  ? Icons.local_shipping_outlined
                  : Icons.receipt_long_outlined,
              size: 54,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_getFilterName(_selectedFilter).toLowerCase()} activity',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When you book a ride or PasaDeliver, it will appear here.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
            ),
            if (_selectedFilter == ActivityStatus.pasaDeliver) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openSchedulePasaDeliver,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule PasaDeliver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required ActivityStatus status,
  }) {
    final isSelected = _selectedFilter == status;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedFilter != status) {
            setState(() => _selectedFilter = status);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentEmerald : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.accentEmerald : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityTrip trip) {
    final isOngoing = trip.status == ActivityStatus.ongoing;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: () => _onTripTapped(trip),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Destination Title, Price & Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(trip.dateTime)} · ${_formatTime(trip.dateTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${trip.totalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.paymentMethod.contains('Cash') ? 'Cash' : 'E-Wallet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Route Box (Pickup -> Dropoff with dotted line)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle, size: 10, color: AppTheme.accentEmerald),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trip.pickupLocation,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primarySlate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2.0,
                        height: 12.0,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trip.dropoffLocation,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primarySlate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Track Route Action Button for Ongoing items (Image 1)
            if (isOngoing) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => _onTripTapped(trip),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentEmerald, width: 1.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    foregroundColor: AppTheme.accentEmerald,
                  ),
                  child: const Text(
                    'Track Route',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  String _getFilterName(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.ongoing:
        return 'Ongoing';
      case ActivityStatus.pasaDeliver:
        return 'Scheduled';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.canceled:
        return 'Canceled';
    }
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
