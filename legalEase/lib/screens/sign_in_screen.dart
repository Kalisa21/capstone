import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _RoleToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primary : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool remember = false;
  bool _isLoading = false;
  bool _isAdmin = false;

  Future<void> _signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Debug logging of environment + email (do not log password)
      try {
        // Using dotenv directly here is optional; SupabaseService already loaded it.
        // ignore: avoid_print
        print('[auth] Attempting sign in email="${email.text.trim()}"');
      } catch (_) {}
      await SupabaseService.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final role = await _fetchUserRole();
      if (!mounted) return;

      if (role == null) {
        await SupabaseService.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load your profile details. Please contact support.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final roleLower = role.toLowerCase();
      final hasAdminRole = roleLower == 'admin';

      if (_isAdmin && !hasAdminRole) {
        await SupabaseService.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have admin permissions.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final targetRoute =
          _isAdmin && hasAdminRole ? Routes.admin : Routes.home;
      Navigator.pushReplacementNamed(context, targetRoute);
    } catch (e) {
      if (mounted) {
        // ignore: avoid_print
        print('[auth] Sign in exception type=${e.runtimeType} details=$e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _fetchUserRole() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final result = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      if (result == null) return null;
      final role = result['role'];
      return role is String ? role : role?.toString();
    } catch (error) {
      debugPrint('Failed to fetch profile role: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 26),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Sign in your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _RoleToggleButton(
                        label: 'User',
                        isSelected: !_isAdmin,
                        onTap: () => setState(() => _isAdmin = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleToggleButton(
                        label: 'Admin',
                        isSelected: _isAdmin,
                        onTap: () => setState(() => _isAdmin = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: email,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: password,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: remember,
                          onChanged: (v) =>
                              setState(() => remember = v ?? false),
                        ),
                        const Text(
                          'Remember me',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SIGN IN'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'or sign in with',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      0,
                      50,
                    ), // height 50, no forced width
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      child: Image.asset(
                        'assets/google.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text(
                    "Don't have an account? SIGN UP",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
