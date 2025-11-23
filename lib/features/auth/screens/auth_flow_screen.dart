import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/auth_text_field.dart';

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  // Controllers
  late PageController _pageController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Keys
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // State
  int _currentPage = 0;
  bool _isLoading = false;
  bool _emailExists = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Navigation Logic
  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  void _handleBack() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  // Auth Logic
  Future<void> _onContinuePressed() async {
    if (_isLoading) return;

    // 1. Welcome Screen -> Email Screen
    if (_currentPage == 0) {
      _goToPage(1);
      return;
    }

    // 2. Email Screen -> Check Logic -> Password Screen
    if (_currentPage == 1) {
      if (!_emailFormKey.currentState!.validate()) return;
      await _checkEmail();
      return;
    }

    // 3. Password Screen -> Submit
    if (_currentPage == 2) {
      if (!_passwordFormKey.currentState!.validate()) return;
      await _handleAuth();
      return;
    }
  }

  Future<void> _checkEmail() async {
    setState(() => _isLoading = true);
    try {
      // Mocking network delay for smoothness if RPC is too fast
      // await Future.delayed(const Duration(milliseconds: 500));
      
      final response = await SupabaseService.client.rpc(
        'user_exists',
        params: {'email_input': _emailController.text.trim()},
      );

      // Handle different possible response formats from Supabase RPC
      if (response is bool) {
        _emailExists = response;
      } else if (response is Map<String, dynamic>) {
        // If response is a map like {"exists": true}
        _emailExists = response['exists'] as bool? ?? false;
      } else {
        // Fallback: assume user doesn't exist if we can't determine
        _emailExists = false;
      }
      _goToPage(2);
    } catch (e) {
      if (mounted) _showError('Error checking email: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_emailExists) {
        await SupabaseService.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await SupabaseService.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please verify your email.')),
          );
        }
      }
      
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic background color based on theme
    final backgroundColor = isDark 
        ? theme.colorScheme.surface 
        : const Color(0xFF075E54); 
        // Keep WhatsApp green for Light Mode, or use theme.primaryColor

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar (Back Button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        onPressed: _currentPage > 0 ? _handleBack : null,
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Scrollable Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  children: [
                    _WelcomePage(isDark: isDark),
                    _EmailPage(
                      controller: _emailController,
                      formKey: _emailFormKey,
                      isDark: isDark,
                      onSubmit: _onContinuePressed,
                    ),
                    _PasswordPage(
                      email: _emailController.text,
                      isExistingUser: _emailExists,
                      passwordController: _passwordController,
                      confirmController: _confirmPasswordController,
                      formKey: _passwordFormKey,
                      obscurePassword: _obscurePassword,
                      obscureConfirm: _obscureConfirmPassword,
                      isDark: isDark,
                      onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      onToggleConfirm: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      onSubmit: _onContinuePressed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFab(theme, isDark),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildFab(ThemeData theme, bool isDark) {
    // Determine label and icon based on state
    String label = 'Get Started';
    IconData icon = Icons.arrow_forward;

    if (_currentPage == 1) {
      label = 'Continue';
    } else if (_currentPage == 2) {
      label = _emailExists ? 'Sign In' : 'Sign Up';
      icon = _emailExists ? Icons.login : Icons.person_add;
    }

    final fabColor = isDark ? theme.colorScheme.primary : Colors.white;
    final fabTextColor = isDark ? theme.colorScheme.onPrimary : const Color(0xFF075E54);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 16),
      child: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _onContinuePressed,
        backgroundColor: fabColor,
        foregroundColor: fabTextColor,
        elevation: 4,
        highlightElevation: 8,
        icon: _isLoading 
          ? Container(
              width: 24, 
              height: 24, 
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                strokeWidth: 2, 
                color: fabTextColor,
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(icon)),
            ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

// --- Sub-Pages Components ---

class _WelcomePage extends StatelessWidget {
  final bool isDark;
  const _WelcomePage({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Hero(
            tag: 'auth_logo',
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 50,
                color: isDark ? Theme.of(context).colorScheme.onPrimaryContainer : const Color(0xFF075E54),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome to HLT',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect with friends and family\nseamlessly and securely.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white70 : Colors.white70,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
          // Space for FAB
          const SizedBox(height: 80), 
        ],
      ),
    );
  }
}

class _EmailPage extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isDark;
  final VoidCallback onSubmit;

  const _EmailPage({
    required this.controller,
    required this.formKey,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'auth_logo',
            child: SizedBox(
              height: 60,
              width: 60,
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: isDark ? Colors.white54 : Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter your email',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.white,
            ),
          ),
           const SizedBox(height: 8),
           Text(
             "We'll check if you have an account",
             style: TextStyle(
               fontSize: 16,
               color: isDark ? Colors.white70 : Colors.white70,
             ),
           ),
           const SizedBox(height: 32),
           Form(
             key: formKey,
             child: Container(
               decoration: BoxDecoration(
                 color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
                 borderRadius: BorderRadius.circular(16),
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.1),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   )
                 ],
               ),
               padding: const EdgeInsets.all(4),
               child: AuthTextField(
                 controller: controller,
                 labelText: 'Email Address',
                 keyboardType: TextInputType.emailAddress,
                 textInputAction: TextInputAction.done,
                 onSubmitted: (_) => onSubmit(),
                 validator: (value) {
                   if (value == null || value.isEmpty) return 'Email is required';
                   if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                     return 'Please enter a valid email';
                   }
                   return null;
                 },
               ),
             ),
           ),
         ],
       ),
     );
   }
 }

class _PasswordPage extends StatelessWidget {
  final String email;
  final bool isExistingUser;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final GlobalKey<FormState> formKey;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool isDark;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  const _PasswordPage({
    required this.email,
    required this.isExistingUser,
    required this.passwordController,
    required this.confirmController,
    required this.formKey,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.isDark,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'auth_logo',
              child: SizedBox(
                height: 60,
                width: 60,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: isDark ? Colors.white54 : Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isExistingUser ? 'Welcome back' : 'Create account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: isDark ? Colors.white70 : Colors.white70),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: passwordController,
                      labelText: 'Password',
                      obscureText: obscurePassword,
                      textInputAction: isExistingUser ? TextInputAction.done : TextInputAction.next,
                      onSubmitted: isExistingUser ? (_) => onSubmit() : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: onTogglePassword,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    if (!isExistingUser) ...[
                      Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                      AuthTextField(
                        controller: confirmController,
                        labelText: 'Confirm Password',
                        obscureText: obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onSubmit(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: onToggleConfirm,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value != passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
