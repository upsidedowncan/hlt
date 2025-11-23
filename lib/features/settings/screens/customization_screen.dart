import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../shared/widgets/section_widgets.dart';

// Constants for the radii
const double externalRadius = 28.0; // The big outer corners
const double internalRadius = 6.0;  // The small corners between items

// -----------------------------------------
// Custom Widgets
// -----------------------------------------



class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key, this.onBackPressed});

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    Widget content = Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24), // Responsive padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            const SectionHeader(title: 'Theme'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Theme Mode',
                  subtitle: CustomizationScreen._getThemeModeText(settings.themeMode),
                  isMobile: isMobile,
                  trailing: PopupMenuButton<ThemeMode>(
                    onSelected: (mode) {
                      settings.setThemeMode(mode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Theme changed to ${_getThemeModeText(mode)}')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Colors Section
            const SectionHeader(title: 'Colors'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Theme Presets',
                  subtitle: CustomizationScreen._getThemePresetText(settings.themePreset),
                  isMobile: isMobile,
                  trailing: PopupMenuButton<String>(
                    onSelected: (preset) {
                      settings.applyThemePreset(preset);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Applied ${_getThemePresetText(preset)} preset')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'classic',
                        child: Text('Classic'),
                      ),
                      PopupMenuItem(
                        value: 'vibrant-dark',
                        child: Text('Vibrant Dark'),
                      ),
                      PopupMenuItem(
                        value: 'minimal',
                        child: Text('Minimal'),
                      ),
                      PopupMenuItem(
                        value: 'creative',
                        child: Text('Creative'),
                      ),
                      PopupMenuItem(
                        value: 'productivity',
                        child: Text('Productivity'),
                      ),
                      PopupMenuItem(
                        value: 'warm-evening',
                        child: Text('Warm Evening'),
                      ),
                      PopupMenuItem(
                        value: 'cool-day',
                        child: Text('Cool Day'),
                      ),
                      PopupMenuItem(
                        value: 'dynamic-system',
                        child: Text('Dynamic System'),
                      ),
                    ],
                    child: const Icon(Icons.palette),
                  ),
                ),
                SizedBox(
                  height: 70, // Fixed height to match other tiles
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.0,
                      horizontal: isMobile ? 16.0 : 20.0, // Match SettingsTile responsive padding
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.color_lens_outlined, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Dynamic Colors',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use system colors',
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
                        Switch(
                          value: settings.useDynamicColors,
                          onChanged: (value) {
                            settings.setUseDynamicColors(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(value ? 'Dynamic colors enabled' : 'Dynamic colors disabled')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.brush_outlined,
                  title: 'Color Mode',
                  subtitle: CustomizationScreen._getColorModeText(settings.colorMode),
                  isMobile: isMobile,
                  trailing: PopupMenuButton<String>(
                    onSelected: (mode) {
                      settings.setColorMode(mode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Color mode changed to ${_getColorModeText(mode)}')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'default',
                        child: Text('Default'),
                      ),
                      PopupMenuItem(
                        value: 'vibrant',
                        child: Text('Vibrant'),
                      ),
                      PopupMenuItem(
                        value: 'muted',
                        child: Text('Muted'),
                      ),
                      PopupMenuItem(
                        value: 'pastel',
                        child: Text('Pastel'),
                      ),
                      PopupMenuItem(
                        value: 'monochrome',
                        child: Text('Monochrome'),
                      ),
                      PopupMenuItem(
                        value: 'high-contrast',
                        child: Text('High Contrast'),
                      ),
                      PopupMenuItem(
                        value: 'warm',
                        child: Text('Warm'),
                      ),
                      PopupMenuItem(
                        value: 'cool',
                        child: Text('Cool'),
                      ),
                    ],
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
                SettingsTile(
                  icon: Icons.circle,
                  title: 'Custom Accent Color',
                  subtitle: 'Pick your color',
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: settings.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  onTap: () {
                    _showCustomColorPicker(context, settings);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Typography Section
            const SectionHeader(title: 'Typography'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.text_fields_outlined,
                  title: 'Font Family',
                  subtitle: settings.fontFamily,
                  isMobile: isMobile,
                  trailing: PopupMenuButton<String>(
                    onSelected: (font) {
                      settings.setFontFamily(font);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Font changed to $font')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'Nunito Sans',
                        child: Text('Nunito Sans'),
                      ),
                      PopupMenuItem(
                        value: 'Inter',
                        child: Text('Inter'),
                      ),
                      PopupMenuItem(
                        value: 'Lato',
                        child: Text('Lato'),
                      ),
                      PopupMenuItem(
                        value: 'Poppins',
                        child: Text('Poppins'),
                      ),
                      PopupMenuItem(
                        value: 'Open Sans',
                        child: Text('Open Sans'),
                      ),
                      PopupMenuItem(
                        value: 'Roboto',
                        child: Text('Roboto'),
                      ),
                    ],
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Animations Section
            const SectionHeader(title: 'Animations'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.animation_outlined,
                  title: 'Transition Type',
                  subtitle: CustomizationScreen._getTransitionTypeText(settings.transitionType),
                  isMobile: isMobile,
                  trailing: PopupMenuButton<String>(
                    onSelected: (type) {
                      settings.setTransitionType(type);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Transition type changed to ${_getTransitionTypeText(type)}')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'slide',
                        child: Text('Slide'),
                      ),
                      PopupMenuItem(
                        value: 'fade',
                        child: Text('Fade'),
                      ),
                      PopupMenuItem(
                        value: 'scale',
                        child: Text('Scale'),
                      ),
                      PopupMenuItem(
                        value: 'rotate',
                        child: Text('Rotate'),
                      ),
                      PopupMenuItem(
                        value: 'bounce',
                        child: Text('Bounce'),
                      ),
                    ],
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
                SizedBox(
                  height: 70, // Fixed height to match other tiles
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.0,
                      horizontal: isMobile ? 16.0 : 20.0, // Match SettingsTile responsive padding
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.speed_outlined, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Animation Speed',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(settings.animationSpeed * 100).round()}%',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 14,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? 80 : 120, // Responsive width
                          child: Slider(
                            value: settings.animationSpeed,
                            min: 0.5,
                            max: 2.0,
                            divisions: 6,
                            onChanged: (value) {
                              settings.setAnimationSpeed(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.timeline_outlined,
                  title: 'Easing Curve',
                  subtitle: CustomizationScreen._getEasingCurveText(settings.easingCurve),
                  isMobile: isMobile,
                  trailing: PopupMenuButton<String>(
                    onSelected: (curve) {
                      settings.setEasingCurve(curve);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Easing curve changed to ${_getEasingCurveText(curve)}')),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'easeInOutCubicEmphasized',
                        child: Text('Emphasized'),
                      ),
                      PopupMenuItem(
                        value: 'easeInOutCubic',
                        child: Text('Cubic'),
                      ),
                      PopupMenuItem(
                        value: 'easeInOut',
                        child: Text('Standard'),
                      ),
                      PopupMenuItem(
                        value: 'linear',
                        child: Text('Linear'),
                      ),
                      PopupMenuItem(
                        value: 'bounceOut',
                        child: Text('Bounce'),
                      ),
                      PopupMenuItem(
                        value: 'elasticOut',
                        child: Text('Elastic'),
                      ),
                      PopupMenuItem(
                        value: 'easeInBack',
                        child: Text('Overshoot'),
                      ),
                    ],
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ],
             ),

             const SizedBox(height: 24),

             // Experimental Section
             const SectionHeader(title: 'Experimental'),
             const SizedBox(height: 8),
             SettingsGroup(
               children: [
                 SettingsTile(
                   icon: Icons.code_outlined,
                   title: 'Code Syntax Highlighting',
                   subtitle: CustomizationScreen._getCodeHighlightThemeText(settings.codeHighlightTheme),
                   isMobile: isMobile,
                   trailing: PopupMenuButton<String>(
                     onSelected: (theme) {
                       settings.setCodeHighlightTheme(theme);
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Code highlighting changed to ${_getCodeHighlightThemeText(theme)}')),
                       );
                     },
                     itemBuilder: (context) => [
                       PopupMenuItem(
                         value: 'auto',
                         child: Text('Auto (Theme-based)'),
                       ),
                       PopupMenuItem(
                         value: 'github',
                         child: Text('GitHub'),
                       ),
                       PopupMenuItem(
                         value: 'monokai',
                         child: Text('Monokai'),
                       ),
                       PopupMenuItem(
                         value: 'vs',
                         child: Text('Visual Studio'),
                       ),
                       PopupMenuItem(
                         value: 'atom-one-dark',
                         child: Text('Atom One Dark'),
                       ),
                     ],
                     child: const Icon(Icons.arrow_drop_down),
                   ),
                 ),
               ],
             ),

             const SizedBox(height: 40),
           ],
         ),
       ),
     );

      if (onBackPressed != null) {
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
              'Customization',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2), height: 1),
            ),
          ),
          body: content,
        );
      } else {
       return content;
     }
   }







  void _showColorPicker(BuildContext context, AppSettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accent Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose your preferred accent color:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _colorOption(context, settings, Colors.blue, 'Blue'),
                _colorOption(context, settings, Colors.green, 'Green'),
                _colorOption(context, settings, Colors.purple, 'Purple'),
                _colorOption(context, settings, Colors.orange, 'Orange'),
                _colorOption(context, settings, Colors.pink, 'Pink'),
                _colorOption(context, settings, Colors.teal, 'Teal'),
                _colorOption(context, settings, const Color(0xFF6750A4), 'Default'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  static String _getThemePresetText(String preset) {
    switch (preset) {
      case 'classic':
        return 'Classic';
      case 'vibrant-dark':
        return 'Vibrant Dark';
      case 'minimal':
        return 'Minimal';
      case 'creative':
        return 'Creative';
      case 'productivity':
        return 'Productivity';
      case 'warm-evening':
        return 'Warm Evening';
      case 'cool-day':
        return 'Cool Day';
      case 'dynamic-system':
        return 'Dynamic System';
      default:
        return preset;
    }
  }

  static String _getColorModeText(String mode) {
    switch (mode) {
      case 'default':
        return 'Default';
      case 'vibrant':
        return 'Vibrant';
      case 'muted':
        return 'Muted';
      case 'pastel':
        return 'Pastel';
      case 'monochrome':
        return 'Monochrome';
      case 'high-contrast':
        return 'High Contrast';
      case 'warm':
        return 'Warm';
      case 'cool':
        return 'Cool';
      default:
        return mode;
    }
  }

  static String _getTransitionTypeText(String type) {
    switch (type) {
      case 'slide':
        return 'Slide';
      case 'fade':
        return 'Fade';
      case 'scale':
        return 'Scale';
      case 'rotate':
        return 'Rotate';
      case 'bounce':
        return 'Bounce';
      default:
        return type;
    }
  }

  static String _getEasingCurveText(String curve) {
    switch (curve) {
      case 'easeInOutCubicEmphasized':
        return 'Emphasized';
      case 'easeInOutCubic':
        return 'Cubic';
      case 'easeInOut':
        return 'Standard';
      case 'linear':
        return 'Linear';
      case 'bounceOut':
        return 'Bounce';
      case 'elasticOut':
        return 'Elastic';
      case 'easeInBack':
        return 'Overshoot';
      default:
        return curve;
    }
  }

  static String _getCodeHighlightThemeText(String theme) {
    switch (theme) {
      case 'auto':
        return 'Auto (Theme-based)';
      case 'github':
        return 'GitHub';
      case 'monokai':
        return 'Monokai';
      case 'vs':
        return 'Visual Studio';
      case 'atom-one-dark':
        return 'Atom One Dark';
      default:
        return theme;
    }
  }

  void _showCustomColorPicker(BuildContext context, AppSettingsProvider settings) {
    Color selectedColor = settings.accentColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Custom Accent Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose any color:'),
              const SizedBox(height: 16),
              // Color preview
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // HSV Color Picker (simplified version)
              _buildColorPicker(setState, selectedColor, (color) {
                setState(() => selectedColor = color);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                settings.setAccentColor(selectedColor);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Custom accent color applied')),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(StateSetter setState, Color currentColor, Function(Color) onColorChanged) {
    return Column(
      children: [
        // Hue slider
        const Text('Hue'),
        Slider(
          value: HSVColor.fromColor(currentColor).hue,
          min: 0,
          max: 360,
          onChanged: (value) {
            final hsv = HSVColor.fromColor(currentColor);
            final newColor = hsv.withHue(value).toColor();
            onColorChanged(newColor);
          },
        ),
        // Saturation slider
        const Text('Saturation'),
        Slider(
          value: HSVColor.fromColor(currentColor).saturation,
          min: 0,
          max: 1,
          onChanged: (value) {
            final hsv = HSVColor.fromColor(currentColor);
            final newColor = hsv.withSaturation(value).toColor();
            onColorChanged(newColor);
          },
        ),
        // Value/Brightness slider
        const Text('Brightness'),
        Slider(
          value: HSVColor.fromColor(currentColor).value,
          min: 0,
          max: 1,
          onChanged: (value) {
            final hsv = HSVColor.fromColor(currentColor);
            final newColor = hsv.withValue(value).toColor();
            onColorChanged(newColor);
          },
        ),
      ],
    );
  }

  Widget _colorOption(BuildContext context, AppSettingsProvider settings, Color color, String name) {
    final isSelected = settings.accentColor.value == color.value;
    return InkWell(
      onTap: () {
        settings.setAccentColor(color);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accent color changed to $name')),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                size: 24,
              )
            : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}