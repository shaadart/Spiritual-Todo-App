import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spiritual_todo/Todo/todo_screen.dart';

import '../Models/prayer_model.dart';
import '../Service/db_helper.dart';
import 'add_todo.dart';

class PrayerDetailsScreen extends StatefulWidget {
  final PrayerTime prayer;
  final List<TaskHelper> tasks;

  PrayerDetailsScreen({required this.prayer, required this.tasks});

  @override
  _PrayerDetailsScreenState createState() => _PrayerDetailsScreenState();
}

class _PrayerDetailsScreenState extends State<PrayerDetailsScreen> {
  late ScrollController _scrollController;
  final Coordinates coordinates =
      Coordinates(21.2588, 81.6290); // Replace with your coordinates
  final params = CalculationMethod.karachi.getParameters();
  late PrayerTimes prayerTimes;
  late final SunnahTimes sunnahTimes;
  late DateTime currentTime;
  List<TaskHelper> _tasks = [];
  Set<int> _expandedTasks = {}; // Track expanded task IDs
  List<TaskHelper> _deletedTasks = []; // Track deleted tasks
  void _toggleExpansion(int taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper(
    dbName: "userDatabase.db",
    dbVersion: 3,
    dbTable: "TaskTable",
    columnId: 'id',
    columnName: 'task',
    columnTime: 'time',
    columnAssociatedPrayer: 'associatedPrayer',
    columnDaysOfWeek: 'daysOfWeek',
  );
  void _loadTasks() async {
    final records = await _dbHelper.queryDatabase();
    print("Fetched records: $records"); // Debug print to check fetched records
    final tasks = records.map((map) => TaskHelper.fromMap(map)).toList();
    tasks.sort((a, b) {
      DateTime now = DateTime.now();
      DateTime aUpcoming = a.getUpcomingDateTime(now);
      DateTime bUpcoming = b.getUpcomingDateTime(now);
      return aUpcoming.compareTo(bUpcoming);
    });
    // _tasksController.add(tasks);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    setState(() {
      _updatePrayerTimes();
      _tasks = widget.tasks; // Initialize local tasks list
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePrayerTimes() {
    setState(() {
      prayerTimes = PrayerTimes.today(coordinates, params);
      sunnahTimes = SunnahTimes(prayerTimes); // Initialize SunnahTimes
      currentTime = DateTime.now();
    });
  }

  void _addTask(String title, DateTime time, List daysOfWeek) {
    final newId = _tasks.isEmpty
        ? 1
        : (_tasks.map((task) => task.id).reduce((a, b) => a > b ? a : b) + 1);

    setState(() {
      _tasks.add(TaskHelper(newId, title, time,
          PrayerUtils.getAssociatedPrayer(time, prayerTimes, sunnahTimes), []
          // Initialize with empty days, can be updated later
          ));
    });
  }

//   String _getAssociatedPrayer(DateTime taskTime) {
//   DateTime fajrEnd = prayerTimes.sunrise;
//   DateTime sunriseEnd = prayerTimes.dhuhr;
//   DateTime dhuhrEnd = prayerTimes.asr;
//   DateTime asrEnd = prayerTimes.maghrib;
//   DateTime maghribEnd = prayerTimes.isha;
//   DateTime MidnightStart = sunnahTimes.lastThirdOfTheNight;

//   if (taskTime.isAfter(prayerTimes.fajr) &&
//       taskTime.isBefore(fajrEnd)) {
//     return "Fajr";
//   } else if (taskTime.isAfter(prayerTimes.sunrise) &&
//       taskTime.isBefore(sunriseEnd)) {
//     return "Sunrise";
//   } else if (taskTime.isAfter(prayerTimes.dhuhr) &&
//       taskTime.isBefore(dhuhrEnd)) {
//     return "Dhuhr";
//   } else if (taskTime.isAfter(prayerTimes.asr) &&
//       taskTime.isBefore(asrEnd)) {
//     return "Asr";
//   } else if (taskTime.isAfter(prayerTimes.maghrib) &&
//       taskTime.isBefore(maghribEnd)) {
//     return "Maghrib";
//   } else if (taskTime.isAfter(prayerTimes.isha)) {
//     return "Isha";
//   } else if (taskTime.isAfter(MidnightStart)) {
//     return "Last Night";
//   }

//   return "";
// }
  Future<void> _deleteTask(int id) async {
    final deletedTaskMap =
        await _dbHelper.getTask(id); // Get the task to delete
    if (deletedTaskMap != null) {
      final deletedTask = TaskHelper.fromMap(deletedTaskMap);
      // Cancel the delayed deletion if undo is pressed
      Future.delayed(Duration(milliseconds: 1), () async {
        if (!_deletedTasks.contains(deletedTask)) {
          await _dbHelper.deleteRecord(id);
          AwesomeNotifications().cancel(id); // Cancel the notification
          setState(() {
            _deletedTasks.add(deletedTask); // Add to deleted tasks list
            _expandedTasks
                .remove(id); // Remove from expanded tasks when deleted
          });
        }
      });
    }
  }

  void _scheduleNotification(TaskHelper task) {
    DateTime upcomingDateTime = task.getUpcomingDateTime(DateTime.now());

    // Debug print to check scheduled time
    print("Upcoming DateTime: $upcomingDateTime");
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: task.id,
        channelKey: 'basic_channel',
        body: 'Reminder',
        title: task.title,
        autoDismissible: false,
        displayOnForeground: true,
        displayOnBackground: true,
        wakeUpScreen: true,
        fullScreenIntent: true,
      ),
      schedule: NotificationCalendar.fromDate(
        date: upcomingDateTime,
        repeats: true,
      ),
    );
    print("Scheduling notification for: $upcomingDateTime");
  }

  Future<void> _updateTask(TaskHelper task) async {
    await _dbHelper.updateRecord(task.toMap());

    // Cancel existing notification
    AwesomeNotifications().cancel(task.id);

    // Schedule new notification
    _scheduleNotification(task);
  }

  void _undoDelete(TaskHelper deletedTask) {
    setState(() {
      _deletedTasks.remove(deletedTask); // Remove from deleted tasks list
      _dbHelper
          .insertRecord(deletedTask.toMap()); // Re-insert task into database
      _loadTasks(); // Reload tasks to refresh UI
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        shape: CircleBorder(),
        elevation: 0.3,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return AddTaskSheet(
                onAddTask: (title, time) {
                  _addTask(title, time, []);
                },
                prayerTimes: prayerTimes,
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text('${widget.prayer.label} Tasks',
            style: GoogleFonts.pixelifySans()),
        actions: [Chip(label: Text('${widget.tasks.length}')), Text("      ")],
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: widget.tasks.isEmpty
          ? Center(
              child: Text(
                'No tasks added in ${widget.prayer.label}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          : ListView.builder(
              itemCount: widget.tasks.length, // Use filtered tasks
              itemBuilder: (context, index) {
                TaskHelper task = widget.tasks[index];
                return TaskItem(
                  key: ValueKey(task.id),
                  task: task,
                  onUpdate: (updatedTask) {
                    _updateTask(updatedTask);
                  },
                  onDelete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: Duration(milliseconds: 1500),
                        content: Text('${task.title} is deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            _undoDelete(task);
                          },
                        ),
                      ),
                    );
                    _deleteTask(task.id);
                  },
                  onCollapse: () {
                    _toggleExpansion(task.id);
                  },
                );
              },
            ),
    );
  }
}
