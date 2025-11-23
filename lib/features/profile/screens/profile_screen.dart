import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/user_provider.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/widgets/section_widgets.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';

// Constants for the radii
const double externalRadius = 28.0; // The big outer corners
const double internalRadius = 6.0;  // The small corners between items

// -----------------------------------------
// Custom Widgets
// -----------------------------------------



class ProfileScreen extends StatefulWidget {
  final double bottomPadding;
  const ProfileScreen({super.key, this.bottomPadding = 0.0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  app_user.User? _user;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _loadProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      // Add timeout to prevent infinite loading
      final user = await ProfileService.getCurrentUserProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Profile loading timed out');
        },
      );
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
    });
    await _loadProfile();
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => ProfileEditDialog(
        user: _user!,
        onSaved: _refreshProfile,
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<UserProvider>(context, listen: false).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2), height: 1),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    } else if (_user == null) {
      return _buildErrorView();
    } else {
      return _buildProfileView();
    }
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = false;
                _user = null;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          AppSpacing.verticalMedium,
          Text(
            'Failed to load profile',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalSmall,
          Text(
            'You might not be authenticated or there might be a connection issue.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalMedium,
          ElevatedButton(
            onPressed: _refreshProfile,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              children: [
                ProfileAvatar(
                  avatarUrl: _user!.avatarUrl,
                  displayName: _user!.displayName,
                  size: AppSizes.avatarXLarge,
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Account'),
                const SizedBox(height: 8),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.person,
                      title: 'Display Name',
                      subtitle: _user!.displayName ?? 'Not set',
                      isMobile: isMobile,
                    ),
                    SettingsTile(
                      icon: Icons.alternate_email,
                      title: 'Username',
                      subtitle: _user!.username ?? 'Not set',
                      isMobile: isMobile,
                    ),
                    SettingsTile(
                      icon: Icons.email,
                      title: 'Email',
                      subtitle: _user!.email ?? 'Not set',
                      isMobile: isMobile,
                    ),
                    SettingsTile(
                      icon: Icons.calendar_today,
                      title: 'Member since',
                      subtitle: _user!.createdAt != null
                          ? '${_user!.createdAt!.day}/${_user!.createdAt!.month}/${_user!.createdAt!.year}'
                          : 'Unknown',
                      isMobile: isMobile,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Actions'),
                const SizedBox(height: 8),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.edit,
                      title: 'Edit Profile',
                      subtitle: 'Update your profile information',
                      isMobile: isMobile,
                      onTap: _showEditDialog,
                    ),
                    SettingsTile(
                      icon: Icons.logout,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      isMobile: isMobile,
                      onTap: _signOut,
                    ),
                  ],
                ),
                 const SizedBox(height: 40),
               ],
             ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon, {Color? textColor}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        AppSpacing.horizontalMedium,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor ?? Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}