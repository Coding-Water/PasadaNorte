import 'dart:async';
import 'location_service.dart';

enum QueueStatus { outsideTerminal, queued, departingWithPassenger, autoPassed }

class TodaTerminal {
  final String id;
  final String name;
  final LocationPoint centerPoint;
  final double radiusMeters;

  TodaTerminal({
    required this.id,
    required this.name,
    required this.centerPoint,
    required this.radiusMeters,
  });
}

class TodaQueueService {
  // Laoag City TODA Terminals with 30m Geofences
  static final List<TodaTerminal> laoagTerminals = [
    TodaTerminal(
      id: 'term_01',
      name: 'Laoag Central Terminal & Public Market TODA',
      centerPoint: LocationService.laoagLandmarks[0],
      radiusMeters: 35.0,
    ),
    TodaTerminal(
      id: 'term_02',
      name: 'MMSU Laoag Campus TODA',
      centerPoint: LocationService.laoagLandmarks[1],
      radiusMeters: 30.0,
    ),
    TodaTerminal(
      id: 'term_03',
      name: 'Laoag Plaza & Heritage Center TODA',
      centerPoint: LocationService.laoagLandmarks[2],
      radiusMeters: 30.0,
    ),
  ];

  // Zero-Touch Speed Check Threshold (Speed > 12 km/h = Walk-in departure)
  static const double speedCheckoutThresholdKmh = 12.0;
  // 15-second Auto-Pass timer for unanswered dispatch alerts
  static const int autoPassSeconds = 15;

  static QueueStatus evaluateQueueStatus({
    required double currentLat,
    required double currentLng,
    required double currentSpeedKmh,
    required TodaTerminal terminal,
  }) {
    double distanceInKm = LocationService.calculateDistanceInKm(
      currentLat,
      currentLng,
      terminal.centerPoint.latitude,
      terminal.centerPoint.longitude,
    );

    double distanceMeters = distanceInKm * 1000;

    if (currentSpeedKmh > speedCheckoutThresholdKmh && distanceMeters > terminal.radiusMeters) {
      // Driver moved away at > 12 km/h -> Auto-checkout walk-in passenger
      return QueueStatus.departingWithPassenger;
    } else if (distanceMeters <= terminal.radiusMeters) {
      // Inside geofence -> Auto-enter FIFO queue
      return QueueStatus.queued;
    } else {
      return QueueStatus.outsideTerminal;
    }
  }
}
