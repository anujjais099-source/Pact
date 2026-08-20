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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

enum _NameCheck { idle, checking, free, taken }

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Timer? _debounce;
  _NameCheck _check = _NameCheck.idle;
  bool _obscure = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Finding out your username is taken *after* filling in a whole form is a
  /// small betrayal, so we check as they type.
  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (Validators.username(value) != null) {
      setState(() => _check = _NameCheck.idle);
      return;
    }
    setState(() => _check = _NameCheck.checking);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await ref.read(userRepositoryProvider).isUsernameAvailable(value);
        if (mounted) setState(() => _check = free ? _NameCheck.free : _NameCheck.taken);
      } catch (_) {
        if (mounted) setState(() => _check = _NameCheck.idle);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_check == _NameCheck.taken) return;
    FocusScope.of(context).unfocus();

    await ref.read(authControllerProvider.notifier).signUp(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
    // The router takes it from here: verified? goal? match.
  }

  Widget? get _usernameSuffix => switch (_check) {
        _NameCheck.checking => const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: PactColors.textTertiary),
            ),
          ),
        _NameCheck.free =>
          const Icon(Icons.check_rounded, color: PactColors.green, size: 20),
        _NameCheck.taken =>
          const Icon(Icons.close_rounded, color: PactColors.red, size: 20),
        _NameCheck.idle => null,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final t = Theme.of(context).textTheme;

    return PactScaffold(
      title: 'Create account',
      leading: const BackButton(),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(top: 84, bottom: 32),
          children: [
            Text('Pick a name your\npartner will see.', style: t.headlineMedium),
            Gap.h8,
            Text(
              'That, and one photo a day, is everything they ever learn about you.',
              style: t.bodyMedium,
            ),
            Gap.h32,
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'earlybird_92',
                counterText: '',
                suffixIcon: _usernameSuffix,
                errorText: _check == _NameCheck.taken ? 'Already taken' : null,
              ),
              validator: Validators.username,
              onChanged: _onUsernameChanged,
            ),
            Gap.h16,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              validator: Validators.email,
            ),
            Gap.h16,
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'At least 8 characters',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20,
                    color: PactColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (state.hasError) ...[
              Gap.h16,
              PactError(message: state.error.toString()),
            ],
            Gap.h32,
            PactButton(
              label: 'Continue',
              loading: state.isLoading,
              onPressed: _check == _NameCheck.checking ? null : _submit,
            ),
            Gap.h16,
            Text(
              'We only email you to verify the account. No newsletters, no digests.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(fontSize: 12.5, color: PactColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
