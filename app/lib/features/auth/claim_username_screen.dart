import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../data/repositories/user_repository.dart';
import '../../state/auth_controller.dart';

/// Recovery path: the account exists in Auth but `createProfile` never landed —
/// a dropped connection at exactly the wrong second. Without this the user is
/// stranded on the splash forever and cannot even re-register, because their
/// email is already taken by their own orphaned account.
class ClaimUsernameScreen extends ConsumerStatefulWidget {
  const ClaimUsernameScreen({super.key});

  @override
  ConsumerState<ClaimUsernameScreen> createState() => _ClaimUsernameScreenState();
}

class _ClaimUsernameScreenState extends ConsumerState<ClaimUsernameScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _controller.text.trim();
    final problem = Validators.username(username);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final free = await ref.read(userRepositoryProvider).isUsernameAvailable(username);
      if (!free) {
        setState(() => _error = 'That username is taken.');
        return;
      }
      await ref.read(userRepositoryProvider).createProfile(username: username);
      // The profile stream fires and the router moves on from here.
    } catch (_) {
      setState(() => _error = 'Could not finish setting up. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return PactScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text('One thing left.', style: t.headlineMedium),
          Gap.h8,
          Text(
            'Your account exists but it never got a name. Pick one and your Pact can start.',
            style: t.bodyMedium?.copyWith(fontSize: 15),
          ),
          Gap.h24,
          TextField(
            controller: _controller,
            autocorrect: false,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'earlybird_92',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            Gap.h12,
            PactError(message: _error!),
          ],
          const Spacer(),
          PactButton(label: 'Continue', loading: _saving, onPressed: _submit),
          Gap.h8,
          PactButton(
            label: 'Sign out',
            style: PactButtonStyle.ghost,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          Gap.h16,
        ],
      ),
    );
  }
}
