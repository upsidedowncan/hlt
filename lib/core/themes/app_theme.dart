import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';

class ColorModeUtils {
  static ColorScheme applyColorMode(ColorScheme colorScheme, String colorMode) {
    switch (colorMode) {
      case 'vibrant':
        return _makeVibrant(colorScheme);
      case 'muted':
        return _makeMuted(colorScheme);
      case 'pastel':
        return _makePastel(colorScheme);
      case 'monochrome':
        return _makeMonochrome(colorScheme);
      case 'high-contrast':
        return _makeHighContrast(colorScheme);
      case 'warm':
        return _makeWarm(colorScheme);
      case 'cool':
        return _makeCool(colorScheme);
      case 'default':
      default:
        return colorScheme;
    }
  }

  static Color applyColorModeToColor(Color color, String colorMode) {
    switch (colorMode) {
      case 'vibrant':
        return _increaseSaturationAndBrightness(color, 0.3, 0.2);
      case 'muted':
        return _decreaseSaturation(color, 0.3);
      case 'pastel':
        return _makePastelColor(color);
      case 'monochrome':
        return _makeGrayscale(color);
      case 'high-contrast':
        return _increaseContrast(color);
      case 'warm':
        return _shiftToWarm(color);
      case 'cool':
        return _shiftToCool(color);
      case 'default':
      default:
        return color;
    }
  }

