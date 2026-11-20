import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Resilient disk-cached [TileProvider] for weak mobile data connections:
/// 1. Serves previously viewed Laoag/Ilocos Norte tiles instantly from disk cache.
/// 2. Deduplicates in-flight requests for the same tile URL.
/// 3. Retries transient 3G/4G timeouts (up to 2 attempts, 8s timeout each).
/// 4. Falls back to OpenStreetMap (Streets) or Esri World Imagery (Satellite)
///    if `mt1.google.com` fails or is throttled on a mobile carrier IP.
class ResilientCachedTileProvider extends TileProvider {
  static final ResilientCachedTileProvider instance =
      ResilientCachedTileProvider._();

  static final http.Client _httpClient = http.Client();
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static Directory? _cacheDir;

  ResilientCachedTileProvider._()
      : super(
          headers: <String, String>{
            'User-Agent': 'PasadaNorte/1.0 (ph.laoag.pasadanorte)',
          },
        );

  static bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  static Directory _getCacheDir() {
    if (_cacheDir != null) return _cacheDir!;
    final dir = Directory('${Directory.systemTemp.path}/pasadanorte_map_tiles');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Generates a collision-free cache filename separating map styles (Streets vs Satellite).
  @visibleForTesting
  static String cacheKeyFor(String url, TileCoordinates coords) {
    final styleTag = url.contains('lyrs=y')
        ? 'sat'
        : (url.contains('openstreetmap.org') ? 'osm' : 'str');
    // 32-bit FNV-1a hash of the full URL so tail coordinates never collide styles
    int hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(8, '0');
    return 'z${coords.z}_x${coords.x}_y${coords.y}_${styleTag}_$hex.tile';
  }

  /// Verifies bytes represent an actual PNG, JPEG, or WebP image (not an HTML error page).
  @visibleForTesting
  static bool isValidImageBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 128) return false;
    // PNG: 89 50 4E 47
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    // JPEG: FF D8 FF
    final isJpg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    // WebP: RIFF....WEBP
    final isWebp = bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isPng || isJpg || isWebp;
  }

  @visibleForTesting
  static String resolveFallbackUrl(String primaryUrl, TileCoordinates coords) {
    final isSatellite = primaryUrl.contains('lyrs=y');
    if (isSatellite) {
      final safeZ = coords.z > 18 ? 18 : coords.z;
      final shift = coords.z - safeZ;
      final x = coords.x >> shift;
      final y = coords.y >> shift;
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$safeZ/$y/$x';
    }
    return 'https://tile.openstreetmap.org/${coords.z}/${coords.x}/${coords.y}.png';
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final primaryUrl = getTileUrl(coordinates, options);
    final fallbackUrl = resolveFallbackUrl(primaryUrl, coordinates);
    final reqHeaders = <String, String>{
      'User-Agent': 'PasadaNorte/1.0 (ph.laoag.pasadanorte)',
      ...headers,
    };

    return _ResilientTileImageProvider(
      primaryUrl: primaryUrl,
      fallbackUrl: fallbackUrl,
      coordinates: coordinates,
      headers: reqHeaders,
    );
  }

  static Future<Uint8List> _fetchTileBytes({
    required String primaryUrl,
    required String fallbackUrl,
    required TileCoordinates coordinates,
    required Map<String, String> headers,
  }) {
    final existing = _inFlight[primaryUrl];
    if (existing != null) return existing;

    final future = _fetchTileBytesInternal(
      primaryUrl: primaryUrl,
      fallbackUrl: fallbackUrl,
      coordinates: coordinates,
      headers: headers,
    ).whenComplete(() => _inFlight.remove(primaryUrl));

    _inFlight[primaryUrl] = future;
    return future;
  }

  static Future<Uint8List> _fetchTileBytesInternal({
    required String primaryUrl,
    required String fallbackUrl,
    required TileCoordinates coordinates,
    required Map<String, String> headers,
  }) async {
    final bool inTest = _isWidgetTest;
    File? cacheFile;

    if (!kIsWeb && !inTest) {
      try {
        final dir = _getCacheDir();
        cacheFile = File('${dir.path}/${cacheKeyFor(primaryUrl, coordinates)}');
        if (await cacheFile.exists()) {
          final cached = await cacheFile.readAsBytes();
          if (isValidImageBytes(cached)) {
            return cached;
          }
        }
      } catch (_) {}
    }

    final List<String> candidates = primaryUrl == fallbackUrl
        ? [primaryUrl]
        : [primaryUrl, fallbackUrl];

    for (final url in candidates) {
      final int maxAttempts = inTest ? 1 : 2;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          final resp = await _httpClient
              .get(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200 && isValidImageBytes(resp.bodyBytes)) {
            if (cacheFile != null && !inTest) {
              unawaited(
                cacheFile.writeAsBytes(resp.bodyBytes, flush: false).catchError(
                      (_) => cacheFile!,
                    ),
              );
            }
            return resp.bodyBytes;
          }
        } catch (_) {}
        if (!inTest && attempt + 1 < maxAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        }
      }
    }

    throw Exception(
      'Failed to load map tile z=${coordinates.z} x=${coordinates.x} y=${coordinates.y}',
    );
  }
}

class _ResilientTileImageProvider
    extends ImageProvider<_ResilientTileImageProvider> {
  final String primaryUrl;
  final String fallbackUrl;
  final TileCoordinates coordinates;
  final Map<String, String> headers;

  const _ResilientTileImageProvider({
    required this.primaryUrl,
    required this.fallbackUrl,
    required this.coordinates,
    required this.headers,
  });

  @override
  Future<_ResilientTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_ResilientTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ResilientTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: primaryUrl,
    );
  }

  Future<ui.Codec> _loadAsync(
    _ResilientTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await ResilientCachedTileProvider._fetchTileBytes(
      primaryUrl: key.primaryUrl,
      fallbackUrl: key.fallbackUrl,
      coordinates: key.coordinates,
      headers: key.headers,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ResilientTileImageProvider &&
        other.primaryUrl == primaryUrl &&
        other.coordinates == coordinates;
  }

  @override
  int get hashCode => Object.hash(primaryUrl, coordinates);
}
