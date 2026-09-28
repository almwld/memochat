abstract final class AppFormat {
  static String date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  static String dateTime(DateTime value) => '${date(value)} ${time(value)}';
  static String currency(num value, {String symbol = ''}) => '$symbol${value.toStringAsFixed(2)}';
}
