import 'package:flutter/material.dart';
import '../../../core/services/toda_queue_service.dart';

class TodaQueueScreen extends StatefulWidget {
  final String driverName;

  const TodaQueueScreen({
    super.key,
    required this.driverName,
  });

  @override
  State<TodaQueueScreen> createState() => _TodaQueueScreenState();
}

class _TodaQueueScreenState extends State<TodaQueueScreen> {
  final TodaTerminal _activeTerminal = TodaQueueService.laoagTerminals[0];
  QueueStatus _currentStatus = QueueStatus.queued;
  int _queuePosition = 1;
  double _simulatedSpeed = 0.0;

  final List<Map<String, String>> _queueDrivers = [
    {'rank': '#1', 'body': 'Tricycle #042 (You)', 'driver': 'Juan Dela Cruz', 'status': 'Next in Line'},
    {'rank': '#2', 'body': 'Tricycle #018', 'driver': 'Pedro Santos', 'status': 'Waiting in Geofence'},
    {'rank': '#3', 'body': 'Tricycle #089', 'driver': 'Mark Ramos', 'status': 'Waiting in Geofence'},
    {'rank': '#4', 'body': 'Tricycle #112', 'driver': 'Rogelio Agcaoili', 'status': 'Waiting in Geofence'},
  ];

  void _simulateWalkInDeparture() {
    setState(() {
      _simulatedSpeed = 16.5; // > 12 km/h
      _currentStatus = QueueStatus.departingWithPassenger;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Zero-Touch Checkout: Speed > 12 km/h detected. Checked out of queue!'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _simulateTerminalReentry() {
    setState(() {
      _simulatedSpeed = 0.0;
      _currentStatus = QueueStatus.queued;
      _queuePosition = 4; // Moves to back of line
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Geofence Re-entry Detected. Added to back of queue (#4).'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Pila (TODA Queue)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Terminal Geofence Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _activeTerminal.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'GEOFENCE ACTIVE',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Queue Rank:', style: TextStyle(color: Colors.white70)),
                        Text(
                          'POSITION #$_queuePosition',
                          style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Zero-Touch GPS Status Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _currentStatus == QueueStatus.queued ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentStatus == QueueStatus.queued ? Colors.green : Colors.amber,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentStatus == QueueStatus.queued ? Icons.sensors : Icons.directions_run,
                      color: _currentStatus == QueueStatus.queued ? Colors.green : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentStatus == QueueStatus.queued
                                ? 'Zero-Touch Passive GPS Queueing'
                                : 'Walk-in Departure Detected (${_simulatedSpeed} km/h)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _currentStatus == QueueStatus.queued ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                          Text(
                            _currentStatus == QueueStatus.queued
                                ? 'Zero taps needed. Auto-checks out when you drive away.'
                                : 'Auto-checked out from queue position #1.',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Live Terminal Drivers List (${_queueDrivers.length} active)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Live Queue List
              Expanded(
                child: ListView.separated(
                  itemCount: _queueDrivers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _queueDrivers[index];
                    final isMe = index == 0 && _currentStatus == QueueStatus.queued;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isMe ? Colors.amber : Colors.blue.shade100,
                        child: Text(
                          item['rank']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.black : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      title: Text(
                        item['body']!,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          color: isMe ? Colors.blue.shade900 : Colors.black,
                        ),
                      ),
                      subtitle: Text(item['driver']!, style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isMe ? 'Next for Ride' : item['status']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.green.shade900 : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Simulation Buttons for Testing Zero-Touch Automation
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentStatus == QueueStatus.queued ? _simulateWalkInDeparture : _simulateTerminalReentry,
                      child: Text(_currentStatus == QueueStatus.queued ? 'Simulate Walk-in Drive' : 'Simulate Re-entry'),
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
}
