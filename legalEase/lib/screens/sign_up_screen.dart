import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController about = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();
  bool accepted = false;
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    if (password.text != confirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms & policy')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'name': name.text.trim().isNotEmpty
              ? name.text.trim()
              : email.text.trim().split('@')[0],
          'about': about.text.trim().isNotEmpty ? about.text.trim() : 'User',
        },
      );

      if (mounted) {
        if (response.user != null) {
          // Profile should be created automatically by database trigger
          // But let's also try to create it manually if trigger doesn't exist yet
          try {
            final userId = response.user!.id;

            // Wait a moment for trigger to create profile
            await Future.delayed(const Duration(milliseconds: 500));

            // Check if profile already exists (from trigger)
            try {
              final existingProfile = await SupabaseService.client
                  .from('profiles')
                  .select()
                  .eq('user_id', userId)
                  .maybeSingle();

              // Only create profile if it doesn't exist
              if (existingProfile == null) {
                final profileName = name.text.trim().isNotEmpty
                    ? name.text.trim()
                    : email.text.trim().split('@')[0];
                final profileAbout = about.text.trim().isNotEmpty
                    ? about.text.trim()
                    : 'User';

                await SupabaseService.client.from('profiles').insert({
                  'user_id': userId,
                  'name': profileName,
                  'about': profileAbout,
                  'role': 'user',
                });
              }
            } catch (tableError) {
              // Table might not exist - show helpful error
              if (tableError.toString().contains('relation') ||
                  tableError.toString().contains('does not exist') ||
                  tableError.toString().contains('42P01')) {
                throw Exception('profiles_table_not_found');
              }
              rethrow;
            }
          } catch (profileError) {
            // Check if error is about missing table
            if (profileError.toString().contains('profiles_table_not_found') ||
                profileError.toString().contains('relation') ||
                profileError.toString().contains('does not exist')) {
              throw Exception(
                'Database tables not created. Please run the SQL migrations in Supabase Dashboard first.',
              );
            }
            // Profile might already exist from trigger
            debugPrint('Profile creation note: $profileError');
            // Continue anyway - trigger might have created it
          }

          // After successful signup, redirect user to sign-in screen instead of home.
          Navigator.pushReplacementNamed(context, '/signin');
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        // Provide more user-friendly error messages
        String displayMessage = 'Sign up failed';
        if (errorMessage.contains('email') || errorMessage.contains('Email')) {
          displayMessage =
              'This email is already registered. Please sign in instead.';
        } else if (errorMessage.contains('password') ||
            errorMessage.contains('Password')) {
          displayMessage =
              'Password is too weak. Please use a stronger password.';
        } else if (errorMessage.contains('Database error') ||
            errorMessage.contains('500') ||
            errorMessage.contains('not created') ||
            errorMessage.contains('migration')) {
          displayMessage =
              '⚠️ Database tables not created!\n\nPlease run the SQL migrations in Supabase Dashboard:\n\n1. Go to: https://supabase.com/dashboard\n2. Open SQL Editor\n3. Run: 001_create_tables.sql\n4. Run: 002_create_profile_trigger.sql\n\nSee: supabase/migrations/README_FIX_AUTH.md';
        } else {
          displayMessage =
              'Sign up failed: ${errorMessage.length > 100 ? errorMessage.substring(0, 100) + '...' : errorMessage}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(controller: name, hintText: 'Name'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: email,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: about,
                  hintText: 'About you (User / Admin)',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: password,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: confirm,
                  hintText: 'Confirm Password',
                  obscureText: true,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: accepted,
                      onChanged: (v) => setState(() => accepted = v ?? false),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70),
                          children: [
                            const TextSpan(text: 'I understand the '),
                            TextSpan(
                              text: 'terms & policy',
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final url = Uri.parse(
                                    'https://1drv.ms/w/c/b139b2ef3a39b056/Ec_HHR-1J39Llfh0irazW7IB8uwAuVluhpy5FBVUz_nSDw?e=peYeK2',
                                  );
                                  bool opened = false;
                                  try {
                                    opened = await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {}
                                  if (!opened) {
                                    try {
                                      opened = await launchUrl(
                                        url,
                                        mode: LaunchMode.inAppBrowserView,
                                      );
                                    } catch (_) {}
                                  }
                                  if (!opened && mounted) {
                                    await Clipboard.setData(
                                      ClipboardData(text: url.toString()),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not open. Link copied to clipboard.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
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
                      : const Text('SIGN UP'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'or sign up with',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50), // only height
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signin'),
                  child: const Text(
                    'Have an account? SIGN IN',
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
