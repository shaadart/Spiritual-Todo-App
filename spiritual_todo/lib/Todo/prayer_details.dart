import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spiritual_todo/Todo/todo_screen.dart';

import '../Models/prayer_model.dart';
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
  List<TaskHelper> _tasks = []; // Local list to manage tasks
  Set<int> _expandedTasks = {}; // Track expanded task IDs
  void _toggleExpansion(int taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
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
      _tasks.add(TaskHelper(
        newId,
        title,
        time,
        PrayerUtils.getAssociatedPrayer(time, prayerTimes, sunnahTimes),
        []
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
//     return "Midnight";
//   }

//   return "";
// }

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
        actions: [Chip(label: Text('${_tasks.length}')), Text("      ")],
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.all(21.0),
                  child: Text(
                      "starts at ${widget.prayer.time.toString().substring(11, 16)}"),
                ),
                if (_tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('No tasks for this prayer time.'),
                  )
                else
                  ..._tasks
                      .map(
                        (task) => TaskItem(
                          key: ValueKey(task.id),
                          onCollapse: () => _toggleExpansion(task.id),
                          task: task,
                          onUpdate: (updatedTask) {
                            setState(() {
                              // Update the task in the list
                              final index = _tasks
                                  .indexWhere((t) => t.id == updatedTask.id);
                              if (index != -1) {
                                _tasks[index] = updatedTask;
                              }
                            });
                          },
                          onDelete: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${task.title} is deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    // Implement undo logic here
                                  },
                                ),
                              ),
                            );
                            setState(() {
                              // Remove the task from the list
                              _tasks.removeWhere((t) => t.id == task.id);
                            });
                          },
                        ),
                      )
                      .toList()
              ],
            ),
          ),
        ],
      ),
    );
  }
}
