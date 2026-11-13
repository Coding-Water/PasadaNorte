import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedSession {
  final String phoneNumber;
  final String fullName;
  final String role; // 'driver' or 'rider'
  final bool isPendingReview;
  final String? idType;

  const CachedSession({
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.isPendingReview = false,
    this.idType,
  });
}

/// Persists the active user/driver session locally so returning users
/// do not need to log in again every time they reopen the app.
class SessionCacheService {
  static const String _kPhone = 'pn_session_phone';
  static const String _kFullName = 'pn_session_full_name';
  static const String _kRole = 'pn_session_role';
  static const String _kPendingReview = 'pn_session_driver_pending_review';
  static const String _kIdType = 'pn_session_id_type';

  static Future<void> saveDriverSession({
    required String phoneNumber,
    required String fullName,
    required bool isPendingReview,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPhone, phoneNumber);
      await prefs.setString(_kFullName, fullName);
      await prefs.setString(_kRole, 'driver');
      await prefs.setBool(_kPendingReview, isPendingReview);
      await prefs.remove(_kIdType);
    } catch (e) {
      debugPrint('SessionCacheService.saveDriverSession error: $e');
    }
  }

  static Future<void> saveRiderSession({
    required String phoneNumber,
    required String fullName,
    String? idType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPhone, phoneNumber);
      await prefs.setString(_kFullName, fullName);
      await prefs.setString(_kRole, 'rider');
      await prefs.setBool(_kPendingReview, false);
      if (idType != null && idType.isNotEmpty) {
        await prefs.setString(_kIdType, idType);
      } else {
        await prefs.remove(_kIdType);
      }
    } catch (e) {
      debugPrint('SessionCacheService.saveRiderSession error: $e');
    }
  }

  static Future<CachedSession?> getSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_kPhone);
      final role = prefs.getString(_kRole);
      if (phone == null || phone.isEmpty || role == null || role.isEmpty) {
        return null;
      }
      final fullName = prefs.getString(_kFullName) ?? 'Laoag User';
      final isPendingReview = prefs.getBool(_kPendingReview) ?? false;
      final idType = prefs.getString(_kIdType);
      return CachedSession(
        phoneNumber: phone,
        fullName: fullName,
        role: role,
        isPendingReview: isPendingReview,
        idType: idType,
      );
    } catch (e) {
      debugPrint('SessionCacheService.getSavedSession error: $e');
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPhone);
      await prefs.remove(_kFullName);
      await prefs.remove(_kRole);
      await prefs.remove(_kPendingReview);
      await prefs.remove(_kIdType);
    } catch (e) {
      debugPrint('SessionCacheService.clearSession error: $e');
    }
  }
}
