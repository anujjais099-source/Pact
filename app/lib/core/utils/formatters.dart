import 'package:intl/intl.dart';

abstract final class Fmt {
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _date = DateFormat('d MMM');

  static String time(DateTime? t) => t == null ? '--:--' : _time.format(t.toLocal());
  static String date(DateTime? t) => t == null ? '' : _date.format(t.toLocal());

  /// `07h 12m` / `48m` / `9m 20s` — tightens as the deadline closes in.
  static String countdown(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    }
    if (d.inMinutes >= 10) return '${d.inMinutes}m';
    return '${d.inMinutes}m ${d.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }

  static String dayWord(int n) => n == 1 ? 'day' : 'days';

  static String submittedAt(DateTime? t) =>
      t == null ? 'Submitted' : 'Submitted at ${time(t)}';

  static String percent(double v) =>
      '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}%';
}
