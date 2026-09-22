import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat shortDate = DateFormat.yMMMd();
  static final DateFormat fullDateTime = DateFormat.yMMMd().add_jm();
  static final DateFormat monthDay = DateFormat.MMMd();

  static String formatShort(DateTime date) => shortDate.format(date);
  static String formatFull(DateTime date) => fullDateTime.format(date);
  static String formatMonthDay(DateTime date) => monthDay.format(date);

  static String expiryRelativeText(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays < 0) {
      final abs = diffDays.abs();
      return abs == 1 ? 'Expired yesterday' : 'Expired $abs days ago';
    } else if (diffDays == 0) {
      return 'Expires today';
    } else if (diffDays == 1) {
      return 'Expires tomorrow';
    } else {
      return 'Expires in $diffDays days';
    }
  }
}
