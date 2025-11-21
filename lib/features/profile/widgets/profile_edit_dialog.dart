import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../shared/models/user.dart' as app_user;
import '../widgets/profile_avatar.dart';

class ProfileEditDialog extends StatefulWidget {
  final app_user.User user;
  final VoidCallback onSaved;

  const ProfileEditDialog({
    super.key,
    required this.user,
    required this.onSaved,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog>
    with TickerProviderStateMixin {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _avatarUrl;
  File? _avatarFile;
  bool _isLoading = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName ?? '';
    _usernameController.text = widget.user.username ?? '';
    _avatarUrl = widget.user.avatarUrl;

    _slideController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_displayNameController.text.trim().isEmpty) {
      _showError('Please enter a display name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? newAvatarUrl = _avatarUrl;

      // Upload new avatar if selected
      if (_avatarFile != null) {
        newAvatarUrl = await ProfileService.uploadAvatar(_avatarFile!);
        if (newAvatarUrl == null) {
          _showError('Failed to upload avatar');
          return;
        }
      }

      // Update profile
      final success = await ProfileService.updateProfile(
        displayName: _displayNameController.text.trim(),
        username: _usernameController.text.trim().isEmpty 
            ? null 
            : _usernameController.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      if (success) {
        widget.onSaved();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        _showError('Failed to update profile');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Profile',
                style: AppTextStyles.headline2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalLarge,
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    ProfileAvatar(
                      avatarUrl: _avatarFile != null ? null : _avatarUrl,
                      displayName: _displayNameController.text,
                      size: AppSizes.avatarXLarge,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.verticalLarge,
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your display name',
                ),
                textInputAction: TextInputAction.next,
              ),
              AppSpacing.verticalMedium,
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (Optional)',
                  hintText: 'Enter your username',
                ),
                textInputAction: TextInputAction.done,
              ),
              AppSpacing.verticalLarge,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Text('Save'),
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