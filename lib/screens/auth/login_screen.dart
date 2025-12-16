import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            // --- HANDLE SUCCESS ---
            if (state is AuthMessage) {
              if (!_isLogin) setState(() => _isLogin = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }

            // --- HANDLE ERRORS ---
            if (state is AuthError) {
              final bool isVerificationError = state.isVerificationError;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 6),
                  action: isVerificationError
                      ? SnackBarAction(
                          label: 'RESEND EMAIL',
                          textColor: Colors.white,
                          onPressed: () {
                            context.read<AuthBloc>().add(
                              AuthResendVerificationEmail(
                                _emailController.text,
                                _passwordController.text,
                              ),
                            );
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
                    Image.asset(
                      'assets/images/linguaflow_logo_transparent.png',
                      height: 100.0,
                      width: 100.0,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'LinguaFlow',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    const Text(
                      'Learning the natural way',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    if (!_isLogin)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Enter your name' : null,
                      ),
                    if (!_isLogin) const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Enter password' : null,
                    ),

                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text("Forgot Password?"),
                        ),
                      ),

                    const SizedBox(height: 24),

                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Sign up'
                            : 'Already have an account? Login',
                      ),
                    ),

                    // ===============================================
                    // GOOGLE SIGN IN SECTION
                    // ===============================================
                    const SizedBox(height: 20),
                    Row(
                      children: const [
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
                        context.read<AuthBloc>().add(
                          AuthGoogleLoginRequested(),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      // If you don't have a Google asset, use an icon
                      icon: SizedBox(
                        width: 24,
                        height: 24,
                        // Ensure you have this asset or replace with Icon(Icons.login)
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
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
                  AuthResetPasswordRequested(resetEmailController.text.trim()),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
