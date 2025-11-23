import 'package:flutter/material.dart';

// Constants for the radii
const double externalRadius = 28.0; // The big outer corners
const double internalRadius = 6.0;  // The small corners between items

// -----------------------------------------
// Shared Section Widgets
// -----------------------------------------

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<Widget> structuredChildren = [];
    int len = children.length;

    for (int i = 0; i < len; i++) {
      BorderRadius borderRadius;

      // Logic to determine border radius based on position in the list
      if (len == 1) {
        // Only one item: all corners rounded heavily
        borderRadius = BorderRadius.circular(externalRadius);
      } else if (i == 0) {
        // First item: Top heavy, bottom slight
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(externalRadius),
          topRight: Radius.circular(externalRadius),
          bottomLeft: Radius.circular(internalRadius),
          bottomRight: Radius.circular(internalRadius),
        );
      } else if (i == len - 1) {
        // Last item: Top slight, bottom heavy
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(internalRadius),
          topRight: Radius.circular(internalRadius),
          bottomLeft: Radius.circular(externalRadius),
          bottomRight: Radius.circular(externalRadius),
        );
      } else {
        // Middle items: All slight
        borderRadius = BorderRadius.circular(internalRadius);
      }

      // Wrap the tile in a Material widget with the calculated radius
      structuredChildren.add(
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
          // Clip antiAlias creates smoother rounded corners than hardEdge
          clipBehavior: Clip.antiAlias,
          child: Padding(
            // Add small padding to prevent content from touching the rounded edges
            padding: const EdgeInsets.all(1),
            child: children[i],
          ),
        )
      );

      // Add the "cut" space between items if it's not the last one
      if (i < len - 1) {
        structuredChildren.add(
          // This SizedBox reveals the dark scaffold background, creating the "cut"
          const SizedBox(height: 3)
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: structuredChildren,
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isMobile;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 70, // Fixed height for all tiles
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 14.0,
            horizontal: isMobile ? 16.0 : 20.0, // Responsive horizontal padding
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}