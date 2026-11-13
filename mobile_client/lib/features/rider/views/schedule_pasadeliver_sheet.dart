import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/activity_trip_model.dart';

class SchedulePasaDeliverSheet extends StatefulWidget {
  final VoidCallback onScheduled;

  const SchedulePasaDeliverSheet({super.key, required this.onScheduled});

  static Future<void> show(BuildContext context, {required VoidCallback onScheduled}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchedulePasaDeliverSheet(onScheduled: onScheduled),
    );
  }

  @override
  State<SchedulePasaDeliverSheet> createState() => _SchedulePasaDeliverSheetState();
}

class _SchedulePasaDeliverSheetState extends State<SchedulePasaDeliverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _recipientNameCtrl = TextEditingController(text: 'Maria Santos');
  final _recipientPhoneCtrl = TextEditingController(text: '0917 555 4321');
  final _packageDescCtrl = TextEditingController(text: 'Public Market Groceries & Documents');
  final _pickupCtrl = TextEditingController(text: 'Laoag Public Market');
  final _dropoffCtrl = TextEditingController(text: 'Fonacier Street, Brgy. 17');

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 3));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 30);

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _packageDescCtrl.dispose();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final newTrip = ActivityTrip(
      id: 'DELIVER-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: 'PasaDeliver: ${_recipientNameCtrl.text.trim()}',
      dateTime: scheduledDateTime,
      status: ActivityStatus.pasaDeliver,
      vehicleType: 'PasaDeliver Express',
      vehicleSubtitle: 'Scheduled Package Errand',
      pickupLocation: _pickupCtrl.text.trim(),
      dropoffLocation: _dropoffCtrl.text.trim(),
      tripFare: 45.00,
      discount: 0.00,
      driverTip: 10.00,
      paymentMethod: 'Cash upon Delivery',
      transactionId: 'TRX${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
      bookingId: 'BKG${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      driverName: 'Assigned upon Dispatch',
      driverRating: 5.0,
      driverVehicle: 'Verified TODA Tricycle Driver',
      isDelivery: true,
      packageDescription: _packageDescCtrl.text.trim(),
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
    );

    ActivityRepository.addTrip(newTrip);
    Navigator.pop(context);
    widget.onScheduled();

      }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule PasaDeliver',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          Text(
                            'On-demand parcel & errand booking across Laoag',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Pickup Location
                TextFormField(
                  controller: _pickupCtrl,
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    prefixIcon: const Icon(Icons.storefront_rounded, color: AppTheme.accentEmerald, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Dropoff Location
                TextFormField(
                  controller: _dropoffCtrl,
                  decoration: InputDecoration(
                    labelText: 'Delivery Destination',
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Package Description
                TextFormField(
                  controller: _packageDescCtrl,
                  decoration: InputDecoration(
                    labelText: 'Parcel / Errand Description',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppTheme.primarySlate, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Recipient Details Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _recipientNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Recipient Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _recipientPhoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Mobile No.',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date & Time Selectors
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded, size: 18),
                        label: Text(_selectedTime.format(context)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm & Schedule PasaDeliver',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
