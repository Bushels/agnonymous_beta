import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/elevator_location.dart';
import '../../providers/elevator_locations_provider.dart';
import '../../providers/farmer_reports_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/reporting/social_proof_counter.dart';

final _logger = Logger(level: Level.debug);

/// Available commodities for price reporting.
const _commodities = [
  'Canola',
  'Wheat HRS',
  'Durum',
  'Barley',
  'Oats',
  'Peas',
  'Lentils',
  'Flaxseed',
  'Corn',
  'Soybeans',
];

/// Grade options for grain reports.
const _grades = ['#1', '#2', '#3', 'Feed', 'Sample'];

/// 3-step wizard for reporting a price at an elevator.
///
/// Accepts optional [elevatorLocationId], [elevatorName], and
/// [preselectedCommodity] to skip the elevator search step.
class ReportPriceScreen extends ConsumerStatefulWidget {
  final String? elevatorLocationId;
  final String? elevatorName;
  final String? preselectedCommodity;

  const ReportPriceScreen({
    super.key,
    this.elevatorLocationId,
    this.elevatorName,
    this.preselectedCommodity,
  });

  @override
  ConsumerState<ReportPriceScreen> createState() => _ReportPriceScreenState();
}

class _ReportPriceScreenState extends ConsumerState<ReportPriceScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Elevator selection
  String? _selectedElevatorId;
  String? _selectedElevatorName;
  String? _selectedElevatorCompany;
  String? _selectedElevatorCity;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Step 2: Price entry
  final TextEditingController _bidController = TextEditingController();
  String? _selectedCommodity;
  String? _selectedGrade;
  String _bidUnit = 'bushel'; // default
  final TextEditingController _notesController = TextEditingController();

  // Step 3: Publish (unused for now but reserved for future animation state)

  @override
  void initState() {
    super.initState();
    // Pre-fill if elevator info was passed in
    if (widget.elevatorLocationId != null) {
      _selectedElevatorId = widget.elevatorLocationId;
      _selectedElevatorName = widget.elevatorName;
      // Start at step 2 if elevator is pre-selected
      _currentStep = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(1);
      });
    }
    if (widget.preselectedCommodity != null) {
      _selectedCommodity = widget.preselectedCommodity;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _bidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedElevatorId != null;
      case 1:
        final bid = double.tryParse(_bidController.text);
        return bid != null && bid > 0 && _selectedCommodity != null;
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('You must be logged in to report a price.');
      }

      final bid = double.parse(_bidController.text);

      final data = {
        'reporter_id': userId,
        if (_selectedElevatorId != null)
          'elevator_location_id': _selectedElevatorId,
        'elevator_name': _selectedElevatorName ?? 'Unknown Elevator',
        'commodity': _selectedCommodity,
        if (_selectedGrade != null) 'grade': _selectedGrade,
        'reported_bid_cad': bid,
        'bid_unit': _bidUnit,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      };

      await submitPriceReport(supabase, data);

      // Invalidate elevator reports so they refresh
      if (_selectedElevatorId != null) {
        ref.invalidate(elevatorReportsProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Price reported! +3 reputation points',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF84CC16),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back after a short delay
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop(true); // true = report submitted
        }
      }
    } catch (e) {
      _logger.e('Error submitting price report', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSelectElevatorStep(),
                  _buildEnterPriceStep(),
                  _buildPublishStep(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // TOP BAR with back button and progress dots
  // ================================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 20),
              onPressed: _prevPage,
            )
          else
            IconButton(
              icon: const Icon(Icons.close,
                  color: Color(0xFF94A3B8), size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report a Price',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            children: List.generate(3, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Container(
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF84CC16)
                      : isCompleted
                          ? const Color(0xFF84CC16).withValues(alpha: 0.5)
                          : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BOTTOM NAV
  // ================================================================

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: GestureDetector(
                onTap: _prevPage,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Center(
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: GestureDetector(
              onTap: _canProceed
                  ? (isLastStep ? _submitReport : _nextPage)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _canProceed
                      ? const Color(0xFF84CC16)
                      : const Color(0xFF334155),
                  boxShadow: _canProceed
                      ? [
                          BoxShadow(
                            color: const Color(0xFF84CC16)
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isLastStep ? 'Publish Price' : 'Next',
                          style: GoogleFonts.inter(
                            color: _canProceed
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

  // ================================================================
  // STEP 1: Select Elevator
  // ================================================================

  Widget _buildSelectElevatorStep() {
    // Fetch elevators -- load all active elevators (up to 500)
    final elevatorsAsync = ref.watch(
      elevatorLocationsProvider(
        const ElevatorFilterParams(limit: 500),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Elevator',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Which elevator are you reporting a price for?',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ).animate().fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 20),

          // Search field
          GlassTextField(
            controller: _searchController,
            hintText: 'Search by name, city, or company...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),

          // Elevator list
          elevatorsAsync.when(
            data: (elevators) {
              final filtered = _filterElevators(elevators);
              if (filtered.isEmpty) {
                return _buildEmptySearchState();
              }
              return _buildElevatorList(filtered);
            },
            loading: () => _buildShimmerList(),
            error: (error, _) => _buildErrorCard(
              'Failed to load elevators. Please try again.',
            ),
          ),
        ],
      ),
    );
  }

  List<ElevatorLocation> _filterElevators(List<ElevatorLocation> elevators) {
    if (_searchQuery.isEmpty) return elevators;
    final query = _searchQuery.toLowerCase();
    return elevators.where((e) {
      return e.facilityName.toLowerCase().contains(query) ||
          e.company.toLowerCase().contains(query) ||
          e.city.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildElevatorList(List<ElevatorLocation> elevators) {
    return Column(
      children: elevators.take(20).map((elevator) {
        final isSelected = _selectedElevatorId == elevator.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedElevatorId = elevator.id;
                _selectedElevatorName = elevator.facilityName;
                _selectedElevatorCompany = elevator.company;
                _selectedElevatorCity = elevator.city;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF84CC16)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? const Color(0xFF84CC16).withValues(alpha: 0.08)
                    : const Color(0xFF1E293B).withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF84CC16).withValues(alpha: 0.15)
                          : elevator.companyColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store,
                      color: isSelected
                          ? const Color(0xFF84CC16)
                          : elevator.companyColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elevator.facilityName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${elevator.company} \u2022 ${elevator.city}, ${elevator.province}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF84CC16),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptySearchState() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.search_off,
              color: const Color(0xFF64748B), size: 48),
          const SizedBox(height: 12),
          Text(
            'No elevators found',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Column(
      children: List.generate(
        5,
        (i) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: Colors.white.withValues(alpha: 0.04),
        );
  }

  Widget _buildErrorCard(String message) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STEP 2: Enter Price
  // ================================================================

  Widget _buildEnterPriceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Price Details',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 8),
          if (_selectedElevatorName != null)
            Text(
              _selectedElevatorName!,
              style: GoogleFonts.inter(
                color: const Color(0xFF84CC16),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 24),

          // Commodity selection
          Text(
            'COMMODITY',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commodities.map((commodity) {
              final isSelected = _selectedCommodity == commodity;
              return GestureDetector(
                onTap: () => setState(() => _selectedCommodity = commodity),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected
                        ? const Color(0xFF84CC16).withValues(alpha: 0.15)
                        : const Color(0xFF1E293B),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF84CC16)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    commodity,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? const Color(0xFF84CC16)
                          : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Bid price input
          Text(
            'BID PRICE (CAD)',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Dollar sign prefix
              Container(
                height: 56,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Center(
                  child: Text(
                    'C\$',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF84CC16),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Text input
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _bidController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF475569),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Unit toggle (bushel / tonne)
          Text(
            'UNIT',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildUnitToggle('bushel', '\$/bushel'),
              const SizedBox(width: 8),
              _buildUnitToggle('tonne', '\$/tonne'),
            ],
          ),
          const SizedBox(height: 24),

          // Grade dropdown
          Text(
            'GRADE (OPTIONAL)',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _grades.map((grade) {
              final isSelected = _selectedGrade == grade;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedGrade = isSelected ? null : grade;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF1E293B),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    grade,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Notes
          Text(
            'NOTES (OPTIONAL)',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _notesController,
            hintText: 'e.g. "Price from office board", "Cash only"...',
            maxLines: 2,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(String unit, String label) {
    final isSelected = _bidUnit == unit;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bidUnit = unit),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? const Color(0xFF84CC16).withValues(alpha: 0.12)
                : const Color(0xFF1E293B),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF84CC16)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected
                    ? const Color(0xFF84CC16)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STEP 3: Publish
  // ================================================================

  Widget _buildPublishStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Publish',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 24),

          // Summary card
          GlassContainer(
            padding: const EdgeInsets.all(20),
            border: Border.all(
              color: const Color(0xFF84CC16).withValues(alpha: 0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Elevator
                Row(
                  children: [
                    const Icon(Icons.store,
                        color: Color(0xFF84CC16), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedElevatorName ?? 'Unknown Elevator',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedElevatorCompany != null ||
                    _selectedElevatorCity != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      [
                        _selectedElevatorCompany,
                        _selectedElevatorCity,
                      ].where((e) => e != null).join(' \u2022 '),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Commodity & Grade
                Row(
                  children: [
                    const Icon(Icons.grain,
                        color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCommodity ?? 'No Commodity',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedGrade != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF334155),
                        ),
                        child: Text(
                          _selectedGrade!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'C\$${_bidController.text}/${_bidUnit == 'bushel' ? 'bu' : 't'}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF84CC16),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                if (_notesController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes,
                          color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _notesController.text.trim(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate().fade(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Social proof counter
          const SocialProofCounter()
              .animate()
              .fade(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 16),

          // Info text
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'When 3 farmers confirm your price, it becomes a verified data point visible on the map.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fade(duration: 500.ms, delay: 300.ms),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
