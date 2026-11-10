import '../../fare/services/fare_calculator_service.dart';

enum UserRole {
  rider,
  driver,
  todaAdmin,
  mincAdmin,
  none;

  bool get isDriver => this == UserRole.driver;
  bool get isRider => this == UserRole.rider;
  bool get isTodaAdmin => this == UserRole.todaAdmin;
  bool get isMincAdmin => this == UserRole.mincAdmin;
  bool get isAdmin => this == UserRole.todaAdmin || this == UserRole.mincAdmin;

  static UserRole fromDbString(String? role) {
    switch (role) {
      case 'driver':
        return UserRole.driver;
      case 'rider':
        return UserRole.rider;
      case 'toda_admin':
      case 'todaAdmin':
        return UserRole.todaAdmin;
      case 'minc_admin':
      case 'mincAdmin':
        return UserRole.mincAdmin;
      default:
        return UserRole.none;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.driver:
        return 'driver';
      case UserRole.rider:
        return 'rider';
      case UserRole.todaAdmin:
        return 'toda_admin';
      case UserRole.mincAdmin:
        return 'minc_admin';
      case UserRole.none:
        return 'none';
    }
  }
}

enum VerificationStatus { pending, approved, rejected, reUploadRequested }

class UserModel {
  final String id;
  final String phoneNumber;
  final String fullName;
  final UserRole role;
  final PassengerCategory passengerCategory;
  final String? idCardUrl;
  final String? faceScanUrl;
  final VerificationStatus verificationStatus;
  final double? aiConfidenceScore;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.passengerCategory = PassengerCategory.regular,
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
      'role': role.toDbString(),
      'passenger_category': passengerCategory.name,
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
      role: UserRole.fromDbString(json['role']),
      passengerCategory: PassengerCategory.values.firstWhere(
        (e) => e.name == json['passenger_category'],
        orElse: () => PassengerCategory.regular,
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
