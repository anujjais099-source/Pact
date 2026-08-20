import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/auth_controller.dart';

/// Verification happens in a mail app, so nothing tells us when it lands.
/// We poll gently while the screen is open, and offer a manual check.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  int _cooldown = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);

    final verified = await ref.read(authControllerProvider.notifier).checkVerified();

    if (!mounted) return;
    setState(() => _checking = false);
    if (!verified && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not verified yet. Check your inbox and spam.')),
      );
    }
  }

  Future<void> _resend() async {
    final ok = await ref.read(authControllerProvider.notifier).resendVerification();
    if (!mounted) return;
    if (ok) {
      setState(() => _cooldown = 30);
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
          return;
        }
        setState(() => _cooldown--);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final email = ref.watch(authStateProvider).value?.email;

    return PactScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: PactColors.violetSoft,
              borderRadius: Radii.md,
            ),
            child: const Icon(Icons.mark_email_unread_rounded,
                color: PactColors.violet, size: 28),
          ),
          Gap.h24,
          Text('Check your inbox.', style: t.headlineMedium),
          Gap.h8,
          Text(
            'We sent a verification link${email == null ? '' : ' to $email'}. '
            'Tap it, come back, and your Pact begins.',
            style: t.bodyMedium?.copyWith(fontSize: 15),
          ),
          Gap.h16,
          Text(
            'Verification keeps the pool honest — a partner who can vanish and '
            'respawn is no partner at all.',
            style: t.bodyMedium?.copyWith(fontSize: 13, color: PactColors.textTertiary),
          ),
          const Spacer(),
          PactButton(
            label: 'I have verified',
            loading: _checking,
            onPressed: () => _check(),
          ),
          Gap.h8,
          PactButton(
            label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
            style: PactButtonStyle.secondary,
            onPressed: _cooldown > 0 ? null : _resend,
          ),
          Gap.h8,
          PactButton(
            label: 'Use a different account',
            style: PactButtonStyle.ghost,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          Gap.h16,
        ],
      ),
    );
  }
}