  static ColorScheme _makeVibrant(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _increaseSaturationAndBrightness(colorScheme.primary, 0.3, 0.2),
      secondary: _increaseSaturationAndBrightness(colorScheme.secondary, 0.3, 0.2),
      tertiary: _increaseSaturationAndBrightness(colorScheme.tertiary, 0.3, 0.2),
      primaryContainer: _increaseSaturationAndBrightness(colorScheme.primaryContainer, 0.2, 0.1),
      secondaryContainer: _increaseSaturationAndBrightness(colorScheme.secondaryContainer, 0.2, 0.1),
      tertiaryContainer: _increaseSaturationAndBrightness(colorScheme.tertiaryContainer, 0.2, 0.1),
      surface: _increaseSaturationAndBrightness(colorScheme.surface, 0.1, 0.05),
      surfaceVariant: _increaseSaturationAndBrightness(colorScheme.surfaceVariant, 0.1, 0.05),
      surfaceContainerHighest: _increaseSaturationAndBrightness(colorScheme.surfaceContainerHighest, 0.15, 0.08),
      surfaceContainerHigh: _increaseSaturationAndBrightness(colorScheme.surfaceContainerHigh, 0.12, 0.06),
      surfaceContainer: _increaseSaturationAndBrightness(colorScheme.surfaceContainer, 0.08, 0.04),
      surfaceContainerLow: _increaseSaturationAndBrightness(colorScheme.surfaceContainerLow, 0.05, 0.02),
      surfaceContainerLowest: _increaseSaturationAndBrightness(colorScheme.surfaceContainerLowest, 0.02, 0.01),
      background: _increaseSaturationAndBrightness(colorScheme.background, 0.05, 0.02),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static ColorScheme _makeMuted(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _decreaseSaturation(colorScheme.primary, 0.3),
      secondary: _decreaseSaturation(colorScheme.secondary, 0.3),
      tertiary: _decreaseSaturation(colorScheme.tertiary, 0.3),
      primaryContainer: _decreaseSaturation(colorScheme.primaryContainer, 0.2),
      secondaryContainer: _decreaseSaturation(colorScheme.secondaryContainer, 0.2),
      tertiaryContainer: _decreaseSaturation(colorScheme.tertiaryContainer, 0.2),
      surface: _decreaseSaturation(colorScheme.surface, 0.1),
      surfaceVariant: _decreaseSaturation(colorScheme.surfaceVariant, 0.1),
      surfaceContainerHighest: _decreaseSaturation(colorScheme.surfaceContainerHighest, 0.15),
      surfaceContainerHigh: _decreaseSaturation(colorScheme.surfaceContainerHigh, 0.12),
      surfaceContainer: _decreaseSaturation(colorScheme.surfaceContainer, 0.08),
      surfaceContainerLow: _decreaseSaturation(colorScheme.surfaceContainerLow, 0.05),
      surfaceContainerLowest: _decreaseSaturation(colorScheme.surfaceContainerLowest, 0.02),
      background: _decreaseSaturation(colorScheme.background, 0.05),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static ColorScheme _makePastel(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _makePastelColor(colorScheme.primary),
      secondary: _makePastelColor(colorScheme.secondary),
      tertiary: _makePastelColor(colorScheme.tertiary),
      primaryContainer: _makePastelColor(colorScheme.primaryContainer),
      secondaryContainer: _makePastelColor(colorScheme.secondaryContainer),
      tertiaryContainer: _makePastelColor(colorScheme.tertiaryContainer),
      surface: _makePastelColor(colorScheme.surface),
      surfaceVariant: _makePastelColor(colorScheme.surfaceVariant),
      surfaceContainerHighest: _makePastelColor(colorScheme.surfaceContainerHighest),
      surfaceContainerHigh: _makePastelColor(colorScheme.surfaceContainerHigh),
      surfaceContainer: _makePastelColor(colorScheme.surfaceContainer),
      surfaceContainerLow: _makePastelColor(colorScheme.surfaceContainerLow),
      surfaceContainerLowest: _makePastelColor(colorScheme.surfaceContainerLowest),
      background: _makePastelColor(colorScheme.background),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static Color _increaseSaturationAndBrightness(Color color, double saturationIncrease, double brightnessIncrease) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + saturationIncrease).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + brightnessIncrease).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _decreaseSaturation(Color color, double saturationDecrease) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation - saturationDecrease).clamp(0.0, 1.0)).toColor();
  }

  static Color _makePastelColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
  }

  static ColorScheme _makeMonochrome(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _makeGrayscale(colorScheme.primary),
      secondary: _makeGrayscale(colorScheme.secondary),
      tertiary: _makeGrayscale(colorScheme.tertiary),
      primaryContainer: _makeGrayscale(colorScheme.primaryContainer),
      secondaryContainer: _makeGrayscale(colorScheme.secondaryContainer),
      tertiaryContainer: _makeGrayscale(colorScheme.tertiaryContainer),
      surface: _makeGrayscale(colorScheme.surface),
      surfaceVariant: _makeGrayscale(colorScheme.surfaceVariant),
      surfaceContainerHighest: _makeGrayscale(colorScheme.surfaceContainerHighest),
      surfaceContainerHigh: _makeGrayscale(colorScheme.surfaceContainerHigh),
      surfaceContainer: _makeGrayscale(colorScheme.surfaceContainer),
      surfaceContainerLow: _makeGrayscale(colorScheme.surfaceContainerLow),
      surfaceContainerLowest: _makeGrayscale(colorScheme.surfaceContainerLowest),
      background: _makeGrayscale(colorScheme.background),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static ColorScheme _makeHighContrast(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _increaseContrast(colorScheme.primary),
      secondary: _increaseContrast(colorScheme.secondary),
      tertiary: _increaseContrast(colorScheme.tertiary),
      primaryContainer: _increaseContrast(colorScheme.primaryContainer),
      secondaryContainer: _increaseContrast(colorScheme.secondaryContainer),
      tertiaryContainer: _increaseContrast(colorScheme.tertiaryContainer),
      surface: _makeDarker(colorScheme.surface),
      surfaceVariant: _makeDarker(colorScheme.surfaceVariant),
      surfaceContainerHighest: _makeDarker(colorScheme.surfaceContainerHighest),
      surfaceContainerHigh: _makeDarker(colorScheme.surfaceContainerHigh),
      surfaceContainer: _makeDarker(colorScheme.surfaceContainer),
      surfaceContainerLow: _makeDarker(colorScheme.surfaceContainerLow),
      surfaceContainerLowest: _makeDarker(colorScheme.surfaceContainerLowest),
      background: _makeDarker(colorScheme.background),
      // Ensure proper text contrast - high contrast mode uses white text
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
      onSurfaceVariant: Colors.white,
      onPrimaryContainer: Colors.white,
      onSecondaryContainer: Colors.white,
      onTertiaryContainer: Colors.white,
    );
  }

  static ColorScheme _makeWarm(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _shiftToWarm(colorScheme.primary),
      secondary: _shiftToWarm(colorScheme.secondary),
      tertiary: _shiftToWarm(colorScheme.tertiary),
      primaryContainer: _shiftToWarm(colorScheme.primaryContainer),
      secondaryContainer: _shiftToWarm(colorScheme.secondaryContainer),
      tertiaryContainer: _shiftToWarm(colorScheme.tertiaryContainer),
      surface: _addWarmTint(colorScheme.surface),
      surfaceVariant: _addWarmTint(colorScheme.surfaceVariant),
      surfaceContainerHighest: _addWarmTint(colorScheme.surfaceContainerHighest),
      surfaceContainerHigh: _addWarmTint(colorScheme.surfaceContainerHigh),
      surfaceContainer: _addWarmTint(colorScheme.surfaceContainer),
      surfaceContainerLow: _addWarmTint(colorScheme.surfaceContainerLow),
      surfaceContainerLowest: _addWarmTint(colorScheme.surfaceContainerLowest),
      background: _addWarmTint(colorScheme.background),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static ColorScheme _makeCool(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    return colorScheme.copyWith(
      primary: _shiftToCool(colorScheme.primary),
      secondary: _shiftToCool(colorScheme.secondary),
      tertiary: _shiftToCool(colorScheme.tertiary),
      primaryContainer: _shiftToCool(colorScheme.primaryContainer),
      secondaryContainer: _shiftToCool(colorScheme.secondaryContainer),
      tertiaryContainer: _shiftToCool(colorScheme.tertiaryContainer),
      surface: _addCoolTint(colorScheme.surface),
      surfaceVariant: _addCoolTint(colorScheme.surfaceVariant),
      surfaceContainerHighest: _addCoolTint(colorScheme.surfaceContainerHighest),
      surfaceContainerHigh: _addCoolTint(colorScheme.surfaceContainerHigh),
      surfaceContainer: _addCoolTint(colorScheme.surfaceContainer),
      surfaceContainerLow: _addCoolTint(colorScheme.surfaceContainerLow),
      surfaceContainerLowest: _addCoolTint(colorScheme.surfaceContainerLowest),
      background: _addCoolTint(colorScheme.background),
      // Ensure proper text contrast
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.black,
      onTertiary: isLight ? Colors.white : Colors.black,
      onSurface: isLight ? Colors.black : Colors.white,
      onBackground: isLight ? Colors.black : Colors.white,
      onSurfaceVariant: isLight ? Colors.black : Colors.white,
      onPrimaryContainer: isLight ? Colors.black : Colors.white,
      onSecondaryContainer: isLight ? Colors.black : Colors.white,
      onTertiaryContainer: isLight ? Colors.black : Colors.white,
    );
  }

  static Color _makeGrayscale(Color color) {
    final gray = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114).round();
    return Color.fromARGB(color.alpha, gray, gray, gray);
  }

  static Color _increaseContrast(Color color) {
    final hsl = HSLColor.fromColor(color);
    final lightness = hsl.lightness;
    final newLightness = lightness > 0.5 ? (lightness + 0.2).clamp(0.0, 1.0) : (lightness - 0.2).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  static Color _makeDarker(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }

  static Color _shiftToWarm(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Shift hue towards warm colors (reds, oranges, yellows)
    final currentHue = hsl.hue;
    final targetHue = 30.0; // Orange range
    final newHue = (currentHue + targetHue) / 2;
    return hsl.withHue(newHue).withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0)).toColor();
  }

  static Color _shiftToCool(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Shift hue towards cool colors (blues, greens, purples)
    final currentHue = hsl.hue;
    final targetHue = 220.0; // Blue range
    final newHue = (currentHue + targetHue) / 2;
    return hsl.withHue(newHue).withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0)).toColor();
  }

  static Color _addWarmTint(Color color) {
    // Blend with warm orange tint
    const warmTint = Color(0xFFFFE4B5); // Light orange
    return Color.alphaBlend(warmTint.withOpacity(0.1), color);
  }

  static Color _addCoolTint(Color color) {
    // Blend with cool blue tint
    const coolTint = Color(0xFFE0F6FF); // Light blue
    return Color.alphaBlend(coolTint.withOpacity(0.1), color);
  }
}

