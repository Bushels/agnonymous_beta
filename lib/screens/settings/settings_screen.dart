import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/glass_container.dart';
import '../legal/legal_disclaimer_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _priceAlerts = true;
  final bool _darkMode = true; // Always dark for now

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f0f23),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Notifications Section
                  _buildSectionHeader('Notifications'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: FontAwesomeIcons.bell,
                          title: 'Push Notifications',
                          subtitle: 'Receive notifications on your device',
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _showComingSoonSnackbar('Push notifications');
                          },
                        ),
                        // Email notifications hidden as they imply account
                        // Price alerts could still be relevant locally or via push
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: FontAwesomeIcons.tag,
                          title: 'Price Alerts',
                          subtitle: 'Get notified of significant price changes',
                          value: _priceAlerts,
                          onChanged: (value) {
                            setState(() => _priceAlerts = value);
                            _showComingSoonSnackbar('Price alerts');
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Appearance Section
                  _buildSectionHeader('Appearance'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: FontAwesomeIcons.moon,
                          title: 'Dark Mode',
                          subtitle: 'Use dark theme',
                          value: _darkMode,
                          onChanged: (value) {
                            // Dark mode is always on for now
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dark mode is the only available theme'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Privacy Section
                  _buildSectionHeader('Privacy & Security'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.scaleBalanced,
                          title: 'Legal Disclaimer',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LegalDisclaimerScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.shield,
                          title: 'Privacy Policy',
                          onTap: () => _showComingSoonSnackbar('Privacy Policy'),
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.fileContract,
                          title: 'Terms of Service',
                          onTap: () => _showComingSoonSnackbar('Terms of Service'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // About Section
                  _buildSectionHeader('About'),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.circleInfo,
                          title: 'App Version',
                          subtitle: '1.0.0 (Beta)',
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.bug,
                          title: 'Report a Bug',
                          onTap: () => _showComingSoonSnackbar('Bug reporting'),
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: FontAwesomeIcons.star,
                          title: 'Rate the App',
                          onTap: () => _showComingSoonSnackbar('App rating'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: FaIcon(
        icon,
        size: 18,
        color: titleColor ?? Colors.grey[400],
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: titleColor ?? Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: Colors.grey[600])
              : null),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: FaIcon(
        icon,
        size: 18,
        color: Colors.grey[400],
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF84CC16),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.1),
      indent: 56,
    );
  }

  void _showComingSoonSnackbar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon!')),
    );
  }
}
