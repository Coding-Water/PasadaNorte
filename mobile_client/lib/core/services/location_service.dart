import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final String name;
  final String zoneCode;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.zoneCode = 'Z01',
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

class RouteResult {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final bool isRoadRoute;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    required this.isRoadRoute,
  });
}

class LocationService {
  // Default home residential GPS coordinate in Laoag City (used if emulator GPS is set outside Philippines)
  static LocationPoint cachedUserHomeLocation = const LocationPoint(
    name: 'My Current Location (Brgy. 10 San Jose, Laoag City)',
    latitude: 18.1984,
    longitude: 120.5948,
    zoneCode: 'GPS',
  );

  // Automatically warms up and resolves the user's real GPS location on app open
  static Future<LocationPoint> warmUpDeviceGpsLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 4));
        // Check if device/emulator is in or near Philippines (lat 4..22, lon 116..127);
        // Android emulators default to Mountain View CA (37.42, -122.08) unless overridden.
        final bool isInPhilippines = pos.latitude >= 4.0 &&
            pos.latitude <= 22.0 &&
            pos.longitude >= 116.0 &&
            pos.longitude <= 127.0;

        final double targetLat = isInPhilippines ? pos.latitude : 18.1984;
        final double targetLng = isInPhilippines ? pos.longitude : 120.5948;
        final String street = await reverseGeocodePoint(targetLat, targetLng);

        cachedUserHomeLocation = LocationPoint(
          name: 'My Location ($street)',
          latitude: targetLat,
          longitude: targetLng,
          zoneCode: 'GPS',
        );
        return cachedUserHomeLocation;
      }
    } catch (_) {}
    return cachedUserHomeLocation;
  }

  // Haversine formula to calculate straight-line distance in kilometers
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

    return max(0.3, double.parse(distance.toStringAsFixed(2)));
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Live OpenStreetMap / Nominatim Geocoding Search for ANY street, store, barangay, or place in Laoag City / Ilocos Norte
  static Future<List<LocationPoint>> searchPlacesInLaoag(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return laoagLandmarks;

    final searchQuery = trimmed.toLowerCase().contains('laoag')
        ? trimmed
        : '$trimmed, Laoag City, Ilocos Norte, Philippines';

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(searchQuery)}'
      '&format=json&limit=8&addressdetails=1',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'PasadaNorteLaoagApp/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          return list.map((item) {
            final map = item as Map<String, dynamic>;
            final displayName = (map['display_name'] as String?) ?? trimmed;
            final shortName = displayName.split(',').take(2).join(', ').trim();
            return LocationPoint(
              name: shortName.isNotEmpty ? shortName : displayName,
              latitude: double.tryParse(map['lat'].toString()) ?? 18.1960,
              longitude: double.tryParse(map['lon'].toString()) ?? 120.5935,
              zoneCode: 'PIN',
            );
          }).toList();
        }
      }
    } catch (_) {}

    // Local filter fallback if offline
    return laoagLandmarks
        .where((p) => p.name.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();
  }

  // Reverse geocodes any tapped coordinate on the map into its real street / barangay address
  static Future<String> reverseGeocodePoint(double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=json&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'PasadaNorteLaoagApp/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[
            if (address['amenity'] != null) address['amenity'].toString(),
            if (address['shop'] != null) address['shop'].toString(),
            if (address['road'] != null) address['road'].toString(),
            if (address['suburb'] != null)
              address['suburb'].toString()
            else if (address['village'] != null)
              address['village'].toString()
            else if (address['neighbourhood'] != null)
              address['neighbourhood'].toString(),
          ];
          if (parts.isNotEmpty) {
            return parts.take(2).join(', ');
          }
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName.split(',').take(2).join(', ').trim();
        }
      }
    } catch (_) {}

    return 'Pinned Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  // Computes actual road route distance and geometry using the public OSRM routing API,
  // with automatic urban road-factor fallback if offline.
  static Future<RouteResult> fetchRoadRoute(
    LocationPoint origin,
    LocationPoint destination,
  ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final points = coordinates.map((coord) {
            final pair = coord as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList();

          return RouteResult(
            distanceKm: max(0.5, double.parse((distanceMeters / 1000.0).toStringAsFixed(2))),
            durationMinutes: max(2, (durationSeconds / 60.0).ceil()),
            polylinePoints: points,
            isRoadRoute: true,
          );
        }
      }
    } catch (_) {
      // Fallback to Haversine with 1.28 urban street circuity factor
    }

    final straightKm = calculateDistanceInKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final estimatedRoadKm = double.parse((straightKm * 1.28).toStringAsFixed(2));
    final estimatedMins = max(2, (estimatedRoadKm / 0.35).ceil()); // ~21 km/h urban tricycle speed

    return RouteResult(
      distanceKm: max(0.5, estimatedRoadKm),
      durationMinutes: estimatedMins,
      polylinePoints: [origin.latLng, destination.latLng],
      isRoadRoute: false,
    );
  }

  // 10 Laoag City Zones (Z01 to Z10) for Objective 3 Demand Forecasting
  // (10 zones × 56 days × 12 operating hours = 6,720 zone-hour intervals;
  // 5,040 training zone-hours in Weeks 1–6; 1,680 held-out test zone-hours in Weeks 7–8;
  // 3,500–5,000 actual completed trips)
  static const List<LocationPoint> laoagPrimaryZones = [
    LocationPoint(
      name: 'Laoag Central Terminal & Public Market',
      latitude: 18.1972,
      longitude: 120.5925,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Mariano Marcos State University (MMSU Laoag)',
      latitude: 18.1925,
      longitude: 120.5960,
      zoneCode: 'Z02',
    ),
    LocationPoint(
      name: 'Laoag City Plaza & Sinking Bell Tower',
      latitude: 18.1965,
      longitude: 120.5938,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'Laoag City General Hospital (LCGH)',
      latitude: 18.1880,
      longitude: 120.5890,
      zoneCode: 'Z04',
    ),
    LocationPoint(
      name: 'INCAT (Ilocos Norte College of Arts and Trades)',
      latitude: 18.1990,
      longitude: 120.5980,
      zoneCode: 'Z05',
    ),
    LocationPoint(
      name: 'Provincial Capitol & Aurora Park Hub',
      latitude: 18.1960,
      longitude: 120.5920,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Northwestern University (NWU) Corridor',
      latitude: 18.2040,
      longitude: 120.5885,
      zoneCode: 'Z07',
    ),
    LocationPoint(
      name: 'Robinsons Place / Commercial Hub',
      latitude: 18.1845,
      longitude: 120.5912,
      zoneCode: 'Z08',
    ),
    LocationPoint(
      name: 'Gilbert Bridge North Approach & Bus Terminal',
      latitude: 18.1910,
      longitude: 120.5905,
      zoneCode: 'Z09',
    ),
    LocationPoint(
      name: 'Laoag International Airport Corridor (Gabu)',
      latitude: 18.1811,
      longitude: 120.5306,
      zoneCode: 'Z10',
    ),
  ];

  // Extended Laoag City Landmarks for quick destination search & pin drop
  static const List<LocationPoint> laoagLandmarks = laoagPrimaryZones;
}
