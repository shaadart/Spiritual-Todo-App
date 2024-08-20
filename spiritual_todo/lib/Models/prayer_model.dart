// lib/utils/prayer_utils.dart
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PrayerTime {
  final String label;
  final DateTime time;
  final int? timeDifference;

  PrayerTime(this.label, this.time, {this.timeDifference});
}

class TaskHelper {
  final int id;
  String title;
  DateTime time;
  String associatedPrayer;
  List<String> daysOfWeek;

  TaskHelper(
      this.id, this.title, this.time, this.associatedPrayer, this.daysOfWeek);

  factory TaskHelper.fromMap(Map<String, dynamic> map) {
    return TaskHelper(
      map['id'],
      map['task'],
      _parseTime(map['time']),
      map['associatedPrayer'] ?? '',
      (map['daysOfWeek'] as String).split(',')
        ..removeWhere((day) => day.isEmpty),
    );
  }

DateTime getUpcomingDateTime(DateTime now) {
  DateTime taskDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    time.hour,
    time.minute,
  );

  // If task time is in the past, move to the next available day
  if (taskDateTime.isBefore(now)) {
    do {
      taskDateTime = taskDateTime.add(Duration(days: 1));
    } while (!daysOfWeek.contains(_getDayString(taskDateTime.weekday)));
  }

  return taskDateTime;
}


  String _getDayString(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
      default:
        return 'Once';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task': title,
      'time': _formatTime(time),
      'associatedPrayer': associatedPrayer,
      'daysOfWeek': daysOfWeek.isEmpty ? 'Once' : daysOfWeek.join(','),
    };
  }

static DateTime _parseTime(String timeString) {
  try {
    return DateFormat('hh:mm a').parse(timeString.trim());
  } catch (e) {
    return DateTime.now();
  }
}
   String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class PrayerUtils {
  static String getAssociatedPrayer(
      DateTime taskTime, PrayerTimes prayerTimes, SunnahTimes sunnahTimes) {
    DateTime taskDate = DateTime(taskTime.year, taskTime.month, taskTime.day);

    // Define prayer times for the day
    DateTime fajrStart = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.fajr.hour, prayerTimes.fajr.minute);
    DateTime sunriseStart = DateTime(taskDate.year, taskDate.month,
        taskDate.day, prayerTimes.sunrise.hour, prayerTimes.sunrise.minute);
    DateTime dhuhrStart = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.dhuhr.hour, prayerTimes.dhuhr.minute);
    DateTime asrStart = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.asr.hour, prayerTimes.asr.minute);
    DateTime maghribStart = DateTime(taskDate.year, taskDate.month,
        taskDate.day, prayerTimes.maghrib.hour, prayerTimes.maghrib.minute);
    DateTime ishaStart = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.isha.hour, prayerTimes.isha.minute);

    // Define end times for the prayers
    DateTime fajrEnd = sunriseStart;
    DateTime sunriseEnd = dhuhrStart;
    DateTime dhuhrEnd = asrStart;
    DateTime asrEnd = maghribStart;
    DateTime maghribEnd = ishaStart;
    DateTime ishaEnd = DateTime(
        taskDate.year, taskDate.month, taskDate.day + 1, 00, 00); // Last Night

    // Check if the task time falls into any of the prayer times
    if (taskTime.isAfter(fajrStart) && taskTime.isBefore(fajrEnd)) {
      print("Current Associated Prayer: Fajr");
      return "Fajr";
    } else if (taskTime.isAfter(sunriseStart) &&
        taskTime.isBefore(sunriseEnd)) {
      print("Current Associated Prayer: Sunrise");
      return "Sunrise";
    } else if (taskTime.isAfter(dhuhrStart) && taskTime.isBefore(dhuhrEnd)) {
      print("Current Associated Prayer: Dhuhr");
      return "Dhuhr";
    } else if (taskTime.isAfter(asrStart) && taskTime.isBefore(asrEnd)) {
      print("Current Associated Prayer: Asr");
      return "Asr";
    } else if (taskTime.isAfter(maghribStart) &&
        taskTime.isBefore(maghribEnd)) {
      print("Current Associated Prayer: Maghrib");
      return "Maghrib";
    } else if (taskTime.isAfter(ishaStart) && taskTime.isBefore(ishaEnd)) {
      print("Current Associated Prayer: Isha");
      return "Isha";
    }

    print("Current Associated Prayer: Last Night");
    return "Last Night";
  }
}
