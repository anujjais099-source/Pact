import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// A pact has exactly one timezone, so both partners share one midnight.
/// This computes day keys and deadlines in *that* zone, matching
/// functions/src/time.ts byte for byte.
abstract final class PactClock {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  /// The device's IANA zone, e.g. `Asia/Kolkata`. Stored on the user document
  /// and used as the pact zone for whoever was waiting first.
  static Future<String> deviceTimezone() async {
    try {
      return await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      return 'UTC';
    }
  }

  static tz.Location _loc(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }

  static tz.TZDateTime nowIn(String timezone) =>
      tz.TZDateTime.now(_loc(timezone));

  /// `YYYY-MM-DD` inside the pact's zone.
  static String dayKey(String timezone, [DateTime? at]) {
    final loc = _loc(timezone);
    final t = at == null
        ? tz.TZDateTime.now(loc)
        : tz.TZDateTime.from(at, loc);
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  /// Next local midnight — the moment the day is judged.
  static DateTime deadline(String timezone) {
    final loc = _loc(timezone);
    final now = tz.TZDateTime.now(loc);
    return tz.TZDateTime(loc, now.year, now.month, now.day).add(const Duration(days: 1));
  }

  static Duration timeUntilDeadline(String timezone) {
    final left = deadline(timezone).difference(nowIn(timezone));
    return left.isNegative ? Duration.zero : left;
  }

  /// True inside the final hour — the app turns urgent here.
  static bool isFinalHour(String timezone) =>
      timeUntilDeadline(timezone) <= const Duration(hours: 1);
}
