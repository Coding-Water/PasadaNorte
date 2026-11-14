import 'package:flutter/foundation.dart';
import 'system_notification_service.dart';

enum DocumentExpirySeverity {
  valid,
  expiringSoon,
  expired,
}

class ExpiredDocumentItem {
  final String docKey;
  final String label;
  final DateTime expiryDate;
  final DocumentExpirySeverity severity;
  final int daysDelta; // negative = days overdue, positive = days remaining

  const ExpiredDocumentItem({
    required this.docKey,
    required this.label,
    required this.expiryDate,
    required this.severity,
    required this.daysDelta,
  });

  bool get isExpired => severity == DocumentExpirySeverity.expired;
  bool get isExpiringSoon => severity == DocumentExpirySeverity.expiringSoon;
}

class MockSmsDispatchEntry {
  final String phoneNumber;
  final String driverName;
  final String message;
  final DateTime? graceUntil;
  final DateTime dispatchedAt;

  const MockSmsDispatchEntry({
    required this.phoneNumber,
    required this.driverName,
    required this.message,
    required this.graceUntil,
    required this.dispatchedAt,
  });
}

/// Evaluates driver document expiry dates, extracts expiry dates from OCR text,
/// and dispatches renewal grace-period notifications + mock/live SMS alerts.
class DocumentExpiryService {
  static final List<MockSmsDispatchEntry> mockSmsOutbox = [];

  static const Map<String, int> _monthMap = {
    'JAN': 1,
    'JANUARY': 1,
    'FEB': 2,
    'FEBRUARY': 2,
    'MAR': 3,
    'MARCH': 3,
    'APR': 4,
    'APRIL': 4,
    'MAY': 5,
    'JUN': 6,
    'JUNE': 6,
    'JUL': 7,
    'JULY': 7,
    'AUG': 8,
    'AUGUST': 8,
    'SEP': 9,
    'SEPT': 9,
    'SEPTEMBER': 9,
    'OCT': 10,
    'OCTOBER': 10,
    'NOV': 11,
    'NOVEMBER': 11,
    'DEC': 12,
    'DECEMBER': 12,
  };

