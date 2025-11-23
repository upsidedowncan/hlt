import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user.dart' as app_user;
import '../../shared/repositories/profile_service.dart';

class UserProvider with ChangeNotifier {
  app_user.User? _currentUser;
  bool _isLoading = false;
  String? _error;

  app_user.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCurrentUser() async {
    _setLoading(true);
    _error = null;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Try to get full profile from database
        final profile = await ProfileService.getCurrentUserProfile();
        if (profile != null) {
          _currentUser = profile;
        } else {
          // Fallback to basic auth user
          _currentUser = app_user.User(
            id: user.id,
            email: user.email ?? '',
            displayName: user.email?.split('@').first ?? 'User',
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile() async {
    if (_currentUser != null) {
      final profile = await ProfileService.getCurrentUserProfile();
      if (profile != null) {
        _currentUser = profile;
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _error = null;

    try {
      // Update online status before signing out
      if (_currentUser != null) {
        await ProfileService.updateOnlineStatus(false);
      }
      
      await Supabase.instance.client.auth.signOut();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}