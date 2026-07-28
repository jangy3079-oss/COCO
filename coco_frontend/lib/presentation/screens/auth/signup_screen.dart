import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_type.dart';
import '../../../l10n/generated/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserType _userType = UserType.tourist;
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.agreeTermsRequired)),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO(backend): POST /api/auth/signup 연동
    // body: { nickname, email, password, role: _userType.apiValue }
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.signupSuccessMessage)),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.userTypeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _UserTypeCard(
                        selected: _userType == UserType.local,
                        icon: Icons.storefront_rounded,
                        title: l10n.userTypeLocal,
                        subtitle: l10n.userTypeLocalDesc,
                        onTap: () => setState(() => _userType = UserType.local),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UserTypeCard(
                        selected: _userType == UserType.tourist,
                        icon: Icons.travel_explore_rounded,
                        title: l10n.userTypeTourist,
                        subtitle: l10n.userTypeTouristDesc,
                        onTap: () => setState(() => _userType = UserType.tourist),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: l10n.nicknameLabel,
                    hintText: l10n.nicknameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.nicknameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    hintText: l10n.emailHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.emailRequired;
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                      return l10n.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequired;
                    }
                    if (value.length < 8) {
                      return l10n.passwordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return l10n.confirmPasswordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _agreeTerms,
                  onChanged: (value) => setState(() => _agreeTerms = value ?? false),
                  title: Text(l10n.agreeTermsLabel, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CocoTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.signupButton),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccountPrompt,
                        style: TextStyle(color: Colors.grey.shade700)),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(l10n.goToLogin),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: selected ? CocoTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? CocoTheme.primary : Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? CocoTheme.primary : CocoTheme.secondary,
                )),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
