import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_data.dart';
import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_vectors.dart';
import '../widgets/app_vector.dart';
import '../widgets/peam_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/soft_card.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    final error = await SessionScope.of(
      context,
    ).requestLoginCode(_employeeIdController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _verifyCode() async {
    setState(() => _error = null);
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the email verification code.');
      return;
    }
    setState(() => _busy = true);
    final session = SessionScope.of(context);
    final error = await session.verifyLoginCode(_codeController.text);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pushReplacementNamed(MainShell.routeName);
  }

  Future<void> _requestDeviceChange() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await SessionScope.of(context).requestDeviceChange();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error =
          error ??
          'Request sent. HRMDO must approve this phone before you can sign in here.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final challenge = session.pendingChallenge;
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
                          child: challenge == null
                              ? _EmployeeIdStep(
                                  formKey: _formKey,
                                  employeeIdController: _employeeIdController,
                                  error: _error,
                                  showPrototypeHint: !session.isLiveAuth,
                                  onSubmit: _sendCode,
                                )
                              : _CodeStep(
                                  challenge: challenge,
                                  codeController: _codeController,
                                  error: _error,
                                  showPrototypeHint: !session.isLiveAuth,
                                  deviceChangeRequired:
                                      session.deviceChangeRequired,
                                  onChangeId: () {
                                    _codeController.clear();
                                    session.clearLoginChallenge();
                                    setState(() => _error = null);
                                  },
                                  onRequestDeviceChange: _requestDeviceChange,
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
                    label: challenge == null
                        ? 'Send email code'
                        : 'Verify and bind this phone',
                    icon: challenge == null
                        ? Icons.mail_outline
                        : Icons.verified_user_outlined,
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : challenge == null
                        ? _sendCode
                        : _verifyCode,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Text(
                    'HRMDO creates employee accounts. This phone is bound after the first successful sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmployeeIdStep extends StatelessWidget {
  const _EmployeeIdStep({
    required this.formKey,
    required this.employeeIdController,
    required this.error,
    required this.showPrototypeHint,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController employeeIdController;
  final String? error;
  final bool showPrototypeHint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          'Enter your Employee ID. PEAM sends a one-time code to the work email HRMDO stored for you.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Form(
          key: formKey,
          child: TextFormField(
            key: const Key('login-employee-id'),
            controller: employeeIdController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
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
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const Key('login-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (showPrototypeHint) ...[
          const SizedBox(height: 14),
          SoftCard(
            color: AppColors.lavender,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Demo  ·  Employee ID ${SampleData.demoEmployee.employeeNumber}  ·  code ${SampleData.prototypeEmailCode}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.challenge,
    required this.codeController,
    required this.error,
    required this.showPrototypeHint,
    required this.deviceChangeRequired,
    required this.onChangeId,
    required this.onRequestDeviceChange,
  });

  final LoginChallenge challenge;
  final TextEditingController codeController;
  final String? error;
  final bool showPrototypeHint;
  final bool deviceChangeRequired;
  final VoidCallback onChangeId;
  final VoidCallback onRequestDeviceChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A verification code was sent to the email HRMDO has on file.',
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          challenge.maskedEmail,
          key: const Key('login-masked-email'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 18),
        TextFormField(
          key: const Key('login-code'),
          controller: codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Email verification code',
            hintText: '6-digit code',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const Key('login-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (showPrototypeHint) ...[
          const SizedBox(height: 14),
          SoftCard(
            color: AppColors.peach,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Prototype: email sending is simulated. Use code ${SampleData.prototypeEmailCode}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('login-change-id'),
            onPressed: onChangeId,
            child: const Text('Use a different Employee ID'),
          ),
        ),
        if (deviceChangeRequired)
          TextButton(
            key: const Key('login-device-change'),
            onPressed: onRequestDeviceChange,
            child: const Text('Submit a device-change request'),
          ),
      ],
    );
  }
}
