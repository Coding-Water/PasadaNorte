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
    name: 'My Current Location (J. P. Rizal Street, Brgy. 10 San Jose, Laoag City)',
    latitude: 18.1978,
    longitude: 120.5944,
    zoneCode: 'GPS',
  );

  // Bounding box for Laoag City & Ilocos Norte (left, top, right, bottom)
  // viewbox=lon_min,lat_max,lon_max,lat_min
  static const String _laoagViewbox = '120.5100,18.2500,120.6600,18.1400';

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

        final double targetLat = isInPhilippines ? pos.latitude : 18.1978;
        final double targetLng = isInPhilippines ? pos.longitude : 120.5944;
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

    return max(0.15, double.parse(distance.toStringAsFixed(2)));
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Formats an address object from Nominatim or Photon into a clean, accurate Laoag street/place string
  static String _formatDetailedAddress(Map<String, dynamic> item, String fallbackQuery) {
    final name = (item['name'] as String?)?.trim() ?? '';
    final address = item['address'] as Map<String, dynamic>?;
    if (address != null) {
      final poi = address['amenity'] ??
          address['shop'] ??
          address['building'] ??
          address['tourism'] ??
          address['office'] ??
          address['leisure'] ??
          address['College'] ??
          address['school'] ??
          address['hospital'];
      final houseNumber = address['house_number'];
      final road = address['road'] ?? address['pedestrian'] ?? address['street'];
      final barangay = address['suburb'] ??
          address['neighbourhood'] ??
          address['village'] ??
          address['quarter'] ??
          address['hamlet'];
      final city = address['city'] ?? address['town'] ?? address['municipality'] ?? 'Laoag City';

      final parts = <String>[];
      if (name.isNotEmpty) {
        parts.add(name);
      } else if (poi != null && poi.toString().trim().isNotEmpty) {
        parts.add(poi.toString().trim());
      }

      if (road != null && road.toString().trim().isNotEmpty) {
        final roadStr = houseNumber != null
            ? '$houseNumber ${road.toString().trim()}'
            : road.toString().trim();
        if (!parts.any((p) => p.toLowerCase().contains(roadStr.toLowerCase()))) {
          parts.add(roadStr);
        }
      }

      if (barangay != null && barangay.toString().trim().isNotEmpty) {
        final brgyStr = barangay.toString().trim();
        if (!parts.any((p) => p.toLowerCase().contains(brgyStr.toLowerCase()))) {
          parts.add(brgyStr);
        }
      }

      if (city.toString().trim().isNotEmpty &&
          !parts.any((p) => p.toLowerCase().contains(city.toString().toLowerCase()))) {
        parts.add(city.toString().trim());
      }

      if (parts.isNotEmpty) {
        return parts.take(3).join(', ');
      }
    }

    final displayName = (item['display_name'] as String?)?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName
          .split(',')
          .map((s) => s.trim())
          .where((s) =>
              s.isNotEmpty &&
              s != 'Philippines' &&
              s != 'Ilocos Region' &&
              !RegExp(r'^\d{4}$').hasMatch(s))
          .take(3)
          .join(', ');
    }
    return fallbackQuery;
  }

  // Multi-source Live Geocoding Search bounded to Laoag City & Ilocos Norte
  // Uses local gazetteer + Photon (Komoot) + Nominatim with strict Laoag viewbox & countrycodes=ph
  static Future<List<LocationPoint>> searchPlacesInLaoag(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final lowerQuery = trimmed.toLowerCase();
    final List<LocationPoint> combinedResults = [];
    final Set<String> seenKeys = {};

    void addUnique(LocationPoint pt) {
      final key =
          '${pt.name.toLowerCase()}_${pt.latitude.toStringAsFixed(3)}_${pt.longitude.toStringAsFixed(3)}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        combinedResults.add(pt);
      }
    }

    // 1. Instant high-precision match against verified Laoag City streets, barangays, schools, malls & landmarks
    for (final place in laoagComprehensiveGazetteer) {
      if (place.name.toLowerCase().contains(lowerQuery)) {
        addUnique(place);
      }
    }

    // 2. Live Nominatim Geocoder bounded strictly to Laoag City / Ilocos Norte (countrycodes=ph & viewbox)
    final searchQuery = lowerQuery.contains('laoag')
        ? trimmed
        : '$trimmed, Laoag City, Ilocos Norte';

    final nominatimUri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(searchQuery)}'
      '&format=jsonv2'
      '&addressdetails=1'
      '&countrycodes=ph'
      '&viewbox=$_laoagViewbox'
      '&bounded=0'
      '&limit=10',
    );

    try {
      final response = await http.get(
        nominatimUri,
        headers: {
          'User-Agent': 'PasadaNorteLaoagSmartParatransit/2.0 (laoag-pasadanorte.ph)',
          'Accept-Language': 'en-PH,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        for (final raw in list) {
          final map = raw as Map<String, dynamic>;
          final lat = double.tryParse(map['lat']?.toString() ?? '');
          final lon = double.tryParse(map['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;

          // Prioritize results within Ilocos Norte (lat 17.8..18.6, lon 120.3..120.9)
          if (lat < 17.5 || lat > 18.7 || lon < 120.2 || lon > 121.0) continue;

          final formattedName = _formatDetailedAddress(map, trimmed);
          addUnique(
            LocationPoint(
              name: formattedName,
              latitude: lat,
              longitude: lon,
              zoneCode: 'PIN',
            ),
          );
        }
      }
    } catch (_) {}

    // 3. Fallback / supplementary Photon Geocode API (fast fuzzy autocomplete biased to Laoag City center)
    if (combinedResults.length < 4) {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeComponent("$trimmed Laoag")}'
        '&lat=18.1960&lon=120.5935'
        '&limit=8',
      );
      try {
        final resp = await http.get(photonUri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? [];
          for (final feat in features) {
            final fMap = feat as Map<String, dynamic>;
            final geom = fMap['geometry'] as Map<String, dynamic>?;
            final props = fMap['properties'] as Map<String, dynamic>?;
            if (geom == null || props == null) continue;
            final coords = geom['coordinates'] as List<dynamic>?;
            if (coords == null || coords.length < 2) continue;
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            if (lat < 17.5 || lat > 18.7 || lon < 120.2 || lon > 121.0) continue;

            final pName = props['name']?.toString() ?? '';
            final pStreet = props['street']?.toString() ?? '';
            final pDistrict = props['district']?.toString() ?? props['locality']?.toString() ?? '';
            final pCity = props['city']?.toString() ?? 'Laoag City';

            final labelParts = <String>[
              if (pName.isNotEmpty) pName,
              if (pStreet.isNotEmpty && pStreet != pName) pStreet,
              if (pDistrict.isNotEmpty && pDistrict != pName) pDistrict,
              if (pCity.isNotEmpty) pCity,
            ];
            if (labelParts.isNotEmpty) {
              addUnique(
                LocationPoint(
                  name: labelParts.take(3).join(', '),
                  latitude: lat,
                  longitude: lon,
                  zoneCode: 'PIN',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    return combinedResults;
  }

  // Reverse geocodes any tapped coordinate on the map into its real street / barangay address
  static Future<String> reverseGeocodePoint(double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=jsonv2&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'PasadaNorteLaoagSmartParatransit/2.0 (laoag-pasadanorte.ph)',
          'Accept-Language': 'en-PH,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final formatted = _formatDetailedAddress(data, '');
        if (formatted.isNotEmpty) {
          return formatted;
        }
      }
    } catch (_) {}

    // Offline fallback: find nearest known street/place in Laoag City
    LocationPoint? nearest;
    double minDist = double.infinity;
    for (final p in laoagComprehensiveGazetteer) {
      final d = calculateDistanceInKm(lat, lng, p.latitude, p.longitude);
      if (d < minDist) {
        minDist = d;
        nearest = p;
      }
    }
    if (nearest != null && minDist <= 0.8) {
      return 'Near ${nearest.name}';
    }

    return 'Pinned Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  // Computes actual road route distance and street-following geometry using OSRM (primary + backup mirrors)
  // and orthogonal Laoag street-grid fallback if completely offline (never a diagonal flying line).
  static Future<RouteResult> fetchRoadRoute(
    LocationPoint origin,
    LocationPoint destination,
  ) async {
    final endpoints = [
      'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'User-Agent': 'PasadaNorteLaoagSmartParatransit/2.0 (laoag-pasadanorte.ph)',
          },
        ).timeout(const Duration(seconds: 6));

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

            if (points.length >= 2) {
              // Ensure exact start & end alignment with road snap
              final densePoints = _densifyPolyline(points, maxSegmentMeters: 18.0);
              return RouteResult(
                distanceKm: max(0.4, double.parse((distanceMeters / 1000.0).toStringAsFixed(2))),
                durationMinutes: max(2, (durationSeconds / 60.0).ceil()),
                polylinePoints: densePoints,
                isRoadRoute: true,
              );
            }
          }
        }
      } catch (_) {
        // Try next routing server
      }
    }

    // Offline fallback: Orthogonal Laoag street-grid path (follows Laoag's NNE-SSW / WNW-ESE street grid
    // along J.P. Rizal St / Rizal Ave / Gen. Segundo Ave instead of flying diagonally through blocks)
    final gridPoints = _buildLaoagStreetGridFallbackPath(origin.latLng, destination.latLng);
    final straightKm = calculateDistanceInKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final estimatedRoadKm = double.parse((straightKm * 1.28).toStringAsFixed(2));
    final estimatedMins = max(2, (estimatedRoadKm / 0.35).ceil());

    return RouteResult(
      distanceKm: max(0.4, estimatedRoadKm),
      durationMinutes: estimatedMins,
      polylinePoints: _densifyPolyline(gridPoints, maxSegmentMeters: 18.0),
      isRoadRoute: false,
    );
  }

  // Densifies a road polyline so live tricycle animation glides smoothly along every street corner
  static List<LatLng> _densifyPolyline(List<LatLng> points, {double maxSegmentMeters = 18.0}) {
    if (points.length < 2) return points;
    final List<LatLng> result = [points.first];
    const Distance distanceCalc = Distance();

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final segMeters = distanceCalc.as(LengthUnit.Meter, p1, p2);
      if (segMeters > maxSegmentMeters) {
        final int subdivisions = (segMeters / maxSegmentMeters).ceil();
        for (int s = 1; s < subdivisions; s++) {
          final double t = s / subdivisions;
          result.add(
            LatLng(
              p1.latitude + (p2.latitude - p1.latitude) * t,
              p1.longitude + (p2.longitude - p1.longitude) * t,
            ),
          );
        }
      }
      result.add(p2);
    }
    return result;
  }

  // Laoag City's downtown street grid is rotated ~22 degrees NNE (Gen. Segundo Ave / AH26)
  // and ~112 degrees ESE (J. P. Rizal St). If offline, project onto the street grid axes
  // so the route turns at a 90-degree street intersection rather than cutting across buildings.
  static List<LatLng> _buildLaoagStreetGridFallbackPath(LatLng start, LatLng end) {
    // Unit vectors for Laoag's tilted street grid (~22° NNE avenue axis and ~112° ESE cross-street axis)
    const double angleRad = 22.0 * pi / 180.0;
    final double ux = sin(angleRad); // dLng direction for NNE avenue
    final double uy = cos(angleRad); // dLat direction for NNE avenue

    final double dLat = end.latitude - start.latitude;
    final double dLng = end.longitude - start.longitude;

    // Project delta onto the NNE avenue axis
    final double projAvenue = dLng * ux + dLat * uy;
    final LatLng corner = LatLng(
      start.latitude + projAvenue * uy,
      start.longitude + projAvenue * ux,
    );

    return [start, corner, end];
  }

  // 10 Laoag City Zones (Z01 to Z10) for Objective 3 Demand Forecasting
  // (10 zones × 56 days × 12 operating hours = 6,720 zone-hour intervals;
  // 5,040 training zone-hours in Weeks 1–6; 1,680 held-out test zone-hours in Weeks 7–8;
  // 3,500–5,000 actual completed trips)
  static const List<LocationPoint> laoagPrimaryZones = [
    LocationPoint(
      name: 'Laoag Central Terminal & Public Market, J. P. Rizal St, Laoag City',
      latitude: 18.1972,
      longitude: 120.5925,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Mariano Marcos State University (MMSU CTE), Castro Ave, Laoag City',
      latitude: 18.1995,
      longitude: 120.5982,
      zoneCode: 'Z02',
    ),
    LocationPoint(
      name: 'Laoag City Plaza & Sinking Bell Tower, A. Mabini St, Laoag City',
      latitude: 18.1961,
      longitude: 120.5936,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'Laoag City General Hospital (LCGH), Brgy. 40 Nalbo, Laoag City',
      latitude: 18.1880,
      longitude: 120.5835,
      zoneCode: 'Z04',
    ),
    LocationPoint(
      name: 'INCAT (Ilocos Norte College of Arts and Trades), P. Gomez St, Laoag City',
      latitude: 18.1988,
      longitude: 120.5985,
      zoneCode: 'Z05',
    ),
    LocationPoint(
      name: 'Ilocos Norte Provincial Capitol & Aurora Park, J. P. Rizal St, Laoag City',
      latitude: 18.1965,
      longitude: 120.5939,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Northwestern University (NWU), Airport Ave, Brgy. 47 Bengcag, Laoag City',
      latitude: 18.1905,
      longitude: 120.5698,
      zoneCode: 'Z07',
    ),
    LocationPoint(
      name: 'Robinsons Place Ilocos, Manila North Road (San Nicolas–Laoag Corridor)',
      latitude: 18.1695,
      longitude: 120.5872,
      zoneCode: 'Z08',
    ),
    LocationPoint(
      name: 'Gilbert Bridge North Approach & Partas Bus Terminal, Laoag City',
      latitude: 18.1928,
      longitude: 120.5929,
      zoneCode: 'Z09',
    ),
    LocationPoint(
      name: 'Laoag International Airport (LAO), Brgy. 35 Gabu, Laoag City',
      latitude: 18.1781,
      longitude: 120.5319,
      zoneCode: 'Z10',
    ),
  ];

  // Comprehensive Verified Gazetteer of Laoag City Streets, Barangays, Schools, Terminals & Establishments
  static const List<LocationPoint> laoagComprehensiveGazetteer = [
    ...laoagPrimaryZones,
    LocationPoint(
      name: 'J. P. Rizal Street (Downtown Commercial Strip), Laoag City',
      latitude: 18.1968,
      longitude: 120.5934,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'General Segundo Avenue (AH26 / Laoag-Bacarra Rd), Laoag City',
      latitude: 18.1992,
      longitude: 120.5951,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'Jollibee Laoag Bacarra Road, Gen. Segundo Ave, Laoag City',
      latitude: 18.1982,
      longitude: 120.5947,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'Chowking Laoag Bacarra Road, Gen. Segundo Ave, Laoag City',
      latitude: 18.1988,
      longitude: 120.5949,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'GV Florida Bus Terminal, Hernando Ave, Brgy. 7-A, Laoag City',
      latitude: 18.1980,
      longitude: 120.5919,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Partas Bus Terminal Laoag, M. H. del Pilar St, Laoag City',
      latitude: 18.1952,
      longitude: 120.5988,
      zoneCode: 'Z09',
    ),
    LocationPoint(
      name: 'Farinas Trans Bus Terminal, F. R. Castro Ave, Laoag City',
      latitude: 18.1996,
      longitude: 120.5912,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Saint William Cathedral (Laoag Cathedral), A. Mabini St, Laoag City',
      latitude: 18.1955,
      longitude: 120.5934,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'Museo Ilocos Norte, V. Llanes St, Brgy. 10, Laoag City',
      latitude: 18.1972,
      longitude: 120.5932,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Laoag City Hall, Tupaz St, Brgy. 10, Laoag City',
      latitude: 18.1958,
      longitude: 120.5928,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Gov. Roque B. Ablan Sr. Memorial Hospital (GRBASMH), P. Gomez St, Laoag City',
      latitude: 18.1977,
      longitude: 120.5978,
      zoneCode: 'Z05',
    ),
    LocationPoint(
      name: 'Ilocos Norte National High School (INNHS), P. Gomez St, Laoag City',
      latitude: 18.1985,
      longitude: 120.5998,
      zoneCode: 'Z05',
    ),
    LocationPoint(
      name: 'Divine Word College of Laoag (DWCL), Gen. Segundo Ave, Laoag City',
      latitude: 18.2036,
      longitude: 120.5968,
      zoneCode: 'Z02',
    ),
    LocationPoint(
      name: 'SM Hypermarket / Savemore Market Laoag, J. P. Rizal St, Laoag City',
      latitude: 18.1974,
      longitude: 120.5916,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Puregold Laoag, Nolasco St, Brgy. 14, Laoag City',
      latitude: 18.1970,
      longitude: 120.5955,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'A. Mabini Street, Brgy. 9 Santa Angela, Laoag City',
      latitude: 18.1964,
      longitude: 120.5941,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'M. H. del Pilar Street, Brgy. 16 San Jacinto, Laoag City',
      latitude: 18.1959,
      longitude: 120.5965,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'F. R. Castro Avenue, Brgy. 1 San Lorenzo, Laoag City',
      latitude: 18.2002,
      longitude: 120.5945,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'P. Gomez Street, Brgy. 13 Nuestra Señora de Visitacion, Laoag City',
      latitude: 18.1981,
      longitude: 120.5972,
      zoneCode: 'Z05',
    ),
    LocationPoint(
      name: 'Andres Castro Street, Brgy. 15 San Guillermo, Laoag City',
      latitude: 18.1974,
      longitude: 120.5964,
      zoneCode: 'Z03',
    ),
    LocationPoint(
      name: 'V. Llanes Street, Brgy. 10 San Jose, Laoag City',
      latitude: 18.1976,
      longitude: 120.5938,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Balintawak Street, Brgy. 9, Laoag City',
      latitude: 18.1979,
      longitude: 120.5935,
      zoneCode: 'Z06',
    ),
    LocationPoint(
      name: 'Hernando Avenue, Brgy. 5 San Pedro, Laoag City',
      latitude: 18.1986,
      longitude: 120.5924,
      zoneCode: 'Z01',
    ),
    LocationPoint(
      name: 'Fort Ilocandia Resort Hotel, Brgy. 37 Calayab, Laoag City',
      latitude: 18.1585,
      longitude: 120.5210,
      zoneCode: 'Z10',
    ),
    LocationPoint(
      name: 'Java Hotel, Gen. Segundo Ave (Bacarra Road), Brgy. 55-B Salet, Laoag City',
      latitude: 18.2125,
      longitude: 120.5985,
      zoneCode: 'Z02',
    ),
  ];

  // Alias for compatibility
  static const List<LocationPoint> laoagLandmarks = laoagPrimaryZones;
}
