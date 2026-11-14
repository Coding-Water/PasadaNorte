import '../../../core/services/supabase_service.dart';

enum PassengerCategory { regular, student, senior, pwd }

enum TripType { standard, specialPakyaw, pabiliPadala }

class FareConfig {
  double regularFirstKmFare;
  double discountedFirstKmFare;
  double succeedingKmRate;
  double baseDistanceKm;
  double succeedingDiscountRate;
  bool useProvisionalBracketAddOns; // Oct 2026 SP Provisional ₱3.00 / ₱5.00 succeeding brackets
  double bracketTier1AddOn; // ₱3.00 for first succeeding bracket (e.g., >1.5 km to 3.0 km)
  double bracketTier2AddOn; // ₱5.00 for extended succeeding bracket (>3.0 km)
  double ltfrbPlatformShareRatio; // LTFRB MC No. 2025-10 50%-50% platform-operator discount sharing
  double intraCityThresholdKm; // <= 8 km: Laoag City & San Nicolas Metro ordinance rate
  double interMunicipalityKmRate; // > 8 km: Ilocos Norte inter-municipality highway / pakyaw rate
  String ordinanceLabel;

  FareConfig({
    this.regularFirstKmFare = 20.00,
    this.discountedFirstKmFare = 15.00,
    this.succeedingKmRate = 2.00,
    this.baseDistanceKm = 1.00,
    this.succeedingDiscountRate = 0.20,
    this.useProvisionalBracketAddOns = false,
    this.bracketTier1AddOn = 3.00,
    this.bracketTier2AddOn = 5.00,
    this.ltfrbPlatformShareRatio = 0.50,
    this.intraCityThresholdKm = 8.00,
    this.interMunicipalityKmRate = 15.00,
    this.ordinanceLabel =
        'City Ordinance No. 2023-005 (₱20 Reg / ₱15 Disc 1st km + ₱2/km; ₱15/km > 8 km Inter-Municipality)',
  });

  Map<String, dynamic> toJson() => {
        'regular_first_km_fare': regularFirstKmFare,
        'discounted_first_km_fare': discountedFirstKmFare,
        'succeeding_km_rate': succeedingKmRate,
        'base_distance_km': baseDistanceKm,
        'succeeding_discount_rate': succeedingDiscountRate,
        'use_provisional_brackets': useProvisionalBracketAddOns,
        'bracket_tier1_addon': bracketTier1AddOn,
        'bracket_tier2_addon': bracketTier2AddOn,
        'ltfrb_platform_share_ratio': ltfrbPlatformShareRatio,
        'intra_city_threshold_km': intraCityThresholdKm,
        'inter_municipality_km_rate': interMunicipalityKmRate,
        'ordinance_label': ordinanceLabel,
      };

  factory FareConfig.fromJson(Map<String, dynamic> json) => FareConfig(
        regularFirstKmFare: (json['regular_first_km_fare'] as num?)?.toDouble() ?? 20.00,
        discountedFirstKmFare: (json['discounted_first_km_fare'] as num?)?.toDouble() ?? 15.00,
        succeedingKmRate: (json['succeeding_km_rate'] as num?)?.toDouble() ?? 2.00,
        baseDistanceKm: (json['base_distance_km'] as num?)?.toDouble() ?? 1.00,
        succeedingDiscountRate: (json['succeeding_discount_rate'] as num?)?.toDouble() ?? 0.20,
        useProvisionalBracketAddOns: (json['use_provisional_brackets'] as bool?) ?? false,
        bracketTier1AddOn: (json['bracket_tier1_addon'] as num?)?.toDouble() ?? 3.00,
        bracketTier2AddOn: (json['bracket_tier2_addon'] as num?)?.toDouble() ?? 5.00,
        ltfrbPlatformShareRatio: (json['ltfrb_platform_share_ratio'] as num?)?.toDouble() ?? 0.50,
        intraCityThresholdKm: (json['intra_city_threshold_km'] as num?)?.toDouble() ?? 8.00,
        interMunicipalityKmRate: (json['inter_municipality_km_rate'] as num?)?.toDouble() ?? 15.00,
        ordinanceLabel: json['ordinance_label'] ??
            'City Ordinance No. 2023-005 (₱20 Reg / ₱15 Disc 1st km + ₱2/km)',
      );
}

class FareBreakdown {
  final double distanceKm;
  final double baseDistanceKm;
  final double baseFare;
  final double distanceFare;
  final double subtotal;
  final double discountAmount;
  final double platformDiscountShare; // 50% TNC share under LTFRB MC No. 2025-10
  final double operatorDiscountShare; // 50% Operator share under LTFRB MC No. 2025-10
  final double tripTypeMultiplier;
  final double finalFare;
  final PassengerCategory category;
  final TripType tripType;
  final bool usedBracketAddOns;
  final bool isInterMunicipality;

  FareBreakdown({
    required this.distanceKm,
    required this.baseDistanceKm,
    required this.baseFare,
    required this.distanceFare,
    required this.subtotal,
    required this.discountAmount,
    required this.platformDiscountShare,
    required this.operatorDiscountShare,
    required this.tripTypeMultiplier,
    required this.finalFare,
    required this.category,
    required this.tripType,
    this.usedBracketAddOns = false,
    this.isInterMunicipality = false,
  });
}

