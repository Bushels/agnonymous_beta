import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/auth_provider.dart';
import '../screens/leaderboard/leaderboard_screen.dart';

class HeaderBar extends ConsumerStatefulWidget {
  final Function(String) onSearchChanged;
  const HeaderBar({super.key, required this.onSearchChanged});

  @override
  ConsumerState<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends ConsumerState<HeaderBar> {
  bool isSearchExpanded = false;
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final authState = ref.watch(authProvider);
    final userProfile = ref.watch(currentUserProfileProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isSearchExpanded) ...[
            Text(
              'Agnonymous',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
          if (isSearchExpanded)
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        isSearchExpanded = false;
                        searchController.clear();
                        widget.onSearchChanged('');
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
          if (!isSearchExpanded) ...[
            Row(
              children: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isSearchExpanded = true;
                    });
                  },
                ),

                // Leaderboard Icon
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trophy, size: 18, color: Colors.amber),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                  tooltip: 'Leaderboard',
                ),

                // Profile Icon
                GestureDetector(
                  onTap: () {
                    if (authState.isAuthenticated) {
                      Navigator.of(context).pushNamed('/profile');
                    } else {
                      Navigator.of(context).pushNamed('/login');
                    }
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF84CC16).withOpacity(0.2),
                    child: authState.isAuthenticated && userProfile != null
                        ? Text(
                            userProfile.username.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF84CC16),
                            ),
                          )
                        : const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
