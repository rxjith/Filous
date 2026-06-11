import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isSignInMode = true;
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignInMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('Auth Error: ${error.code} - ${error.message}');
      String message = error.message ?? 'Authentication failed';
      
      if (message.contains('CONFIGURATION_NOT_FOUND')) {
        message = 'Firebase Auth is not fully set up. Please enable "Email/Password" in your Firebase Console.';
      }
      
      _showError(message);
    } catch (error) {
      debugPrint('General Auth Error: $error');
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      debugPrint('Google Sign-In Error (Firebase): ${error.code} - ${error.message}');
      String message = error.message ?? 'Google Sign-In Failed';
      if (message.contains('CONFIGURATION_NOT_FOUND')) {
        message = 'Google Auth is not enabled in Firebase Console.';
      }
      _showError(message);
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      String message = 'Google Sign-In failed.';
      if (error.toString().contains('ApiException: 10')) {
        message = 'Google Sign-In Error (10): Ensure your SHA-1 fingerprint is added to Firebase Console.';
      }
      _showError(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      debugPrint('Guest Sign-In Error (Firebase): ${error.code} - ${error.message}');
      String message = error.message ?? 'Guest login failed';
      if (error.code == 'admin-restricted-operation' || message.contains('CONFIGURATION_NOT_FOUND')) {
        message = 'Guest login (Anonymous) is disabled in Firebase Console.';
      }
      _showError(message);
    } catch (error) {
      debugPrint('Guest Sign-In Error: $error');
      _showError('Could not log in as guest.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Prevent keyboard layout compression bugs entirely
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Section
                  Icon(Icons.account_balance_wallet, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isSignInMode ? 'WELCOME BACK' : 'CREATE ACCOUNT',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  Text(
                    _isSignInMode ? 'Log into your Filous vault' : 'Start tracking your financial pipeline',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Email Input Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined), isDense: true),
                    validator: (val) => (val == null || !val.contains('@')) ? 'Please enter a valid email address' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password Input Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: _isSignInMode ? TextInputAction.done : TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outlined), isDense: true),
                    validator: (val) => (val == null || val.trim().length < 6) ? 'Password must be at least 6 characters long' : null,
                    onFieldSubmitted: (_) => _isSignInMode ? _submitAuthForm() : null,
                  ),
                  
                  // Conditional Confirm Password Field (Only shows up during Sign Up Mode)
                  if (!_isSignInMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_clock_outlined), isDense: true),
                      validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                      onFieldSubmitted: (_) => _submitAuthForm(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Primary Standard Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitAuthForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignInMode ? 'SIGN IN' : 'REGISTER', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clean "OR" Separator Layout
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.4))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('OR CONTINUE WITH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4))),
                      ),
                      Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.4))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Styled Third-Party Identity Provider Button (Google)
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                    ),
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 20,
                      width: 20,
                      errorBuilder: (context, _, __) => const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    label: Text(
                      _isSignInMode ? 'Sign in with Google' : 'Sign up with Google',
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Guest Login Option
                  TextButton(
                    onPressed: _isLoading ? null : _handleGuestSignIn,
                    child: const Text(
                      'Continue as Guest',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // Interactive Mode Toggle link
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _formKey.currentState?.reset();
                            setState(() => _isSignInMode = !_isSignInMode);
                          },
                    child: Text(
                      _isSignInMode ? "Don't have an account? Sign Up" : 'Already have an account? Sign In',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}