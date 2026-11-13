import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'rider_map_booking_screen.dart';

const String kSavedAddressesPrefsKey = 'pasada_saved_addresses_v1';

class SavedAddressesScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;

  const SavedAddressesScreen({
    super.key,
    required this.fullName,
    this.lockedCategory = PassengerCategory.regular,
  });

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(kSavedAddressesPrefsKey) ?? const [];
      final parsed = raw
          .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _addresses = parsed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _persistAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        kSavedAddressesPrefsKey,
        _addresses.map((e) => jsonEncode(e)).toList(),
      );
    } catch (_) {}
  }

  IconData _iconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home_rounded;
    if (l.contains('school') || l.contains('campus') || l.contains('univ')) {
      return Icons.school_rounded;
    }
    if (l.contains('work') || l.contains('office')) {
      return Icons.work_rounded;
    }
    return Icons.location_on_rounded;
  }

  Future<void> _openAddOrEditAddress({Map<String, dynamic>? existing, int? index}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressMapScreen(existingAddress: existing),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (index != null && index >= 0 && index < _addresses.length) {
        _addresses[index] = result;
      } else {
        _addresses.add(result);
      }
    });
    await _persistAddresses();
  }

  void _bookToAddress(Map<String, dynamic> addr) {
    final point = LocationPoint(
      name: addr['address']?.toString() ?? addr['label']?.toString() ?? 'Saved Place',
      latitude: (addr['lat'] as num).toDouble(),
      longitude: (addr['lng'] as num).toDouble(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiderMapBookingScreen(
          fullName: widget.fullName,
          lockedCategory: widget.lockedCategory,
          initialTripType: TripType.standard,
          initialDropoff: point,
        ),
      ),
    );
  }

  Future<void> _deleteAddress(int index) async {
    setState(() => _addresses.removeAt(index));
    await _persistAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Saved Addresses',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentEmerald),
                  )
                : _addresses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8EF),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.add_location_alt_rounded,
                                  color: AppTheme.accentEmerald,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No saved addresses yet',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Save your Home, Work, School, or other frequent stops in Laoag City by pinning them on the map.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _addresses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final addr = _addresses[index];
                          final label = addr['label']?.toString() ?? 'Saved Place';
                          final addressText = addr['address']?.toString() ?? '';
                          final details = addr['details']?.toString() ?? '';

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _bookToAddress(addr),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x070F172A),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _iconForLabel(label),
                                        color: AppTheme.accentEmerald,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primarySlate,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Book ride here',
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.directions_rounded,
                                          color: AppTheme.accentEmerald,
                                          size: 20,
                                        ),
                                        onPressed: () => _bookToAddress(addr),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _openAddOrEditAddress(
                                              existing: addr,
                                              index: index,
                                            );
                                          } else if (action == 'book') {
                                            _bookToAddress(addr);
                                          } else if (action == 'delete') {
                                            _deleteAddress(index);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'book',
                                            child: Text('Set as Drop-off'),
                                          ),
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit Address'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    addressText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (details.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      details,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _openAddOrEditAddress(),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add Address',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddAddressMapScreen extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddAddressMapScreen({super.key, this.existingAddress});

  @override
  State<AddAddressMapScreen> createState() => _AddAddressMapScreenState();
}

class _AddAddressMapScreenState extends State<AddAddressMapScreen> {
  final MapController _mapController = MapController();
  late final TextEditingController _searchCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _detailsCtrl;

  Timer? _debounce;
  bool _isSearching = false;
  bool _isResolvingPin = false;
  List<LocationPoint> _searchResults = const [];

  LatLng _pinnedLatLng = const LatLng(18.1972, 120.5925);
  String _pinnedAddress = 'Laoag City Public Market, Brgy. 11 Sta. Balbina, Laoag';
  String _selectedPreset = 'Home';

