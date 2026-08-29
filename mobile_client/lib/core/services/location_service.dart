import 'dart:math';

class LocationPoint {
  final double latitude;
  final double longitude;
  final String name;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.name,
  });
}

class LocationService {
  static double calculateDistanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadiusKm * c;

    return max(0.5, double.parse(distance.toStringAsFixed(2)));
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  static final List<LocationPoint> laoagLandmarks = [
    LocationPoint(
      name: 'Laoag Central Terminal & Public Market',
      latitude: 18.1972,
      longitude: 120.5925,
    ),
    LocationPoint(
      name: 'Mariano Marcos State University (MMSU Laoag)',
      latitude: 18.1925,
      longitude: 120.5960,
    ),
    LocationPoint(
      name: 'Laoag City Plaza & Sinking Bell Tower',
      latitude: 18.1965,
      longitude: 120.5938,
    ),
    LocationPoint(
      name: 'Laoag City General Hospital',
      latitude: 18.1880,
      longitude: 120.5890,
    ),
    LocationPoint(
      name: 'Laoag International Airport Corridor',
      latitude: 18.1811,
      longitude: 120.5306,
    ),
    LocationPoint(
      name: 'Northwestern University Laoag',
      latitude: 18.2040,
      longitude: 120.5885,
    ),
  ];
}
