// 登录页 - Email / Google / Apple 三选一
//
// 设计：
//   - 全屏页，底部三个大按钮
//   - 邮箱登录在底部弹 sheet（要输 email + password）
//   - 三方登录直接调用（Mock 立即成功）

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.account_circle_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '登录后跨设备同步历史',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '匿名账号的本地记录会自动迁移到新账号',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 40),
              _emailButton(),
              const SizedBox(height: 12),
              _googleButton(),
              const SizedBox(height: 12),
              _appleButton(),
              const Spacer(),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        )),
                child: const Text('没有账号？立即注册'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailButton() => FilledButton.icon(
        onPressed: _loading ? null : _emailSignIn,
        icon: const Icon(Icons.email_outlined),
        label: const Text('使用邮箱登录'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _googleButton() => OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        icon: const Icon(Icons.g_mobiledata, size: 28),
        label: const Text('使用 Google 登录'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _appleButton() => OutlinedButton.icon(
        onPressed: _loading ? null : _appleSignIn,
        icon: const Icon(Icons.apple),
        label: const Text('使用 Apple 登录'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Future<void> _emailSignIn() async {
    final cred = await showModalBottomSheet<({String email, String password})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EmailLoginSheet(),
    );
    if (cred == null) return;
    setState(() => _loading = true);
    final r = await AuthService.signInWithEmail(
      email: cred.email,
      password: cred.password,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      Navigator.of(context).pop();
    } else {
      _showError(r.error ?? '登录失败');
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    final r = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      Navigator.of(context).pop();
    } else {
      _showError(r.error ?? 'Google 登录失败');
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _loading = true);
    final r = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      Navigator.of(context).pop();
    } else {
      _showError(r.error ?? 'Apple 登录失败');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
    ));
  }
}

class _EmailLoginSheet extends StatefulWidget {
  const _EmailLoginSheet();

  @override
  State<_EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<_EmailLoginSheet> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '邮箱登录',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_emailCtrl.text.isEmpty || _pwdCtrl.text.isEmpty) return;
    Navigator.of(context).pop((
      email: _emailCtrl.text.trim(),
      password: _pwdCtrl.text,
    ));
  }
}
