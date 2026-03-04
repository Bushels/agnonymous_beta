import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/farm_profile.dart';
import '../../models/crop_plan.dart';
import '../../providers/my_farm_provider.dart';
import '../../widgets/glass_container.dart';

final _logger = Logger(level: Level.debug);

/// Available crops for selection during onboarding.
const _availableCrops = [
  'Canola',
  'Wheat HRS',
  'Barley',
  'Oats',
  'Peas',
  'Lentils',
  'Flaxseed',
  'Corn',
  'Soybeans',
  'Durum',
];

/// Province pre-selections: top 3 crops per province.
const _provinceDefaults = {
  'MB': ['Canola', 'Wheat HRS', 'Soybeans'],
  'SK': ['Canola', 'Wheat HRS', 'Lentils'],
  'AB': ['Canola', 'Wheat HRS', 'Barley'],
};

/// Province full names for display.
const _provinceNames = {
  'SK': 'Saskatchewan',
  'AB': 'Alberta',
  'MB': 'Manitoba',
};

/// Crop icon mapping.
const _cropIcons = {
  'Canola': Icons.eco,
  'Wheat HRS': Icons.grass,
  'Barley': Icons.grain,
  'Oats': Icons.spa,
  'Peas': Icons.circle,
  'Lentils': Icons.lens,
  'Flaxseed': Icons.local_florist,
  'Corn': Icons.energy_savings_leaf,
  'Soybeans': Icons.water_drop,
  'Durum': Icons.grass,
};

/// Cost field labels for the cost entry step.
const _costFields = [
  ('seedCostPerAcre', 'Seed', Icons.agriculture),
  ('fertilizerCostPerAcre', 'Fertilizer', Icons.science),
  ('chemicalCostPerAcre', 'Chemical', Icons.medication),
  ('fuelCostPerAcre', 'Fuel', Icons.local_gas_station),
  ('cropInsuranceCostPerAcre', 'Crop Insurance', Icons.security),
  ('landCostPerAcre', 'Land', Icons.landscape),
  ('equipmentCostPerAcre', 'Equipment', Icons.precision_manufacturing),
  ('labourCostPerAcre', 'Labour', Icons.people),
  ('otherCostPerAcre', 'Other', Icons.more_horiz),
];

/// My Farm onboarding: 4-step flow to set up farm profile and crop plans.
class MyFarmOnboardingScreen extends ConsumerStatefulWidget {
  const MyFarmOnboardingScreen({super.key});

  @override
  ConsumerState<MyFarmOnboardingScreen> createState() =>
      _MyFarmOnboardingScreenState();
}

