import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/globals.dart';
import '../../../app/theme.dart';
import '../../../services/analytics_service.dart';

// --- CATEGORY DROPDOWN ---
class CategoryChips extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const List<String> categories = [
    'Farming',
    'Livestock',
    'Ranching',
    'Crops',
    'Markets',
    'Weather',
    'Chemicals',
    'Equipment',
    'Politics',
    'Input Prices',
    'General',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedCategory.isNotEmpty
                      ? theme.colorScheme.primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1F2937),
                  icon: FaIcon(
                    FontAwesomeIcons.chevronDown,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  items: [
                    // Explicit "All Categories" option
                    DropdownMenuItem<String>(
                      value: '',
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.filter,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'All Categories',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Text(
                              getIconForCategory(category),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 10),
                            Text(category),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value != null && value.isNotEmpty) {
                      AnalyticsService.instance.logCategoryFilter(category: value);
                    }
                    onCategoryChanged(value ?? '');
                  },
                ),
              ),
            ),
          ),
          if (selectedCategory.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => onCategoryChanged(''),
              icon: const FaIcon(
                FontAwesomeIcons.xmark,
                size: 20,
                color: Colors.white,
              ),
              tooltip: 'Clear filter',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.error.withOpacity(0.8),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
