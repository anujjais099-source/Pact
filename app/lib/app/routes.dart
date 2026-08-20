/// Every route in the app. Nine screens, no more — the whole product is one
/// loop, and the router should read like that loop.
abstract final class Routes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signUp = '/sign-up';
  static const String signIn = '/sign-in';
  static const String verifyEmail = '/verify-email';
  static const String claimUsername = '/claim-username';
  static const String goalSetup = '/goal';
  static const String matchmaking = '/matchmaking';
  static const String home = '/home';
  static const String checkIn = '/check-in';
  static const String partner = '/partner';
  static const String profile = '/profile';
  static const String pactBroken = '/pact-broken';
}
