import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_settings_provider.dart';

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Section
            _buildSectionHeader('Theme', Icons.palette, theme),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Theme Mode'),
                    subtitle: Text(_getThemeModeText(settings.themeMode)),
                    trailing: PopupMenuButton<ThemeMode>(
                      onSelected: (mode) {
                        print('Theme mode selected: $mode');
                        settings.setThemeMode(mode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Theme changed to ${_getThemeModeText(mode)}')),
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        const PopupMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        const PopupMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Animations Section
            _buildSectionHeader('Animations', Icons.animation, theme),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Page Transitions'),
                    subtitle: Text(_getTransitionTypeText(settings.transitionType)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (type) {
                        print('Transition type selected: $type');
                        settings.setTransitionType(type);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transition changed to ${_getTransitionTypeText(type)}')),
                        );
                      },
                       itemBuilder: (context) => [
                         const PopupMenuItem(
                           value: 'slide',
                           child: Text('Slide'),
                         ),
                         const PopupMenuItem(
                           value: 'fade',
                           child: Text('Fade'),
                         ),
                         const PopupMenuItem(
                           value: 'scale',
                           child: Text('Scale'),
                         ),
                         const PopupMenuItem(
                           value: 'rotate',
                           child: Text('Rotate'),
                         ),
                         const PopupMenuItem(
                           value: 'bounce',
                           child: Text('Bounce'),
                         ),
                       ],
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                  ),
                   Divider(height: 1, color: theme.dividerColor),
                   ListTile(
                     title: const Text('Animation Speed'),
                     subtitle: Text('${(settings.animationSpeed * 100).round()}%'),
                     trailing: SizedBox(
                       width: 120,
                       child: Slider(
                         value: settings.animationSpeed,
                         min: 0.5,
                         max: 2.0,
                         divisions: 6,
                         onChanged: (value) {
                           print('Animation speed changed to: $value');
                           settings.setAnimationSpeed(value);
                         },
                       ),
                     ),
                   ),
                   Divider(height: 1, color: theme.dividerColor),
                   ListTile(
                     title: const Text('Easing Curve'),
                     subtitle: Text(_getEasingCurveText(settings.easingCurve)),
                     trailing: PopupMenuButton<String>(
                       onSelected: (curve) {
                         settings.setEasingCurve(curve);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Easing curve changed to ${_getEasingCurveText(curve)}')),
                         );
                       },
                       itemBuilder: (context) => [
                         const PopupMenuItem(
                           value: 'easeInOutCubicEmphasized',
                           child: Text('Emphasized'),
                         ),
                         const PopupMenuItem(
                           value: 'easeInOutCubic',
                           child: Text('Cubic'),
                         ),
                         const PopupMenuItem(
                           value: 'easeInOut',
                           child: Text('Standard'),
                         ),
                         const PopupMenuItem(
                           value: 'linear',
                           child: Text('Linear'),
                         ),
                         const PopupMenuItem(
                           value: 'bounceOut',
                           child: Text('Bounce'),
                         ),
                         const PopupMenuItem(
                           value: 'elasticOut',
                           child: Text('Elastic'),
                         ),
                         const PopupMenuItem(
                           value: 'easeInBack',
                           child: Text('Overshoot'),
                         ),
                       ],
                       child: const Icon(Icons.timeline),
                     ),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Colors Section
             _buildSectionHeader('Colors', Icons.color_lens, theme),
             const SizedBox(height: 16),

             Container(
               decoration: BoxDecoration(
                 color: theme.colorScheme.surfaceContainerHighest,
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Column(
                 children: [
                   ListTile(
                     title: const Text('Theme Presets'),
                     subtitle: Text(_getThemePresetText(settings.themePreset)),
                     trailing: PopupMenuButton<String>(
                       onSelected: (preset) {
                         settings.applyThemePreset(preset);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Applied ${_getThemePresetText(preset)} preset')),
                         );
                       },
                       itemBuilder: (context) => [
                         const PopupMenuItem(
                           value: 'classic',
                           child: Text('Classic'),
                         ),
                         const PopupMenuItem(
                           value: 'vibrant-dark',
                           child: Text('Vibrant Dark'),
                         ),
                         const PopupMenuItem(
                           value: 'minimal',
                           child: Text('Minimal'),
                         ),
                         const PopupMenuItem(
                           value: 'creative',
                           child: Text('Creative'),
                         ),
                         const PopupMenuItem(
                           value: 'productivity',
                           child: Text('Productivity'),
                         ),
                         const PopupMenuItem(
                           value: 'warm-evening',
                           child: Text('Warm Evening'),
                         ),
                         const PopupMenuItem(
                           value: 'cool-day',
                           child: Text('Cool Day'),
                         ),
                         const PopupMenuItem(
                           value: 'dynamic-system',
                           child: Text('Dynamic System'),
                         ),
                       ],
                       child: const Icon(Icons.palette),
                     ),
                   ),
                   Divider(height: 1, color: theme.dividerColor),
                   SwitchListTile(
                     title: const Text('Dynamic Colors'),
                     subtitle: const Text('Use system accent colors when available'),
                     value: settings.useDynamicColors,
                     onChanged: (value) {
                       settings.setUseDynamicColors(value);
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(value ? 'Dynamic colors enabled' : 'Dynamic colors disabled')),
                       );
                     },
                   ),
                   Divider(height: 1, color: theme.dividerColor),
                   ListTile(
                     title: const Text('Color Mode'),
                     subtitle: Text(_getColorModeText(settings.colorMode)),
                     trailing: PopupMenuButton<String>(
                       onSelected: (mode) {
                         settings.setColorMode(mode);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Color mode changed to ${_getColorModeText(mode)}')),
                         );
                       },
                       itemBuilder: (context) => [
                         const PopupMenuItem(
                           value: 'default',
                           child: Text('Default'),
                         ),
                         const PopupMenuItem(
                           value: 'vibrant',
                           child: Text('Vibrant'),
                         ),
                         const PopupMenuItem(
                           value: 'muted',
                           child: Text('Muted'),
                         ),
                         const PopupMenuItem(
                           value: 'pastel',
                           child: Text('Pastel'),
                         ),
                         const PopupMenuItem(
                           value: 'monochrome',
                           child: Text('Monochrome'),
                         ),
                         const PopupMenuItem(
                           value: 'high-contrast',
                           child: Text('High Contrast'),
                         ),
                         const PopupMenuItem(
                           value: 'warm',
                           child: Text('Warm'),
                         ),
                         const PopupMenuItem(
                           value: 'cool',
                           child: Text('Cool'),
                         ),
                       ],
                       child: const Icon(Icons.arrow_drop_down),
                     ),
                   ),
                   Divider(height: 1, color: theme.dividerColor),
                   ListTile(
                     title: const Text('Custom Accent Color'),
                     subtitle: const Text('Choose your preferred accent color'),
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
            ),

            const SizedBox(height: 24),

            // Typography Section
            _buildSectionHeader('Typography', Icons.text_fields, theme),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Font Size'),
                    subtitle: Text('${(settings.fontSizeScale * 100).round()}%'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: settings.fontSizeScale,
                        min: 0.8,
                        max: 1.4,
                        divisions: 6,
                        onChanged: (value) {
                          settings.setFontSizeScale(value);
                        },
                      ),
                    ),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                   ListTile(
                     title: const Text('Font Family'),
                     subtitle: Text(settings.fontFamily),
                     trailing: PopupMenuButton<String>(
                       onSelected: (font) {
                         settings.setFontFamily(font);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Font changed to $font')),
                         );
                       },
                       itemBuilder: (context) => [
                         const PopupMenuItem(
                           value: 'Nunito Sans',
                           child: Text('Nunito Sans'),
                         ),
                         const PopupMenuItem(
                           value: 'Inter',
                           child: Text('Inter'),
                         ),
                         const PopupMenuItem(
                           value: 'Lato',
                           child: Text('Lato'),
                         ),
                         const PopupMenuItem(
                           value: 'Poppins',
                           child: Text('Poppins'),
                         ),
                         const PopupMenuItem(
                           value: 'Open Sans',
                           child: Text('Open Sans'),
                         ),
                         const PopupMenuItem(
                           value: 'Roboto',
                           child: Text('Roboto'),
                         ),
                       ],
                       child: const Icon(Icons.arrow_drop_down),
                     ),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
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
          ),
        ),
      ],
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getTransitionTypeText(String type) {
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
        return 'Slide';
    }
  }

  String _getColorModeText(String mode) {
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
        return 'Default';
    }
  }

  String _getThemePresetText(String preset) {
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
        return 'Classic';
    }
  }

  String _getEasingCurveText(String curve) {
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
        return 'Emphasized';
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
            const Text('Choose your preferred accent color:'),
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
              const Text('Choose any color:'),
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
}