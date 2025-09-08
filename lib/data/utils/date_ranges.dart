extension SessionsDateRanges on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
  DateTime get dayEnd   => DateTime(year, month, day, 23, 59, 59, 999);

  /// ISO week (Mon–Sun)
  DateTime get weekStart {
    final int weekdayMon1 = weekday == DateTime.sunday ? 7 : weekday;
    final start = dayStart.subtract(Duration(days: weekdayMon1 - 1));
    return DateTime(start.year, start.month, start.day);
  }
  DateTime get weekEnd => DateTime(weekStart.year, weekStart.month, weekStart.day, 23, 59, 59, 999)
      .add(const Duration(days: 6));

  DateTime get monthStart => DateTime(year, month, 1);
  DateTime get monthEnd {
    final firstNext = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstNext.subtract(const Duration(milliseconds: 1));
  }
}
