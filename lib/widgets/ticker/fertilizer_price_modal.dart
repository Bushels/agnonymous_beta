/// Fertilizer Price Submission Modal
/// Bottom sheet for posting fertilizer prices to the ticker
library;

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../main.dart' show PROVINCES_STATES;
import '../../models/fertilizer_ticker_models.dart';
import '../../providers/fertilizer_ticker_provider.dart';

/// Show the fertilizer price submission modal
Future<void> showFertilizerPriceModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const FertilizerPriceModal(),
  );
}

class FertilizerPriceModal extends ConsumerStatefulWidget {
  const FertilizerPriceModal({super.key});

  @override
  ConsumerState<FertilizerPriceModal> createState() => _FertilizerPriceModalState();
}

class _FertilizerPriceModalState extends ConsumerState<FertilizerPriceModal> {
  FertilizerType _selectedType = FertilizerType.urea46;
  String _selectedProvinceState = 'Alberta';
  late WeightUnit _selectedUnit;
  late TickerCurrency _selectedCurrency;
  DeliveryMode _selectedDeliveryMode = DeliveryMode.pickedUp;

  final _priceController = TextEditingController();
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _updateDefaults();
  }

  void _updateDefaults() {
    _selectedUnit = defaultUnitForProvinceState(_selectedProvinceState);
    _selectedCurrency = defaultCurrencyForProvinceState(_selectedProvinceState);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onProvinceChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedProvinceState = value;
        _updateDefaults();
      });
    }
  }

  Future<void> _submitPrice() async {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await ref.read(fertilizerPriceSubmissionProvider.notifier).submitPrice(
      fertilizerType: _selectedType,
      price: price,
      unit: _selectedUnit,
      currency: _selectedCurrency,
      provinceState: _selectedProvinceState,
      deliveryMode: _selectedDeliveryMode,
    );

    if (success && mounted) {
      // Trigger confetti
      _confettiController.play();
      
      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Delay popping to show confetti
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      
      // Show success and close
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Price sent to ticker! 🚀'),
            ],
          ),
          backgroundColor: const Color(0xFF84CC16),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(fertilizerPriceSubmissionProvider);
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF84CC16).withOpacity(0.2),
                            const Color(0xFF84CC16).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.dollarSign,
                        color: Color(0xFF84CC16),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post Fertilizer Price',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Anonymous • Updates ticker instantly',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Fertilizer Type Selection
                Text(
                  'FERTILIZER TYPE',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTypeChip(FertilizerType.urea46),
                    const SizedBox(width: 8),
                    _buildTypeChip(FertilizerType.nh3),
                    const SizedBox(width: 8),
                    _buildTypeChip(FertilizerType.s15),
                  ],
                ),
                const SizedBox(height: 20),

                // Delivery Mode
                Text(
                  'DELIVERY MODE',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDeliveryChip(DeliveryMode.pickedUp),
                    const SizedBox(width: 12),
                    _buildDeliveryChip(DeliveryMode.delivered),
                  ],
                ),
                const SizedBox(height: 20),

                // Province/State
                Text(
                  'PROVINCE / STATE',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedProvinceState,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F2937),
                    underline: const SizedBox(),
                    style: GoogleFonts.inter(color: Colors.white),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    items: PROVINCES_STATES.map((ps) => DropdownMenuItem(
                      value: ps,
                      child: Text(ps),
                    )).toList(),
                    onChanged: _onProvinceChanged,
                  ),
                ),
                const SizedBox(height: 20),

                // Unit Selection
                Text(
                  'UNIT (AUTO-DETECTED)',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildUnitChip(WeightUnit.metricTonne, 'Canada'),
                    const SizedBox(width: 12),
                    _buildUnitChip(WeightUnit.shortTon, 'USA'),
                  ],
                ),
                const SizedBox(height: 20),

                // Price Input
                Text(
                  'PRICE',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedCurrency.symbol,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFF84CC16),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0.00',
                                  hintStyle: GoogleFonts.robotoMono(
                                    color: Colors.grey.shade600,
                                    fontSize: 24,
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        '/${_selectedUnit.abbreviation}',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Error message
                if (submissionState.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            submissionState.error!,
                            style: GoogleFonts.inter(
                              color: Colors.red.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),

                // Submit Button with Confetti
                // Submit Button with Confetti
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: submissionState.isSubmitting ? null : _submitPrice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84CC16),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF84CC16).withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: submissionState.isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(FontAwesomeIcons.paperPlane, size: 16),
                                  const SizedBox(width: 12),
                                  Text(
                                    'SEND TO TICKER',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        colors: const [
                          Color(0xFF84CC16), // Light green
                          Color(0xFFF97316), // Funny/Orange
                          Colors.white,
                          Colors.amber,
                        ],
                        createParticlePath: drawStar, 
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(FertilizerType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      const Color(0xFF84CC16).withOpacity(0.3),
                      const Color(0xFF84CC16).withOpacity(0.1),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF84CC16) : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                type.code,
                style: GoogleFonts.robotoMono(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                type.displayName,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.grey.shade300 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryChip(DeliveryMode mode) {
    final isSelected = _selectedDeliveryMode == mode;
    final icon = mode == DeliveryMode.pickedUp 
        ? Icons.store_mall_directory_outlined
        : FontAwesomeIcons.truck;
        
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDeliveryMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF84CC16).withOpacity(0.15) 
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF84CC16) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              if (mode == DeliveryMode.pickedUp)
                Icon(icon as IconData, color: isSelected ? const Color(0xFF84CC16) : Colors.grey, size: 20)
              else
                FaIcon(icon as IconData, color: isSelected ? const Color(0xFF84CC16) : Colors.grey, size: 18),
              const SizedBox(height: 8),
              Text(
                mode.displayName,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitChip(WeightUnit unit, String region) {
    final isSelected = _selectedUnit == unit;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedUnit = unit),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF84CC16).withOpacity(0.15) 
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF84CC16) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? const Color(0xFF84CC16) : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.displayName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    region,
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom Path to paint stars.
Path drawStar(Size size) {
  // Method to convert degree to radians
  double degToRad(double deg) => deg * (math.pi / 180.0);

  const numberOfPoints = 5;
  final halfWidth = size.width / 2;
  final externalRadius = halfWidth;
  final internalRadius = halfWidth / 2.5;
  final degreesPerStep = degToRad(360 / numberOfPoints);
  final halfDegreesPerStep = degreesPerStep / 2;
  final path = Path();
  final fullAngle = degToRad(360);
  path.moveTo(size.width, halfWidth);

  for (double step = 0; step < fullAngle; step += degreesPerStep) {
    path.lineTo(halfWidth + externalRadius * math.cos(step),
        halfWidth + externalRadius * math.sin(step));
    path.lineTo(halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
  }
  path.close();
  return path;
}
