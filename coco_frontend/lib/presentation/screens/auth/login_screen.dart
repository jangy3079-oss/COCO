import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/coco_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _keepSignedIn = true;
  bool _isLoading = false;

  bool get _canLogin =>
      _emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_canLogin) return;
    setState(() => _isLoading = true);
    try {
      final result = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      AuthTokenStore.setToken(result.accessToken);
      if (!mounted) return;
      context.go('/feed');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CocoMark(width: 48, height: 42),
                    const SizedBox(height: 16),
                    Text(
                      l10n.loginWelcomeBackTitle,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.loginSubtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    _AuthField(
                      label: l10n.emailLabel,
                      controller: _emailController,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _AuthField(
                      label: l10n.passwordLabel,
                      controller: _passwordController,
                      hintText: '••••••••',
                      obscureText: !_showPassword,
                      onChanged: (_) => setState(() {}),
                      suffix: TextButton(
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                        child: Text(
                          _showPassword ? l10n.loginPasswordHide : l10n.loginPasswordShow,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
                          child: Row(
                            children: [
                              _CheckBox(checked: _keepSignedIn),
                              const SizedBox(width: 8),
                              Text(l10n.loginKeepSignedIn, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.myPageComingSoon), duration: const Duration(seconds: 1)),
                          ),
                          child: Text(l10n.loginForgotPassword, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _canLogin ? CocoTheme.primary : const Color(0xFFE8E8E6),
                          foregroundColor: _canLogin ? Colors.white : Colors.black.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: (_canLogin && !_isLoading) ? _handleLogin : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(l10n.loginButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.loginNoAccountPrompt, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          InkWell(
                            onTap: () => context.push('/signup'),
                            child: Text(
                              l10n.goToSignup,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const _AuthField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    final borderColor = filled ? CocoTheme.primary : Colors.grey.shade300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, color: CocoTheme.secondary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CocoTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? CocoTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: checked ? CocoTheme.primary : Colors.grey.shade400, width: 1.6),
      ),
      child: checked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
    );
  }
}
