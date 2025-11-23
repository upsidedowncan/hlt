import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/ai_visualization_screen.dart';
import '../../features/chat/screens/html_visualization_screen.dart';
import '../../features/chat/screens/ai_settings_screen.dart';
import '../../features/chat/screens/call_screen.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

import '../../features/settings/screens/customization_screen.dart';
import '../constants/app_constants.dart';
import '../providers/app_settings_provider.dart';

class AppRouter {
  // Custom page builder with dynamic transitions
  static Page<void> _buildPageWithTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    bool slideFromRight = true,
  }) {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);

    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final transitionType = settings.transitionType;
        final curve = settings.getCurve();

        switch (transitionType) {
          case 'fade':
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: curve,
              ),
              child: child,
            );
          case 'scale':
            return ScaleTransition(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )),
              child: child,
            );
          case 'rotate':
            return RotationTransition(
              turns: Tween<double>(
                begin: slideFromRight ? 0.1 : -0.1,
                end: 0.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )),
              child: child,
            );
          case 'bounce':
            return SlideTransition(
              position: Tween<Offset>(
                begin: slideFromRight ? const Offset(1.2, 0.0) : const Offset(-1.2, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.bounceOut,
              )),
              child: child,
            );
          case 'slide':
          default:
            const begin = Offset(1.0, 0.0); // Slide from right
            const end = Offset.zero;

            final tween = Tween(begin: slideFromRight ? begin : -begin, end: end)
                .chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
        }
      },
      transitionDuration: Duration(milliseconds: (400 * settings.animationSpeed).round()),
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthRoute = state.uri.toString() == AppConstants.authRoute;
      final isSplashRoute = state.uri.toString() == AppConstants.splashRoute;
      
      if (session == null && !isAuthRoute && !isSplashRoute) {
        return AppConstants.authRoute;
      }
      
      if (session != null && isAuthRoute) {
        return AppConstants.homeRoute;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.splashRoute,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.authRoute,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const AuthScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.homeRoute,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),

       // ---------- THIS IS THE CORRECTED ROUTE ----------
       GoRoute(
         path: AppConstants.chatRoute,
         pageBuilder: (context, state) => _buildPageWithTransition(
           context: context,
           state: state,
           child: Builder(
             builder: (context) {
               final conversationId = state.uri.queryParameters['conversationId'];
               final aiConversationId = state.uri.queryParameters['aiConversationId'];
               return ChatScreen(
                 conversationId: conversationId,
                 aiConversationId: aiConversationId,
               );
             },
           ),
         ),
       ),
       GoRoute(
         path: AppConstants.aiVisualizationRoute,
         pageBuilder: (context, state) => _buildPageWithTransition(
           context: context,
           state: state,
           child: const AiVisualizationScreen(),
         ),
       ),
       GoRoute(
         path: AppConstants.htmlVisualizationRoute,
         pageBuilder: (context, state) => _buildPageWithTransition(
           context: context,
           state: state,
           child: const HtmlVisualizationScreen(),
         ),
       ),
       // -------------------------------------------------

      GoRoute(
        path: AppConstants.profileRoute,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),

      GoRoute(
        path: AppConstants.aiSettingsRoute,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const AiSettingsScreen(),
          slideFromRight: false, // Slide from left for back navigation
        ),
      ),
        GoRoute(
          path: AppConstants.customizationRoute,
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: const CustomizationScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.callRoute,
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: Builder(
              builder: (context) {
                final receiverId = state.uri.queryParameters['receiverId'];
                final callId = state.uri.queryParameters['callId'];
                final conversationId = state.uri.queryParameters['conversationId'];
                return CallScreen(
                  receiverId: receiverId,
                  callId: callId,
                  conversationId: conversationId,
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: AppConstants.incomingCallRoute,
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: Builder(
              builder: (context) {
                final callId = state.uri.queryParameters['callId'];
                final callerId = state.uri.queryParameters['callerId'];

                if (callId == null || callerId == null) {
                  // Handle missing parameters
                  return const Scaffold(
                    body: Center(
                      child: Text('Invalid call parameters'),
                    ),
                  );
                }

                return IncomingCallScreen(
                  callId: callId,
                  callerId: callerId,
                );
              },
            ),
          ),
        ),
    ],
  );
}

// The SplashScreen code remains unchanged.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    // Wait for 2 seconds to show splash, then check auth state
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        context.go(AppConstants.homeRoute);
      } else {
        context.go(AppConstants.authRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
