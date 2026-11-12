enum ActivityStatus { ongoing, pasaDeliver, completed, canceled }

class ActivityTrip {
  final String id;
  final String title;
  final DateTime dateTime;
  final ActivityStatus status;
  final String vehicleType;
  final String vehicleSubtitle;
  final String pickupLocation;
  final String dropoffLocation;
  final double tripFare;
  final double discount;
  final double driverTip;
  final String paymentMethod;
  final String transactionId;
  final String bookingId;
  final String driverName;
  final double driverRating;
  final String driverVehicle;
  final bool isDelivery;
  final String? packageDescription;
  final String? recipientName;
  final String? recipientPhone;

  double get totalPaid => (tripFare - discount + driverTip).clamp(0.0, 9999.0);

  const ActivityTrip({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.status,
    required this.vehicleType,
    required this.vehicleSubtitle,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.tripFare,
    this.discount = 0.0,
    this.driverTip = 0.0,
    required this.paymentMethod,
    required this.transactionId,
    required this.bookingId,
    required this.driverName,
    this.driverRating = 4.9,
    required this.driverVehicle,
    this.isDelivery = false,
    this.packageDescription,
    this.recipientName,
    this.recipientPhone,
  });

  ActivityTrip copyWith({
    ActivityStatus? status,
  }) {
    return ActivityTrip(
      id: id,
      title: title,
      dateTime: dateTime,
      status: status ?? this.status,
      vehicleType: vehicleType,
      vehicleSubtitle: vehicleSubtitle,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      tripFare: tripFare,
      discount: discount,
      driverTip: driverTip,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      bookingId: bookingId,
      driverName: driverName,
      driverRating: driverRating,
      driverVehicle: driverVehicle,
      isDelivery: isDelivery,
      packageDescription: packageDescription,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
    );
  }
}

/// In-memory repository seeded with realistic Laoag City trips.
class ActivityRepository {
  static final List<ActivityTrip> _trips = [
    // 1. Ongoing trip
    ActivityTrip(
      id: 'TRIP-ONGOING-001',
      title: 'STI College Laoag',
      dateTime: DateTime.now().subtract(const Duration(minutes: 8)),
      status: ActivityStatus.ongoing,
      vehicleType: 'PasadaNorte Tricycle',
      vehicleSubtitle: '3-5 mins · 1-3 passengers',
      pickupLocation: 'Gen. Segundo Ave cor. Lagasca St',
      dropoffLocation: 'STI College Laoag, 5HVW+JPP, Pila',
      tripFare: 25.00,
      discount: 5.00,
      driverTip: 0.00,
      paymentMethod: 'Cash (Pay Driver Directly)',
      transactionId: 'TRX1221240956',
      bookingId: 'BKG926084',
      driverName: 'Danilo Agcaoili',
      driverRating: 4.9,
      driverVehicle: 'Honda TMX 125, Blue • TODA-042',
    ),

    // 2. PasaDeliver scheduled errand
    ActivityTrip(
      id: 'DELIVER-001',
      title: 'PasaDeliver: Public Market Padala',
      dateTime: DateTime.now().add(const Duration(hours: 2)),
      status: ActivityStatus.pasaDeliver,
      vehicleType: 'PasaDeliver Express',
      vehicleSubtitle: 'Package & Errand Delivery',
      pickupLocation: 'Laoag Public Market (Fruit Section)',
      dropoffLocation: 'Fonacier Street, Brgy. 17 San Francisco',
      tripFare: 40.00,
      discount: 0.00,
      driverTip: 10.00,
      paymentMethod: 'GCash e-Wallet',
      transactionId: 'TRX1222240941',
      bookingId: 'BKG720469',
      driverName: 'Rommel Corpuz',
      driverRating: 5.0,
      driverVehicle: 'Kawasaki Barako II • TODA-118',
      isDelivery: true,
      packageDescription: 'Fresh produce & dry goods parcel',
      recipientName: 'Maria Santos',
      recipientPhone: '+63 917 555 4321',
    ),

    // 3. Completed trip
    ActivityTrip(
      id: 'TRIP-COMPLETED-001',
      title: 'Fonacier Street, Brgy. 17',
      dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      status: ActivityStatus.completed,
      vehicleType: 'PasadaNorte Tricycle',
      vehicleSubtitle: '5-7 mins · 1-3 passengers',
      pickupLocation: 'Lagasca St, Jollibee Bacarra Rd',
      dropoffLocation: 'Fonacier Street, Brgy. 17 San Francisco',
      tripFare: 25.00,
      discount: 5.00,
      driverTip: 0.00,
      paymentMethod: 'Cash (Pay Driver Directly)',
      transactionId: 'TRX1221240956',
      bookingId: 'BKG926084',
      driverName: 'Richard Davis',
      driverRating: 4.9,
      driverVehicle: 'Honda TMX 125, White • XYZ-5678',
    ),

    // 4. Completed trip 2
    ActivityTrip(
      id: 'TRIP-COMPLETED-002',
      title: 'Laoag City General Hospital',
      dateTime: DateTime.now().subtract(const Duration(days: 3, hours: 5)),
      status: ActivityStatus.completed,
      vehicleType: 'PasadaNorte Tricycle',
      vehicleSubtitle: '8-10 mins · 1-3 passengers',
      pickupLocation: 'Aurora Park, Laoag City Hall',
      dropoffLocation: 'Laoag City General Hospital, Brgy. 46',
      tripFare: 30.00,
      discount: 6.00,
      driverTip: 5.00,
      paymentMethod: 'Maya Digital Checkout',
      transactionId: 'TRX1219241420',
      bookingId: 'BKG811204',
      driverName: 'Eduardo Fernandez',
      driverRating: 4.8,
      driverVehicle: 'Yamaha YTX 125, Black • TODA-089',
    ),

    // 5. Canceled trip
    ActivityTrip(
      id: 'TRIP-CANCELED-001',
      title: 'Robinsons Place Ilocos Norte',
      dateTime: DateTime.now().subtract(const Duration(days: 4, hours: 1)),
      status: ActivityStatus.canceled,
      vehicleType: 'PasadaNorte Tricycle',
      vehicleSubtitle: 'Trip Canceled by Passenger',
      pickupLocation: 'Rizal St, Laoag Central School',
      dropoffLocation: 'Robinsons Place Ilocos, San Nicolas',
      tripFare: 35.00,
      discount: 0.00,
      driverTip: 0.00,
      paymentMethod: 'Cash (Pay Driver Directly)',
      transactionId: 'TRX1218241105',
      bookingId: 'BKG604192',
      driverName: 'Marvin Ramos',
      driverRating: 4.7,
      driverVehicle: 'Bajaj RE, Green • TODA-204',
    ),
  ];

  static List<ActivityTrip> get trips => List.unmodifiable(_trips);

  static List<ActivityTrip> getOngoing() =>
      _trips.where((t) => t.status == ActivityStatus.ongoing).toList();

  static List<ActivityTrip> getPasaDeliver() =>
      _trips.where((t) => t.status == ActivityStatus.pasaDeliver).toList();

  static List<ActivityTrip> getCompleted() =>
      _trips.where((t) => t.status == ActivityStatus.completed).toList();

  static List<ActivityTrip> getCanceled() =>
      _trips.where((t) => t.status == ActivityStatus.canceled).toList();

  static void addTrip(ActivityTrip trip) {
    _trips.insert(0, trip);
  }

  static void cancelTrip(String tripId) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: ActivityStatus.canceled);
    }
  }
}