  static const List<String> _presets = ['Home', 'Work', 'School', 'Other'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAddress;
    final initialName = existing?['label']?.toString() ?? 'Home';
    _selectedPreset = _presets.contains(initialName) ? initialName : 'Other';
    _nameCtrl = TextEditingController(text: initialName);
    _detailsCtrl = TextEditingController(
      text: existing?['details']?.toString() ?? '',
    );
    _searchCtrl = TextEditingController();

    if (existing != null &&
        existing['lat'] != null &&
        existing['lng'] != null) {
      _pinnedLatLng = LatLng(
        (existing['lat'] as num).toDouble(),
        (existing['lng'] as num).toDouble(),
      );
      _pinnedAddress = existing['address']?.toString() ?? _pinnedAddress;
    } else {
      _centerOnCurrentGps();
    }
  }

  Future<void> _centerOnCurrentGps() async {
    try {
      final gps = await LocationService.warmUpDeviceGpsLocation();
      if (!mounted) return;
      final pt = LatLng(gps.latitude, gps.longitude);
      setState(() {
        _pinnedLatLng = pt;
        _pinnedAddress = gps.name;
      });
      _mapController.move(pt, 16.5);
    } catch (_) {}
  }

  Future<void> _updatePin(LatLng point) async {
    setState(() {
      _pinnedLatLng = point;
      _isResolvingPin = true;
      _searchResults = const [];
    });
    final resolved = await LocationService.reverseGeocodePoint(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _pinnedAddress = resolved;
      _isResolvingPin = false;
    });
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final found = await LocationService.searchPlacesInLaoag(val);
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchResults = found;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _saveAddress() {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim().isEmpty
        ? (_selectedPreset == 'Other' ? 'Saved Place' : _selectedPreset)
        : _nameCtrl.text.trim();
    Navigator.pop(context, <String, dynamic>{
      'label': name,
      'address': _pinnedAddress,
      'details': _detailsCtrl.text.trim(),
      'lat': _pinnedLatLng.latitude,
      'lng': _pinnedLatLng.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortTitle = _pinnedAddress.split(', ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // Top Map Pinning Area
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinnedLatLng,
                    initialZoom: 16.0,
                    onTap: (_, latLng) => _updatePin(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pasadanorte.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinnedLatLng,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFEF4444),
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Top Search Bar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A0F172A),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search for a location',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.primarySlate,
                              ),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _searchResults = const []);
                                          },
                                        )
                                      : null),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A0F172A),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (_, idx) {
                                final place = _searchResults[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                    color: AppTheme.accentEmerald,
                                    size: 20,
                                  ),
                                  title: Text(
                                    place.name.split(', ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    final pt = LatLng(
                                      place.latitude,
                                      place.longitude,
                                    );
                                    setState(() {
                                      _pinnedLatLng = pt;
                                      _pinnedAddress = place.name;
                                      _searchResults = const [];
                                    });
                                    _mapController.move(pt, 16.5);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Back & My Location Floating Buttons
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.primarySlate,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: AppTheme.primarySlate,
                      ),
                      onPressed: _centerOnCurrentGps,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Form Area
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        widget.existingAddress == null
                            ? 'Add an Address'
                            : 'Edit Address',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Pinned Location Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isResolvingPin
                                      ? 'Resolving pinned location...'
                                      : shortTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppTheme.primarySlate,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _pinnedAddress,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _presets.map((preset) {
                        final isSelected = _selectedPreset == preset;
                        return ChoiceChip(
                          label: Text(preset),
                          selected: isSelected,
                          selectedColor: AppTheme.accentEmerald,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primarySlate,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedPreset = preset;
                              if (preset != 'Other') {
                                _nameCtrl.text = preset;
                              } else if (_presets.contains(_nameCtrl.text.trim())) {
                                _nameCtrl.clear();
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Home, Work, School, Mom\'s House',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Address Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _detailsCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Floor, unit number, landmark',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFE8F8EF),
                                foregroundColor: AppTheme.accentEmerald,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saveAddress,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentEmerald,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Save Address',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
