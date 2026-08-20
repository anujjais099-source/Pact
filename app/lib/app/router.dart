import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth_repository.dart';
import '../demo/demo_mode.dart';
import '../features/auth/claim_username_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/checkin/camera_screen.dart';
import '../features/home/home_screen.dart';
import '../features/matchmaking/matchmaking_screen.dart';
import '../features/onboarding/goal_setup_screen.dart';
import '../features/pact_broken/pact_broken_screen.dart';
import '../features/partner/match_screen.dart';
import '../features/profile/profile_screen.dart';
import '../state/pact_memory.dart';
import '../state/providers.dart';
import 'routes.dart';

/// Rebuilds the router whenever anything that can change the user's stage moves.
final _refreshProvider = Provider<_Refresh>((ref) {
  final notifier = _Refresh();
  ref.listen(authStateProvider, (_, __) => notifier.bump());
  ref.listen(currentUserProvider, (_, __) => notifier.bump());
  ref.listen(pactMemoryProvider, (_, __) => notifier.bump());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _Refresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_refreshProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.verifyEmail, builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: Routes.claimUsername, builder: (_, __) => const ClaimUsernameScreen()),
      GoRoute(path: Routes.goalSetup, builder: (_, __) => const GoalSetupScreen()),
      GoRoute(path: Routes.matchmaking, builder: (_, __) => const MatchmakingScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: Routes.checkIn, builder: (_, __) => const CameraScreen()),
      GoRoute(path: Routes.partner, builder: (_, __) => const MatchScreen()),
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: Routes.pactBroken, builder: (_, __) => const PactBrokenScreen()),
    ],
    errorBuilder: (_, __) => const SplashScreen(),
  );
});

/// The whole product as a single funnel. Each guard answers exactly one
/// question, in the order a new user meets them.
String? _redirect(Ref ref, String location) {
  // A demo build has no account, so none of the funnel below applies. Land on
  // Home and allow only the screens that exist without a backend.
  if (ref.read(demoModeProvider)) {
    const inDemo = {Routes.home, Routes.checkIn, Routes.partner, Routes.profile};
    return inDemo.contains(location) ? null : Routes.home;
  }

  final auth = ref.read(authStateProvider);

  // 1. Still resolving the session.
  if (auth.isLoading) {
    return location == Routes.splash ? null : Routes.splash;
  }

  const authRoutes = {Routes.welcome, Routes.signIn, Routes.signUp};

  // 2. Signed out.
  final user = auth.value;
  if (user == null) {
    return authRoutes.contains(location) ? null : Routes.welcome;
  }

  // 3. Signed in but the email is still unproven.
  if (!user.emailVerified) {
    return location == Routes.verifyEmail ? null : Routes.verifyEmail;
  }

  // 4. Profile document still on its way from createProfile.
  final profile = ref.read(currentUserProvider);
  if (profile.isLoading && !profile.hasValue) {
    return location == Routes.splash ? null : Routes.splash;
  }
  // Profile stream resolved to nothing: the account exists in Auth but
  // createProfile never landed. Let them claim a name rather than strand them.
  final me = profile.value;
  if (me == null) {
    return location == Routes.claimUsername ? null : Routes.claimUsername;
  }

  // 5. No goal yet.
  if (me.goalName.trim().isEmpty) {
    return location == Routes.goalSetup ? null : Routes.goalSetup;
  }

  // 6. A pact ended while they were away — say so before anything else.
  final pendingBreak = ref.read(pactMemoryProvider);
  if (pendingBreak != null && !me.hasPact) {
    return location == Routes.pactBroken ? null : Routes.pactBroken;
  }

  // 7. Unmatched.
  if (!me.hasPact) {
    return location == Routes.matchmaking ? null : Routes.matchmaking;
  }

  // 8. Matched: the four in-pact screens are all legal.
  const inPact = {Routes.home, Routes.checkIn, Routes.partner, Routes.profile};
  return inPact.contains(location) ? null : Routes.home;
}
