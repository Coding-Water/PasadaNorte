import 'location_service.dart';
import 'supabase_service.dart';

enum QueueStatus {
  outsideTerminal,
  queued,
  departingWithPassenger,
  passingThrough,
  stuckInTraffic,
  wrongToda,
  autoPassed,
}

class TodaTerminal {
  final String id;
  final String name;
  final String todaCode;
  final LocationPoint centerPoint;
  double radiusMeters;
  final int dwellTimeSeconds;
  final double speedLimitKmh;

  TodaTerminal({
    required this.id,
    required this.name,
    required this.todaCode,
    required this.centerPoint,
    required this.radiusMeters,
    this.dwellTimeSeconds = 30,
    this.speedLimitKmh = 5.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'toda_code': todaCode,
      'latitude': centerPoint.latitude,
      'longitude': centerPoint.longitude,
      'radius_meters': radiusMeters,
      'dwell_time_seconds': dwellTimeSeconds,
      'speed_limit_kmh': speedLimitKmh,
    };
  }

  factory TodaTerminal.fromJson(Map<String, dynamic> json) {
    return TodaTerminal(
      id: json['id'],
      name: json['name'],
      todaCode: json['toda_code'] ?? 'GENERAL-TODA',
      centerPoint: LocationPoint(
        name: json['name'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      ),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      dwellTimeSeconds: json['dwell_time_seconds'] ?? 30,
      speedLimitKmh: (json['speed_limit_kmh'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class TodaQueueService {
  static final List<TodaTerminal> laoagTerminals = [
    TodaTerminal(
      id: 'term_01',
      name: 'Laoag Central Terminal & Public Market TODA',
      todaCode: 'CENTRAL-TODA',
      centerPoint: LocationService.laoagLandmarks[0],
      radiusMeters: 25.0,
      dwellTimeSeconds: 30,
    ),
    TodaTerminal(
      id: 'term_02',
      name: 'INCAT School Gate TODA Pila',
      todaCode: 'INCAT-TODA',
      centerPoint: LocationPoint(
        name: 'INCAT (Ilocos Norte College of Arts and Trades)',
        latitude: 18.1990,
        longitude: 120.5980,
      ),
      radiusMeters: 15.0,
      dwellTimeSeconds: 25,
    ),
    TodaTerminal(
      id: 'term_03',
      name: 'MMSU Laoag Campus TODA',
      todaCode: 'MMSU-TODA',
      centerPoint: LocationService.laoagLandmarks[1],
      radiusMeters: 15.0,
      dwellTimeSeconds: 30,
    ),
    TodaTerminal(
      id: 'term_04',
      name: 'Laoag Plaza & Heritage Center TODA',
      todaCode: 'PLAZA-TODA',
      centerPoint: LocationService.laoagLandmarks[2],
      radiusMeters: 12.0,
      dwellTimeSeconds: 30,
    ),
    TodaTerminal(
      id: 'term_05',
      name: 'Laoag City General Hospital Pila',
      todaCode: 'HOSPITAL-TODA',
      centerPoint: LocationService.laoagLandmarks[3],
      radiusMeters: 10.0,
      dwellTimeSeconds: 20,
    ),
  ];

  static void updateAdminPilaRadius(
    String terminalId,
    double newRadiusMeters, {
    bool syncToCloud = true,
  }) {
    final index = laoagTerminals.indexWhere((t) => t.id == terminalId);
    if (index != -1) {
      laoagTerminals[index].radiusMeters = newRadiusMeters;
      if (syncToCloud) {
        SupabaseService.updateTerminalRadius(terminalId, newRadiusMeters);
      }
    }
  }

  static const double speedCheckoutThresholdKmh = 10.0;
  static const int autoPassSeconds = 15;

  static QueueStatus evaluateQueueStatus({
    required double currentLat,
    required double currentLng,
    required double currentSpeedKmh,
    required TodaTerminal terminal,
    String? driverTodaCode,
    bool hasPassenger = false,
    int dwellSeconds = 0,
  }) {
    if (hasPassenger) {
      return QueueStatus.outsideTerminal;
    }

    if (driverTodaCode != null && driverTodaCode.isNotEmpty && driverTodaCode != terminal.todaCode) {
      return QueueStatus.wrongToda;
    }

    double distanceInKm = LocationService.calculateDistanceInKm(
      currentLat,
      currentLng,
      terminal.centerPoint.latitude,
      terminal.centerPoint.longitude,
    );

    double distanceMeters = distanceInKm * 1000;

    if (distanceMeters > terminal.radiusMeters) {
      if (currentSpeedKmh > speedCheckoutThresholdKmh) {
        return QueueStatus.departingWithPassenger;
      }
      return QueueStatus.outsideTerminal;
    }

    if (currentSpeedKmh > terminal.speedLimitKmh) {
      return QueueStatus.passingThrough;
    }

    if (dwellSeconds < terminal.dwellTimeSeconds) {
      return QueueStatus.stuckInTraffic;
    }

    return QueueStatus.queued;
  }
}