class FareCalculatorService {
  // Configurable ordinance fare-matrix engine supporting:
  // 1. Pre-adjustment baseline (City Ordinance No. 2023-005: ₱20 Reg / ₱15 Disc 1st 1.0 km + ₱2/km)
  // 2. Oct 2026 SP Provisional fuel-hike matrix (Ilocos Times, 2026: ₱25 Reg / ₱20 Disc 1st 1.5 km + ₱3/₱5 brackets)
  // 3. Configurable 50%-50% platform-operator discount cost-sharing (LTFRB MC No. 2025-10)
  static FareConfig activeConfig = FareConfig();

  static void updateFareConfig({
    required double regularFirstKmFare,
    required double discountedFirstKmFare,
    required double succeedingKmRate,
    double? baseDistanceKm,
    bool? useProvisionalBracketAddOns,
    double? ltfrbPlatformShareRatio,
    String? ordinanceLabel,
    bool syncToCloud = true,
  }) {
    activeConfig.regularFirstKmFare = regularFirstKmFare;
    activeConfig.discountedFirstKmFare = discountedFirstKmFare;
    activeConfig.succeedingKmRate = succeedingKmRate;
    if (baseDistanceKm != null && baseDistanceKm > 0) {
      activeConfig.baseDistanceKm = baseDistanceKm;
    }
    if (useProvisionalBracketAddOns != null) {
      activeConfig.useProvisionalBracketAddOns = useProvisionalBracketAddOns;
    }
    if (ltfrbPlatformShareRatio != null) {
      activeConfig.ltfrbPlatformShareRatio = ltfrbPlatformShareRatio.clamp(0.0, 1.0);
    }
    if (ordinanceLabel != null && ordinanceLabel.trim().isNotEmpty) {
      activeConfig.ordinanceLabel = ordinanceLabel.trim();
    }
    if (syncToCloud) {
      SupabaseService.upsertFareConfig(activeConfig);
    }
  }

  static FareBreakdown calculateFare({
    required double distanceKm,
    PassengerCategory category = PassengerCategory.regular,
    TripType tripType = TripType.standard,
  }) {
    final config = activeConfig;
    final bool isDiscounted = category != PassengerCategory.regular;

    // Flat ₱5.00 municipal tariff reduction on the base distance tier
    final double effectiveFirstKm =
        isDiscounted ? config.discountedFirstKmFare : config.regularFirstKmFare;
    final double firstKmSavings = config.regularFirstKmFare - effectiveFirstKm;

    double succeedingRaw = 0.0;
    double succeedingDiscount = 0.0;
    final bool isInterMunicipality = distanceKm > config.intraCityThresholdKm;

    if (distanceKm > config.baseDistanceKm) {
      final double intraCapKm =
          distanceKm.clamp(config.baseDistanceKm, config.intraCityThresholdKm);
      final double intraRemainingDist = intraCapKm - config.baseDistanceKm;
      final double extraInterTownDist = isInterMunicipality
          ? (distanceKm - config.intraCityThresholdKm)
          : 0.0;

      if (config.useProvisionalBracketAddOns) {
        // Oct 2026 SP Provisional Matrix: incremental distance add-ons of ₱3.00 and ₱5.00
        // for succeeding kilometer brackets (Ilocos Times, 2026)
        if (intraRemainingDist > 0) {
          if (intraRemainingDist <= 1.5) {
            succeedingRaw = config.bracketTier1AddOn;
          } else {
            final double extraBeyondBracket1 = intraRemainingDist - 1.5;
            succeedingRaw = config.bracketTier1AddOn +
                (extraBeyondBracket1 <= 1.5
                    ? config.bracketTier2AddOn
                    : config.bracketTier2AddOn + ((extraBeyondBracket1 - 1.5) * config.succeedingKmRate));
          }
        }
      } else {
        succeedingRaw = intraRemainingDist * config.succeedingKmRate;
      }

      if (extraInterTownDist > 0) {
        succeedingRaw += extraInterTownDist * config.interMunicipalityKmRate;
      }

      if (isDiscounted) {
        // 20% statutory discount on succeeding kilometers (LTFRB MC No. 2025-10)
        succeedingDiscount = succeedingRaw * config.succeedingDiscountRate;
      }
    }

    final double regularSubtotal = config.regularFirstKmFare + succeedingRaw;
    final double totalDiscount = firstKmSavings + succeedingDiscount;
    final double discountedSubtotal = regularSubtotal - totalDiscount;

    // Optional trip type multiplier (Standard = 1.0x)
    double multiplier = 1.0;
    if (tripType == TripType.specialPakyaw) {
      multiplier = 1.5;
    } else if (tripType == TripType.pabiliPadala) {
      multiplier = 1.25;
    }

    final double finalFare = discountedSubtotal * multiplier;
    final double scaledDiscount = double.parse((totalDiscount * multiplier).toStringAsFixed(2));
    final double platformShare =
        double.parse((scaledDiscount * config.ltfrbPlatformShareRatio).toStringAsFixed(2));
    final double operatorShare =
        double.parse((scaledDiscount - platformShare).toStringAsFixed(2));

    return FareBreakdown(
      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      baseDistanceKm: config.baseDistanceKm,
      baseFare: config.regularFirstKmFare,
      distanceFare: double.parse(succeedingRaw.toStringAsFixed(2)),
      subtotal: double.parse(regularSubtotal.toStringAsFixed(2)),
      discountAmount: scaledDiscount,
      platformDiscountShare: platformShare,
      operatorDiscountShare: operatorShare,
      tripTypeMultiplier: multiplier,
      finalFare: double.parse(finalFare.toStringAsFixed(2)),
      category: category,
      tripType: tripType,
      usedBracketAddOns: config.useProvisionalBracketAddOns,
      isInterMunicipality: isInterMunicipality,
    );
  }
}
