import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Autofill
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/constants/terms_and_policies.dart';

// ==============================================================================
// 1. THE WRAPPER (Mobile Only)
// ==============================================================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: LoginFormContent(),
        ),
      ),
    );
  }
}

// ==============================================================================
// 2. THE CONTENT (Reusable Logic)
// ==============================================================================
class LoginFormContent extends StatefulWidget {
  const LoginFormContent({super.key});

  @override
  State<LoginFormContent> createState() => _LoginFormContentState();
}

class _LoginFormContentState extends State<LoginFormContent> {
  // --- PERSISTENCE LAYER ---
  // Static variables survive widget destruction/re-creation.
  // This fixes the issue where data disappears if the app reloads the LoginScreen.
  static String _preservedEmail = '';
  static String _preservedPassword = '';
  static String _preservedName = '';

  // Controllers
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nameController;

  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _acceptedTerms = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Controllers with Preserved Data
    _emailController = TextEditingController(text: _preservedEmail);
    _passwordController = TextEditingController(text: _preservedPassword);
    _nameController = TextEditingController(text: _preservedName);

    // 2. Add Listeners to update Preserved Data in real-time
    _emailController.addListener(() {
      _preservedEmail = _emailController.text;
    });
    _passwordController.addListener(() {
      _preservedPassword = _passwordController.text;
    });
    _nameController.addListener(() {
      _preservedName = _nameController.text;
    });

    // 3. Check for missed errors (Screen Flicker Fix)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AuthBloc>().state;
      if (state is AuthError) {
        _showErrorSnackBar(context, state);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- HELPER: Centralized Error Handling ---
  void _showErrorSnackBar(BuildContext context, AuthError state) {
    FocusScope.of(context).unfocus(); // Force Keyboard close

    final bool isVerificationError = state.isVerificationError;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: isVerificationError
            ? SnackBarAction(
                label: 'RESEND EMAIL',
                textColor: Colors.white,
                onPressed: () {
                  // Use the Preserved/Current values to resend
                  final email = _emailController.text.trim();
                  final pass = _passwordController.text;

                  if (email.isNotEmpty && pass.isNotEmpty) {
                    context.read<AuthBloc>().add(
                          AuthResendVerificationEmail(email, pass),
                        );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Fields empty. Please re-enter credentials."),
                      ),
                    );
                  }
                },
              )
            : SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // ---------------------------------------------------------------------
        // 1. SUCCESS STATE
        // ---------------------------------------------------------------------
        if (state is AuthMessage) {
          FocusScope.of(context).unfocus();

          // If registered, switch to Login but keep data
          if (!_isLogin) {
            setState(() {
              _isLogin = true;
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // ---------------------------------------------------------------------
        // 2. ERROR STATE
        // ---------------------------------------------------------------------
        if (state is AuthError) {
          _showErrorSnackBar(context, state);
        }
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LOGO
                Image.asset(
                  'assets/images/linguaflow_logo_transparent.png',
                  height: 100.0,
                  width: 100.0,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.language, size: 100),
                ),

                const Text(
                  'LinguaFlow',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Learning language the natural way',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ---------------------------------------------------------
                // NAME FIELD (Sign Up Only)
                // ---------------------------------------------------------
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ---------------------------------------------------------
                // EMAIL FIELD
                // ---------------------------------------------------------
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter email';
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ---------------------------------------------------------
                // PASSWORD FIELD
                // ---------------------------------------------------------
                TextFormField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submitForm(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Enter password' : null,
                ),

                // FORGOT PASSWORD
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text("Forgot Password?"),
                    ),
                  ),

                const SizedBox(height: 16),

                // ---------------------------------------------------------
                // TERMS AND CONDITIONS
                // ---------------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        onChanged: (val) {
                          setState(() {
                            _acceptedTerms = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: "I agree to the "),
                            TextSpan(
                              text: "Terms & Conditions",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _showLegalDialog(
                                    context,
                                    "Terms & Conditions",
                                    TermsAndPolicies.termsOfService,
                                  );
                                },
                            ),
                            const TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _showLegalDialog(
                                    context,
                                    "Privacy Policy",
                                    TermsAndPolicies.privacyPolicy,
                                  );
                                },
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------------------------------------------------------
                // SUBMIT BUTTON
                // ---------------------------------------------------------
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_isLogin ? 'Login' : 'Sign Up'),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ---------------------------------------------------------
                // TOGGLE MODE
                // ---------------------------------------------------------
                TextButton(
                  onPressed: () {
                    // Just toggle mode. DO NOT CLEAR CONTROLLERS.
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Don\'t have an account? Sign up'
                        : 'Already have an account? Login',
                  ),
                ),

                // ---------------------------------------------------------
                // GOOGLE SIGN IN
                // ---------------------------------------------------------
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();

                    if (!_acceptedTerms) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please accept the Terms & Privacy Policy to continue.",
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    context.read<AuthBloc>().add(AuthGoogleLoginRequested());
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  icon: SizedBox(
                    width: 24,
                    height: 24,
                    child: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.login),
                    ),
                  ),
                  label: const Text(
                    "Sign in with Google",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "By using Google Sign-In, you also agree to Google's Terms of Service and Privacy Policy.",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIC METHODS
  // ---------------------------------------------------------------------------

  void _submitForm() {
    FocusScope.of(context).unfocus(); 

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please accept the Terms & Privacy Policy to continue.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      TextInput.finishAutofillContext();

      if (_isLogin) {
        context.read<AuthBloc>().add(
              AuthLoginRequested(
                _emailController.text.trim(),
                _passwordController.text,
              ),
            );
      } else {
        context.read<AuthBloc>().add(
              AuthRegisterRequested(
                _emailController.text.trim(),
                _passwordController.text,
                _nameController.text.trim(),
              ),
            );
      }
    }
  }

  void _showLegalDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Markdown(
            data: content,
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address to receive a password reset link.",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (resetEmailController.text.isNotEmpty) {
                context.read<AuthBloc>().add(
                      AuthResetPasswordRequested(
                        resetEmailController.text.trim(),
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }
}