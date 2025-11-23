import 'package:flutter/material.dart';

// Material 3 Expressive Button Implementation
class M3ExpressiveButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final ButtonVariant variant;

  const M3ExpressiveButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = ButtonVariant.primary,
  });

  // Factory constructors for different variants
  factory M3ExpressiveButton.primary({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
  }) = _PrimaryM3ExpressiveButton;

  factory M3ExpressiveButton.secondary({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
  }) = _SecondaryM3ExpressiveButton;

  @override
  State<M3ExpressiveButton> createState() => _M3ExpressiveButtonState();
}

enum ButtonVariant { primary, secondary }

class _PrimaryM3ExpressiveButton extends M3ExpressiveButton {
  const _PrimaryM3ExpressiveButton({
    required super.onPressed,
    required super.label,
    super.icon,
  }) : super(variant: ButtonVariant.primary);
}

class _SecondaryM3ExpressiveButton extends M3ExpressiveButton {
  const _SecondaryM3ExpressiveButton({
    required super.onPressed,
    required super.label,
    super.icon,
  }) : super(variant: ButtonVariant.secondary);
}

class _M3ExpressiveButtonState extends State<M3ExpressiveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // M3 Specs:
    // Resting: High radius (Stadium/Pill)
    // Pressed: Low radius (Small rounded corners)
    final double currentRadius = _isPressed ? 8.0 : 32.0;

    // Duration: M3 expressive motion is usually around 200-300ms
    final Duration animationDuration = const Duration(milliseconds: 250);

    // Color scheme based on variant
    final Color backgroundColor = widget.variant == ButtonVariant.primary
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final Color foregroundColor = widget.variant == ButtonVariant.primary
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Listener(
      // We use Listener to trigger the animation state immediately on touch down
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 32.0, end: currentRadius),
        duration: animationDuration,
        curve: Curves.easeOutCubic, // Smooth organic curve
        builder: (context, radius, child) {
          return PhysicalModel(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            elevation: _isPressed ? 2 : 6, // Lowers elevation on press
            child: Container(
              height: 56, // M3 standard for large touch targets
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  // Ensure splash matches the current animated radius
                  borderRadius: BorderRadius.circular(radius),
                  splashColor: foregroundColor.withOpacity(0.1),
                  highlightColor: Colors.transparent, // Handled by container animation
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: foregroundColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Global Button Styling with M3 Expressive behavior
class AppButtons {
  // M3 Expressive primary button
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    if (isLoading) {
      return M3ExpressiveButton.primary(
        onPressed: () {},
        label: text,
        icon: null, // Loading state doesn't show icon
      );
    }

    return M3ExpressiveButton.primary(
      onPressed: onPressed,
      label: text,
      icon: icon,
    );
  }

  // M3 Expressive secondary button
  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return M3ExpressiveButton.secondary(
      onPressed: onPressed,
      label: text,
      icon: icon,
    );
  }

  // Regular buttons for cases where expressive behavior isn't needed
  static Widget textButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
      label: Text(text),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}





class AppSpacing {
  static const Widget verticalTiny = SizedBox(height: 4);
  static const Widget verticalSmall = SizedBox(height: 8);
  static const Widget verticalMedium = SizedBox(height: 16);
  static const Widget verticalLarge = SizedBox(height: 24);
  static const Widget verticalXLarge = SizedBox(height: 32);
  
  static const Widget horizontalTiny = SizedBox(width: 4);
  static const Widget horizontalSmall = SizedBox(width: 8);
  static const Widget horizontalMedium = SizedBox(width: 16);
  static const Widget horizontalLarge = SizedBox(width: 24);
  static const Widget horizontalXLarge = SizedBox(width: 32);
}

class AppBorderRadius {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(16));
  static const BorderRadius xLarge = BorderRadius.all(Radius.circular(20));
  
  static const BorderRadius onlyTopLarge = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
  );
  
  static const BorderRadius onlyBottomLarge = BorderRadius.only(
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  static const BorderRadius android15Section = BorderRadius.all(Radius.circular(16));
}

class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}