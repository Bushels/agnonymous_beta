/// Create Price Screen
/// Enhanced input pricing screen with Coming Soon states for non-fertilizer types
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/ticker/fertilizer_price_modal.dart';

class CreatePriceScreen extends StatefulWidget {
  const CreatePriceScreen({super.key});

  @override
  State<CreatePriceScreen> createState() => _CreatePriceScreenState();
}

class _CreatePriceScreenState extends State<CreatePriceScreen> {
  String _productType = 'Fertilizer';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Post Input Price',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF84CC16).withOpacity(0.1),
                      const Color(0xFF84CC16).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF84CC16).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.circleInfo, 
                      color: Color(0xFF84CC16), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your price helps farmers negotiate better deals!',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 24),

              Text(
                'SELECT CATEGORY',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 24),
              
              // Content based on selection
              if (_productType == 'Fertilizer')
                _buildFertilizerContent()
              else
                _buildComingSoonContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTypeCard('Fertilizer', FontAwesomeIcons.seedling, true, false),
          _buildTypeCard('Chemical', FontAwesomeIcons.flask, false, true),
          _buildTypeCard('Seed', FontAwesomeIcons.wheatAwn, false, true),
          _buildTypeCard('Equipment', FontAwesomeIcons.tractor, false, true),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String label, IconData icon, bool isSelected, bool isComingSoon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _productType = label;
        });
      },
      child: Stack(
        children: [
          Container(
            width: 90,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF84CC16).withOpacity(0.2) 
                  : const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFF84CC16) 
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  icon,
                  color: isSelected 
                      ? const Color(0xFF84CC16) 
                      : isComingSoon 
                          ? Colors.grey.shade600
                          : Colors.grey,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected 
                        ? Colors.white 
                        : isComingSoon 
                            ? Colors.grey.shade600 
                            : Colors.grey,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Coming Soon Badge
          if (isComingSoon)
            Positioned(
              top: 4,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SOON',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFertilizerContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2937),
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF84CC16).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF84CC16).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(
              FontAwesomeIcons.dollarSign,
              color: Color(0xFF84CC16),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fertilizer Pricing',
            style: GoogleFonts.outfit(
              color: Colors.white, 
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit NH3 or 46-0-0 (Urea) prices to help build regional price transparency.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey.shade400, 
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                showFertilizerPriceModal(context);
              },
              icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 16),
              label: Text(
                'Post Fertilizer Price',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84CC16),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildComingSoonContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.clockRotateLeft,
              color: Colors.orange.shade400,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$_productType Pricing',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'COMING SOON',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We\'re working on expanding our pricing database to include $_productType prices. Check back soon!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade400,
              side: BorderSide(color: Colors.grey.shade600),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Go Back', style: GoogleFonts.inter()),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }
}
