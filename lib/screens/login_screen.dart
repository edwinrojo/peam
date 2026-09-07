import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/peam_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final session = SessionScope.of(context);
    final error = await session.login(
      employeeNumber: _employeeIdController.text,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pushReplacementNamed(MainShell.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppVector(AppVectors.heroAttendance, height: 88),
                    const SizedBox(height: 8),
                    const PeamLogo(showWordmark: true, size: 48),
                    const SizedBox(height: 16),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Use your Employee ID and password to record event attendance.',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  key: const Key('login-employee-id'),
                                  controller: _employeeIdController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Employee ID',
                                    hintText: '1234',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter your Employee ID';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('login-password'),
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password resets are processed by HRMDO. Contact your administrator.',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              key: const Key('login-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SoftCard(
                            color: AppColors.lavender,
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Demo  ·  ${SampleData.demoEmployee.employeeNumber}  ·  ${SampleData.demoEmployee.password}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: PrimaryButton(
                key: const Key('login-button'),
                label: 'Login',
                icon: Icons.arrow_forward_rounded,
                onPressed: _submit,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Need an account?',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  TextButton(
                    key: const Key('register-link'),
                    onPressed: () {
                      Navigator.of(context).pushNamed(RegisterScreen.routeName);
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
