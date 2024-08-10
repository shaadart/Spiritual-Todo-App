import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import 'db_helper.dart';
void updatePrayerTimesTask() {
  Workmanager().executeTask((task, inputData) async {
    final dbHelper = PrayerTimesDatabaseHelper();
    final storedCoordinates = await dbHelper.getStoredCoordinates();

    if (storedCoordinates != null) {
      print('Stored coordinates: $storedCoordinates');

      final prayerTimes = PrayerTimes.today(
        storedCoordinates,
        CalculationMethod.karachi.getParameters(),
      );

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final prayerTimesMap = {
        'date': today,
        'fajr': prayerTimes.fajr.toIso8601String(),
        'sunrise': prayerTimes.sunrise.toIso8601String(),
        'dhuhr': prayerTimes.dhuhr.toIso8601String(),
        'asr': prayerTimes.asr.toIso8601String(),
        'maghrib': prayerTimes.maghrib.toIso8601String(),
        'isha': prayerTimes.isha.toIso8601String(),
        'midnight': SunnahTimes(prayerTimes).lastThirdOfTheNight.toIso8601String(),
      };

      final id = await dbHelper.insertPrayerTimes(prayerTimesMap);
      print('Inserted prayer times with ID: $id');
    } else {
      print('No stored coordinates found.');
    }

    return Future.value(true);
  });
}


void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    updatePrayerTimesTask();
    return Future.value(true);
  });
}
