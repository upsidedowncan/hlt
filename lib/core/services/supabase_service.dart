import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient? _client;
  
  static SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
  
  // Auth helpers
  static GoTrueClient get auth => client.auth;
  
  // Database helpers
  static SupabaseQueryBuilder Function(String) get database => client.from;
  
  // Storage helpers
  static SupabaseStorageClient get storage => client.storage;
  
  // Realtime helpers
  static RealtimeChannel getChannel(String channelName) {
    return client.channel(channelName);
  }
}