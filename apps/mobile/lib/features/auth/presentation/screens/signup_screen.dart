import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signup() {
    if (_formKey.currentState!.validate()) {
      ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surface),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Create account',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start renting smarter today.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 36),
                    SkipItTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'John Doe',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SkipItTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Email is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SkipItTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Password is required';
                        if (value.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SkipItTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SkipItButton(
                      label: 'Create Account',
                      isLoading: authState.status == AuthStatus.loading,
                      onPressed: _signup,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.surface)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        ),
                        const Expanded(child: Divider(color: AppColors.surface)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                        icon: Image.network(
                          'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                          height: 24,
                          errorBuilder: (_, __, ___) => const Icon(Icons.login, color: AppColors.primary),
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.surface),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
