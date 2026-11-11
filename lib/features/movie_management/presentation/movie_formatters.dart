/// Display helpers shared by the movie screens.
abstract final class MovieFormatters {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `148` → `2h 28m`, `45` → `45m`. Returns `null` for unknown runtimes.
  static String? runtime(int? minutes) {
    if (minutes == null || minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  /// `12345` → `12.3k`, `2500000` → `2.5M`.
  static String compactCount(int value) {
    if (value >= 1000000) return '${_trim(value / 1000000)}M';
    if (value >= 1000) return '${_trim(value / 1000)}k';
    return '$value';
  }

  /// `2024-03-01` → `1 Mar 2024`. Unparseable input is returned unchanged.
  static String date(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return '${parsed.day} ${_months[parsed.month - 1]} ${parsed.year}';
  }

  static String _trim(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
