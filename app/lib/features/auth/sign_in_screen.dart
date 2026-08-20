import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../state/auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (Validators.email(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type your email first, then tap reset.')),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).resetPassword(email);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent to $email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final t = Theme.of(context).textTheme;

    return PactScaffold(
      title: 'Sign in',
      leading: const BackButton(),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(top: 84, bottom: 32),
          children: [
            Text('Someone is\nwaiting on you.', style: t.headlineMedium),
            Gap.h32,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
            Gap.h16,
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20,
                    color: PactColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (state.hasError) ...[
              Gap.h16,
              PactError(message: state.error.toString()),
            ],
            Gap.h24,
            PactButton(label: 'Sign in', loading: state.isLoading, onPressed: _submit),
            Gap.h8,
            PactButton(
              label: 'Forgot password',
              style: PactButtonStyle.ghost,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}
