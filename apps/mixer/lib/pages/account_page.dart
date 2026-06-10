// 账号详情页 - 显示当前账号 + 绑定状态 + 升级/退出

import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'register_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号')),
      body: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthService.currentUser,
        builder: (_, user, __) {
          if (user == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => _openLogin(context),
                child: const Text('登录'),
              ),
            );
          }
          return _buildBody(context, user);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuthUser user) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 头像 + 信息
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Icon(
                          user.isAnonymous
                              ? Icons.person_outline
                              : Icons.person,
                          size: 32,
                          color: scheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (user.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '用户 ID: ${user.userId}',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.outline,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 已绑定方式
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '已绑定登录方式',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: user.linkedMethods
              .map((m) => Chip(
                    avatar: Icon(_iconFor(m), size: 16),
                    label: Text(m.labelZh),
                    backgroundColor: scheme.primaryContainer,
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),

        // 操作
        if (user.isAnonymous) ...[
          _actionTile(
            context,
            icon: Icons.upgrade,
            iconColor: scheme.primary,
            title: '升级账号',
            subtitle: '绑定邮箱后可在其它设备登录，数据自动同步',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RegisterPage(),
            )),
          ),
          _actionTile(
            context,
            icon: Icons.login,
            title: '已有账号？登录',
            onTap: () => _openLogin(context),
          ),
        ] else ...[
          if (!user.linkedMethods.contains(AuthMethod.email))
            _actionTile(
              context,
              icon: Icons.email_outlined,
              title: '绑定邮箱',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RegisterPage(),
              )),
            ),
          if (!user.linkedMethods.contains(AuthMethod.google))
            _actionTile(
              context,
              icon: Icons.g_mobiledata,
              title: '绑定 Google',
              onTap: () async {
                final r = await AuthService.signInWithGoogle();
                _showResult(context, r.ok ? '已绑定 Google' : (r.error ?? '失败'));
              },
            ),
          if (!user.linkedMethods.contains(AuthMethod.apple))
            _actionTile(
              context,
              icon: Icons.apple,
              title: '绑定 Apple',
              onTap: () async {
                final r = await AuthService.signInWithApple();
                _showResult(context, r.ok ? '已绑定 Apple' : (r.error ?? '失败'));
              },
            ),
          const Divider(height: 32),
          _actionTile(
            context,
            icon: Icons.logout,
            iconColor: scheme.error,
            title: '退出登录',
            subtitle: '退出后将恢复匿名账号',
            onTap: () => _confirmSignOut(context),
          ),
        ],

        const SizedBox(height: 24),
        Center(
          child: Text(
            '注册于 ${_fmtDate(user.createdAt)}',
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
        ),
      ],
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onTap,
        ),
      );

  IconData _iconFor(AuthMethod m) {
    switch (m) {
      case AuthMethod.anonymous:
        return Icons.person_outline;
      case AuthMethod.email:
        return Icons.email_outlined;
      case AuthMethod.google:
        return Icons.g_mobiledata;
      case AuthMethod.apple:
        return Icons.apple;
      case AuthMethod.wechat:
        return Icons.chat_bubble_outline;
    }
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('退出后会恢复成本机匿名账号，云端数据不会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.signOut();
    }
  }

  void _showResult(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
