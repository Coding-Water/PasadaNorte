enum UserRole { rider, driver, none }

enum VerificationStatus { pending, approved, rejected, reUploadRequested }

class UserModel {
  final String id;
  final String phoneNumber;
  final String fullName;
  final UserRole role;
  final String? idCardUrl;
  final String? faceScanUrl;
  final VerificationStatus verificationStatus;
  final double? aiConfidenceScore;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.idCardUrl,
    this.faceScanUrl,
    this.verificationStatus = VerificationStatus.pending,
    this.aiConfidenceScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'role': role.name,
      'id_card_url': idCardUrl,
      'face_scan_url': faceScanUrl,
      'verification_status': verificationStatus.name,
      'ai_confidence_score': aiConfidenceScore,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      fullName: json['full_name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.none,
      ),
      idCardUrl: json['id_card_url'],
      faceScanUrl: json['face_scan_url'],
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verification_status'],
        orElse: () => VerificationStatus.pending,
      ),
      aiConfidenceScore: (json['ai_confidence_score'] as num?)?.toDouble(),
    );
  }
}
