import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() once prefs are loaded.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('prefsProvider must be overridden in main()'),
);

const _kLastPact = 'pact.lastPactId';
const _kPendingBreak = 'pact.pendingBreakPactId';

/// When a pact breaks, the server clears `currentPactId` — which would drop the
/// user straight back into matchmaking with no explanation. We keep the id of
/// the pact they just lost so the app can say the one sentence that matters:
/// "Your Pact has been broken."
class PactMemory extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).getString(_kPendingBreak);

  SharedPreferences get _prefs => ref.read(prefsProvider);

  /// Called on every user-document tick.
  Future<void> observe(String? currentPactId) async {
    if (currentPactId != null && currentPactId.isNotEmpty) {
      await _prefs.setString(_kLastPact, currentPactId);
      if (state != null) {
        // A fresh pact supersedes an unread break notice.
        await acknowledge();
      }
      return;
    }

    final last = _prefs.getString(_kLastPact);
    if (last != null && last.isNotEmpty) {
      await _prefs.remove(_kLastPact);
      await _prefs.setString(_kPendingBreak, last);
      state = last;
    }
  }

  Future<void> acknowledge() async {
    await _prefs.remove(_kPendingBreak);
    state = null;
  }
}

final pactMemoryProvider =
    NotifierProvider<PactMemory, String?>(PactMemory.new);
