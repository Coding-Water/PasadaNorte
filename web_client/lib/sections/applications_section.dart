part of '../main.dart';

extension _ApplicationsSection on _WebAdminDashboardState {

  // ===========================================================================
  // 9B. DRIVER APPLICATIONS & VEHICLE COMPLIANCE VIEW (LAOAG MINC CODE)
  // ===========================================================================
  Widget _buildDriverApplicationsView() {
    final filtered = _driverApplications.where((app) {
      final query = _driverAppSearchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (app['full_name']?.toString().toLowerCase().contains(query) ?? false) ||
          (app['phone_number']?.toString().toLowerCase().contains(query) ?? false) ||
          (app['plate_or_mv_file']?.toString().toLowerCase().contains(query) ?? false) ||
          (app['motorcycle_brand_model']?.toString().toLowerCase().contains(query) ?? false);

      if (_driverAppFilter == 'All') {
        return matchesSearch && app['application_status'] != 'rejected';
      }
      return matchesSearch && (app['application_status'] == _driverAppFilter);
    }).toList();

    final totalCount =
        _driverApplications.where((a) => a['application_status'] != 'rejected').length;
    final pendingCount = _driverApplications.where((a) => a['application_status'] == 'submitted' || a['application_status'] == 'under_review').length;
    final approvedCount = _driverApplications.where((a) => a['application_status'] == 'approved').length;
    final rejectedCount = _driverApplications.where((a) => a['application_status'] == 'rejected').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Header
        const Text(
          'Laoag City Driver Applications & Vehicle Compliance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'MINC Paratransit review queue: Personal clearances, 110cc–200cc engine specs, model year 2016+, OR/CR, and 4-angle tricycle photos.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Statistics Summary Bar
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Applications',
                value: '$totalCount',
                icon: Icons.assignment_outlined,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Review',
                value: '$pendingCount',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Approved Drivers',
                value: '$approvedCount',
                icon: Icons.check_circle_outline_rounded,
                color: WebTheme.brandEmerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _refresh(() {
                  _driverAppFilter =
                      _driverAppFilter == 'rejected' ? 'All' : 'rejected';
                }),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: _driverAppFilter == 'rejected'
                        ? Border.all(color: const Color(0xFFDC2626), width: 1.8)
                        : null,
                  ),
                  child: _buildMetricTile(
                    title: 'Rejected (Trash)',
                    value: '$rejectedCount',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_driverAppFilter == 'rejected') ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rejected Trash - Rejected applications are stored here for future reference. You can permanently delete them or leave them here.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => _refresh(() => _driverAppFilter = 'All'),
                  child: const Text('Back to Active Queue'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Search & Filter Toolbar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search applicant by name, phone, plate #, or motorcycle model...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => _refresh(() => _driverAppSearchQuery = val),
                ),
              ),
              const SizedBox(width: 14),
              Wrap(
                spacing: 8,
                children: [
                  _buildAppFilterChip('All', 'All ($totalCount)'),
                  _buildAppFilterChip('submitted', 'Pending ($pendingCount)'),
                  _buildAppFilterChip('approved', 'Approved ($approvedCount)'),
                  _buildAppFilterChip('resubmission_requested', 'Resubmit'),
                  _buildAppFilterChip('rejected', 'Rejected ($rejectedCount)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Application Cards List
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No driver applications found matching your criteria.',
                style: TextStyle(color: Colors.grey, fontSize: 13.5),
              ),
            ),
          )
        else
          ...filtered.map((app) => _buildDriverApplicationCard(app)),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppFilterChip(String filterVal, String label) {
    final isSelected = _driverAppFilter == filterVal;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      selected: isSelected,
      selectedColor: const Color(0xFFDCFCE7),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF15803D) : const Color(0xFF0F172A)),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF16A34A) : Colors.grey.shade300),
      onSelected: (_) => _refresh(() => _driverAppFilter = filterVal),
    );
  }

  Widget _buildDriverApplicationCard(Map<String, dynamic> app) {
    final status = app['application_status']?.toString() ?? 'submitted';
    final isApproved = status == 'approved';
    final isResubmit = status == 'resubmission_requested';
    final isRejected = status == 'rejected';
    final age = app['age'] as int? ?? 30;
    final isFitToWorkMandatory = age >= 50 && age <= 55;
    final hasFitToWork = app['fit_to_work_cert_url'] != null;
    final displacement = app['engine_displacement_cc'] as int? ?? 125;
    final isDisplacementValid = displacement >= 110 && displacement <= 200;
    final modelYear = app['model_year'] as int? ?? 2020;
    final isModelYearValid = modelYear >= 2016;
    final isOwned = app['is_motorcycle_owned'] as bool? ?? true;
    final maskedPhone = _maskPhoneNumber(app['phone_number']?.toString() ?? '');
    final appKey = _getAppKey(app);
    final faceMatch = _flaggedVerifications.cast<Map<String, dynamic>?>().firstWhere(
      (u) => u?['phone_number'] == app['phone_number'],
      orElse: () => null,
    );
    final double? faceSimilarity = (faceMatch?['similarity'] as num?)?.toDouble();
    final String faceVerifyStatus = (faceMatch?['status'] ?? 'pending').toString();
    final String faceDetail = faceSimilarity == null
        ? 'Liveness & 1:1 Face Match ($faceVerifyStatus)'
        : (faceSimilarity <= 0
            ? 'Match 0.0% (No Face Detected) • $faceVerifyStatus'
            : 'Match ${faceSimilarity.toStringAsFixed(1)}% • $faceVerifyStatus');
    if (!(_docReviewStatus[appKey]?.containsKey('face_bio_scan') ?? false) &&
        faceSimilarity != null &&
        faceSimilarity >= 85.0) {
      (_docReviewStatus[appKey] ??= {})['face_bio_scan'] = 'pass';
    }

    final requiredDocItems = _getRequiredDocSpecs(
      isFitToWorkMandatory: isFitToWorkMandatory,
      isOwned: isOwned,
    );
    final int totalRequiredDocs = requiredDocItems.length;
    final int passedDocsCount = requiredDocItems.where((item) {
      final col = item.$1;
      final hasFile = col == 'face_bio_scan'
          ? true
          : (app[col]?.toString().trim() ?? '').isNotEmpty;
      return hasFile && _getDocReviewState(appKey, col) == 'pass';
    }).length;
    final int flaggedResubmitCount = requiredDocItems.where((item) {
      return _getDocReviewState(appKey, item.$1) == 'resubmit';
    }).length;
    final bool allRequirementsFulfilled =
        totalRequiredDocs > 0 && passedDocsCount == totalRequiredDocs;

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);
    String statusLabel = 'PENDING REVIEW';
    if (isApproved) {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = WebTheme.brandEmerald;
      statusLabel = 'APPROVED DRIVER';
    } else if (isResubmit) {
      statusBg = const Color(0xFFFEF9C3);
      statusColor = const Color(0xFF854D0E);
      statusLabel = 'RESUBMISSION REQUESTED';
    } else if (isRejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'REJECTED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved ? const Color(0xFF86EFAC) : (isRejected ? const Color(0xFFFCA5A5) : Colors.grey.shade200),
          width: isApproved ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                _buildDriverAvatar(app, isApproved),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            app['full_name']?.toString() ?? 'Driver Applicant',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Age $age (Born ${app['birth_date']})',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                          if (isFitToWorkMandatory) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasFitToWork ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasFitToWork ? Icons.medical_services_rounded : Icons.warning_amber_rounded,
                                    size: 12,
                                    color: hasFitToWork ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasFitToWork ? 'Fit-to-Work Medical Verified' : 'Fit-to-Work Medical Mandated (50-55)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: hasFitToWork ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Contact: $maskedPhone • TODA: ${app['toda_code'] ?? 'TODA-01'} • Submitted: ${app['submitted_at']?.toString().split('T').first ?? 'Today'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Main 4-Grid Breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Personal Clearances & 2. Motorcycle Specs
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Col A: Personal & Government Clearances
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.badge_rounded, size: 16, color: WebTheme.brandEmerald),
                                SizedBox(width: 6),
                                Text(
                                  'Personal & Clearance Documents',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'license_photo_url',
                              title: 'Professional Driver\'s License',
                              detail: '${app['license_number'] ?? 'Valid'} (Exp: ${app['license_expiry_date'] ?? '2028'})',
                              isAvailable: app['license_photo_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'Professional Driver\'s License', app['license_photo_url']),
                            ),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'nbi_clearance_url',
                              title: 'NBI Clearance',
                              detail: 'Original / Valid Renewal Receipt',
                              isAvailable: app['nbi_clearance_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'NBI Clearance', app['nbi_clearance_url']),
                            ),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'police_or_barangay_clearance_url',
                              title: 'Barangay or Police Clearance',
                              detail: 'Laoag City Local Jurisdiction',
                              isAvailable: app['police_or_barangay_clearance_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'Barangay/Police Clearance', app['police_or_barangay_clearance_url']),
                            ),
                            if (isFitToWorkMandatory)
                              _buildDocStatusRow(
                                app: app,
                                appKey: appKey,
                                columnKey: 'fit_to_work_cert_url',
                                title: 'Fit-to-Work Medical Certificate',
                                detail: 'Mandated for drivers aged 50 to 55',
                                isAvailable: hasFitToWork,
                                onView: () => _showDriverAppDocDialog(context, 'Fit-to-Work Medical Certificate', app['fit_to_work_cert_url']),
                              ),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'profile_photo_url',
                              title: 'Selfie / Profile Photo',
                              detail: 'White background, well-lit, no accessories',
                              isAvailable: app['profile_photo_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'Driver White-BG Selfie', app['profile_photo_url']),
                            ),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'face_bio_scan',
                              title: '1:1 Face Bio Scan',
                              detail: faceDetail,
                              isAvailable: true,
                              onView: () => _showFaceBioScanDialog(context, app, faceMatch),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Col B: Motorcycle Specs & OR/CR
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF0284C7)),
                                SizedBox(width: 6),
                                Text(
                                  'Motorcycle Specs & Ownership',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSpecRow(
                              label: 'Brand & Model',
                              value: app['motorcycle_brand_model']?.toString() ?? 'Honda TMX 125',
                            ),
                            _buildSpecRow(
                              label: 'Displacement',
                              value: '${displacement}cc',
                              complianceBadge: isDisplacementValid
                                  ? '✓ 110–200cc Compliant'
                                  : '⚠ Out of Range (110–200cc mandated)',
                              isCompliant: isDisplacementValid,
                            ),
                            _buildSpecRow(
                              label: 'Model Year',
                              value: '$modelYear',
                              complianceBadge: isModelYearValid
                                  ? '✓ 2016+ Compliant'
                                  : '⚠ Older than 2016',
                              isCompliant: isModelYearValid,
                            ),
                            _buildSpecRow(
                              label: 'Plate / MV File #',
                              value: app['plate_or_mv_file']?.toString() ?? 'PENDING',
                            ),
                            const Divider(height: 14),
                            Row(
                              children: [
                                const Text(
                                  'Ownership & LTO Documents',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isOwned ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOwned ? 'Registered Owner' : 'Authorized by Owner',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isOwned ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'or_photo_url',
                              title: 'LTO Official Receipt (OR)',
                              detail: 'Current motorcycle registration receipt',
                              isAvailable: app['or_photo_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'LTO Official Receipt (OR)', app['or_photo_url']),
                            ),
                            _buildDocStatusRow(
                              app: app,
                              appKey: appKey,
                              columnKey: 'cr_photo_url',
                              title: 'LTO Certificate of Registration (CR)',
                              detail: 'Vehicle ownership certificate',
                              isAvailable: app['cr_photo_url'] != null,
                              onView: () => _showDriverAppDocDialog(context, 'LTO Certificate of Registration (CR)', app['cr_photo_url']),
                            ),
                            if (!isOwned) ...[
                              _buildDocStatusRow(
                                app: app,
                                appKey: appKey,
                                columnKey: 'owner_authorization_letter_url',
                                title: 'Owner Authorization Letter',
                                detail: 'Signed permission from registered owner',
                                isAvailable: app['owner_authorization_letter_url'] != null,
                                onView: () => _showDriverAppDocDialog(context, 'Owner Authorization Letter', app['owner_authorization_letter_url']),
                              ),
                              _buildDocStatusRow(
                                app: app,
                                appKey: appKey,
                                columnKey: 'owner_id_photo_url',
                                title: 'Owner Valid ID',
                                detail: 'Government-issued ID of registered owner',
                                isAvailable: app['owner_id_photo_url'] != null,
                                onView: () => _showDriverAppDocDialog(context, 'Owner Valid ID', app['owner_id_photo_url']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4-Angle Tricycle Photos Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text(
                            '4-Angle Tricycle Views:',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDocStatusRow(
                        app: app,
                        appKey: appKey,
                        columnKey: 'vehicle_front_photo_url',
                        title: 'Front View',
                        detail: 'Front view with visible plate number & headlight',
                        isAvailable: (app['vehicle_front_photo_url']?.toString().trim() ?? '').isNotEmpty,
                        onView: () => _showDriverAppDocDialog(context, 'Tricycle Front View', app['vehicle_front_photo_url']),
                      ),
                      _buildDocStatusRow(
                        app: app,
                        appKey: appKey,
                        columnKey: 'vehicle_back_photo_url',
                        title: 'Back View',
                        detail: 'Rear view with visible plate / TODA markings',
                        isAvailable: (app['vehicle_back_photo_url']?.toString().trim() ?? '').isNotEmpty,
                        onView: () => _showDriverAppDocDialog(context, 'Tricycle Back View', app['vehicle_back_photo_url']),
                      ),
                      _buildDocStatusRow(
                        app: app,
                        appKey: appKey,
                        columnKey: 'vehicle_left_photo_url',
                        title: 'Left Side',
                        detail: 'Full left side profile of motorcycle & sidecar',
                        isAvailable: (app['vehicle_left_photo_url']?.toString().trim() ?? '').isNotEmpty,
                        onView: () => _showDriverAppDocDialog(context, 'Tricycle Left Side', app['vehicle_left_photo_url']),
                      ),
                      _buildDocStatusRow(
                        app: app,
                        appKey: appKey,
                        columnKey: 'vehicle_right_photo_url',
                        title: 'Right Side',
                        detail: 'Full right side profile of motorcycle & sidecar',
                        isAvailable: (app['vehicle_right_photo_url']?.toString().trim() ?? '').isNotEmpty,
                        onView: () => _showDriverAppDocDialog(context, 'Tricycle Right Side', app['vehicle_right_photo_url']),
                      ),
                    ],
                  ),
                ),

                if (app['admin_notes'] != null && app['admin_notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Admin Review Note: ${app['admin_notes']}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 14),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showDriverAppDocDialog(context, 'Time-Expiring Signed Vault URLs', app['license_photo_url']),
                      icon: const Icon(Icons.vpn_key_rounded, size: 14, color: Color(0xFF0284C7)),
                      label: const Text('RA 10173 Signed URLs (300s)', style: TextStyle(fontSize: 11.5)),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (isRejected) ...[
                          OutlinedButton.icon(
                            onPressed: () => _permanentlyDeleteDriverApp(app),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                            icon: const Icon(Icons.delete_forever_rounded, size: 15, color: Color(0xFFDC2626)),
                            label: const Text(
                              'Delete Permanently',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (!isApproved) ...[
                          OutlinedButton.icon(
                            onPressed: flaggedResubmitCount > 0
                                ? () => _requestResubmissionDriverApp(app)
                                : null,
                            style: flaggedResubmitCount > 0
                                ? OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFFBEB),
                                    side: const BorderSide(color: Color(0xFFD97706)),
                                  )
                                : OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                            icon: Icon(
                              Icons.history_edu_rounded,
                              size: 14,
                              color: flaggedResubmitCount > 0
                                  ? const Color(0xFFD97706)
                                  : Colors.grey.shade400,
                            ),
                            label: Text(
                              flaggedResubmitCount > 0
                                  ? 'Send Resubmission ($flaggedResubmitCount Flagged)'
                                  : 'Request Resubmission',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: flaggedResubmitCount > 0
                                    ? const Color(0xFFD97706)
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _rejectDriverApp(app),
                            icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                            label: const Text('Reject', style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
                          ),
                          ElevatedButton.icon(
                            onPressed: allRequirementsFulfilled
                                ? () => _approveDriverApp(app)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allRequirementsFulfilled
                                  ? WebTheme.brandEmerald
                                  : Colors.grey.shade300,
                              foregroundColor: allRequirementsFulfilled
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              disabledBackgroundColor: Colors.grey.shade200,
                              disabledForegroundColor: Colors.grey.shade500,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 15),
                            label: Text(
                              allRequirementsFulfilled
                                  ? 'Approve & Assign TODA Pila'
                                  : 'Approve & Assign TODA Pila ($passedDocsCount/$totalRequiredDocs Passed)',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF15803D)),
                                const SizedBox(width: 6),
                                Text(
                                  'Franchise Active (${app['toda_code'] ?? 'TODA-01'})',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _approveDriverApp(app, isReassign: true),
                            icon: const Icon(Icons.edit_location_alt_rounded, size: 14, color: WebTheme.brandEmerald),
                            label: const Text(
                              'Assign TODA Pila',
                              style: TextStyle(fontSize: 11.5, color: WebTheme.brandEmerald, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAvatar(Map<String, dynamic> app, bool isApproved) {
    final initial = app['full_name']?.toString().isNotEmpty == true
        ? app['full_name'].toString().substring(0, 1).toUpperCase()
        : 'D';
    final fallback = CircleAvatar(
      radius: 22,
      backgroundColor: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isApproved ? WebTheme.brandEmerald : const Color(0xFF0F172A),
        ),
      ),
    );

    final rawPhoto = app['profile_photo_url']?.toString().trim() ?? '';
    if (rawPhoto.isEmpty) return fallback;

    return FutureBuilder<String?>(
      future: _resolveDriverDocUrl(rawPhoto),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          return fallback;
        }
        return CircleAvatar(
          radius: 22,
          backgroundColor: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
          child: ClipOval(
            child: Image.network(
              resolvedUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
          ),
        );
      },
    );
  }

  Future<void> _permanentlyDeleteDriverApp(Map<String, dynamic> app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Permanently Delete Rejected Application',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
        ),
        content: Text(
          'Delete ${app['full_name']} permanently from Rejected Trash? This cannot be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep for Reference'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final appKey = _getAppKey(app);
    final rawId = app['id']?.toString() ?? '';
    final phone = app['phone_number']?.toString() ?? '';

    try {
      if (rawId.isNotEmpty && !rawId.startsWith('drv_app_')) {
        await Supabase.instance.client
            .from('driver_applications')
            .delete()
            .eq('id', rawId);
      } else if (phone.isNotEmpty) {
        await Supabase.instance.client
            .from('driver_applications')
            .delete()
            .eq('phone_number', phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete from Supabase: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    _refresh(() {
      _driverApplications.removeWhere((a) => _getAppKey(a) == appKey);
      _docReviewStatus.remove(appKey);
      _docReviewReasons.remove(appKey);
      _systemAuditLogs.insert(0, {
        'time': 'Just now',
        'actor': 'MINC Officer Santos',
        'action': 'Permanently deleted rejected application for ${app['full_name']}',
      });
    });
    unawaited(_saveDocReviewCache());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Permanently deleted ${app['full_name']} from Rejected Trash.'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  String _getAppKey(Map<String, dynamic> app) {
    return (app['id'] ?? app['phone_number'] ?? app['full_name'] ?? 'driver')
        .toString();
  }

  String _getDocReviewState(String appKey, String columnKey) {
    return _docReviewStatus[appKey]?[columnKey] ?? 'pending';
  }

  List<(String, String)> _getRequiredDocSpecs({
    required bool isFitToWorkMandatory,
    required bool isOwned,
  }) {
    return [
      ('license_photo_url', "Professional Driver's License"),
      ('nbi_clearance_url', 'NBI Clearance'),
      ('police_or_barangay_clearance_url', 'Barangay or Police Clearance'),
      if (isFitToWorkMandatory)
        ('fit_to_work_cert_url', 'Fit-to-Work Medical Certificate'),
      ('profile_photo_url', 'Selfie / Profile Photo'),
      ('face_bio_scan', '1:1 Face Bio Scan'),
      ('or_photo_url', 'LTO Official Receipt (OR)'),
      ('cr_photo_url', 'LTO Certificate of Registration (CR)'),
      if (!isOwned) ...[
        ('owner_authorization_letter_url', 'Owner Authorization Letter'),
        ('owner_id_photo_url', 'Owner Valid ID'),
      ],
      ('vehicle_front_photo_url', 'Tricycle Front View'),
      ('vehicle_back_photo_url', 'Tricycle Back View'),
      ('vehicle_left_photo_url', 'Tricycle Left Side'),
      ('vehicle_right_photo_url', 'Tricycle Right Side'),
    ];
  }

  void _markDocPassed(String appKey, String columnKey) {
    _refresh(() {
      _docReviewStatus.putIfAbsent(appKey, () => {})[columnKey] = 'pass';
      _docReviewReasons[appKey]?.remove(columnKey);
    });
    unawaited(_saveDocReviewCache());
  }

  Future<void> _openItemResubmitReasonDialog(
    Map<String, dynamic> app,
    String appKey,
    String columnKey,
    String itemLabel,
  ) async {
    String selectedReason = _WebAdminDashboardState._resubmitReasonOptions.first;
    final customController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isOther = selectedReason == 'Other (Specify reason)';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              'Resubmit: $itemLabel',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the reason to show in the driver\'s mobile app:',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _WebAdminDashboardState._resubmitReasonOptions
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 12.5)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type custom reason for $itemLabel...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final finalReason = isOther
                      ? customController.text.trim()
                      : selectedReason;
                  if (finalReason.isEmpty) return;
                  Navigator.pop(ctx, finalReason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark Resubmit'),
              ),
            ],
          );
        },
      ),
    );

    customController.dispose();
    if (result == null || !mounted) return;

    _refresh(() {
      _docReviewStatus.putIfAbsent(appKey, () => {})[columnKey] = 'resubmit';
      _docReviewReasons.putIfAbsent(appKey, () => {})[columnKey] = result;
    });
    unawaited(_saveDocReviewCache());
  }

  Widget _buildDocStatusRow({
    required Map<String, dynamic> app,
    required String appKey,
    required String columnKey,
    required String title,
    required String detail,
    required bool isAvailable,
    required VoidCallback onView,
  }) {
    final reviewState = _getDocReviewState(appKey, columnKey);
    final resubmitReason = _docReviewReasons[appKey]?[columnKey];
    final isPassed = reviewState == 'pass';
    final isResubmit = reviewState == 'resubmit';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPassed
                    ? Icons.check_circle_rounded
                    : isResubmit
                        ? Icons.warning_amber_rounded
                        : (isAvailable
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.cancel_rounded),
                size: 14,
                color: isPassed
                    ? WebTheme.brandEmerald
                    : isResubmit
                        ? const Color(0xFFD97706)
                        : (isAvailable
                            ? const Color(0xFF64748B)
                            : Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title • $detail',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onView,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0284C7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _openItemResubmitReasonDialog(
                  app,
                  appKey,
                  columnKey,
                  title,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isResubmit
                        ? const Color(0xFFFEF3C7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'Resubmit',
                    style: TextStyle(
                      fontSize: 11,
                      color: isResubmit
                          ? const Color(0xFFB45309)
                          : const Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: isAvailable ? () => _markDocPassed(appKey, columnKey) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? const Color(0xFFDCFCE7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isPassed ? '✓ Pass' : 'Pass',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAvailable
                          ? (isPassed
                              ? const Color(0xFF15803D)
                              : WebTheme.brandEmerald)
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isResubmit && resubmitReason != null && resubmitReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                'Reason: $resubmitReason',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required String label,
    required String value,
    String? complianceBadge,
    bool isCompliant = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          if (complianceBadge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                complianceBadge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isCompliant ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _resolveDriverDocUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    const prefix = 'storage://driver-documents/';
    if (rawUrl.startsWith(prefix)) {
      final path = rawUrl.substring(prefix.length);
      try {
        return await Supabase.instance.client.storage
            .from('driver-documents')
            .createSignedUrl(path, 300);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _showDriverAppDocDialog(BuildContext context, String docTitle, String? docUrl) {
    final rawValue = (docUrl ?? '').trim();
    final fileName = rawValue.isEmpty
        ? 'No file submitted'
        : rawValue.split(RegExp(r'[/\\]')).last;
    final lowerName = fileName.toLowerCase();
    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<String?>(
        future: _resolveDriverDocUrl(rawValue),
        builder: (context, snapshot) {
          final resolvedUrl = snapshot.data;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$docTitle (Document Vault)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submitted File: $fileName',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'RA 10173 Protected Access: Signed Supabase Storage links expire in 300 seconds (5 minutes).',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (resolvedUrl != null) ...[
                    if (isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: Image.network(
                            resolvedUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              padding: const EdgeInsets.all(14),
                              color: Colors.grey.shade100,
                              child: const Text(
                                'Preview unavailable in dialog. Click "Open File" below to view in a new tab.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_rounded, color: Color(0xFF0284C7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Document ready ($fileName). Click "Open File" to view or download.',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        resolvedUrl,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        rawValue.isEmpty
                            ? 'No file path was recorded for this document.'
                            : 'Stored reference: $rawValue\n(File was recorded locally on the mobile device or Storage bucket policy blocked upload.)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (resolvedUrl != null) ...[
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: resolvedUrl));
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Signed document URL copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Link'),
                ),
                ElevatedButton.icon(
                  onPressed: () => openUrlInNewTab(resolvedUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open File'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 9C. PASSENGER APPLICATIONS & IDENTITY VERIFICATION VIEW
  // ===========================================================================
  Widget _buildPassengerApplicationsView() {
    final allPassengers = _flaggedVerifications
        .where((u) => (u['role'] ?? 'rider').toString() == 'rider')
        .toList();

    final filtered = allPassengers.where((p) {
      final status = (p['status'] ?? 'pending').toString();
      if (_passengerAppFilter == 'All') return status != 'rejected';
      return status == _passengerAppFilter;
    }).toList();

    final pendingCount =
        allPassengers.where((p) => (p['status'] ?? 'pending') == 'pending').length;
    final approvedCount =
        allPassengers.where((p) => p['status'] == 'approved').length;
    final rejectedCount =
        allPassengers.where((p) => p['status'] == 'rejected').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passenger Applications & ID Verification',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review passenger submitted ID and 1:1 Face Bio Scan (target turnaround: 1 hour or less). Profile photos may be real photos or illustration avatars.',
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        // Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Review (<= 1 hr)',
                value: '$pendingCount',
                icon: Icons.hourglass_top_rounded,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricTile(
                title: 'Approved Passengers',
                value: '$approvedCount',
                icon: Icons.verified_user_rounded,
                color: WebTheme.brandEmerald,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _refresh(() => _passengerAppFilter = 'rejected'),
                borderRadius: BorderRadius.circular(14),
                child: _buildMetricTile(
                  title: 'Rejected (Trash)',
                  value: '$rejectedCount',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Filter Chips
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final filter in const [
              ('All', 'All Active'),
              ('pending', 'Pending'),
              ('approved', 'Approved'),
              ('re_upload_requested', 'Resubmission Requested'),
              ('rejected', 'Rejected (Trash)'),
            ])
              ChoiceChip(
                label: Text(filter.$2),
                selected: _passengerAppFilter == filter.$1,
                onSelected: (_) =>
                    _refresh(() => _passengerAppFilter = filter.$1),
                selectedColor: WebTheme.brandEmerald.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _passengerAppFilter == filter.$1
                      ? WebTheme.brandEmerald
                      : Colors.grey.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No passenger applications found for this filter.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ...filtered.map(_buildPassengerApplicationCard),
      ],
    );
  }

  Widget _buildPassengerAvatar(Map<String, dynamic> pax, bool isApproved) {
    final photoUrl = (pax['profile_photo_url'] ?? '').toString();
    final name = (pax['name'] ?? 'P').toString();

    if (photoUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: 22,
        backgroundColor:
            isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
        child: ClipOval(
          child: Image.asset(
            photoUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.face_rounded,
              color: Color(0xFF0284C7),
              size: 24,
            ),
          ),
        ),
      );
    }

    if (photoUrl.isNotEmpty) {
      return _buildDriverAvatar(
        {
          'profile_photo_url': photoUrl,
          'full_name': name,
        },
        isApproved,
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor:
          isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isApproved
              ? WebTheme.brandEmerald
              : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildPassengerApplicationCard(Map<String, dynamic> pax) {
    final status = (pax['status'] ?? 'pending').toString();
    final isApproved = status == 'approved';
    final isResubmit =
        status == 're_upload_requested' || status == 'resubmission_requested';
    final isRejected = status == 'rejected';
    final paxKey = _getAppKey({
      'id': pax['id'],
      'phone_number': pax['phone_number'],
      'full_name': pax['name'],
    });

    final idPhotoUrl = (pax['id_photo_url'] ?? '').toString();
    final profilePhotoUrl = (pax['profile_photo_url'] ?? '').toString();
    final hasIllustrationAvatar = profilePhotoUrl.startsWith('assets/');
    final double? similarity = (pax['similarity'] as num?)?.toDouble();
    final String faceDetail = similarity == null
        ? 'Liveness & 1:1 Face Match ($status)'
        : (similarity <= 0
            ? 'Match 0.0% (No Face Detected) • $status'
            : 'Match ${similarity.toStringAsFixed(1)}% • $status');
    if (!(_docReviewStatus[paxKey]?.containsKey('face_bio_scan') ?? false) &&
        similarity != null &&
        similarity >= 85.0) {
      (_docReviewStatus[paxKey] ??= {})['face_bio_scan'] = 'pass';
    }

    final idState = _getDocReviewState(paxKey, 'rider_id_photo_url');
    final faceState = _getDocReviewState(paxKey, 'face_bio_scan');
    final bool allPassed = idState == 'pass' && faceState == 'pass';
    final int resubmitCount =
        (idState == 'resubmit' ? 1 : 0) + (faceState == 'resubmit' ? 1 : 0);

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);
    String statusLabel = 'PENDING REVIEW (<= 1 HR)';
    if (isApproved) {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = WebTheme.brandEmerald;
      statusLabel = 'APPROVED PASSENGER';
    } else if (isResubmit) {
      statusBg = const Color(0xFFFEF9C3);
      statusColor = const Color(0xFF854D0E);
      statusLabel = 'RESUBMISSION REQUESTED';
    } else if (isRejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'REJECTED (TRASH)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF86EFAC)
              : (isRejected ? const Color(0xFFFCA5A5) : Colors.grey.shade200),
          width: isApproved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildPassengerAvatar(pax, isApproved),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            (pax['name'] ?? 'Passenger').toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (pax['idType'] ?? 'Submitted ID').toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                          if (hasIllustrationAvatar)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Illustration Avatar Accepted',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7E22CE),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact: ${pax['phone_number'] ?? ''} • Submitted: ${(pax['created_at'] ?? '').toString().split('T').first}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Passenger Verification Checklist (ID + 1:1 Face Bio Scan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fact_check_outlined,
                          size: 16, color: WebTheme.brandEmerald),
                      SizedBox(width: 6),
                      Text(
                        'Passenger Identity Verification (2 Required Checks)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDocStatusRow(
                    app: pax,
                    appKey: paxKey,
                    columnKey: 'rider_id_photo_url',
                    title: 'Submitted ID',
                    detail: (pax['idType'] ?? 'Valid ID').toString(),
                    isAvailable: idPhotoUrl.isNotEmpty || true,
                    onView: () => _showDriverAppDocDialog(
                      context,
                      'Passenger Submitted ID (${pax['idType'] ?? ''})',
                      idPhotoUrl.isNotEmpty ? idPhotoUrl : null,
                    ),
                  ),
                  _buildDocStatusRow(
                    app: pax,
                    appKey: paxKey,
                    columnKey: 'face_bio_scan',
                    title: '1:1 Face Bio Scan',
                    detail: faceDetail,
                    isAvailable: true,
                    onView: () => _showFaceBioScanDialog(
                      context,
                      {
                        'full_name': pax['name'],
                        'phone_number': pax['phone_number'],
                        'role': 'rider',
                        'profile_photo_url': profilePhotoUrl,
                        'id_photo_url': idPhotoUrl,
                        'id_type': pax['idType'] ?? '',
                      },
                      pax,
                    ),
                  ),
                ],
              ),
            ),

            if ((pax['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Admin Review Note: ${pax['note']}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Actions
            if (isRejected)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _permanentlyDeletePassengerApp(pax),
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 17, color: Colors.red),
                    label: const Text(
                      'Delete Permanently',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              )
            else if (!isApproved)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _rejectPassengerApp(pax),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: resubmitCount > 0
                        ? () => _requestResubmissionPassengerApp(pax, paxKey)
                        : null,
                    icon: const Icon(Icons.assignment_late_outlined, size: 16),
                    label: Text(
                      resubmitCount > 0
                          ? 'Request Resubmission ($resubmitCount)'
                          : 'Request Resubmission',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(
                        color: resubmitCount > 0
                            ? Colors.orange.shade400
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        allPassed ? () => _approvePassengerApp(pax) : null,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: Text(
                      allPassed
                          ? 'Approve Passenger'
                          : 'Pass ID & Face Scan First',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WebTheme.brandEmerald,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePassengerApp(Map<String, dynamic> pax) async {
    const note = 'Approved by Laoag MINC Officer (ID & 1:1 Face Scan verified).';
    try {
      await Supabase.instance.client.from('users').update({
        'verification_status': 'approved',
        'admin_review_note': note,
      }).eq('phone_number', pax['phone_number']);
    } catch (_) {}

    await _dispatchAdminSmsNotice(
      phoneNumber: (pax['phone_number'] ?? '').toString(),
      message:
          'PasadaNorte MINC: Hi ${pax['name'] ?? 'Passenger'}, your ID & face verification is APPROVED. You can now book rides with your verified discount.',
    );

    if (mounted) {
      _refresh(() {
        pax['status'] = 'approved';
        pax['note'] = note;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pax['name']} approved as PasadaNorte Passenger!'),
          backgroundColor: WebTheme.brandEmerald,
        ),
      );
    }
  }

  Future<void> _requestResubmissionPassengerApp(
      Map<String, dynamic> pax, String paxKey) async {
    final reasons = <String>[];
    if (_getDocReviewState(paxKey, 'rider_id_photo_url') == 'resubmit') {
      final r = _docReviewReasons[paxKey]?['rider_id_photo_url'] ??
          'Unclear or mismatched ID';
      reasons.add('• Submitted ID: $r');
    }
    if (_getDocReviewState(paxKey, 'face_bio_scan') == 'resubmit') {
      final r = _docReviewReasons[paxKey]?['face_bio_scan'] ??
          'Face bio scan did not match ID photo';
      reasons.add('• 1:1 Face Bio Scan: $r');
    }
    final combinedNote = reasons.isNotEmpty
        ? reasons.join('\n')
        : 'Admin requested resubmission of ID or 1:1 Face Bio Scan.';

    try {
      await Supabase.instance.client.from('users').update({
        'verification_status': 're_upload_requested',
        'admin_review_note': combinedNote,
      }).eq('phone_number', pax['phone_number']);
    } catch (_) {}

    await _dispatchAdminSmsNotice(
      phoneNumber: (pax['phone_number'] ?? '').toString(),
      message:
          'PasadaNorte MINC: Hi ${pax['name'] ?? 'Passenger'}, please re-upload your ID or face scan in the app. Note: $combinedNote',
    );

    if (mounted) {
      _refresh(() {
        pax['status'] = 're_upload_requested';
        pax['note'] = combinedNote;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Resubmission requested for ${pax['name']}.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _rejectPassengerApp(Map<String, dynamic> pax) async {
    final presets = <String>[
      'Suspicious or tampered ID document',
      'Fake or fabricated identity details',
      '1:1 Face Bio Scan does not match submitted ID',
      'Duplicate or fraudulent account activity',
      'Other (Specify reason)',
    ];
    String selected = presets.first;
    final customCtrl = TextEditingController();

    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reject Passenger Application',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select rejection reason for ${pax['name']}:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: presets
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selected = val);
                  },
                ),
                if (selected == 'Other (Specify reason)') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Specify rejection reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final finalReason = selected == 'Other (Specify reason)'
                    ? (customCtrl.text.trim().isEmpty
                        ? 'Rejected by admin'
                        : customCtrl.text.trim())
                    : selected;
                Navigator.pop(ctx, finalReason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Move to Rejected Trash'),
            ),
          ],
        ),
      ),
    );

    if (confirmedReason == null) return;

    try {
      await Supabase.instance.client.from('users').update({
        'verification_status': 'rejected',
        'admin_review_note': confirmedReason,
      }).eq('phone_number', pax['phone_number']);
    } catch (_) {}

    await _dispatchAdminSmsNotice(
      phoneNumber: (pax['phone_number'] ?? '').toString(),
      message:
          'PasadaNorte MINC: Hi ${pax['name'] ?? 'Passenger'}, your passenger verification was declined. Reason: $confirmedReason',
    );

    if (mounted) {
      _refresh(() {
        pax['status'] = 'rejected';
        pax['note'] = confirmedReason;
      });
    }
  }

  Future<void> _permanentlyDeletePassengerApp(Map<String, dynamic> pax) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Passenger?'),
        content: Text(
          'This will permanently remove ${pax['name']} (${pax['phone_number']}) from Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final deletedRows = await Supabase.instance.client
          .from('users')
          .delete()
          .eq('phone_number', pax['phone_number'])
          .select();
      if (deletedRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Delete blocked by Supabase RLS (run migration 20261119_users_admin_delete_policy.sql).',
              ),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete passenger in Supabase: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    if (mounted) {
      _refresh(() {
        _flaggedVerifications.remove(pax);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pax['name']} permanently deleted from Supabase.'),
          backgroundColor: WebTheme.brandEmerald,
        ),
      );
    }
  }

  void _showFaceBioScanDialog(
    BuildContext context,
    Map<String, dynamic> app,
    Map<String, dynamic>? faceMatch,
  ) {
    final similarity = (faceMatch?['similarity'] as num?)?.toDouble();
    final latency = (faceMatch?['latency'] as num?)?.toDouble();
    final status = (faceMatch?['status'] ?? 'pending').toString();
    final note = (faceMatch?['note'] ?? 'Live 1:1 liveness & selfie comparison').toString();
    final roleStr = (app['role'] ?? faceMatch?['role'] ?? 'driver').toString().toLowerCase();
    final isPassenger = roleStr == 'rider' || roleStr == 'passenger';
    final idTypeRaw = (app['id_type'] ?? faceMatch?['idType'] ?? '').toString();
    final idTypeUpper = idTypeRaw.toUpperCase();
    final String roleLabel;
    if (!isPassenger) {
      roleLabel = 'Driver';
    } else if (idTypeUpper.contains('STUDENT')) {
      roleLabel = 'Student Passenger';
    } else if (idTypeUpper.contains('SENIOR') || idTypeUpper.contains('PWD')) {
      roleLabel = 'Senior / PWD Passenger';
    } else {
      roleLabel = 'Regular Passenger';
    }

    final selfieTitle = isPassenger
        ? '$roleLabel Live Verification Selfie'
        : 'Driver Live Verification Selfie';
    final idTitle = isPassenger
        ? '$roleLabel Submitted ID${idTypeRaw.isNotEmpty ? ' ($idTypeRaw)' : ''}'
        : 'Driver License / Submitted ID';

    final liveSelfieUrl = (faceMatch?['profile_photo_url'] ?? '').toString().trim();
    final appSelfieUrl = (app['profile_photo_url'] ?? '').toString().trim();
    final selfieUrl = liveSelfieUrl.isNotEmpty ? liveSelfieUrl : appSelfieUrl;

    final rawIdUrl = (app['id_photo_url'] ??
            app['license_photo_url'] ??
            faceMatch?['id_photo_url'] ??
            '')
        .toString()
        .trim();

    Widget buildPhotoCard(BuildContext dialogCtx, String label, String url, String vaultTitle) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: url.isEmpty
                    ? Center(
                        child: Text(
                          'No photo uploaded',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                        ),
                      )
                    : FutureBuilder<String?>(
                        future: _resolveDriverDocUrl(url),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          final resolved = snapshot.data;
                          if (resolved == null) {
                            return Center(
                              child: Text(
                                'Preview unavailable\n(legacy local path)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                              ),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              resolved,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  'Unable to render image',
                                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showDriverAppDocDialog(
                      context,
                      vaultTitle,
                      url.isNotEmpty ? url : null,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Open Full Vault'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.face_retouching_natural_rounded, color: WebTheme.brandEmerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '1:1 Face Bio Scan Inspection ($roleLabel)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$roleLabel: ${app['full_name'] ?? roleLabel}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                Text('Verification Status: $status', style: const TextStyle(fontSize: 12.5)),
                Text(
                  'AI Face Similarity: ${similarity == null ? 'Pending Face Scan' : (similarity <= 0 ? '0.0% (No Face Detected)' : '${similarity.toStringAsFixed(1)}%')}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: similarity != null && similarity <= 0
                        ? const Color(0xFFDC2626)
                        : null,
                    fontWeight: similarity != null && similarity <= 0
                        ? FontWeight.w700
                        : null,
                  ),
                ),
                if (latency != null && latency > 0)
                  Text('Scan Latency: ${latency.toStringAsFixed(2)}s', style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 6),
                Text('System Note: $note', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildPhotoCard(ctx, 'Submitted ID', rawIdUrl, idTitle),
                    const SizedBox(width: 12),
                    buildPhotoCard(ctx, 'Live 1:1 Selfie', selfieUrl, selfieTitle),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _updateDriverApplicationInSupabase(
    Map<String, dynamic> app,
    Map<String, dynamic> updates,
  ) async {
    final rawId = app['id']?.toString() ?? '';
    final phone = app['phone_number']?.toString() ?? '';
    if (rawId.isNotEmpty && !rawId.startsWith('drv_app_')) {
      await Supabase.instance.client
          .from('driver_applications')
          .update(updates)
          .eq('id', rawId);
    } else if (phone.isNotEmpty) {
      await Supabase.instance.client
          .from('driver_applications')
          .update(updates)
          .eq('phone_number', phone);
    }
  }

  Future<void> _approveDriverApp(
    Map<String, dynamic> app, {
    bool isReassign = false,
  }) async {
    final terminalCodes = _terminals
        .map((t) => (t['code'] ?? 'TODA-01').toString())
        .toList();
    final initialToda = (app['toda_code'] ?? 'TODA-01').toString();
    String selectedToda = terminalCodes.contains(initialToda)
        ? initialToda
        : (terminalCodes.isNotEmpty ? terminalCodes.first : 'TODA-01');
    final pilaController = TextEditingController(
      text: 'Pila #${_driverDirectory.length + 1}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              isReassign
                  ? 'Assign / Update TODA Pila'
                  : 'Approve & Assign TODA Pila',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select the TODA terminal and Pila slot for ${app['full_name']}:',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TODA Terminal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedToda,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _terminals.isEmpty
                        ? [
                            DropdownMenuItem(
                              value: selectedToda,
                              child: Text(
                                '$selectedToda (No TODA Pila created yet)',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ]
                        : _terminals.map((t) {
                            final code = (t['code'] ?? 'TODA-01').toString();
                            final name = (t['name'] ?? code).toString();
                            return DropdownMenuItem(
                              value: code,
                              child: Text(
                                '$code - $name',
                                style: const TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedToda = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TODA Pila Slot / Number',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pilaController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Pila #1',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pilaController.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebTheme.brandEmerald,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isReassign ? 'Save TODA Pila' : 'Confirm & Approve',
                ),
              ),
            ],
          );
        },
      ),
    );

    final pilaSlot = pilaController.text.trim();
    pilaController.dispose();
    if (confirmed != true || pilaSlot.isEmpty || !mounted) return;

    final matchedTerminal = _terminals.cast<Map<String, dynamic>?>().firstWhere(
      (t) => t?['code'] == selectedToda,
      orElse: () => null,
    );
    final terminalName = (matchedTerminal?['name'] ?? selectedToda).toString();
    final note =
        'Approved by Laoag MINC Officer. Assigned TODA Pila: $selectedToda ($pilaSlot) - $terminalName.';

    _refresh(() {
      app['application_status'] = 'approved';
      app['toda_code'] = selectedToda;
      app['admin_notes'] = note;

      final existingIdx = _driverDirectory.indexWhere(
        (d) =>
            d['phone'] == app['phone_number'] || d['name'] == app['full_name'],
      );
      final dirEntry = {
        'bodyNo': pilaSlot,
        'name': app['full_name'],
        'toda': selectedToda,
        'phone': app['phone_number'] ?? '',
        'plateNo': app['plate_or_mv_file'] ?? '1204-IN',
        'profile_photo_url': app['profile_photo_url'] ?? '',
        'status': 'Active & Compliant',
        'complianceRating': 100,
        'tripsToday': 0,
      };
      if (existingIdx >= 0) {
        _driverDirectory[existingIdx] = {
          ..._driverDirectory[existingIdx],
          ...dirEntry,
        };
      } else {
        _driverDirectory.add(dirEntry);
      }

      _systemAuditLogs.insert(0, {
        'time': 'Just now',
        'actor': 'MINC Officer Santos',
        'action':
            '${isReassign ? 'Updated' : 'Approved'} Driver ${app['full_name']} (Assigned $selectedToda $pilaSlot)',
      });
    });

    try {
      await _updateDriverApplicationInSupabase(app, {
        'application_status': 'approved',
        'toda_code': selectedToda,
        'admin_notes': note,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supabase update error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    await _dispatchAdminSmsNotice(
      phoneNumber: (app['phone_number'] ?? app['phone'] ?? '').toString(),
      message:
          'PasadaNorte MINC: Congratulations ${app['full_name'] ?? 'Driver'}! Your franchise application is APPROVED ($selectedToda - $pilaSlot). You may now go online.',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ ${app['full_name']} assigned to $selectedToda ($pilaSlot).',
        ),
        backgroundColor: WebTheme.brandEmerald,
      ),
    );
  }

  void _requestResubmissionDriverApp(Map<String, dynamic> app) {
    final appKey = _getAppKey(app);
    final age = app['age'] as int? ?? 30;
    final isFitToWorkMandatory = age >= 50 && age <= 55;
    final isOwned = app['is_motorcycle_owned'] as bool? ?? true;
    final labelByCol = <String, String>{
      for (final item in _getRequiredDocSpecs(
        isFitToWorkMandatory: isFitToWorkMandatory,
        isOwned: isOwned,
      ))
        item.$1: item.$2,
    };

    final flaggedReasons = _docReviewReasons[appKey] ?? {};
    final compiledLines = flaggedReasons.entries
        .map((e) => '• ${labelByCol[e.key] ?? e.key}: ${e.value}')
        .toList();

    String selectedReason = _WebAdminDashboardState._resubmitReasonOptions.first;
    final customController = TextEditingController(
      text: compiledLines.isNotEmpty ? compiledLines.join('\n') : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final hasCompiled = compiledLines.isNotEmpty;
          final isOther =
              hasCompiled || selectedReason == 'Other (Specify reason)';
          return AlertDialog(
            title: const Text(
              'Request Document Resubmission',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify requirements needed for ${app['full_name']} (shown in mobile app):',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  if (!hasCompiled) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _WebAdminDashboardState._resubmitReasonOptions
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, style: const TextStyle(fontSize: 12.5)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isOther)
                    TextField(
                      controller: customController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter resubmission instructions for the driver...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final finalNote = isOther
                      ? customController.text.trim()
                      : selectedReason;
                  if (finalNote.isEmpty) return;
                  Navigator.pop(ctx);
                  _refresh(() {
                    app['application_status'] = 'resubmission_requested';
                    app['admin_notes'] = finalNote;
                    _systemAuditLogs.insert(0, {
                      'time': 'Just now',
                      'actor': 'MINC Officer Santos',
                      'action':
                          'Requested Resubmission for ${app['full_name']}: $finalNote',
                    });
                  });

                  try {
                    await _updateDriverApplicationInSupabase(app, {
                      'application_status': 'resubmission_requested',
                      'admin_notes': finalNote,
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Supabase update error: $e'),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                    return;
                  }

                  await _dispatchAdminSmsNotice(
                    phoneNumber: (app['phone_number'] ?? app['phone'] ?? '').toString(),
                    message:
                        'PasadaNorte MINC: Hi ${app['full_name'] ?? 'Driver'}, please resubmit your driver application documents. Reason: $finalNote',
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Resubmission notice dispatched to ${app['full_name']}.',
                      ),
                      backgroundColor: const Color(0xFFD97706),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Notice'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _rejectDriverApp(Map<String, dynamic> app) {
    String selectedReason = _WebAdminDashboardState._rejectReasonOptions.first;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isOther = selectedReason == 'Other (Specify reason)';
          return AlertDialog(
            title: const Text(
              'Reject Driver Application',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reject ${app['full_name']} if suspicious activity or repeated fake data is detected:',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _WebAdminDashboardState._rejectReasonOptions
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 12.5)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Specify rejection reason...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final finalReason = isOther
                      ? customController.text.trim()
                      : selectedReason;
                  if (finalReason.isEmpty) return;
                  Navigator.pop(ctx);
                  _refresh(() {
                    app['application_status'] = 'rejected';
                    app['admin_notes'] = finalReason;
                    _systemAuditLogs.insert(0, {
                      'time': 'Just now',
                      'actor': 'MINC Officer Santos',
                      'action':
                          'Rejected Driver Application for ${app['full_name']}: $finalReason',
                    });
                  });

                  try {
                    await _updateDriverApplicationInSupabase(app, {
                      'application_status': 'rejected',
                      'admin_notes': finalReason,
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Supabase update error: $e'),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                    return;
                  }

                  await _dispatchAdminSmsNotice(
                    phoneNumber: (app['phone_number'] ?? app['phone'] ?? '').toString(),
                    message:
                        'PasadaNorte MINC: Hi ${app['full_name'] ?? 'Driver'}, your driver application was rejected. Reason: $finalReason',
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Application for ${app['full_name']} marked REJECTED.',
                      ),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Rejection'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 10. SETTINGS & REGULATORY COMPLIANCE VIEW
  // ===========================================================================
  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System Settings & Regulatory Compliance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('City Ordinance 2023-005 parameters, statutory discount shares, and audit trail.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Laoag City Ordinance & Statutory Discount Mandates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: WebTheme.brandEmerald, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student, Senior Citizen & PWD Municipal Discount (Flat ₱5.00 Off)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('City Ordinance No. 2023-005 (₱20 Reg / ₱15 Disc) & Oct 2026 Provisional Matrix (₱25 Reg / ₱20 Disc) verified via 1:1 ID check.', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('Active (Ord. 2023-005)', style: TextStyle(color: WebTheme.brandEmerald, fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
              Divider(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.balance_rounded, color: WebTheme.brandEmerald, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LTFRB MC No. 2025-10 Discount Cost-Sharing (50%–50% Schema Readiness)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('Database schema retains optional 50% TNC / 50% Operator statutory discount-sharing fields for future commercial TNVS accreditation.', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('Schema Ready', style: TextStyle(color: WebTheme.brandEmerald, fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Audit Trail Logs
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('System Audit Trail', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              ..._systemAuditLogs.map((log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(log['time'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${log['actor']}: ${log['action']}', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 11. FLEET & LIVE INCIDENT COMMAND SENTINEL VIEW
  // ===========================================================================
  Widget _buildLiveMonitoringView() {
    final activeAlerts = _sosAlerts.where((a) => a['status'] == 'ACTIVE_DISPATCHED').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Incident Command & Fleet Monitoring Sentinel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Real-time SOS beacons, PostGIS GPS vehicle coordinates, and emergency PNP response.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _syncFromSupabase();
                    _checkSmsGateStatus();
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Refresh Telemetry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebTheme.brandEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live KPI Metrics Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeAlerts.isNotEmpty ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: activeAlerts.isNotEmpty ? const Color(0xFFF87171) : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE DISTRESS BEACONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: activeAlerts.isNotEmpty ? const Color(0xFF991B1B) : Colors.grey.shade600)),
                        Icon(Icons.emergency_rounded, color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : Colors.grey.shade400, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activeAlerts.length}',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                    ),
                    Text(
                      activeAlerts.isNotEmpty ? 'Immediate response required' : 'All Laoag corridors normal',
                      style: TextStyle(fontSize: 11.5, color: activeAlerts.isNotEmpty ? const Color(0xFFB91C1C) : WebTheme.brandEmerald, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE TRICYCLES ON ROAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        const Icon(Icons.two_wheeler_rounded, color: WebTheme.brandEmerald, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${_driverDirectory.length} Units', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const Text('Approved & active in Laoag City', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LAOAG PNP STANDBY STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        const Icon(Icons.local_police_rounded, color: Color(0xFF2563EB), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('ONLINE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                    const Text('Hotline: (077) 772-0256 Ready', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Active Emergency SOS Beacons Card Table
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 22),
                        SizedBox(width: 10),
                        Text('Live Driver Distress Beacons (Laoag City Command Sentinel)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeAlerts.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activeAlerts.isNotEmpty ? '${activeAlerts.length} ACTIVE INCIDENT' : '✓ 0 ACTIVE DISTRESS',
                        style: TextStyle(
                          color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : WebTheme.brandEmerald,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_sosAlerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No emergency SOS beacons recorded. All drivers operating safely.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ..._sosAlerts.map((alert) {
                  final isActive = alert['status'] == 'ACTIVE_DISPATCHED';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFFFF7F7) : Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive ? Icons.emergency_rounded : Icons.check_circle_rounded,
                            color: isActive ? const Color(0xFFDC2626) : WebTheme.brandEmerald,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${alert['id']} • ${alert['driver_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      alert['status'],
                                      style: TextStyle(
                                        color: isActive ? const Color(0xFFDC2626) : WebTheme.brandEmerald,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Body ${alert['body_number']} • ${alert['plate_number']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text('Trigger: ${alert['alert_reason']} • ${alert['time_ago']}', style: const TextStyle(fontSize: 12)),
                              Text('GPS Coordinates: ${alert['latitude']}, ${alert['longitude']} (${alert['location_name']})', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (isActive) ...[
                              ElevatedButton.icon(
                                onPressed: _isPnpDispatchPaused
                                    ? null
                                    : () => _dispatchLaoagPnp(alert),
                                icon: const Icon(Icons.local_police_rounded, size: 15),
                                label: Text(
                                  _isPnpDispatchPaused
                                      ? 'Dispatch Paused'
                                      : 'Dispatch PNP',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade700,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _showSosIncidentModal(alert),
                                icon: const Icon(Icons.remove_red_eye_rounded, size: 15),
                                label: const Text('Inspect'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _resolveSosAlert(alert),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: WebTheme.brandEmerald,
                                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Resolve'),
                              ),
                            ] else ...[
                              Builder(
                                builder: (context) {
                                  final existingReport = _incidentReports.cast<Map<String, dynamic>?>().firstWhere(
                                        (r) => r?['sos_alert_id']?.toString() == alert['id'].toString(),
                                        orElse: () => null,
                                      );
                                  if (existingReport != null) {
                                    return TextButton.icon(
                                      onPressed: () => _showIncidentReportDetailModal(existingReport),
                                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                                      label: Text('Report ${existingReport['report_code']}'),
                                      style: TextButton.styleFrom(foregroundColor: WebTheme.brandEmerald),
                                    );
                                  }
                                  return OutlinedButton.icon(
                                    onPressed: () => _openResolveIncidentReportDialog(alert, isAlreadyResolved: true),
                                    icon: const Icon(Icons.note_add_rounded, size: 15),
                                    label: const Text('File Incident Report'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0284C7),
                                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Live Queue Board Section
        _buildTodaQueueBoardView(),
      ],
    );
  }

  Widget _buildEmergencySosSentinelBanner() {
    final activeAlerts = _sosAlerts.where((a) => a['status'] == 'ACTIVE_DISPATCHED').toList();
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    final topAlert = activeAlerts.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF2F2),
        border: Border(bottom: BorderSide(color: Color(0xFFF87171), width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ACTIVE EMERGENCY SOS (${activeAlerts.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${topAlert['driver_name']} (${topAlert['body_number']})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${topAlert['location_name']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Reason: ${topAlert['alert_reason']} • GPS: ${topAlert['latitude']}, ${topAlert['longitude']} • Triggered: ${topAlert['time_ago']}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showSosIncidentModal(topAlert),
            icon: const Icon(Icons.shield_rounded, size: 16),
            label: Text(
              _isPnpDispatchPaused
                  ? 'Inspect SOS (Dispatch Paused)'
                  : 'Inspect & Dispatch PNP',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _resolveSosAlert(topAlert),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingDataExportTab() {
    return _buildMlDemandView();
  }

}
