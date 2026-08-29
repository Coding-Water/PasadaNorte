import 'package:flutter/material.dart';
import '../../../core/services/location_service.dart';
import '../../fare/services/fare_calculator_service.dart';

class RiderMapBookingScreen extends StatefulWidget {
  final String fullName;

  const RiderMapBookingScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<RiderMapBookingScreen> createState() => _RiderMapBookingScreenState();
}

class _RiderMapBookingScreenState extends State<RiderMapBookingScreen> {
  LocationPoint _pickupPoint = LocationService.laoagLandmarks[0];
  LocationPoint _dropoffPoint = LocationService.laoagLandmarks[1];
  PassengerCategory _selectedCategory = PassengerCategory.regular;
  TripType _selectedTripType = TripType.standard;

  late FareBreakdown _fareBreakdown;

  @override
  void initState() {
    super.initState();
    _recalculateFare();
  }

  void _recalculateFare() {
    double distanceKm = LocationService.calculateDistanceInKm(
      _pickupPoint.latitude,
      _pickupPoint.longitude,
      _dropoffPoint.latitude,
      _dropoffPoint.longitude,
    );

    setState(() {
      _fareBreakdown = FareCalculatorService.calculateFare(
        distanceKm: distanceKm,
        category: _selectedCategory,
        tripType: _selectedTripType,
      );
    });
  }

  void _requestRide() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, color: Colors.blue, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Finding Nearby Tricycles...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Searching active TODA drivers in Laoag City...\nEstimated Arrival: 3 mins',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Search'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PasadaNorte Laoag'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            color: Colors.blue.shade100,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: Colors.blue.shade800),
                      const SizedBox(height: 8),
                      Text(
                        'Laoag City GPS Map View',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        'Pickup: ${_pickupPoint.name.split(' ')[0]} ➔ Dropoff: ${_dropoffPoint.name.split(' ')[0]}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '₱20.00 Base Rate Ordinance Active',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<LocationPoint>(
                      value: _pickupPoint,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Point',
                        prefixIcon: Icon(Icons.my_location, color: Colors.green),
                      ),
                      items: LocationService.laoagLandmarks.map((point) {
                        return DropdownMenuItem(
                          value: point,
                          child: Text(point.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _pickupPoint = val;
                          _recalculateFare();
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<LocationPoint>(
                      value: _dropoffPoint,
                      decoration: const InputDecoration(
                        labelText: 'Dropoff Destination',
                        prefixIcon: Icon(Icons.location_on, color: Colors.red),
                      ),
                      items: LocationService.laoagLandmarks.map((point) {
                        return DropdownMenuItem(
                          value: point,
                          child: Text(point.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _dropoffPoint = val;
                          _recalculateFare();
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text('Pass Category: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<PassengerCategory>(
                            segments: const [
                              ButtonSegment(value: PassengerCategory.regular, label: Text('Regular', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: PassengerCategory.student, label: Text('Student', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: PassengerCategory.senior, label: Text('Senior/PWD', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_selectedCategory},
                            onSelectionChanged: (set) {
                              setState(() {
                                _selectedCategory = set.first;
                                _recalculateFare();
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Est. Route Distance:', style: TextStyle(fontSize: 13)),
                              Text('${_fareBreakdown.distanceKm} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Base Fare (1st km):', style: TextStyle(fontSize: 13)),
                              Text('₱${_fareBreakdown.baseFare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          if (_fareBreakdown.discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('20% Mandatory Discount:', style: TextStyle(fontSize: 13, color: Colors.green)),
                                Text('-₱${_fareBreakdown.discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Fare:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              Text(
                                '₱${_fareBreakdown.finalFare.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _requestRide,
                      child: Text('Request Ride (₱${_fareBreakdown.finalFare.toStringAsFixed(2)})'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
