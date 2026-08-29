enum PassengerCategory { regular, student, senior, pwd }

enum TripType { standard, specialPakyaw, pabiliPadala }

class FareBreakdown {
  final double distanceKm;
  final double baseFare;
  final double distanceFare;
  final double subtotal;
  final double discountAmount;
  final double tripTypeMultiplier;
  final double finalFare;
  final PassengerCategory category;
  final TripType tripType;

  FareBreakdown({
    required this.distanceKm,
    required this.baseFare,
    required this.distanceFare,
    required this.subtotal,
    required this.discountAmount,
    required this.tripTypeMultiplier,
    required this.finalFare,
    required this.category,
    required this.tripType,
  });
}

class FareCalculatorService {
  static const double baseFareRate = 20.00;
  static const double baseDistanceKm = 1.00;
  static const double rateKm2To4 = 3.00;
  static const double rateKm5Above = 5.00;
  static const double statutoryDiscountRate = 0.20;

  static FareBreakdown calculateFare({
    required double distanceKm,
    PassengerCategory category = PassengerCategory.regular,
    TripType tripType = TripType.standard,
  }) {
    double distanceFare = 0.0;

    if (distanceKm > baseDistanceKm) {
      double remainingDist = distanceKm - baseDistanceKm;

      if (remainingDist <= 3.0) {
        distanceFare = remainingDist * rateKm2To4;
      } else {
        distanceFare = (3.0 * rateKm2To4) + ((remainingDist - 3.0) * rateKm5Above);
      }
    }

    double subtotal = baseFareRate + distanceFare;

    double multiplier = 1.0;
    if (tripType == TripType.specialPakyaw) {
      multiplier = 1.5;
    } else if (tripType == TripType.pabiliPadala) {
      multiplier = 1.25;
    }

    double grossFare = subtotal * multiplier;

    double discountAmount = 0.0;
    if (category != PassengerCategory.regular) {
      discountAmount = grossFare * statutoryDiscountRate;
    }

    double finalFare = grossFare - discountAmount;

    return FareBreakdown(
      distanceKm: distanceKm,
      baseFare: baseFareRate,
      distanceFare: double.parse(distanceFare.toStringAsFixed(2)),
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      discountAmount: double.parse(discountAmount.toStringAsFixed(2)),
      tripTypeMultiplier: multiplier,
      finalFare: double.parse(finalFare.toStringAsFixed(2)),
      category: category,
      tripType: tripType,
    );
  }
}
