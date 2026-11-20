import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/resilient_tile_provider.dart';

void main() {
  group('ResilientCachedTileProvider Bug Tests', () {
    test('cacheKeyFor never collides between Streets and Satellite at same coordinates', () {
      const coords = TileCoordinates(54721, 29398, 16);
      final streetKey = ResilientCachedTileProvider.cacheKeyFor(
        'https://mt1.google.com/vt/lyrs=m&x=54721&y=29398&z=16',
        coords,
      );
      final satKey = ResilientCachedTileProvider.cacheKeyFor(
        'https://mt1.google.com/vt/lyrs=y&x=54721&y=29398&z=16',
        coords,
      );

      expect(streetKey, isNot(equals(satKey)));
      expect(streetKey, contains('_str_'));
      expect(satKey, contains('_sat_'));
    });

    test('isValidImageBytes rejects HTML error pages and tiny payloads', () {
      final htmlBytes = Uint8List.fromList(
        ('<html><body><h1>502 Bad Gateway</h1>' * 6).codeUnits,
      );
      expect(ResilientCachedTileProvider.isValidImageBytes(htmlBytes), isFalse);

      final tinyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      expect(ResilientCachedTileProvider.isValidImageBytes(tinyPng), isFalse);

      final validPng = Uint8List(256)
        ..[0] = 0x89
        ..[1] = 0x50
        ..[2] = 0x4E
        ..[3] = 0x47;
      expect(ResilientCachedTileProvider.isValidImageBytes(validPng), isTrue);

      final validJpg = Uint8List(256)
        ..[0] = 0xFF
        ..[1] = 0xD8
        ..[2] = 0xFF;
      expect(ResilientCachedTileProvider.isValidImageBytes(validJpg), isTrue);
    });

    test('resolveFallbackUrl maps Streets to OSM and clamps Satellite z19 to z18', () {
      const z19 = TileCoordinates(437768, 235184, 19);
      final osmFallback = ResilientCachedTileProvider.resolveFallbackUrl(
        'https://mt1.google.com/vt/lyrs=m&x=437768&y=235184&z=19',
        z19,
      );
      expect(osmFallback, 'https://tile.openstreetmap.org/19/437768/235184.png');

      final satFallback = ResilientCachedTileProvider.resolveFallbackUrl(
        'https://mt1.google.com/vt/lyrs=y&x=437768&y=235184&z=19',
        z19,
      );
      expect(
        satFallback,
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/18/117592/218884',
      );
    });

    test('provider initializes non-empty User-Agent header for OSM compliance', () {
      expect(
        ResilientCachedTileProvider.instance.headers['User-Agent'],
        contains('ph.laoag.pasadanorte'),
      );
    });
  });
}
