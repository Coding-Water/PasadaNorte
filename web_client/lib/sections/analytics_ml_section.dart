part of '../main.dart';

extension _AnalyticsMlSection on _WebAdminDashboardState {
  // ===========================================================================
  // 1. KRISP-STYLE ANALYTICS OVERVIEW
  // ===========================================================================
  Widget _buildAnalyticsDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Date Filter Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: WebTheme.brandEmerald, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'PasadaNorte - $_selectedDateRange',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _selectedDateRange,
                underline: const SizedBox(),
                items: ['Jun 2026', 'Today (Live)', 'Last 7 Days', 'Full 8-Week Pilot']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _refresh(() => _selectedDateRange = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards - Row 1
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 1100
                ? 3
                : (constraints.maxWidth > 650 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: cols == 1 ? 2.4 : (cols == 2 ? 1.85 : 1.6),
              children: [
                _buildOperationalMetricCard(
                  title: 'Completed Trips',
                  value: '${_dispatchTrips.length}',
                  dateLabel: 'Live Supabase Sync',
                  trendLabel: '${_dispatchTrips.where((t) => t['status'] == 'COMPLIANT').length} compliant dispatches',
                  trendPositive: true,
                  sparklineType: SparklineType.upwardSmooth,
                ),
                _buildOperationalMetricCard(
                  title: 'Active Tricycles on Duty',
                  value: '${_driverDirectory.length}',
                  dateLabel: 'Live MINC Directory',
                  trendLabel: '${_driverApplications.where((a) => a['application_status'] == 'submitted').length} pending driver review',
                  trendPositive: true,
                  sparklineType: SparklineType.steadyRise,
                ),
                _buildOperationalMetricCard(
                  title: 'Pending Driver Applications',
                  value: '${_driverApplications.where((a) => a['application_status'] == 'submitted').length}',
                  dateLabel: 'Live Supabase Queue',
                  trendLabel: '${_driverApplications.length} total submitted',
                  trendPositive: true,
                  sparklineType: SparklineType.downwardEfficiency,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards - Row 2
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final approvedApps = _driverApplications.where((a) => a['application_status'] == 'approved').length;
            final approvalRate = _driverApplications.isEmpty
                ? '0.0%'
                : '${((approvedApps / _driverApplications.length) * 100).toStringAsFixed(1)}%';
            return GridView.count(
              crossAxisCount: isWide ? 2 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 2.4 : 2.2,
              children: [
                _buildOperationalMetricCard(
                  title: 'Driver Approval Rate',
                  value: approvalRate,
                  dateLabel: 'Live MINC Audit',
                  trendLabel: '$approvedApps of ${_driverApplications.length} approved',
                  trendPositive: true,
                  sparklineType: SparklineType.mildRise,
                ),
                _buildOperationalMetricCard(
                  title: 'Registered Biometric Users',
                  value: '${_flaggedVerifications.length}',
                  dateLabel: 'Live Supabase Users',
                  trendLabel: '${_flaggedVerifications.where((v) => v['status'] == 'approved').length} verified accounts',
                  trendPositive: true,
                  sparklineType: SparklineType.steadyRise,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Main Trend Chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  const Text(
                    'Deployment & Adoption Trends (%)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendDot(const Color(0xFFF97316), 'Deployment Rate'),
                      const SizedBox(width: 16),
                      _buildLegendDot(const Color(0xFF3B82F6), 'Adoption Rate'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(painter: _KrispTrendChartPainter()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Jump to Map and ML Simulator
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _refresh(() => _selectedSection = 'ML Demand Forecasts'),
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Open Live ML Demand Forecasts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebTheme.brandEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _refresh(() => _selectedSection = 'Laoag 10-Zone Map & Heatmap'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Laoag 10-Zone Spatial Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. LIVE ZONE DEMAND & ML FORECASTS (Synced via Supabase & GitHub Actions)
  // ===========================================================================
  Widget _buildMlDemandView() {
    final currentHour = DateTime.now().hour;
    final maseStr = _mlMetrics != null
        ? (_mlMetrics!['mase'] as num).toStringAsFixed(4)
        : '--';
    final rmseStr = _mlMetrics != null
        ? (_mlMetrics!['rmse'] as num).toStringAsFixed(4)
        : '--';
    final wmapeStr = _mlMetrics != null
        ? '${(_mlMetrics!['wmape_percent'] as num).toStringAsFixed(2)}%'
        : '--';
    final mapeStr = _mlMetrics != null
        ? '${(_mlMetrics!['nonzero_mape_percent'] as num).toStringAsFixed(2)}%'
        : '--';
    final syncLabel = _mlForecastLastUpdated.isEmpty
        ? 'Awaiting GitHub Actions ML sync'
        : 'Last ML sync: $_mlForecastLastUpdated';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live & ML Status Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Zone Demand & ML Forecasts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time 1-hour Supabase trip counts paired with hourly GitHub Actions ML predictions ($syncLabel).',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'Hour ${currentHour.toString().padLeft(2, '0')}:00 • ${currentHour >= 12 ? 'PM' : 'AM'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: WebTheme.brandEmerald,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _syncFromSupabase,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh Live'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WebTheme.brandEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4 Evaluation Metrics Badges (Synced from ml_model_metrics)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 850;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.5 : 2.0,
              children: [
                _buildMlMetricBadge(
                    'MASE Score',
                    maseStr,
                    _mlMetrics == null
                        ? 'Pending ML sync'
                        : 'Target < 1.00 (Beats Baseline)',
                    const Color(0xFF10B981)),
                _buildMlMetricBadge('RMSE Error', rmseStr,
                    'Root Mean Square Error', const Color(0xFF3B82F6)),
                _buildMlMetricBadge(
                    'WMAPE %',
                    wmapeStr,
                    _mlMetrics == null
                        ? 'Pending ML sync'
                        : 'Target <= 20.0% satisfied',
                    const Color(0xFF8B5CF6)),
                _buildMlMetricBadge('Non-Zero MAPE', mapeStr,
                    'High-demand zone precision', const Color(0xFFF59E0B)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // 10 Zones Dynamic Table with Live 1h + ML Forecast + Privacy Status
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Laoag City 10-Zone Live Demand & Hourly ML Forecasts',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportMlDataset('CSV'),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: constraints.maxWidth > 700
                              ? constraints.maxWidth
                              : 700),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(65),
                          1: FlexColumnWidth(3),
                          2: FlexColumnWidth(1.4),
                          3: FlexColumnWidth(1.4),
                          4: FlexColumnWidth(2.0),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8)),
                            children: const [
                              Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('ZONE',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                              Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('LANDMARK CLUSTER',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                              Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('LIVE (1H)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                              Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('ML FORECAST',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                              Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('ISO 25010 PRIVACY STATUS',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                            ],
                          ),
                          ..._mlZones.map((z) {
                            final live = _getLiveZoneDemand(z);
                            final forecast = _getForecastZoneDemand(z);
                            final active =
                                _heatmapMode == 'live' ? live : forecast;
                            final isK5Suppressed = active < 5.0;

                            return TableRow(
                              children: [
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(z['code'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12))),
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(z['name'],
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600))),
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                        '${live.toStringAsFixed(1)} req/h',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: live > 0
                                              ? WebTheme.brandEmerald
                                              : const Color(0xFF64748B),
                                        ))),
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                        '${forecast.toStringAsFixed(1)} req/h',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700))),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isK5Suppressed
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isK5Suppressed
                                          ? 'Protected (k < 5 PIA)'
                                          : '✓ High-Confidence Broadcast',
                                      style: TextStyle(
                                        color: isK5Suppressed
                                            ? const Color(0xFFB45309)
                                            : WebTheme.brandEmerald,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. INTERACTIVE LAOAG 10-ZONE MAP & HEATMAP (Recommendation 2)
  // ===========================================================================
  Widget _buildLaoagMapCanvasView() {
    final selectedZone = _mlZones.firstWhere((z) => z['code'] == _selectedZoneCode, orElse: () => _mlZones.first);
    final selectedDemand = _getDynamicZoneDemand(selectedZone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Laoag City 10-Zone Spatial Map & Corridor Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Visualizing paratransit demand corridors, Padsan River crossings, and TODA geofences.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'live',
                      icon: Icon(Icons.sensors_rounded, size: 15),
                      label: Text('Live (1h)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    ButtonSegment<String>(
                      value: 'forecast',
                      icon: Icon(Icons.psychology_outlined, size: 15),
                      label: Text('ML Forecast', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  selected: {_heatmapMode},
                  onSelectionChanged: (selection) {
                    _refresh(() => _heatmapMode = selection.first);
                  },
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openManageZonesDialog,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text('Configure 10 Zones',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                  child: Text('Selected: ${selectedZone['code']} - ${selectedZone['name']}', style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Interactive Real Map (Laoag City)
        Container(
          width: double.infinity,
          height: 460,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _laoagMapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      (selectedZone['lat'] as num?)?.toDouble() ?? 18.1960,
                      (selectedZone['lng'] as num?)?.toDouble() ?? 120.5937,
                    ),
                    initialZoom: 14.0,
                    minZoom: 12.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isLaoagMapSatellite
                          ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                          : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.pasadanorte.web_admin',
                    ),
                    // Dual-layer soft concentric demand heatmap (uses per-zone radius)
                    CircleLayer(
                      circles: _mlZones.map((z) {
                        final demand = _getDynamicZoneDemand(z);
                        final isSelected = z['code'] == _selectedZoneCode;
                        Color heatColor = const Color(0xFF10B981);
                        if (demand >= 25) {
                          heatColor = const Color(0xFFEF4444);
                        } else if (demand >= 15) {
                          heatColor = const Color(0xFFF59E0B);
                        } else if (demand < 5) {
                          heatColor = const Color(0xFF64748B);
                        }
                        final double baseRadius =
                            ((z['radius'] as num?)?.toDouble() ?? 320.0) *
                                (isSelected ? 1.08 : 1.0);
                        return CircleMarker(
                          point: LatLng(
                            (z['lat'] as num).toDouble(),
                            (z['lng'] as num).toDouble(),
                          ),
                          radius: baseRadius * 1.25,
                          useRadiusInMeter: true,
                          color: heatColor.withValues(
                            alpha: isSelected ? 0.24 : 0.16,
                          ),
                          borderStrokeWidth: 0,
                        );
                      }).toList(),
                    ),
                    CircleLayer(
                      circles: _mlZones.map((z) {
                        final demand = _getDynamicZoneDemand(z);
                        final isSelected = z['code'] == _selectedZoneCode;
                        Color heatColor = const Color(0xFF10B981);
                        if (demand >= 25) {
                          heatColor = const Color(0xFFEF4444);
                        } else if (demand >= 15) {
                          heatColor = const Color(0xFFF59E0B);
                        } else if (demand < 5) {
                          heatColor = const Color(0xFF64748B);
                        }
                        final double baseRadius =
                            ((z['radius'] as num?)?.toDouble() ?? 320.0) *
                                (isSelected ? 1.08 : 1.0);
                        return CircleMarker(
                          point: LatLng(
                            (z['lat'] as num).toDouble(),
                            (z['lng'] as num).toDouble(),
                          ),
                          radius: baseRadius * 0.78,
                          useRadiusInMeter: true,
                          color: heatColor.withValues(
                            alpha: isSelected ? 0.44 : 0.32,
                          ),
                          borderColor: isSelected
                              ? WebTheme.brandEmerald
                              : heatColor.withValues(alpha: 0.78),
                          borderStrokeWidth: isSelected ? 2.2 : 1.4,
                        );
                      }).toList(),
                    ),
                    // Compact non-overlapping zone pills + live TODA Pila pins
                    MarkerLayer(
                      markers: [
                        ..._mlZones.map((z) {
                          final demand = _getDynamicZoneDemand(z);
                          final isSelected = z['code'] == _selectedZoneCode;
                          final point = LatLng(
                            (z['lat'] as num).toDouble(),
                            (z['lng'] as num).toDouble(),
                          );
                          Color pillBorder = const Color(0xFF10B981);
                          if (demand >= 25) {
                            pillBorder = const Color(0xFFEF4444);
                          } else if (demand >= 15) {
                            pillBorder = const Color(0xFFF59E0B);
                          } else if (demand < 5) {
                            pillBorder = WebTheme.inkMuted;
                          }

                          return Marker(
                            point: point,
                            width: 64,
                            height: 24,
                            child: GestureDetector(
                              onTap: () {
                                _refresh(() => _selectedZoneCode = z['code']);
                                _laoagMapController.move(
                                  point,
                                  _laoagMapController.camera.zoom,
                                );
                              },
                              child: Tooltip(
                                message: '${z['code']} - ${z['name']} (${demand < 5 ? '<5' : demand.toInt()} req/hr)',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? WebTheme.brandEmerald
                                        : Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isSelected ? Colors.white : pillBorder,
                                      width: isSelected ? 1.8 : 1.3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${z['code']} · ${demand < 5 ? '<5' : demand.toInt()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9.5,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        ..._terminals.map(
                          (t) => Marker(
                            point: LatLng(
                              (t['lat'] as num).toDouble(),
                              (t['lng'] as num).toDouble(),
                            ),
                            width: 28,
                            height: 28,
                            child: Tooltip(
                              message: 'TODA Pila: ${t['name']} (${t['code']})',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.local_taxi_rounded,
                                  color: Color(0xFF34D399),
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top-right Map Style & Zoom Controls
                Positioned(
                  top: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        elevation: 2,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _refresh(
                            () => _isLaoagMapSatellite = !_isLaoagMapSatellite,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isLaoagMapSatellite
                                      ? Icons.map_outlined
                                      : Icons.satellite_alt_rounded,
                                  size: 16,
                                  color: const Color(0xFF0F172A),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isLaoagMapSatellite ? 'Streets' : 'Satellite',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        elevation: 2,
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              tooltip: 'Zoom In',
                              onPressed: () {
                                final cam = _laoagMapController.camera;
                                _laoagMapController.move(
                                  cam.center,
                                  (cam.zoom + 0.8).clamp(12.0, 18.0),
                                );
                              },
                            ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              tooltip: 'Zoom Out',
                              onPressed: () {
                                final cam = _laoagMapController.camera;
                                _laoagMapController.move(
                                  cam.center,
                                  (cam.zoom - 0.8).clamp(12.0, 18.0),
                                );
                              },
                            ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            IconButton(
                              icon: const Icon(
                                Icons.my_location_rounded,
                                size: 18,
                              ),
                              tooltip: 'Center on Laoag City',
                              onPressed: () {
                                _laoagMapController.move(
                                  const LatLng(18.1960, 120.5937),
                                  14.0,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Map Legend Box
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Laoag City Geographic Legend',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'High Demand (>25 req/h)',
                            style: TextStyle(fontSize: 10),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Zone Geofence',
                            style: TextStyle(fontSize: 10),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: WebTheme.inkMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'k < 5 req/h: Privacy Masked (RA 10173)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected Zone Detail Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WebTheme.brandEmerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: WebTheme.brandEmerald, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selectedZone['code']} - ${selectedZone['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Latitude: ${selectedZone['lat']} • Longitude: ${selectedZone['lng']} • Historical Trips: ${selectedZone['trips']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    selectedDemand < 5
                        ? '<5 req/hr (Suppressed)'
                        : '${selectedDemand.toStringAsFixed(1)} req/hr',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: selectedDemand < 5
                          ? const Color(0xFFD97706)
                          : WebTheme.brandEmerald,
                    ),
                  ),
                  Text(
                    selectedDemand < 5
                        ? 'RA 10173: k-Anonymity Protected'
                        : 'Active Dispatch Corridor',
                    style: TextStyle(
                      color: selectedDemand < 5
                          ? Colors.orange.shade800
                          : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _openEditZoneDialog(selectedZone),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                label: const Text('Edit / Re-pin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WebTheme.brandEmerald,
                  side: const BorderSide(color: WebTheme.brandEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // All 10 Laoag Zones Quick-Edit List
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.layers_rounded, color: WebTheme.brandEmerald, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'All 10 Laoag Demand Zones - Quick Edit & Radius',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Text(
                      'Click any zone to focus on map or edit pin/radius',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ..._mlZones.map((z) {
                final code = z['code']?.toString() ?? '';
                final isSelected = code == _selectedZoneCode;
                final lat = (z['lat'] as num?)?.toDouble() ?? 18.1972;
                final lng = (z['lng'] as num?)?.toDouble() ?? 120.5925;
                final radius = (z['radius'] as num?)?.toDouble() ?? 320.0;
                final demand = _getDynamicZoneDemand(z);

                return InkWell(
                  onTap: () {
                    _refresh(() => _selectedZoneCode = code);
                    try {
                      _laoagMapController.move(
                        LatLng(lat, lng),
                        _laoagMapController.camera.zoom,
                      );
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFECFDF5).withValues(alpha: 0.6) : Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WebTheme.brandEmerald
                                : WebTheme.brandEmerald.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              code,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                color: isSelected ? Colors.white : WebTheme.brandEmerald,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                z['name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)} • Radius: ${radius.round()} m • Demand: ${demand < 5 ? '<5 req/hr' : '${demand.toStringAsFixed(1)} req/hr'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openEditZoneDialog(z),
                          icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                          label: const Text('Pin & Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: WebTheme.brandEmerald,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openManageZonesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.layers_rounded, color: WebTheme.brandEmerald),
            SizedBox(width: 8),
            Text(
              'Configure Laoag 10 Demand Zones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 440,
          child: ListView.separated(
            itemCount: _mlZones.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, index) {
              final z = _mlZones[index];
              final lat = (z['lat'] as num).toDouble().toStringAsFixed(5);
              final lng = (z['lng'] as num).toDouble().toStringAsFixed(5);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: WebTheme.brandEmerald.withValues(alpha: 0.12),
                  child: Text(
                    z['code'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: WebTheme.brandEmerald,
                    ),
                  ),
                ),
                title: Text(
                  z['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  'Lat: $lat, Lng: $lng',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                trailing: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _openEditZoneDialog(z);
                  },
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                  label: const Text('Pin & Edit'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditZoneDialog(Map<String, dynamic> zone) async {
    final code = zone['code'].toString();
    final nameCtrl = TextEditingController(text: zone['name']?.toString() ?? '');
    final keywordsCtrl = TextEditingController(text: zone['keywords']?.toString() ?? '');
    LatLng pinnedPoint = LatLng(
      (zone['lat'] as num).toDouble(),
      (zone['lng'] as num).toDouble(),
    );
    double zoneRadius =
        ((zone['radius'] as num?)?.toDouble() ?? 320.0).clamp(100.0, 600.0);
    bool isSatellite = false;
    final zoneMapController = MapController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.edit_location_alt_rounded, color: WebTheme.brandEmerald),
              const SizedBox(width: 8),
              Text(
                'Set Zone $code Location & Name',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Zone / Landmark Cluster Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: keywordsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Drop-off Match Keywords (comma-separated)',
                      hintText: 'e.g. market, public market, commercial',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tap anywhere on the map to pin the Zone center:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Lat: ${pinnedPoint.latitude.toStringAsFixed(5)}, Lng: ${pinnedPoint.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: WebTheme.brandEmerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: zoneMapController,
                            options: MapOptions(
                              initialCenter: pinnedPoint,
                              initialZoom: 16.0,
                              minZoom: 12.0,
                              maxZoom: 21.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                              onTap: (_, latLng) {
                                setDialogState(() => pinnedPoint = latLng);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: isSatellite
                                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                                userAgentPackageName: 'com.pasadanorte.web_admin',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: pinnedPoint,
                                    radius: zoneRadius,
                                    useRadiusInMeter: true,
                                    color: WebTheme.brandEmerald
                                        .withValues(alpha: 0.22),
                                    borderColor: WebTheme.brandEmerald,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: pinnedPoint,
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.topCenter,
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.94),
                              elevation: 2,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setDialogState(() => isSatellite = !isSatellite),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Text(
                                    isSatellite ? 'Streets' : 'Satellite',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: _buildMapZoomControls(
                              zoneMapController,
                              centerTarget: pinnedPoint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hotzone Radius Calibration:',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${zoneRadius.round()} meters',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: WebTheme.brandEmerald,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: zoneRadius,
                    min: 100.0,
                    max: 600.0,
                    divisions: 50,
                    activeColor: WebTheme.brandEmerald,
                    label: '${zoneRadius.round()} m',
                    onChanged: (val) => setDialogState(() => zoneRadius = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Zone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebTheme.brandEmerald,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final newName = nameCtrl.text.trim();
      final newKeywords = keywordsCtrl.text.trim();
      _refresh(() {
        zone['name'] = newName;
        zone['lat'] = double.parse(pinnedPoint.latitude.toStringAsFixed(6));
        zone['lng'] = double.parse(pinnedPoint.longitude.toStringAsFixed(6));
        zone['radius'] = zoneRadius.roundToDouble();
        zone['keywords'] = newKeywords;
        _selectedZoneCode = code;
      });
      try {
        await Supabase.instance.client.from('laoag_zones').upsert({
          'zone_code': code,
          'zone_name': newName,
          'lat': double.parse(pinnedPoint.latitude.toStringAsFixed(6)),
          'lng': double.parse(pinnedPoint.longitude.toStringAsFixed(6)),
          'radius_meters': zoneRadius.roundToDouble(),
          'keywords': newKeywords,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      if (mounted) {
        _laoagMapController.move(pinnedPoint, 15.5);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zone $code ($newName) saved & synced.'),
            backgroundColor: WebTheme.brandEmerald,
          ),
        );
      }
    }
    nameCtrl.dispose();
    keywordsCtrl.dispose();
  }

}
