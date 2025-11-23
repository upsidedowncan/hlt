import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider with ChangeNotifier {
  // Animation settings
  String _transitionType = 'slide'; // 'slide', 'fade', 'scale', 'rotate', 'bounce'
  String _easingCurve = 'easeInOutCubicEmphasized'; // Easing curve for animations
  double _animationSpeed = 1.0; // 0.5x to 2.0x speed

  // Theme settings
  bool _useSystemTheme = true;
  ThemeMode _themeMode = ThemeMode.system;
  int _accentColorValue = 0xFF6750A4; // Default primary color
  double _fontSizeScale = 1.0;
  String _fontFamily = 'Nunito Sans'; // Default font family
  bool _useDynamicColors = false; // Use system dynamic colors
  String _colorMode = 'default'; // Color mode: 'default', 'vibrant', 'muted', 'pastel', 'monochrome', 'high-contrast', 'warm', 'cool'
  String _themePreset = 'classic'; // Theme preset

  // Notification settings
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  // Privacy settings
  bool _analyticsEnabled = true;

  // Experimental settings
  String _codeHighlightTheme = 'atom-one-dark'; // 'auto', 'github', 'monokai', 'vs', etc.

  // Getters
  String get transitionType => _transitionType;
  String get easingCurve => _easingCurve;
  double get animationSpeed => _animationSpeed;
  bool get useSystemTheme => _useSystemTheme;
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => Color(_accentColorValue);
  double get fontSizeScale => _fontSizeScale;
  String get fontFamily => _fontFamily;
  bool get useDynamicColors => _useDynamicColors;
  String get colorMode => _colorMode;
  String get themePreset => _themePreset;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get analyticsEnabled => _analyticsEnabled;
  String get codeHighlightTheme => _codeHighlightTheme;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _transitionType = prefs.getString('transitionType') ?? 'slide';
    _easingCurve = prefs.getString('easingCurve') ?? 'easeInOutCubicEmphasized';
    _animationSpeed = prefs.getDouble('animationSpeed') ?? 1.0;
    _useSystemTheme = prefs.getBool('useSystemTheme') ?? true;
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
    _accentColorValue = prefs.getInt('accentColor') ?? 0xFF6750A4;
    _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    _fontFamily = prefs.getString('fontFamily') ?? 'Nunito Sans';
    _useDynamicColors = prefs.getBool('useDynamicColors') ?? false;
    _colorMode = prefs.getString('colorMode') ?? 'default';
    _themePreset = prefs.getString('themePreset') ?? 'classic';
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _analyticsEnabled = prefs.getBool('analyticsEnabled') ?? true;
    _codeHighlightTheme = prefs.getString('codeHighlightTheme') ?? 'atom-one-dark';
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transitionType', _transitionType);
    await prefs.setString('easingCurve', _easingCurve);
    await prefs.setDouble('animationSpeed', _animationSpeed);
    await prefs.setBool('useSystemTheme', _useSystemTheme);
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setInt('accentColor', _accentColorValue);
    await prefs.setDouble('fontSizeScale', _fontSizeScale);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setBool('useDynamicColors', _useDynamicColors);
    await prefs.setString('colorMode', _colorMode);
    await prefs.setString('themePreset', _themePreset);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('analyticsEnabled', _analyticsEnabled);
    await prefs.setString('codeHighlightTheme', _codeHighlightTheme);
  }

  void setTransitionType(String type) {
    _transitionType = type;
    _saveSettings();
    notifyListeners();
  }

  void setEasingCurve(String curve) {
    _easingCurve = curve;
    _saveSettings();
    notifyListeners();
  }

  Curve getCurve() {
    switch (_easingCurve) {
      case 'linear':
        return Curves.linear;
      case 'ease':
        return Curves.ease;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'easeInSine':
        return Curves.easeInSine;
      case 'easeOutSine':
        return Curves.easeOutSine;
      case 'easeInOutSine':
        return Curves.easeInOutSine;
      case 'easeInQuad':
        return Curves.easeInQuad;
      case 'easeOutQuad':
        return Curves.easeOutQuad;
      case 'easeInOutQuad':
        return Curves.easeInOutQuad;
      case 'easeInCubic':
        return Curves.easeInCubic;
      case 'easeOutCubic':
        return Curves.easeOutCubic;
      case 'easeInOutCubic':
        return Curves.easeInOutCubic;
      case 'easeInQuart':
        return Curves.easeInQuart;
      case 'easeOutQuart':
        return Curves.easeOutQuart;
      case 'easeInOutQuart':
        return Curves.easeInOutQuart;
      case 'easeInQuint':
        return Curves.easeInQuint;
      case 'easeOutQuint':
        return Curves.easeOutQuint;
      case 'easeInOutQuint':
        return Curves.easeInOutQuint;
      case 'easeInExpo':
        return Curves.easeInExpo;
      case 'easeOutExpo':
        return Curves.easeOutExpo;
      case 'easeInOutExpo':
        return Curves.easeInOutExpo;
      case 'easeInCirc':
        return Curves.easeInCirc;
      case 'easeOutCirc':
        return Curves.easeOutCirc;
      case 'easeInOutCirc':
        return Curves.easeInOutCirc;
      case 'easeInBack':
        return Curves.easeInBack;
      case 'easeOutBack':
        return Curves.easeOutBack;
      case 'easeInOutBack':
        return Curves.easeInOutBack;
      case 'easeInBounce':
        return Curves.bounceIn;
      case 'easeOutBounce':
        return Curves.bounceOut;
      case 'easeInOutBounce':
        return Curves.bounceInOut;
      case 'elasticIn':
        return Curves.elasticIn;
      case 'elasticOut':
        return Curves.elasticOut;
      case 'elasticInOut':
        return Curves.elasticInOut;
      case 'easeInOutCubicEmphasized':
      default:
        return Curves.easeInOutCubicEmphasized;
    }
  }

  void setAnimationSpeed(double speed) {
    _animationSpeed = speed.clamp(0.5, 2.0);
    _saveSettings();
    notifyListeners();
  }

  void setUseSystemTheme(bool useSystem) {
    _useSystemTheme = useSystem;
    if (useSystem) {
      _themeMode = ThemeMode.system;
    }
    _saveSettings();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _useSystemTheme = mode == ThemeMode.system;
    _saveSettings();
    notifyListeners();
    print('Theme mode changed to: $mode');
  }

  void setAccentColor(Color color) {
    _accentColorValue = color.value;
    _saveSettings();
    notifyListeners();
  }

  void setFontSizeScale(double scale) {
    _fontSizeScale = scale.clamp(0.8, 1.4);
    _saveSettings();
    notifyListeners();
  }

  void setFontFamily(String family) {
    _fontFamily = family;
    _saveSettings();
    notifyListeners();
  }

  void setUseDynamicColors(bool useDynamic) {
    _useDynamicColors = useDynamic;
    _saveSettings();
    notifyListeners();
  }

  void setColorMode(String mode) {
    _colorMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setThemePreset(String preset) {
    _themePreset = preset;
    _saveSettings();
    notifyListeners();
  }

  void applyThemePreset(String preset) {
    switch (preset) {
      case 'classic':
        _themeMode = ThemeMode.system;
        _colorMode = 'default';
        _fontFamily = 'Nunito Sans';
        _accentColorValue = 0xFF6750A4; // Default purple
        _useDynamicColors = false;
        break;
      case 'vibrant-dark':
        _themeMode = ThemeMode.dark;
        _colorMode = 'vibrant';
        _fontFamily = 'Poppins';
        _accentColorValue = 0xFFFF6B6B; // Vibrant coral
        _useDynamicColors = false;
        break;
      case 'minimal':
        _themeMode = ThemeMode.light;
        _colorMode = 'muted';
        _fontFamily = 'Inter';
        _accentColorValue = 0xFF616161; // Medium gray
        _useDynamicColors = false;
        break;
      case 'creative':
        _themeMode = ThemeMode.light;
        _colorMode = 'pastel';
        _fontFamily = 'Lato';
        _accentColorValue = 0xFFE91E63; // Soft pink
        _useDynamicColors = false;
        break;
      case 'productivity':
        _themeMode = ThemeMode.light;
        _colorMode = 'muted';
        _fontFamily = 'Inter';
        _accentColorValue = 0xFF1976D2; // Professional blue
        _useDynamicColors = false;
        break;
      case 'warm-evening':
        _themeMode = ThemeMode.dark;
        _colorMode = 'warm';
        _fontFamily = 'Nunito Sans';
        _accentColorValue = 0xFFFF9800; // Warm orange
        _useDynamicColors = false;
        break;
      case 'cool-day':
        _themeMode = ThemeMode.light;
        _colorMode = 'cool';
        _fontFamily = 'Inter';
        _accentColorValue = 0xFF00BCD4; // Cool cyan
        _useDynamicColors = false;
        break;
      case 'dynamic-system':
        _themeMode = ThemeMode.system;
        _colorMode = 'default';
        _fontFamily = 'Nunito Sans';
        _accentColorValue = 0xFF6750A4; // Default purple
        _useDynamicColors = true;
        break;
    }
    _themePreset = preset;
    _saveSettings();
    notifyListeners();
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    _saveSettings();
    notifyListeners();
    print('Notifications enabled: $enabled');
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _saveSettings();
    notifyListeners();
    print('Sound enabled: $enabled');
  }

  void setAnalyticsEnabled(bool enabled) {
    _analyticsEnabled = enabled;
    _saveSettings();
    notifyListeners();
    print('Analytics enabled: $enabled');
  }

  void setCodeHighlightTheme(String theme) {
    _codeHighlightTheme = theme;
    _saveSettings();
    notifyListeners();
  }
}