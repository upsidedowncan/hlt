class AppConstants {
  // App Info
  static const String appName = 'HLT';
  static const String appTagline = 'Hey, Let\'s Talk!';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://nxysjmplxspdhgoybieo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im54eXNqbXBseHNwZGhnb3liaWVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNjkzNzksImV4cCI6MjA3ODg0NTM3OX0.PU0R_ggzCpp7xrqxXBI1TLLbA9V7224KJcldG-yONBo';
  
  // Table Names
  static const String usersTable = 'users';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String participantsTable = 'participants';
  
  // Storage
  static const String avatarsBucket = 'avatars';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
   // Routes
   static const String splashRoute = '/splash';
   static const String authRoute = '/auth';
   static const String homeRoute = '/home';
   static const String chatRoute = '/chat';
   static const String aiVisualizationRoute = '/ai-visualization';
   static const String htmlVisualizationRoute = '/html-visualization';
   static const String profileRoute = '/profile';
   static const String settingsRoute = '/settings';
    static const String aiSettingsRoute = '/ai-settings';
    static const String customizationRoute = '/customization';
    static const String callRoute = '/call';
    static const String incomingCallRoute = '/incoming-call';
}
