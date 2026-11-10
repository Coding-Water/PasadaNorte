import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Provides audio cues and haptic alerts for driver dispatch events
class SoundAlertService {
  static final AudioPlayer _player = AudioPlayer();

  /// Plays high-priority audio chime and haptics when a 15-second dispatch offer arrives
  static Future<void> playDispatchOfferChime() async {
    try {
      // Immediate haptics and system alert sound so driver is alerted without looking at screen
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();

      // Play audio chime via audioplayers
      await _player.stop();
      await _player.play(
        AssetSource('sounds/dispatch_chime.mp3'),
      ).catchError((_) async {
        // If local asset is not available on test device, play alert system sound as fallback
        await SystemSound.play(SystemSoundType.alert);
      });
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Stops any currently playing alert audio
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
