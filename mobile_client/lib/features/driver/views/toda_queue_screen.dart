import 'package:flutter/material.dart';
import '../../../core/services/toda_queue_service.dart';
import '../../../core/theme/app_theme.dart';

/// Full-Screen TODA Digital Pila Queue Board for Drivers
/// Displays the live FIFO terminal queue, driver's queue position,
/// terminal bay status, and Laoag City Ordinance No. 2023-005 compliance notice.
class TodaQueueScreen extends StatefulWidget {
  final String driverName;
  final String? initialTerminalId;

  const TodaQueueScreen({
    super.key,
    required this.driverName,
    this.initialTerminalId,
  });

  @override
  State<TodaQueueScreen> createState() => _TodaQueueScreenState();
}

class _TodaQueueScreenState extends State<TodaQueueScreen> {
  late TodaTerminal _selectedTerminal;

  @override
  void initState() {
    super.initState();
    final defaultId = widget.initialTerminalId ?? 'term_01';
    if (TodaQueueService.laoagTerminals.isEmpty) {
      _selectedTerminal = TodaQueueService.findNearestTerminal(18.1960, 120.5935).terminal;
    } else {
      _selectedTerminal = TodaQueueService.laoagTerminals.firstWhere(
        (t) => t.id == defaultId,
        orElse: () => TodaQueueService.laoagTerminals.first,
      );
    }
  }

  void _refreshQueue() {
    setState(() {});
      }

  @override
  Widget build(BuildContext context) {
    final queue = TodaQueueService.getTerminalQueue(
      _selectedTerminal.id,
      driverName: widget.driverName,
    );
    final currentRank = TodaQueueService.getCurrentDriverRank(
      _selectedTerminal.id,
      driverName: widget.driverName,
    );
    final isQueued = currentRank > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('TODA Digital Pila Queue Board'),
        actions: [
          IconButton(
            tooltip: 'Refresh Queue',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshQueue,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshQueue();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            children: [
              // 1. Terminal Selector Card
              _buildTerminalSelectorCard(),
              const SizedBox(height: 14),

              // 2. Driver Current Queue Status Banner
              _buildDriverStatusBanner(isQueued, currentRank, queue.length),
              const SizedBox(height: 16),

              // 3. Live Dispatch Queue Header & List
              _buildQueueListSection(queue),
              const SizedBox(height: 16),

              // 4. Terminal Bay Operations & Geofence Specs
              _buildTerminalMetricsCard(queue.length),
              const SizedBox(height: 16),

              // 5. Municipal Ordinance Notice Card
              _buildOrdinanceNoticeCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'SELECT TODA TERMINAL BAY'.toUpperCase(),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<TodaTerminal>(
            initialValue: _selectedTerminal,
            isExpanded: true,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: TodaQueueService.laoagTerminals.map((t) {
              return DropdownMenuItem(
                value: t,
                child: Text(
                  '${t.name} (${t.radiusMeters.toStringAsFixed(0)}m)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primarySlate,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedTerminal = val);
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODA Station: ${_selectedTerminal.todaCode}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400, width: 0.8),
                ),
                child: Text(
                  'Radius: ${_selectedTerminal.radiusMeters.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverStatusBanner(bool isQueued, int currentRank, int totalInQueue) {
    if (isQueued) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentEmerald, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.accentEmerald,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentRank == 1 ? 'DISPATCH PRIORITY #1' : 'PILA RANK #$currentRank',
                        style: TextStyle(
                          color: currentRank == 1 ? const Color(0xFFB45309) : AppTheme.accentEmeraldDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Position $currentRank of $totalInQueue',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentEmeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentRank == 1
                        ? 'You are first in line for the next commuter booking dispatch. Keep app open on Standby.'
                        : 'Queued in FIFO line. Estimated turn-around: ~${(currentRank - 1) * 3} - ${currentRank * 4} mins.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1E293B),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 14, color: AppTheme.accentEmerald),
                      const SizedBox(width: 4),
                      Text(
                        'In-bounds within ${_selectedTerminal.radiusMeters.toStringAsFixed(0)}m terminal geofence',
                        style: const TextStyle(fontSize: 11, color: AppTheme.accentEmeraldDark, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOT QUEUED • EN ROUTE / OUTSIDE BAY',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are not currently in the ${_selectedTerminal.name} queue. When arriving at the terminal, enter within ${_selectedTerminal.radiusMeters.toStringAsFixed(0)}m to automatically join the FIFO queue at the tail.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueListSection(List<PilaDriverUnit> queue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live FIFO Terminal Line',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${queue.length} tricycles currently stationed in bay',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${queue.length} IN LINE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No tricycles currently queued in this station.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            ...queue.map((unit) {
              final isMe = unit.isCurrentDriver;
              final isFirst = unit.rank == 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe
                        ? AppTheme.accentEmerald
                        : (isFirst ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0)),
                    width: isMe ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFirst
                            ? const Color(0xFFF59E0B)
                            : (isMe ? AppTheme.accentEmerald : const Color(0xFFF1F5F9)),
                      ),
                      child: Center(
                        child: Text(
                          '#${unit.rank}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: (isFirst || isMe) ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Driver Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isMe ? '${widget.driverName} (YOU)' : unit.driverName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                    color: isMe ? AppTheme.accentEmeraldDark : AppTheme.primarySlate,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentEmerald,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unit.status,
                            style: TextStyle(
                              fontSize: 11,
                              color: isFirst ? const Color(0xFFB45309) : Colors.grey.shade600,
                              fontWeight: isFirst ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body Number Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        unit.bodyNumber,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTerminalMetricsCard(int queuedCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terminal Bay Metrics',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.primarySlate),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Active Bays',
                  value: '$queuedCount / 12',
                  subtitle: '${((queuedCount / 12) * 100).toStringAsFixed(0)}% Occupancy',
                  icon: Icons.local_taxi_rounded,
                  color: AppTheme.accentEmerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Geofence Radius',
                  value: '${_selectedTerminal.radiusMeters.toStringAsFixed(0)}m',
                  subtitle: 'Virtual boundary',
                  icon: Icons.radar_rounded,
                  color: const Color(0xFF0A84FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Dwell Timeout',
                  value: '15s',
                  subtitle: 'Auto-pass timer',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.primarySlate,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdinanceNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laoag City Ordinance No. 2023-005 Compliance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terminal queuing operates on strict automated FIFO ordering. Enqueueing requires physical presence within the geofence bay. GPS spoofing or manual queue manipulation is strictly prohibited and audited in real-time by the Web Command Center.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