class AppTheme {
  static ThemeData lightTheme({
    Color? seedColor,
    double fontSizeScale = 1.0,
    String fontFamily = 'Nunito Sans',
    String colorMode = 'default',
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppColors.primary,
      brightness: Brightness.light,
    );
    final colorScheme = ColorModeUtils.applyColorMode(baseColorScheme, colorMode);

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
       appBarTheme: AppBarTheme(
         centerTitle: true,
         elevation: 0,
         backgroundColor: Colors.transparent,
         foregroundColor: ColorModeUtils.applyColorModeToColor(const Color(0xFF1C1B1F), colorMode),
       ),
       cardTheme: const CardThemeData(
         elevation: 2,
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.all(Radius.circular(16)),
         ),
       ),
       elevatedButtonTheme: ElevatedButtonThemeData(
         style: ButtonStyle(
           shape: WidgetStateProperty.resolveWith<RoundedRectangleBorder>(
             (states) => RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(
                 states.contains(WidgetState.pressed) ? 8.0 : 32.0, // M3 expressive: morph on press
               ),
             ),
           ),
           elevation: WidgetStateProperty.resolveWith<double>(
             (states) => states.contains(WidgetState.pressed) ? 2.0 : 6.0, // Lower elevation on press
           ),
           padding: const WidgetStatePropertyAll(
             EdgeInsets.symmetric(horizontal: 24, vertical: 12),
           ),
           minimumSize: const WidgetStatePropertyAll(Size(0, 56)), // M3 standard height
           shadowColor: WidgetStatePropertyAll(Colors.black.withOpacity(0.15)),
           animationDuration: const Duration(milliseconds: 250), // Smooth transitions
         ),
       ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return baseTheme.copyWith(
      textTheme: TextTheme(
        displayLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displayLarge?.fontSize ?? 57) * fontSizeScale),
        displayMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displayMedium?.fontSize ?? 45) * fontSizeScale),
        displaySmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displaySmall?.fontSize ?? 36) * fontSizeScale),
        headlineLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineLarge?.fontSize ?? 32) * fontSizeScale),
        headlineMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineMedium?.fontSize ?? 28) * fontSizeScale),
        headlineSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineSmall?.fontSize ?? 24) * fontSizeScale),
        titleLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleLarge?.fontSize ?? 22) * fontSizeScale),
        titleMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleMedium?.fontSize ?? 16) * fontSizeScale),
        titleSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleSmall?.fontSize ?? 14) * fontSizeScale),
        bodyLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodyLarge?.fontSize ?? 16) * fontSizeScale),
        bodyMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodyMedium?.fontSize ?? 14) * fontSizeScale),
        bodySmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodySmall?.fontSize ?? 12) * fontSizeScale),
        labelLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * fontSizeScale),
        labelMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelMedium?.fontSize ?? 12) * fontSizeScale),
        labelSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelSmall?.fontSize ?? 11) * fontSizeScale),
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        iconTheme: baseTheme.appBarTheme.iconTheme?.copyWith(size: 24.0 * fontSizeScale) ?? IconThemeData(size: 24.0 * fontSizeScale),
        actionsIconTheme: baseTheme.appBarTheme.actionsIconTheme?.copyWith(size: 24.0 * fontSizeScale) ?? IconThemeData(size: 24.0 * fontSizeScale),
      ),
      iconTheme: baseTheme.iconTheme.copyWith(size: 24.0 * fontSizeScale),
      listTileTheme: baseTheme.listTileTheme.copyWith(
        iconColor: baseTheme.listTileTheme.iconColor,
        minVerticalPadding: (baseTheme.listTileTheme.minVerticalPadding ?? 4.0) * fontSizeScale,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * fontSizeScale,
          vertical: 8.0 * fontSizeScale,
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * fontSizeScale,
          vertical: 12.0 * fontSizeScale,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseTheme.elevatedButtonTheme.style?.copyWith(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              horizontal: 24.0 * fontSizeScale,
              vertical: 12.0 * fontSizeScale,
            ),
          ),
          textStyle: WidgetStateProperty.all(
            baseTheme.textTheme.labelLarge?.copyWith(fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * fontSizeScale),
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme({
    Color? seedColor,
    double fontSizeScale = 1.0,
    String fontFamily = 'Nunito Sans',
    String colorMode = 'default',
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppColors.primary,
      brightness: Brightness.dark,
    );
    final colorScheme = ColorModeUtils.applyColorMode(baseColorScheme, colorMode);

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: ColorModeUtils.applyColorModeToColor(const Color(0xFFE6E0E9), colorMode),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return baseTheme.copyWith(
      textTheme: TextTheme(
        displayLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displayLarge?.fontSize ?? 57) * fontSizeScale),
        displayMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displayMedium?.fontSize ?? 45) * fontSizeScale),
        displaySmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.displaySmall?.fontSize ?? 36) * fontSizeScale),
        headlineLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineLarge?.fontSize ?? 32) * fontSizeScale),
        headlineMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineMedium?.fontSize ?? 28) * fontSizeScale),
        headlineSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.headlineSmall?.fontSize ?? 24) * fontSizeScale),
        titleLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleLarge?.fontSize ?? 22) * fontSizeScale),
        titleMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleMedium?.fontSize ?? 16) * fontSizeScale),
        titleSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.titleSmall?.fontSize ?? 14) * fontSizeScale),
        bodyLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodyLarge?.fontSize ?? 16) * fontSizeScale),
        bodyMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodyMedium?.fontSize ?? 14) * fontSizeScale),
        bodySmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.bodySmall?.fontSize ?? 12) * fontSizeScale),
        labelLarge: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * fontSizeScale),
        labelMedium: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelMedium?.fontSize ?? 12) * fontSizeScale),
        labelSmall: GoogleFonts.getFont(fontFamily, fontSize: (baseTheme.textTheme.labelSmall?.fontSize ?? 11) * fontSizeScale),
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        iconTheme: baseTheme.appBarTheme.iconTheme?.copyWith(size: 24.0 * fontSizeScale) ?? IconThemeData(size: 24.0 * fontSizeScale),
        actionsIconTheme: baseTheme.appBarTheme.actionsIconTheme?.copyWith(size: 24.0 * fontSizeScale) ?? IconThemeData(size: 24.0 * fontSizeScale),
      ),
      iconTheme: baseTheme.iconTheme.copyWith(size: 24.0 * fontSizeScale),
      listTileTheme: baseTheme.listTileTheme.copyWith(
        iconColor: baseTheme.listTileTheme.iconColor,
        minVerticalPadding: (baseTheme.listTileTheme.minVerticalPadding ?? 4.0) * fontSizeScale,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * fontSizeScale,
          vertical: 8.0 * fontSizeScale,
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * fontSizeScale,
          vertical: 12.0 * fontSizeScale,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseTheme.elevatedButtonTheme.style?.copyWith(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              horizontal: 24.0 * fontSizeScale,
              vertical: 12.0 * fontSizeScale,
            ),
          ),
          textStyle: WidgetStateProperty.all(
            baseTheme.textTheme.labelLarge?.copyWith(fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * fontSizeScale),
          ),
        ),
      ),
    );
  }
}