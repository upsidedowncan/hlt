import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../shared/widgets/section_widgets.dart';
import 'customization_screen.dart';
import 'privacy_policy_screen.dart';

// Constants for the radii
const double externalRadius = 28.0; // The big outer corners
const double internalRadius = 6.0;  // The small corners between items

// -----------------------------------------
// Custom Widgets
// -----------------------------------------



// -----------------------------------------
// Main Settings Screen
// -----------------------------------------

class SettingsScreen extends StatefulWidget {
  final double bottomPadding;
  const SettingsScreen({super.key, this.bottomPadding = 0.0});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCustomization = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    Widget settingsContent = Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24), // Responsive padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            const SectionHeader(title: 'Appearance'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.palette,
                  title: 'Customization',
                  subtitle: 'Themes, colors, and animations',
                  isMobile: isMobile,
                  onTap: () {
                    setState(() {
                      _showCustomization = true;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notifications Section
            const SectionHeader(title: 'Notifications'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Coming soon',
                  isMobile: isMobile,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Privacy Section
            const SectionHeader(title: 'Privacy'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy',
                  subtitle: 'Coming soon',
                  isMobile: isMobile,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // About Section
            const SectionHeader(title: 'About'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.info,
                  title: 'Version',
                  subtitle: '0.1.0-alpha',
                  isMobile: isMobile,
                  trailing: IconButton(
                    icon: Icon(Icons.copy, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: '0.1.0-alpha'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Version copied to clipboard')),
                      );
                    },
                  ),
                ),
                SettingsTile(
                  icon: Icons.description,
                  title: 'Privacy Policy',
                  subtitle: 'Terms and conditions',
                  isMobile: isMobile,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                SettingsTile(
                  icon: Icons.help,
                  title: 'About',
                  subtitle: 'Coming soon',
                  isMobile: isMobile,
                ),
              ],
            ),

             const SizedBox(height: 40),
           ],
        ),
      ),
    );

    return Scaffold(
      appBar: _showCustomization ? null : AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2), height: 1),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: (settings.animationSpeed * 300).round()),
          transitionBuilder: (child, animation) => _buildTransition(child, animation, settings),
          child: _showCustomization
            ? CustomizationScreen(
                key: const ValueKey('customization'),
                onBackPressed: () => setState(() => _showCustomization = false),
              )
            : Container(key: const ValueKey('settings'), child: settingsContent),
        ),
      ),
    );
  }

  Widget _buildTransition(Widget child, Animation<double> animation, AppSettingsProvider settings) {
    final curve = _getCurve(settings.easingCurve);
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    switch (settings.transitionType) {
      case 'slide':
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      case 'fade':
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      case 'scale':
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(curvedAnimation),
          child: child,
        );
      case 'rotate':
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.1,
            end: 0.0,
          ).animate(curvedAnimation),
          child: child,
        );
      case 'bounce':
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.bounceOut)),
          child: child,
        );
      default:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
    }
  }

  Curve _getCurve(String curveName) {
    switch (curveName) {
      case 'easeInOutCubicEmphasized':
        return Curves.easeInOutCubicEmphasized;
      case 'easeInOutCubic':
        return Curves.easeInOutCubic;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'linear':
        return Curves.linear;
      case 'bounceOut':
        return Curves.bounceOut;
      case 'elasticOut':
        return Curves.elasticOut;
      case 'easeInBack':
        return Curves.easeInBack;
      default:
        return Curves.easeInOut;
    }
  }
}