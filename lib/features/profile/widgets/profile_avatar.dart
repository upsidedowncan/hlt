import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_styles.dart';

class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.size = AppSizes.avatarMedium,
    this.showBorder = true,
    this.onTap,
  });

@override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          backgroundImage: avatarUrl != null
              ? CachedNetworkImageProvider(avatarUrl!)
              : null,
          child: avatarUrl == null
              ? _buildInitials(context)
              : null,
        ),
      ),
    );
  }

  Widget _buildInitials(BuildContext context) {
    if (displayName == null || displayName!.isEmpty) {
      return Icon(
        Icons.person,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    final names = displayName!.trim().split(' ');
    String initials = '';
    
    if (names.isNotEmpty) {
      initials += names[0][0].toUpperCase();
      if (names.length > 1) {
        initials += names[names.length - 1][0].toUpperCase();
      }
    }

    return Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}