  /// Parses an expiry date from raw OCR text (e.g. from LTO License, OR/CR, MTOP, NBI).
  /// Prioritizes dates appearing near expiry keywords such as EXP, EXPIRY, VALID UNTIL.
  static DateTime? extractExpiryDateFromText(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final lines = rawText.split(RegExp(r'\r?\n'));
    final expiryKeywordRegex = RegExp(
      r'(EXP|EXPIR|VALID\s*(UNTIL|THRU|TO)|DUE\s*DATE|RENEW)',
      caseSensitive: false,
    );

    // 1. Prefer lines with explicit expiry keywords
    for (final line in lines) {
      if (expiryKeywordRegex.hasMatch(line)) {
        final parsed = _parseDateInString(line);
        if (parsed != null) return parsed;
      }
    }

    // 2. Fallback: collect all valid dates and return the latest plausible one
    final candidates = <DateTime>[];
    for (final line in lines) {
      final parsed = _parseDateInString(line);
      if (parsed != null && parsed.year >= 2020 && parsed.year <= 2040) {
        candidates.add(parsed);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  static DateTime? _parseDateInString(String input) {
    // YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(input);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!);
      final m = int.tryParse(isoMatch.group(2)!);
      final d = int.tryParse(isoMatch.group(3)!);
      if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    // MM/DD/YYYY or DD/MM/YYYY (slash or dash)
    final slashMatch = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](20\d{2})\b').firstMatch(input);
    if (slashMatch != null) {
      final p1 = int.tryParse(slashMatch.group(1)!);
      final p2 = int.tryParse(slashMatch.group(2)!);
      final y = int.tryParse(slashMatch.group(3)!);
      if (p1 != null && p2 != null && y != null) {
        // If first part > 12, it's DD/MM/YYYY; otherwise treat as MM/DD/YYYY (PH LTO format)
        final m = p1 > 12 ? p2 : p1;
        final d = p1 > 12 ? p1 : p2;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }

    // DD MMM YYYY (e.g., 15 NOV 2026)
    final dmyText = RegExp(
      r'\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(20\d{2})\b',
    ).firstMatch(input);
    if (dmyText != null) {
      final d = int.tryParse(dmyText.group(1)!);
      final m = _monthMap[dmyText.group(2)!.toUpperCase()];
      final y = int.tryParse(dmyText.group(3)!);
      if (d != null && m != null && y != null && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    // MMM DD, YYYY (e.g., NOV 15, 2026)
    final mdyText = RegExp(
      r'\b([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(20\d{2})\b',
    ).firstMatch(input);
    if (mdyText != null) {
      final m = _monthMap[mdyText.group(1)!.toUpperCase()];
      final d = int.tryParse(mdyText.group(2)!);
      final y = int.tryParse(mdyText.group(3)!);
      if (d != null && m != null && y != null && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    return null;
  }

  /// Evaluates a driver's document expiry dates against [referenceDate].
  static List<ExpiredDocumentItem> evaluateDriverDocuments({
    DateTime? licenseExpiryDate,
    DateTime? orcrExpiryDate,
    DateTime? mtopExpiryDate,
    DateTime? nbiExpiryDate,
    DateTime? referenceDate,
    int expiringSoonThresholdDays = 30,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <ExpiredDocumentItem>[];

    void checkDoc(String key, String label, DateTime? date) {
      if (date == null) return;
      final d = DateTime(date.year, date.month, date.day);
      final delta = d.difference(today).inDays;
      final DocumentExpirySeverity severity;
      if (delta < 0) {
        severity = DocumentExpirySeverity.expired;
      } else if (delta <= expiringSoonThresholdDays) {
        severity = DocumentExpirySeverity.expiringSoon;
      } else {
        severity = DocumentExpirySeverity.valid;
      }
      if (severity != DocumentExpirySeverity.valid) {
        items.add(
          ExpiredDocumentItem(
            docKey: key,
            label: label,
            expiryDate: d,
            severity: severity,
            daysDelta: delta,
          ),
        );
      }
    }

    checkDoc('license_expiry_date', "Professional Driver's License", licenseExpiryDate);
    checkDoc('orcr_expiry_date', 'LTO OR/CR', orcrExpiryDate);
    checkDoc('mtop_expiry_date', 'MTOP / Tricycle Franchise', mtopExpiryDate);
    checkDoc('nbi_expiry_date', 'NBI Clearance', nbiExpiryDate);

    // Most urgent / expired first
    items.sort((a, b) => a.daysDelta.compareTo(b.daysDelta));
    return items;
  }

  static int? graceDaysRemaining(DateTime? renewalGraceUntil, {DateTime? referenceDate}) {
    if (renewalGraceUntil == null) return null;
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final graceDay = DateTime(
      renewalGraceUntil.year,
      renewalGraceUntil.month,
      renewalGraceUntil.day,
    );
    return graceDay.difference(today).inDays;
  }

  /// Sends an in-app Android Notification Center alert and queues/logs an SMS
  /// renewal notice with the granted [graceDays] grace period.
  static Future<MockSmsDispatchEntry> sendRenewalNoticeAndGracePeriod({
    required String driverName,
    required String phoneNumber,
    required List<ExpiredDocumentItem> flaggedDocs,
    int graceDays = 14,
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final graceUntil = now.add(Duration(days: graceDays));
    final graceLabel = graceUntil.toIso8601String().split('T').first;
    final docNames = flaggedDocs.isEmpty
        ? 'driver compliance documents'
        : flaggedDocs.map((d) => d.label).join(', ');

    final smsBody =
        'PasadaNorte MINC Notice: Hi $driverName, your $docNames require renewal. '
        'You have a $graceDays-day grace period until $graceLabel to upload updated documents in the PasadaNorte app.';

    final entry = MockSmsDispatchEntry(
      phoneNumber: phoneNumber,
      driverName: driverName,
      message: smsBody,
      graceUntil: graceUntil,
      dispatchedAt: now,
    );
    mockSmsOutbox.add(entry);

    debugPrint('[MockSMS -> $phoneNumber] $smsBody');

    await SystemNotificationService.notifyDriverDocumentRenewalGrace(
      driverName: driverName,
      documentsSummary: docNames,
      graceDays: graceDays,
      graceDeadlineLabel: graceLabel,
    );

    return entry;
  }
}
