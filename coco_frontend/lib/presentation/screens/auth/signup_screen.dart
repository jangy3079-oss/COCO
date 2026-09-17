import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_type.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authRepository = AuthRepository();
  int _step = 1; // 1: 유형 선택, 2: 정보 입력 + 약관
  UserType _role = UserType.local;

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreeService = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;
  bool _isLoading = false;

  bool get _agreeAll => _agreeService && _agreePrivacy && _agreeMarketing;

  bool get _canSignup =>
      _nicknameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 8 &&
      _agreeService &&
      _agreePrivacy;

  int get _pwStrength {
    final len = _passwordController.text.length;
    if (len == 0) return 0;
    if (len < 8) return 1;
    if (len < 12) return 2;
    return 3;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_step == 2) {
      setState(() => _step = 1);
    } else {
      context.pop();
    }
  }

  void _toggleAllTerms() {
    final on = !_agreeAll;
    setState(() {
      _agreeService = on;
      _agreePrivacy = on;
      _agreeMarketing = on;
    });
  }

  Future<void> _handleSignup() async {
    if (!_canSignup) return;
    setState(() => _isLoading = true);
    try {
      final result = await _authRepository.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
        role: _role.apiValue,
      );
      AuthTokenStore.setToken(result.accessToken);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.signupCompleteSnackbar)),
      );
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  InkWell(onTap: _handleBack, child: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _step == 1 ? 0.5 : 1.0,
                        minHeight: 3,
                        backgroundColor: Colors.black.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(CocoTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$_step/2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signupStep1Title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.4, color: CocoTheme.secondary),
        ),
        const SizedBox(height: 8),
        Text(l10n.signupStep1Subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 28),
        _RoleCard(
          title: l10n.userTypeLocal,
          description: l10n.signupRoleLocalDesc,
          selected: _role == UserType.local,
          onTap: () => setState(() => _role = UserType.local),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          title: l10n.userTypeTourist,
          description: l10n.signupRoleTouristDesc,
          selected: _role == UserType.tourist,
          onTap: () => setState(() => _role = UserType.tourist),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CocoTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => setState(() => _step = 2),
            child: Text(l10n.feedComposerNextButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final l10n = AppLocalizations.of(context)!;
    final roleLabel = _role == UserType.local ? l10n.userTypeLocal : l10n.userTypeTourist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.signupStep2Title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(12)),
              child: Text(roleLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
            ),
            const SizedBox(width: 8),
            Text(l10n.signupRoleSuffix, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 28),
        _SignupField(
          label: l10n.nicknameLabel,
          controller: _nicknameController,
          hintText: l10n.signupNicknameHint,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _SignupField(
          label: l10n.emailLabel,
          controller: _emailController,
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _SignupField(
          label: l10n.passwordLabel,
          controller: _passwordController,
          hintText: l10n.signupPasswordHint,
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _pwStrength / 3,
                  minHeight: 3,
                  backgroundColor: Colors.black.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation(CocoTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              [
                '',
                l10n.signupPwStrengthWeak,
                l10n.signupPwStrengthMedium,
                l10n.signupPwStrengthStrong,
              ][_pwStrength],
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.only(top: 18),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withOpacity(0.07)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _toggleAllTerms,
                child: Row(
                  children: [
                    _BoxCheck(checked: _agreeAll),
                    const SizedBox(width: 10),
                    Text(l10n.signupAgreeAllTerms, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _TermRow(
                label: l10n.signupTermsService,
                required: true,
                checked: _agreeService,
                onTap: () => setState(() => _agreeService = !_agreeService),
              ),
              _TermRow(
                label: l10n.signupTermsPrivacy,
                required: true,
                checked: _agreePrivacy,
                onTap: () => setState(() => _agreePrivacy = !_agreePrivacy),
              ),
              _TermRow(
                label: l10n.signupTermsMarketing,
                required: false,
                checked: _agreeMarketing,
                onTap: () => setState(() => _agreeMarketing = !_agreeMarketing),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _canSignup ? CocoTheme.primary : const Color(0xFFE8E8E6),
              foregroundColor: _canSignup ? Colors.white : Colors.black.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_canSignup && !_isLoading) ? _handleSignup : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.signupCompleteButton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5FAFE) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade400, width: 1.8),
                  ),
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: CocoTheme.primary),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 13, height: 1.6, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _SignupField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _SignupField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _BoxCheck extends StatelessWidget {
  final bool checked;
  const _BoxCheck({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? CocoTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? CocoTheme.primary : Colors.grey.shade400, width: 1.6),
      ),
      child: checked ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
    );
  }
}

class _TermRow extends StatelessWidget {
  final String label;
  final bool required;
  final bool checked;
  final VoidCallback onTap;

  const _TermRow({
    required this.label,
    required this.required,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Text(
                    '✓',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: checked ? CocoTheme.primary : Colors.grey.shade300),
                  ),
                  const SizedBox(width: 9),
                  Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(width: 6),
                  Text(
                    required ? l10n.signupTermRequired : l10n.signupTermOptional,
                    style: TextStyle(fontSize: 11, color: required ? CocoTheme.primary : Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.myPageComingSoon), duration: const Duration(seconds: 1)),
            ),
            child: Text(l10n.signupTermsViewButton, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }
}
