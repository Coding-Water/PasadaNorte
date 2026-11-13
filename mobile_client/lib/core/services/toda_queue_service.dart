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
  mockGpsBlocked,
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
  /// Populated dynamically from Supabase `toda_terminals` created in Web Admin.
  static final List<TodaTerminal> laoagTerminals = [];

  static void replaceTerminalsFromSupabase(List<Map<String, dynamic>> rows) {
    final parsed = <TodaTerminal>[];
    for (final row in rows) {
      final id = row['id']?.toString();
      final name = row['name']?.toString();
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      if (id == null || name == null || lat == null || lng == null) continue;
      parsed.add(
        TodaTerminal(
          id: id,
          name: name,
          todaCode: (row['toda_code'] ?? 'TODA').toString(),
          centerPoint: LocationPoint(
            name: name,
            latitude: lat,
            longitude: lng,
          ),
          radiusMeters: (row['radius_meters'] as num?)?.toDouble() ?? 25.0,
          dwellTimeSeconds:
              (row['min_stop_dwell_seconds'] as num?)?.toInt() ??
                  (row['dwell_time_seconds'] as num?)?.toInt() ??
                  30,
          speedLimitKmh:
              (row['join_speed_limit_kmh'] as num?)?.toDouble() ??
                  (row['speed_limit_kmh'] as num?)?.toDouble() ??
                  5.0,
        ),
      );
    }
    laoagTerminals
      ..clear()
      ..addAll(parsed);
  }

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

  // Finds nearest TODA terminal to a given GPS coordinate
  static ({TodaTerminal terminal, double distanceMeters}) findNearestTerminal(
    double lat,
    double lng,
  ) {
    if (laoagTerminals.isEmpty) {
      return (
        terminal: TodaTerminal(
          id: 'unassigned',
          name: 'No TODA Pila Configured',
          todaCode: 'NONE',
          centerPoint: LocationPoint(
            name: 'Laoag City',
            latitude: lat,
            longitude: lng,
          ),
          radiusMeters: 25.0,
        ),
        distanceMeters: 0.0,
      );
    }
    TodaTerminal nearest = laoagTerminals.first;
    double minDistance = double.infinity;

    for (final term in laoagTerminals) {
      final distKm = LocationService.calculateDistanceInKm(
        lat,
        lng,
        term.centerPoint.latitude,
        term.centerPoint.longitude,
      );
      final distMeters = distKm * 1000;
      if (distMeters < minDistance) {
        minDistance = distMeters;
        nearest = term;
      }
    }

    return (terminal: nearest, distanceMeters: minDistance);
  }

  static QueueStatus evaluateQueueStatus({
    required double currentLat,
    required double currentLng,
    required double currentSpeedKmh,
    required TodaTerminal terminal,
    String? driverTodaCode,
    bool hasPassenger = false,
    int dwellSeconds = 0,
    bool isMockGps = false,
  }) {
    // Hardware-level Mock GPS Detection Sentinel (City Ord. 2023-005 / ISO/IEC 25010)
    if (isMockGps || LocationService.hasMockLocationViolation) {
      return QueueStatus.mockGpsBlocked;
    }

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

  // ==========================================================================
  // Dynamic FIFO Queue State per TODA Terminal (Eliminates Static Hardcoding)
  // ==========================================================================
  static final Map<String, List<PilaDriverUnit>> _queues = {
    'term_01': [],
    'term_02': [],
    'term_03': [],
    'term_04': [],
    'term_05': [],
  };

  static List<PilaDriverUnit> getTerminalQueue(String terminalId, {String? driverName}) {
    final list = _queues[terminalId] ?? [];
    return list.map((u) {
      final bool isMe = driverName != null &&
          (u.driverName.toLowerCase().contains(driverName.toLowerCase()) ||
              driverName.toLowerCase().contains(u.driverName.toLowerCase()));
      return u.copyWith(isCurrentDriver: isMe);
    }).toList();
  }

  static int getCurrentDriverRank(String terminalId, {String? driverName}) {
    final list = getTerminalQueue(terminalId, driverName: driverName);
    for (final u in list) {
      if (u.isCurrentDriver) return u.rank;
    }
    return 0; // 0 indicates not currently queued in terminal
  }

  static bool isDriverQueued(String terminalId, {String? driverName}) {
    return getCurrentDriverRank(terminalId, driverName: driverName) > 0;
  }

  // Dequeues driver when taking a passenger: subsequent drivers move up in line
  static void dequeueDriverForTrip(String terminalId, String driverName) {
    final list = _queues[terminalId];
    if (list == null || list.isEmpty) return;
    final index = list.indexWhere((u) =>
        u.driverName.toLowerCase().contains(driverName.toLowerCase()) ||
        driverName.toLowerCase().contains(u.driverName.toLowerCase()));

    if (index != -1) {
      list.removeAt(index);
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
        if (i == 0) {
          list[i] = list[i].copyWith(status: 'Next to Board (First in Line)');
        }
      }
    }
  }

  // Enqueues driver at tail of FIFO line when returning to terminal geofence
  static int enqueueDriverAtTail(String terminalId, String driverName, String bodyNumber) {
    final list = _queues.putIfAbsent(terminalId, () => []);
    final existingIndex = list.indexWhere((u) =>
        u.driverName.toLowerCase().contains(driverName.toLowerCase()) ||
        driverName.toLowerCase().contains(u.driverName.toLowerCase()) ||
        u.bodyNumber == bodyNumber);

    if (existingIndex != -1) {
      return list[existingIndex].rank;
    }

    final newRank = list.length + 1;
    final newEntry = PilaDriverUnit(
      rank: newRank,
      bodyNumber: bodyNumber,
      driverName: driverName,
      status: newRank == 1 ? 'Next to Board (First in Line)' : 'Just Queued (FIFO Line)',
      isCurrentDriver: true,
    );
    list.add(newEntry);
    return newRank;
  }

  static void resetQueuesForTesting() {
    _queues['term_01'] = [
      PilaDriverUnit(rank: 1, bodyNumber: '#0042', driverName: 'Eduardo "Manong Eddie" Castro', status: 'Next to Board (First in Line)', isCurrentDriver: true),
      PilaDriverUnit(rank: 2, bodyNumber: '#0012', driverName: 'Arturo Domingo', status: 'In Terminal Bay', isCurrentDriver: false),
      PilaDriverUnit(rank: 3, bodyNumber: '#2133', driverName: 'Nestor Valdez', status: 'In Terminal Bay', isCurrentDriver: false),
      PilaDriverUnit(rank: 4, bodyNumber: '#0835', driverName: 'Jaime Alcantara', status: 'In Terminal Bay', isCurrentDriver: false),
      PilaDriverUnit(rank: 5, bodyNumber: '#1058', driverName: 'Crisanto Agbayani', status: 'Standing by', isCurrentDriver: false),
    ];
    _queues['term_02'] = [
      PilaDriverUnit(rank: 1, bodyNumber: '#0019', driverName: 'Rogelio Pascual', status: 'Next to Board', isCurrentDriver: false),
      PilaDriverUnit(rank: 2, bodyNumber: '#1088', driverName: 'Marcos Barba', status: 'In Terminal Bay', isCurrentDriver: false),
      PilaDriverUnit(rank: 3, bodyNumber: '#0412', driverName: 'Emilio Farinas', status: 'Standing by', isCurrentDriver: false),
    ];
    _queues['term_03'] = [
      PilaDriverUnit(rank: 1, bodyNumber: '#0031', driverName: 'Ferdinand Corpuz', status: 'Next to Board', isCurrentDriver: false),
      PilaDriverUnit(rank: 2, bodyNumber: '#1062', driverName: 'Vicente Keon', status: 'In Terminal Bay', isCurrentDriver: false),
    ];
  }
}

class PilaDriverUnit {
  int rank;
  final String bodyNumber;
  final String driverName;
  final String status;
  final bool isCurrentDriver;

  PilaDriverUnit({
    required this.rank,
    required this.bodyNumber,
    required this.driverName,
    required this.status,
    this.isCurrentDriver = false,
  });

  PilaDriverUnit copyWith({
    int? rank,
    String? bodyNumber,
    String? driverName,
    String? status,
    bool? isCurrentDriver,
  }) {
    return PilaDriverUnit(
      rank: rank ?? this.rank,
      bodyNumber: bodyNumber ?? this.bodyNumber,
      driverName: driverName ?? this.driverName,
      status: status ?? this.status,
      isCurrentDriver: isCurrentDriver ?? this.isCurrentDriver,
    );
  }
}
