import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/app_settings_provider.dart';
import 'customization_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCustomization = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCustomization ? 'Customization' : 'Settings'),
        centerTitle: true,
        leading: _showCustomization
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showCustomization = false;
                  });
                },
              )
            : null, // Automatically uses back button if navigation stack is pushed, or null for root
      ),
      body: _showCustomization ? const CustomizationScreen() : _buildSettingsList(context),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettingsProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette, theme),
          const SizedBox(height: 16),
          _buildAppearanceSection(context, theme),

          const SizedBox(height: 24),

           // Notifications Section
           _buildSectionHeader('Notifications', Icons.notifications, theme, isComingSoon: true),
           const SizedBox(height: 16),
           _buildNotificationsSection(theme, settings),

           const SizedBox(height: 24),

           // Privacy Section
           _buildSectionHeader('Privacy', Icons.privacy_tip, theme, isComingSoon: true),
           const SizedBox(height: 16),
           _buildPrivacySection(theme, settings),

           const SizedBox(height: 24),

           // About Section
           _buildSectionHeader('About', Icons.info, theme, isComingSoon: true),
          const SizedBox(height: 16),
          _buildAboutSection(context, theme),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme, {bool isComingSoon = false}) {
    return Row(
      children: [
        Icon(
          icon,
          color: isComingSoon
              ? theme.colorScheme.onSurface.withOpacity(0.5)
              : theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isComingSoon
                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (isComingSoon)
          Text(
            'Coming Soon',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.medium,
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Customization'),
            subtitle: const Text('Themes, animations, colors, and more'),
            trailing: Icon(Icons.arrow_forward_ios, size: AppSizes.iconSmall),
            onTap: () {
              setState(() {
                _showCustomization = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(ThemeData theme, AppSettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppBorderRadius.medium,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Notifications',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            trailing: Icon(
              Icons.lock_clock,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(ThemeData theme, AppSettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppBorderRadius.medium,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Privacy',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            trailing: Icon(
              Icons.lock_clock,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppBorderRadius.medium,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Version',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            subtitle: Text(
              '0.1.0-alpha',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            trailing: Icon(
              Icons.copy,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            enabled: false,
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: Icon(Icons.arrow_forward_ios, size: AppSizes.iconSmall),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          ListTile(
            title: Text(
              'About',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            trailing: Icon(
              Icons.lock_clock,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            enabled: false,
          ),
        ],
      ),
    );
  }
}