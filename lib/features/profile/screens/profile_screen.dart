import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/user_provider.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../shared/models/user.dart' as app_user;
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: _buildBody(),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            children: [
              ProfileAvatar(
                avatarUrl: _user!.avatarUrl,
                displayName: _user!.displayName,
                size: AppSizes.avatarXLarge,
              ),
              AppSpacing.verticalLarge,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingLarge),
                  child: Column(
                    children: [
                      _buildProfileItem(
                        'Display Name',
                        _user!.displayName ?? 'Not set',
                        Icons.person,
                      ),
                      AppSpacing.verticalMedium,
                      _buildProfileItem(
                        'Username',
                        _user!.username ?? 'Not set',
                        Icons.alternate_email,
                      ),
                      AppSpacing.verticalMedium,
                      _buildProfileItem(
                        'Email',
                        _user!.email ?? 'Not set',
                        Icons.email,
                      ),
                      AppSpacing.verticalMedium,
                      _buildProfileItem(
                        'Member since',
                        _user!.createdAt != null
                            ? '${_user!.createdAt!.day}/${_user!.createdAt!.month}/${_user!.createdAt!.year}'
                            : 'Unknown',
                        Icons.calendar_today,
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.verticalLarge,
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showEditDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Sign Out'),
                      onTap: _signOut,
                    ),
                  ],
                ),
              ),
            ],
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