class _MyFarmOnboardingScreenState
    extends ConsumerState<MyFarmOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1: Province
  String? _selectedProvince;

  // Step 2: Crops
  final Map<String, bool> _selectedCrops = {};
  final Map<String, TextEditingController> _acresControllers = {};
  final Map<String, TextEditingController> _yieldControllers = {};

  // Step 3: Costs — map of commodity -> field key -> controller
  final Map<String, Map<String, TextEditingController>> _costControllers = {};

  @override
  void initState() {
    super.initState();
    for (final crop in _availableCrops) {
      _selectedCrops[crop] = false;
      _acresControllers[crop] = TextEditingController();
      _yieldControllers[crop] = TextEditingController();
      _costControllers[crop] = {};
      for (final (key, _, _) in _costFields) {
        _costControllers[crop]![key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _acresControllers.values) {
      c.dispose();
    }
    for (final c in _yieldControllers.values) {
      c.dispose();
    }
    for (final cropCosts in _costControllers.values) {
      for (final c in cropCosts.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  List<String> get _selectedCropList =>
      _selectedCrops.entries.where((e) => e.value).map((e) => e.key).toList();

  void _nextPage() {
    if (_currentStep < 3) {
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
        return _selectedProvince != null;
      case 1:
        return _selectedCropList.isNotEmpty;
      case 2:
        return true; // costs are optional
      case 3:
        return true;
      default:
        return false;
    }
  }

  /// Apply provincial defaults when a province is selected.
  void _onProvinceSelected(String province) {
    setState(() {
      _selectedProvince = province;

      // Reset all crops and pre-select province defaults
      for (final crop in _availableCrops) {
        _selectedCrops[crop] = false;
      }
      final defaults = _provinceDefaults[province] ?? [];
      for (final crop in defaults) {
        _selectedCrops[crop] = true;
      }
    });
  }

  /// Pre-populate costs from provincial defaults for selected crops.
  void _applyProvincialDefaults(List<ProvincialCostDefault> defaults) {
    for (final def in defaults) {
      final crop = def.commodity;
      if (_costControllers.containsKey(crop)) {
        final controllers = _costControllers[crop]!;
        _setControllerValue(controllers['seedCostPerAcre'], def.seedCostPerAcre);
        _setControllerValue(controllers['fertilizerCostPerAcre'], def.fertilizerCostPerAcre);
        _setControllerValue(controllers['chemicalCostPerAcre'], def.chemicalCostPerAcre);
        _setControllerValue(controllers['fuelCostPerAcre'], def.fuelCostPerAcre);
        _setControllerValue(controllers['cropInsuranceCostPerAcre'], def.cropInsuranceCostPerAcre);
        _setControllerValue(controllers['landCostPerAcre'], def.landCostPerAcre);
        _setControllerValue(controllers['equipmentCostPerAcre'], def.equipmentCostPerAcre);
        _setControllerValue(controllers['labourCostPerAcre'], def.labourCostPerAcre);
        _setControllerValue(controllers['otherCostPerAcre'], def.otherCostPerAcre);

        // Also set yield from defaults
        if (def.defaultYieldBuPerAcre != null) {
          _yieldControllers[crop]?.text =
              def.defaultYieldBuPerAcre!.toStringAsFixed(1);
        }
      }
    }
    setState(() {}); // Rebuild to show updated values
  }

  void _setControllerValue(TextEditingController? controller, double? value) {
    if (controller == null || value == null) return;
    controller.text = value.toStringAsFixed(2);
  }

  /// Build a CropPlan from the current form state for a given commodity.
  CropPlan _buildCropPlan(String commodity, String farmProfileId) {
    final costs = _costControllers[commodity]!;
    return CropPlan(
      id: '', // will be assigned by DB
      farmProfileId: farmProfileId,
      commodity: commodity,
      plannedAcres: double.tryParse(_acresControllers[commodity]?.text ?? ''),
      targetYieldBuPerAcre:
          double.tryParse(_yieldControllers[commodity]?.text ?? ''),
      seedCostPerAcre:
          double.tryParse(costs['seedCostPerAcre']?.text ?? ''),
      fertilizerCostPerAcre:
          double.tryParse(costs['fertilizerCostPerAcre']?.text ?? ''),
      chemicalCostPerAcre:
          double.tryParse(costs['chemicalCostPerAcre']?.text ?? ''),
      fuelCostPerAcre:
          double.tryParse(costs['fuelCostPerAcre']?.text ?? ''),
      cropInsuranceCostPerAcre:
          double.tryParse(costs['cropInsuranceCostPerAcre']?.text ?? ''),
      landCostPerAcre:
          double.tryParse(costs['landCostPerAcre']?.text ?? ''),
      equipmentCostPerAcre:
          double.tryParse(costs['equipmentCostPerAcre']?.text ?? ''),
      labourCostPerAcre:
          double.tryParse(costs['labourCostPerAcre']?.text ?? ''),
      otherCostPerAcre:
          double.tryParse(costs['otherCostPerAcre']?.text ?? ''),
      costsSource: 'custom',
    );
  }

  /// Save farm profile and crop plans to Supabase, then navigate to dashboard.
  Future<void> _saveFarmData() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upsert farm profile
      final profileData = {
        'user_id': userId,
        'province': _selectedProvince!,
        'engagement_level': 2,
      };

      final profileResponse = await supabase
          .from('farm_profiles')
          .upsert(profileData, onConflict: 'user_id')
          .select()
          .single();

      final farmProfileId = profileResponse['id'] as String;

      // Upsert crop plans
      final crops = _selectedCropList;
      for (final commodity in crops) {
        final plan = _buildCropPlan(commodity, farmProfileId);
        final insertMap = plan.toInsertMap();
        await supabase.from('crop_plans').upsert(
          insertMap,
          onConflict: 'farm_profile_id,crop_year,commodity',
        );
      }

      // Invalidate providers to refresh data
      ref.invalidate(farmProfileProvider);
      ref.invalidate(cropPlansProvider);
      ref.invalidate(hasFarmProfileProvider);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('Error saving farm data', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving farm data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
            // Top bar with back/progress
            _buildTopBar(),

            // Step content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildProvinceStep(),
                  _buildCropSelectionStep(),
                  _buildCostEntryStep(),
                  _buildBreakevenDashboard(),
                ],
              ),
            ),

            // Bottom navigation
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: _prevPage,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Set Up My Farm',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Progress dots
          Row(
            children: List.generate(4, (index) {
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

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == 3;

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
                    border: Border.all(
                      color: const Color(0xFF334155),
                    ),
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
            child: GlowingButton(
              onTap: _canProceed
                  ? (isLastStep ? _saveFarmData : _nextPage)
                  : null,
              isLoading: _isSaving,
              color: _canProceed
                  ? const Color(0xFF84CC16)
                  : const Color(0xFF334155),
              height: 48,
              borderRadius: BorderRadius.circular(12),
              child: Text(
                isLastStep ? 'Done — Go to Dashboard' : 'Next',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 1: Province Selection
  // ============================================================

  Widget _buildProvinceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where is your farm?',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Select your province to load regional cost defaults.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ).animate().fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 32),
          ...FarmProfile.validProvinces.asMap().entries.map((entry) {
            final index = entry.key;
            final province = entry.value;
            final isSelected = _selectedProvince == province;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _onProvinceSelected(province),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF84CC16)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? const Color(0xFF84CC16).withValues(alpha: 0.08)
                        : const Color(0xFF1E293B).withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF84CC16).withValues(alpha: 0.15)
                              : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: isSelected
                              ? const Color(0xFF84CC16)
                              : const Color(0xFF64748B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              province,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _provinceNames[province] ?? province,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF84CC16),
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            ).animate().fade(
                  duration: 300.ms,
                  delay: (80 * index).ms,
                ).slideX(begin: 0.05);
          }),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2: Crop Selection
  // ============================================================

  Widget _buildCropSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you grow?',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Select your crops and enter planned acres.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ).animate().fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableCrops.asMap().entries.map((entry) {
                  final index = entry.key;
                  final crop = entry.value;
                  final isSelected = _selectedCrops[crop] == true;
                  final cardWidth =
                      (constraints.maxWidth - (crossAxisCount - 1) * 10) /
                          crossAxisCount;

                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCrops[crop] = !isSelected;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  _cropIcons[crop] ?? Icons.eco,
                                  color: isSelected
                                      ? const Color(0xFF84CC16)
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF84CC16),
                                    size: 18,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              crop,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 36,
                                child: TextFormField(
                                  controller: _acresControllers[crop],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[\d.]')),
                                  ],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Acres',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF84CC16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(
                        duration: 300.ms,
                        delay: (50 * index).ms,
                      );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: Cost Entry
  // ============================================================

  Widget _buildCostEntryStep() {
    final crops = _selectedCropList;
    final province = _selectedProvince;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your costs',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
              const SizedBox(height: 8),
              Text(
                'Per-acre costs for each crop. We pre-filled provincial averages.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ).animate().fade(duration: 400.ms, delay: 50.ms),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Auto-load provincial defaults
        if (province != null)
          Consumer(
            builder: (context, ref, _) {
              final defaults = ref.watch(provincialDefaultsProvider(province));
              return defaults.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFF84CC16),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => ref.invalidate(
                        provincialDefaultsProvider(province)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Could not load provincial defaults. Tap to retry.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF59E0B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (defaults) {
                  // Auto-apply defaults on first load
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (defaults.isNotEmpty) {
                      _applyProvincialDefaults(defaults);
                    }
                  });
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: crops.length,
            itemBuilder: (context, index) {
              return _buildCropCostCard(crops[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCropCostCard(String commodity, int index) {
    final costs = _costControllers[commodity]!;
    final yieldController = _yieldControllers[commodity]!;

    // Build a temporary CropPlan for live calculations
    final plan = _buildCropPlan(commodity, '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        blur: 10,
        opacity: 0.08,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _cropIcons[commodity] ?? Icons.eco,
                  color: const Color(0xFF84CC16),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  commodity,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Reset to provincial average button
                if (_selectedProvince != null)
                  GestureDetector(
                    onTap: () {
                      final prov = _selectedProvince!;
                      final defaults =
                          ref.read(provincialDefaultsProvider(prov));
                      defaults.whenData((defs) {
                        final match = defs
                            .where((d) => d.commodity == commodity)
                            .toList();
                        if (match.isNotEmpty) {
                          _applyProvincialDefaults(match);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                      child: Text(
                        'Reset',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Yield input
            Row(
              children: [
                Text(
                  'Target Yield (bu/ac):',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  height: 34,
                  child: TextFormField(
                    controller: yieldController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF84CC16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cost fields
            ...(_costFields.map((field) {
              final (key, label, icon) = field;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFF64748B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      height: 32,
                      child: TextFormField(
                        controller: costs[key],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFF84CC16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })),

            // Running totals
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Cost/ac',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${plan.calculatedTotalCost.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Breakeven/bu',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.calculatedBreakeven != null
                            ? '\$${plan.calculatedBreakeven!.toStringAsFixed(2)}'
                            : '--',
                        style: GoogleFonts.outfit(
                          color: plan.calculatedBreakeven != null
                              ? const Color(0xFF84CC16)
                              : const Color(0xFF64748B),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms, delay: (80 * index).ms).slideY(begin: 0.05);
  }

  // ============================================================
  // STEP 4: Breakeven Dashboard
  // ============================================================

  Widget _buildBreakevenDashboard() {
    final crops = _selectedCropList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Breakeven Summary',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'See if selling today makes money. These numbers update as market data flows in.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ).animate().fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 24),
          ...crops.asMap().entries.map((entry) {
            final index = entry.key;
            final commodity = entry.value;
            final plan = _buildCropPlan(commodity, '');
            final breakeven = plan.calculatedBreakeven;
            final totalCost = plan.calculatedTotalCost;
            final yield_ = double.tryParse(
                _yieldControllers[commodity]?.text ?? '');

            // Color coding: grey if no data, green positive
            Color cardColor;
            Color textColor;
            if (breakeven == null) {
              cardColor = const Color(0xFF64748B);
              textColor = const Color(0xFF94A3B8);
            } else {
              cardColor = const Color(0xFF84CC16);
              textColor = const Color(0xFF84CC16);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LuxuryGlassContainer(
                blur: 12,
                opacity: 0.08,
                glowColor: cardColor,
                glowIntensity: 0.15,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Crop icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _cropIcons[commodity] ?? Icons.eco,
                        color: cardColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commodity,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Cost: \$${totalCost.toStringAsFixed(2)}/ac',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              if (yield_ != null && yield_ > 0) ...[
                                const SizedBox(width: 12),
                                Text(
                                  'Yield: ${yield_.toStringAsFixed(0)} bu/ac',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Breakeven price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          breakeven != null
                              ? '\$${breakeven.toStringAsFixed(2)}'
                              : '--',
                          style: GoogleFonts.outfit(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '/bu',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fade(
                  duration: 300.ms,
                  delay: (100 * index).ms,
                ).slideY(begin: 0.1);
          }),
        ],
      ),
    );
  }
}
