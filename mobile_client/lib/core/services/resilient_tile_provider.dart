import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Resilient disk-cached [TileProvider] for weak mobile data connections:
/// 1. Serves previously viewed Laoag/Ilocos Norte tiles instantly from disk cache.
/// 2. Retries transient 3G/4G timeouts (up to 2 attempts, 8s timeout each).
/// 3. Falls back to OpenStreetMap standard tiles if Google `mt1.google.com`
///    fails or is throttled on a mobile carrier IP.
class ResilientCachedTileProvider extends TileProvider {
  static final ResilientCachedTileProvider instance =
      ResilientCachedTileProvider._();

  static final http.Client _httpClient = http.Client();
  static Directory? _cacheDir;

  ResilientCachedTileProvider._();

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

  static String _cacheKeyFor(String url, TileCoordinates coords) {
    final digest = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    final shortHash =
        digest.length > 24 ? digest.substring(digest.length - 24) : digest;
    return 'z${coords.z}_x${coords.x}_y${coords.y}_$shortHash.tile';
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final primaryUrl = getTileUrl(coordinates, options);
    final isSatellite = primaryUrl.contains('lyrs=y');
    final fallbackUrl = isSatellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/${coordinates.z}/${coordinates.y}/${coordinates.x}'
        : 'https://tile.openstreetmap.org/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';

    return _ResilientTileImageProvider(
      primaryUrl: primaryUrl,
      fallbackUrl: fallbackUrl,
      coordinates: coordinates,
      headers: headers,
    );
  }

  static Future<Uint8List> _fetchTileBytes({
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
        cacheFile = File('${dir.path}/${_cacheKeyFor(primaryUrl, coordinates)}');
        if (await cacheFile.exists()) {
          final cached = await cacheFile.readAsBytes();
          if (cached.lengthInBytes > 128) {
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
          if (resp.statusCode == 200 && resp.bodyBytes.lengthInBytes > 128) {
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

    throw Exception('Failed to load map tile z=${coordinates.z} x=${coordinates.x} y=${coordinates.y}');
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
