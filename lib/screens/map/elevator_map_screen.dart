import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster_plus/flutter_map_marker_cluster_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/elevator_location.dart';
import '../../providers/elevator_locations_provider.dart';
import '../../providers/my_farm_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/map/elevator_detail_sheet.dart';

/// Interactive map of licensed grain elevators across the prairies.
class ElevatorMapScreen extends ConsumerStatefulWidget {
  const ElevatorMapScreen({super.key});

  @override
  ConsumerState<ElevatorMapScreen> createState() => _ElevatorMapScreenState();
}

class _ElevatorMapScreenState extends ConsumerState<ElevatorMapScreen> {
  /// Currently selected province filter (null = show all).
  String? _selectedProvince;

  /// MapController for programmatic pan/zoom.
  final MapController _mapController = MapController();

  // Default center: central Saskatchewan.
  static const _defaultCenter = LatLng(52.0, -106.0);
  static const _defaultZoom = 6.0;

  @override
  Widget build(BuildContext context) {
    final params = ElevatorFilterParams(province: _selectedProvince);
    final elevatorsAsync = ref.watch(elevatorLocationsProvider(params));
    final farmProfile = ref.watch(farmProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // --- Map layer ---
          elevatorsAsync.when(
            loading: () => _buildLoadingMap(),
            error: (err, _) => _buildErrorState(err),
            data: (elevators) => _buildMap(elevators, farmProfile),
          ),

          // --- Province filter chips ---
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: _buildFilterChips(),
            ),
          ),

          // --- Elevator count badge ---
          if (elevatorsAsync.hasValue)
            Positioned(
              bottom: 16,
              left: 16,
              child: _buildCountBadge(elevatorsAsync.value!.length),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------
  Widget _buildFilterChips() {
    const provinces = [null, 'SK', 'AB', 'MB'];
    const labels = ['All', 'SK', 'AB', 'MB'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(provinces.length, (i) {
          final isSelected = _selectedProvince == provinces[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                labels[i],
                style: GoogleFonts.inter(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedProvince = provinces[i]);
              },
              backgroundColor:
                  const Color(0xFF1E293B).withValues(alpha: 0.85),
              selectedColor: const Color(0xFF84CC16),
              checkmarkColor: const Color(0xFF0F172A),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF84CC16)
                    : const Color(0xFF334155),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: -0.3);
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------
  Widget _buildMap(
    List<ElevatorLocation> elevators,
    AsyncValue<dynamic> farmProfileAsync,
  ) {
    // Build markers from elevator data.
    final markers = elevators.map((e) => _elevatorMarker(e)).toList();

    // Farm location for distance rings + farm pin.
    // FarmProfile does not yet have lat/lng fields; when the model is
    // extended, populate farmLatLng from the profile here.
    final farmLatLng = _extractFarmLatLng(farmProfileAsync);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: farmLatLng ?? _defaultCenter,
        initialZoom: farmLatLng != null ? 8.0 : _defaultZoom,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: const Color(0xFF0F172A),
      ),
      children: [
        // Dark basemap tiles
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.agnonymous.beta',
          retinaMode: true,
        ),

        // Distance rings when farm location is available
        if (farmLatLng != null) ...[
          CircleLayer(
            circles: [
              // 25 km ring
              CircleMarker(
                point: farmLatLng,
                radius: 25000,
                useRadiusInMeter: true,
                color: const Color(0xFF84CC16).withValues(alpha: 0.04),
                borderStrokeWidth: 1.0,
                borderColor: const Color(0xFF84CC16).withValues(alpha: 0.25),
              ),
              // 50 km ring
              CircleMarker(
                point: farmLatLng,
                radius: 50000,
                useRadiusInMeter: true,
                color: const Color(0xFF84CC16).withValues(alpha: 0.02),
                borderStrokeWidth: 1.0,
                borderColor: const Color(0xFF84CC16).withValues(alpha: 0.15),
              ),
              // 100 km ring
              CircleMarker(
                point: farmLatLng,
                radius: 100000,
                useRadiusInMeter: true,
                color: Colors.transparent,
                borderStrokeWidth: 1.0,
                borderColor: const Color(0xFF84CC16).withValues(alpha: 0.08),
              ),
            ],
          ),
        ],

        // Farm pin
        if (farmLatLng != null)
          MarkerLayer(
            markers: [
              Marker(
                point: farmLatLng,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF84CC16).withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

        // Clustered elevator markers
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 60,
            size: const Size(40, 40),
            markers: markers,
            builder: (context, clusterMarkers) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF84CC16).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF84CC16).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${clusterMarkers.length}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Extract farm location from the farm profile async value.
  /// Returns null until FarmProfile model gains lat/lng fields.
  LatLng? _extractFarmLatLng(AsyncValue<dynamic> farmProfileAsync) {
    // FarmProfile does not currently expose latitude/longitude.
    // When the model is extended, return LatLng(profile.lat, profile.lng).
    return null;
  }

  /// Creates a 32px circular marker for a single elevator.
  Marker _elevatorMarker(ElevatorLocation elevator) {
    return Marker(
      point: LatLng(elevator.latitude, elevator.longitude),
      width: 32,
      height: 32,
      child: GestureDetector(
        onTap: () => _showElevatorDetail(elevator),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(
              color: elevator.companyColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: elevator.companyColor.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            _facilityIcon(elevator.facilityType),
            color: elevator.companyColor,
            size: 14,
          ),
        ),
      ),
    );
  }

  IconData _facilityIcon(String facilityType) {
    switch (facilityType) {
      case 'terminal':
        return Icons.warehouse;
      case 'process':
        return Icons.factory;
      default:
        return Icons.grain;
    }
  }

  // ---------------------------------------------------------------------------
  // Elevator detail bottom sheet
  // ---------------------------------------------------------------------------
  void _showElevatorDetail(ElevatorLocation elevator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ElevatorDetailSheet(elevator: elevator),
    );
  }

  // ---------------------------------------------------------------------------
  // Count badge
  // ---------------------------------------------------------------------------
  Widget _buildCountBadge(int count) {
    return GlassContainer(
      blur: 10,
      opacity: 0.15,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grain, color: Color(0xFF84CC16), size: 14),
          const SizedBox(width: 6),
          Text(
            '$count elevator${count == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 200.ms);
  }

  // ---------------------------------------------------------------------------
  // Loading / Error states
  // ---------------------------------------------------------------------------
  Widget _buildLoadingMap() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: const Color(0xFF0F172A),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.agnonymous.beta',
          retinaMode: true,
        ),
        // Centered loading indicator
        const _MapOverlayWidget(
          child: CircularProgressIndicator(color: Color(0xFF84CC16)),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load elevators',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$err',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                // Invalidate the provider to retry.
                ref.invalidate(elevatorLocationsProvider(
                  ElevatorFilterParams(province: _selectedProvince),
                ));
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF84CC16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple widget to overlay a child on the center of the map.
class _MapOverlayWidget extends StatelessWidget {
  final Widget child;
  const _MapOverlayWidget({required this.child});

  @override
  Widget build(BuildContext context) {
    // We use Align to place the child in the centre of the map.
    // FlutterMap children that are not recognized layers are overlaid directly.
    return Center(child: child);
  }
}
