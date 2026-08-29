import 'package:flutter/material.dart';
import 'toda_queue_screen.dart';

class DriverMapDutyScreen extends StatefulWidget {
  final String fullName;

  const DriverMapDutyScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<DriverMapDutyScreen> createState() => _DriverMapDutyScreenState();
}

class _DriverMapDutyScreenState extends State<DriverMapDutyScreen> {
  bool _isOnline = true;
  int _queuePosition = 1;

  void _toggleDutyStatus(bool value) {
    setState(() {
      _isOnline = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnline
              ? 'You are now ONLINE. Passive GPS Auto-Queueing active.'
              : 'You are now OFFLINE.',
        ),
        backgroundColor: _isOnline ? Colors.green : Colors.grey.shade800,
      ),
    );
  }

  void _simulateIncomingRideRequest() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.volume_up, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('INCOMING RIDE REQUEST', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔊 Voice Alert: "Adda sakay dita Laoag Market!"', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('• Pickup: Laoag Central Market', style: TextStyle(color: Colors.white)),
            Text('• Dropoff: MMSU Laoag Campus', style: TextStyle(color: Colors.white)),
            Text('• Distance: 2.1 km', style: TextStyle(color: Colors.white)),
            Text('• Fare: ₱26.00 (Cash)', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Auto-pass in 12 seconds...', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride Accepted! Navigating to Laoag Central Market...'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('ACCEPT RIDE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver: ${widget.fullName}'),
        backgroundColor: _isOnline ? Colors.blue.shade900 : Colors.grey.shade800,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: _isOnline ? Colors.green.shade800 : Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.check_circle : Icons.offline_bolt,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'DUTY ONLINE' : 'DUTY OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  onChanged: _toggleDutyStatus,
                  activeColor: Colors.amber,
                ),
              ],
            ),
          ),

          if (_isOnline)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TodaQueueScreen(driverName: widget.fullName),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.amber.shade800,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📍 LAOAG CENTRAL TERMINAL TODA (Tap to view Pila)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PILA RANK #$_queuePosition',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 72, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        const Text(
                          'PasadaNorte Laoag Driver Map',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '🔴 High Passenger Demand Detected at Laoag Central Market',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _simulateIncomingRideRequest,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Simulate Incoming Ride Request'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900),
                        ),
                      ],
                    ),
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
