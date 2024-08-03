// lib/utils/prayer_utils.dart
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';

class PrayerTime {
  final String label;
  final DateTime time;

  PrayerTime(this.label, this.time);
}

class TaskHelper {
  final int id;
  String title;
  DateTime time; // Change from final to mutable
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
      (map['daysOfWeek'] as String).split(','),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task': title,
      'time': _formatTime(time),
      'associatedPrayer': associatedPrayer,
      'daysOfWeek': daysOfWeek.join(','),
    };
  }

  static DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


class PrayerUtils {
  static String getAssociatedPrayer(
      DateTime taskTime, PrayerTimes prayerTimes, SunnahTimes sunnahTimes) {
    DateTime taskDate = DateTime(taskTime.year, taskTime.month, taskTime.day);

    // Define prayer times
    DateTime fajrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.sunrise.hour, prayerTimes.sunrise.minute);
    DateTime sunriseEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.dhuhr.hour, prayerTimes.dhuhr.minute);
    DateTime dhuhrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.asr.hour, prayerTimes.asr.minute);
    DateTime asrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.maghrib.hour, prayerTimes.maghrib.minute);
    DateTime maghribEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.isha.hour, prayerTimes.isha.minute);

    // Define Isha end and Midnight start times, considering next day for Midnight
    DateTime ishaEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
        prayerTimes.isha.hour, prayerTimes.isha.minute);
    DateTime MidnightStart = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day + 1,
        sunnahTimes.lastThirdOfTheNight.hour,
        sunnahTimes.lastThirdOfTheNight.minute);
    DateTime MidnightEnd = DateTime(taskDate.year, taskDate.month,
        taskDate.day + 1, prayerTimes.fajr.hour, prayerTimes.fajr.minute);

    // Check Midnight time

    // Check other prayers
    if ((taskTime.isBefore(fajrEnd) && taskTime.isAfter(prayerTimes.fajr)) ||
        taskTime == prayerTimes.fajr) {
      return "Fajr";
    } else if ((taskTime.isBefore(sunriseEnd) &&
            taskTime.isAfter(prayerTimes.sunrise)) ||
        taskTime == prayerTimes.sunrise) {
      return "Sunrise";
    } else if ((taskTime.isBefore(dhuhrEnd) &&
            taskTime.isAfter(prayerTimes.dhuhr)) ||
        taskTime == prayerTimes.dhuhr) {
      return "Dhuhr";
    } else if ((taskTime.isBefore(asrEnd) &&
            taskTime.isAfter(prayerTimes.asr)) ||
        taskTime == prayerTimes.asr) {
      return "Asr";
    } else if ((taskTime.isBefore(maghribEnd) &&
            taskTime.isAfter(prayerTimes.maghrib)) ||
        taskTime == prayerTimes.maghrib) {
      return "Maghrib";
    } else if ((taskTime.isAfter(maghribEnd) && taskTime.isBefore(ishaEnd)) ||
        taskTime == prayerTimes.isha) {
      return "Isha";
    } else if ((taskTime.isBefore(MidnightStart) &&
        taskTime.isAfter(DateTime(
            taskDate.year, taskDate.month, taskDate.day + 1, 00, 00)))) {
      return "Isha";
    }
    return "Midnight";
  }
}
