import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class AppColors {
  static const Color primary = Color(0xFF006D40); // Nice green color
  static const Color secondary = Color(0xFF2E7D32);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color background = Color(0xFFFFFBFE);
  static const Color error = Color(0xFFBA1A1A);
  
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color onError = Color(0xFFFFFFFF);
  
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  
  static const Color messageBubble = Color(0xFFE7E0EC);
  static const Color myMessageBubble = Color(0xFF006D40);
  static const Color onlineIndicator = Color(0xFF4CAF50);
  static const Color typingIndicator = Color(0xFFFF9800);

  // Color mode aware versions
  static Color primaryWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(primary, colorMode);
  static Color secondaryWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(secondary, colorMode);
  static Color surfaceWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(surface, colorMode);
  static Color backgroundWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(background, colorMode);
  static Color errorWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(error, colorMode);
  static Color outlineWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(outline, colorMode);
  static Color outlineVariantWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(outlineVariant, colorMode);
  static Color surfaceVariantWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(surfaceVariant, colorMode);
  static Color messageBubbleWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(messageBubble, colorMode);
  static Color myMessageBubbleWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(myMessageBubble, colorMode);
  static Color onlineIndicatorWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(onlineIndicator, colorMode);
  static Color typingIndicatorWithMode(String colorMode) => ColorModeUtils.applyColorModeToColor(typingIndicator, colorMode);
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
}

class AppSizes {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 40.0;
  static const double avatarLarge = 56.0;
  static const double avatarXLarge = 80.0;
}