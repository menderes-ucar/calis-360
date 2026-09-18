import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/errors/auth_error_mapper.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import 'auth_visuals.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showMessage('Lütfen tüm alanları doldurun.');
      return;
    }

    if (password != confirm) {
      _showMessage('Şifreler eşleşmiyor.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => loading = true);

    try {
      final success = await ref
          .read(authControllerProvider.notifier)
          .register(email: email, password: password);

      if (!mounted) return;
      if (success) {
        _showMessage('Hesabın oluşturuldu.');
        context.go(AppRoutes.home);
      } else {
        final state = ref.read(authControllerProvider);
        if (state.hasError) {
          _showMessage(AuthErrorMapper.message(state.error!));
        }
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const AuthBrand(
                    title: 'Hedefine bugün başla',
                    subtitle:
                        'Çalışma düzenini kur, çözümlerini kaydet ve gelişimini tek ekrandan takip et.',
                    icon: Icons.rocket_launch_rounded,
                  ),
                  const SizedBox(height: 18),
                  const AuthFeaturePills(),
                  const SizedBox(height: 22),
                  AuthCard(
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hesap oluştur',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Başlamak için e-posta ve şifreni belirle.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AuthVisuals.muted,
                                ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              hintText: 'ornek@email.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              helperText: 'En az 6 karakter',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Şifreyi göster'
                                    : 'Şifreyi gizle',
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: confirmController,
                            obscureText: obscureConfirm,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onSubmitted: (_) => loading ? null : register(),
                            decoration: InputDecoration(
                              labelText: 'Şifre Tekrar',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                tooltip: obscureConfirm
                                    ? 'Şifreyi göster'
                                    : 'Şifreyi gizle',
                                onPressed: () => setState(
                                  () => obscureConfirm = !obscureConfirm,
                                ),
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: loading ? null : register,
                            icon: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(loading ? 'Hesap oluşturuluyor...' : 'Kayıt Ol'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Zaten hesabın var mı?'),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => context.go(AppRoutes.login),
                        child: const Text('Giriş Yap'),
                      ),
                    ],
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
