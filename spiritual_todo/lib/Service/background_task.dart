import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../Models/prayer_model.dart';
import 'db_helper.dart';

void updatePrayerTimesTask() {
  Workmanager().executeTask((task, inputData) async {
    final dbHelper = PrayerTimesDatabaseHelper();
    final taskDbHelper = DatabaseHelper(
      dbName: "userDatabase.db",
      dbVersion: 3,
      dbTable: 'TaskTable',
      columnId: 'id',
      columnName: 'task',
      columnTime: 'time',
      columnAssociatedPrayer: 'associatedPrayer',
      columnDaysOfWeek: 'daysOfWeek',
    );
    final storedCoordinates = await dbHelper.getStoredCoordinates();

    if (storedCoordinates != null) {
      print('Stored coordinates found: $storedCoordinates');

      final prayerTimes = PrayerTimes.today(
        storedCoordinates,
        CalculationMethod.karachi.getParameters(),
      );

      // Print out the new prayer times for debugging
      print('Fetched prayer times:');
      print('Fajr: ${prayerTimes.fajr}');
      print('Dhuhr: ${prayerTimes.dhuhr}');
      print('Asr: ${prayerTimes.asr}');
      print('Maghrib: ${prayerTimes.maghrib}');
      print('Isha: ${prayerTimes.isha}');

      // Fetch the previous day's prayer times and calculate the differences
      final yesterday = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(Duration(days: 1)),
      );
      final previousPrayerTimesMap =
          await dbHelper.getPrayerTimesByDate(yesterday);

      if (previousPrayerTimesMap != null) {
        final timeDifferences = calculateTimeDifferences(
          previousPrayerTimesMap,
          prayerTimes,
        );

        // Log the time differences
        print('Time differences calculated: $timeDifferences');

        // Adjust tasks based on differences
        final tasks = await taskDbHelper.queryDatabase();
        for (var taskMap in tasks) {
          TaskHelper task = TaskHelper.fromMap(taskMap);
          final associatedPrayer = task.associatedPrayer;

          DateTime newTaskTime = adjustTaskTimeBasedOnDifference(
            task.time,
            associatedPrayer,
            timeDifferences,
          );
          task.time = newTaskTime;
          await taskDbHelper.updateRecord(task.toMap());

          // Log the task update
          print('Task "${task.title}" updated to new time: $newTaskTime');
        }
      }
    }

    print('updatePrayerTimesTask finished.');
    return Future.value(true);
  });
}

Map<String, Duration> calculateTimeDifferences(
    Map<String, dynamic> previousPrayerTimesMap, PrayerTimes prayerTimes) {
  // Calculate the differences between the current and previous day's prayer times
  return {
    'Fajr': prayerTimes.fajr
        .difference(DateTime.parse(previousPrayerTimesMap['fajr'])),
    'Dhuhr': prayerTimes.dhuhr
        .difference(DateTime.parse(previousPrayerTimesMap['dhuhr'])),
    'Asr': prayerTimes.asr
        .difference(DateTime.parse(previousPrayerTimesMap['asr'])),
    'Maghrib': prayerTimes.maghrib
        .difference(DateTime.parse(previousPrayerTimesMap['maghrib'])),
    'Isha': prayerTimes.isha
        .difference(DateTime.parse(previousPrayerTimesMap['isha'])),
  };
}

DateTime adjustTaskTimeBasedOnDifference(DateTime taskTime,
    String associatedPrayer, Map<String, Duration> timeDifferences) {
  // Adjust the task time based on the prayer time difference
  return taskTime.add(timeDifferences[associatedPrayer] ?? Duration.zero);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("background task executing:  $task");
    updatePrayerTimesTask();
    return Future.value(true);
  });
}
