import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/pact_theme.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/user_repository.dart';
import '../demo/demo_mode.dart';
import '../state/pact_memory.dart';
import '../state/providers.dart';
import 'router.dart';

class PactApp extends ConsumerStatefulWidget {
  const PactApp({super.key});

  @override
  ConsumerState<PactApp> createState() => _PactAppState();
}

class _PactAppState extends ConsumerState<PactApp> {
  String? _notificationsFor;

  @override
  Widget build(BuildContext context) {
    // Side effects that belong to the session, not to any one screen.
    // A demo build has no Firebase behind it, so none of them run.
    if (!ref.read(demoModeProvider)) {
      _watchSession();
    }

    return _app(context);
  }

  void _watchSession() {
    ref.listen(currentUserProvider, (_, next) {
      final me = next.value;
      if (me == null) {
        _notificationsFor = null;
        return;
      }

      // Remember a pact that just ended so we can explain it once.
      ref.read(pactMemoryProvider.notifier).observe(me.currentPactId);

      if (_notificationsFor != me.uid) {
        _notificationsFor = me.uid;
        ref.read(notificationRepositoryProvider).init(me.uid);
        ref.read(userRepositoryProvider).touchSession(
              me.uid,
              emailVerified: ref.read(emailVerifiedProvider),
            );
      }
    });
  }

  Widget _app(BuildContext context) {
    return MaterialApp.router(
      title: 'Pact',
      debugShowCheckedModeBanner: false,
      theme: PactTheme.build(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Accessibility yes, blown-up layouts no.
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
