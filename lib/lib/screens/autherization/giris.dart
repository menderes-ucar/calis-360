import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/errors/auth_error_mapper.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import 'auth_visuals.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Lütfen e-posta ve şifre alanlarını doldurun.');
      return;
    }

    setState(() => loading = true);

    try {
      final success = await ref
          .read(authControllerProvider.notifier)
          .signIn(email: email, password: password);

      if (!mounted) return;
      if (success) {
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

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Şifre sıfırlamak için önce e-posta adresinizi yazın.');
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email);
    if (!mounted) return;

    if (success) {
      _showMessage('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.');
    } else {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        _showMessage(AuthErrorMapper.message(state.error!));
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
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const AuthBrand(
                    title: 'Tekrar hoş geldin',
                    subtitle:
                        'Planına, sorularına ve analizlerine kaldığın yerden devam et.',
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
                            'Giriş yap',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Hesabına erişmek için bilgilerini gir.',
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
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => loading ? null : login(),
                            decoration: InputDecoration(
                              labelText: 'Şifre',
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
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading ? null : resetPassword,
                              child: const Text('Şifremi unuttum'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FilledButton.icon(
                            onPressed: loading ? null : login,
                            icon: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(loading ? 'Giriş yapılıyor...' : 'Giriş Yap'),
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
                      const Text('Henüz hesabın yok mu?'),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => context.go(AppRoutes.register),
                        child: const Text('Kayıt Ol'),
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
