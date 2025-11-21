import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user.dart' as app_user;

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<app_user.User?> getCurrentUserProfile() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return null;
      }

      final response = await _client.rpc('get_current_user').single();
      debugPrint('ProfileService: RPC response: $response');

      final user = app_user.User.fromMap(response);
      debugPrint('ProfileService: Parsed user: $user');
      return user;
    } catch (e) {
      debugPrint('ProfileService: Error fetching current user profile: $e');
      // If user doesn't exist in database, create a basic profile
      try {
        final currentUser = _client.auth.currentUser;
        if (currentUser != null) {
          return app_user.User(
            id: currentUser.id,
            email: currentUser.email ?? '',
            displayName: currentUser.email?.split('@').first ?? 'User',
            isOnline: true,
          );
        }
      } catch (fallbackError) {
        debugPrint('ProfileService: Fallback user creation failed: $fallbackError');
      }
      return null;
    }
  }

  static Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromMap(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  static Future<bool> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (displayName != null) updateData['display_name'] = displayName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await _client
          .from('users')
          .update(updateData)
          .eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  static Future<String?> uploadAvatar(File imageFile) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';

      await _client.storage
          .from('avatars')
          .upload(fileName, imageFile);

      final response = _client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return response;
} catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  static Future<bool> updateOnlineStatus(bool isOnline) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('Error updating online status: $e');
      return false;
    }
  }

  static Future<List<app_user.User>> searchUsers(String query) async {
    try {
      debugPrint('ProfileService: Searching for users with query: "$query"');
      if (query.isEmpty) {
        debugPrint('ProfileService: Query is empty, returning empty list');
        return [];
      }

      debugPrint('ProfileService: Calling search_users database function...');

      // Call the database function via RPC
      final response = await _client.rpc('search_users', params: {
        'search_query': query,
      });

      debugPrint('ProfileService: Database function response: $response');
      final users = (response as List<dynamic>)
          .map((user) => app_user.User.fromMap(user as Map<String, dynamic>))
          .toList();

      debugPrint('ProfileService: Found ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('ProfileService: Error searching users: $e');
      return [];
    }
  }
}