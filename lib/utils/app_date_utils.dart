class AppDateUtils {
  AppDateUtils._();

  static DateTime dayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime addCalendarDays(DateTime date, int days) {
    final day = dayOnly(date);
    return DateTime(day.year, day.month, day.day + days);
  }

  static DateTime startOfWeekMonday(DateTime date) {
    final day = dayOnly(date);
    return addCalendarDays(day, DateTime.monday - day.weekday);
  }
}
