import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/document_expiry_service.dart';

void main() {
  setUp(() {
    DocumentExpiryService.mockSmsOutbox.clear();
  });

  group('DocumentExpiryService OCR, Expiry Evaluation & Mock SMS Grace Test', () {
    test('extractExpiryDateFromText parses LTO, OR/CR, and MTOP date formats', () {
      const ltoSample = '''
        REPUBLIC OF THE PHILIPPINES
        DEPARTMENT OF TRANSPORTATION - LTO
        ISSUE DATE: 2022-05-10
        EXPIRATION DATE: 2025-05-10
      ''';
      final ltoExpiry = DocumentExpiryService.extractExpiryDateFromText(ltoSample);
      expect(ltoExpiry, DateTime(2025, 5, 10));

      const orcrSample = '''
        OFFICIAL RECEIPT
        DATE PAID: 03/15/2025
        VALID UNTIL: 15 NOV 2026
      ''';
      final orcrExpiry = DocumentExpiryService.extractExpiryDateFromText(orcrSample);
      expect(orcrExpiry, DateTime(2026, 11, 15));

      const slashSample = 'EXPIRY: 11/01/2026';
      expect(
        DocumentExpiryService.extractExpiryDateFromText(slashSample),
        DateTime(2026, 11, 1),
      );
    });

    test('evaluateDriverDocuments flags expired & expiring docs sorted most urgent first', () {
      final ref = DateTime(2026, 11, 14);
      final issues = DocumentExpiryService.evaluateDriverDocuments(
        licenseExpiryDate: DateTime(2026, 11, 2), // expired 12 days ago
        orcrExpiryDate: DateTime(2026, 11, 9), // expired 5 days ago
        mtopExpiryDate: DateTime(2026, 11, 24), // expiring in 10 days
        nbiExpiryDate: DateTime(2027, 3, 1), // valid (> 30 days)
        referenceDate: ref,
      );

      expect(issues.length, 3);
      expect(issues[0].docKey, 'license_expiry_date');
      expect(issues[0].isExpired, isTrue);
      expect(issues[0].daysDelta, -12);

      expect(issues[1].docKey, 'orcr_expiry_date');
      expect(issues[1].isExpired, isTrue);
      expect(issues[1].daysDelta, -5);

      expect(issues[2].docKey, 'mtop_expiry_date');
      expect(issues[2].isExpiringSoon, isTrue);
      expect(issues[2].daysDelta, 10);
    });

    test('sendRenewalNoticeAndGracePeriod dispatches mock SMS & computes grace deadline', () async {
      final ref = DateTime(2026, 11, 14);
      final issues = DocumentExpiryService.evaluateDriverDocuments(
        licenseExpiryDate: DateTime(2026, 11, 2),
        orcrExpiryDate: DateTime(2026, 11, 9),
        referenceDate: ref,
      );

      final dispatch = await DocumentExpiryService.sendRenewalNoticeAndGracePeriod(
        driverName: 'Jose Dela Cruz',
        phoneNumber: '+639175550142',
        flaggedDocs: issues,
        graceDays: 14,
        referenceDate: ref,
      );

      expect(DocumentExpiryService.mockSmsOutbox.length, 1);
      expect(dispatch.phoneNumber, '+639175550142');
      expect(dispatch.message, contains("Professional Driver's License"));
      expect(dispatch.message, contains('LTO OR/CR'));
      expect(dispatch.message, contains('14-day grace period until 2026-11-28'));
      expect(
        DocumentExpiryService.graceDaysRemaining(dispatch.graceUntil, referenceDate: ref),
        14,
      );
    });
  });
}
