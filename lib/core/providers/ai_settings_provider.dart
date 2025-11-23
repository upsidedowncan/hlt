import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsProvider with ChangeNotifier {
  bool _useDeepMode = false; // false = Quick (Z.ai), true = Deep (Perplexity)
  int _memoryMessageCount = 10; // Number of previous messages to include in AI context

  bool get useDeepMode => _useDeepMode;
  int get memoryMessageCount => _memoryMessageCount;

  AiSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useDeepMode = prefs.getBool('useDeepMode') ?? false;
    _memoryMessageCount = prefs.getInt('memoryMessageCount') ?? 10;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDeepMode', _useDeepMode);
    await prefs.setInt('memoryMessageCount', _memoryMessageCount);
  }

  void toggleAiMode() {
    _useDeepMode = !_useDeepMode;
    _saveSettings();
    notifyListeners();
  }

  void setMemoryMessageCount(int count) {
    _memoryMessageCount = count.clamp(0, 50);
    _saveSettings();
    notifyListeners();
  }
}