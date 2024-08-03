import 'dart:async'; // Import StreamController
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spiritual_todo/Service/db_helper.dart'; // Import your DB helper

import '../Models/prayer_model.dart'; // Import your TaskHelper model

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spiritual_todo/Service/db_helper.dart';
import '../Models/prayer_model.dart'; // Import your TaskHelper model

class TodoScreen extends StatefulWidget {
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final StreamController<List<TaskHelper>> _tasksController =
      StreamController.broadcast();
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

  @override
  void initState() {
    super.initState();
    _startPolling();
    _loadTasks();
  }

  @override
  void dispose() {
    _tasksController.close();
    super.dispose();
  }

  void _startPolling() {
    _loadTasks(); // Initial load
    Timer.periodic(Duration(seconds: 3), (timer) async {
      _loadTasks(); // Poll the database every 3 seconds
    });
  }

  Future<void> _loadTasks() async {
    final records = await _dbHelper.queryDatabase();
    final tasks = records.map((map) => TaskHelper.fromMap(map)).toList();
    _tasksController.add(tasks);
  }

  Future<void> _updateTask(TaskHelper task) async {
    await _dbHelper.updateRecord(task.toMap());
    _loadTasks(); // Reload tasks after update
  }

  Future<void> _deleteTask(int id) async {
    await _dbHelper.deleteRecord(id); // Use the task ID for deletion
    _loadTasks(); // Reload tasks after deletion
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Todo',
          style: GoogleFonts.pixelifySans(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      body: StreamBuilder<List<TaskHelper>>(
        stream: _tasksController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks found'));
          } else {
            final todos = snapshot.data!;
            return ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final task = todos[index];
                return TaskItem(
                  task: task,
                  onUpdate: (updatedTask) {
                    _updateTask(updatedTask);
                  },
                  onDelete: () {
                    _deleteTask(task.id); // Use task ID for deletion
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

class TaskItem extends StatefulWidget {
  final TaskHelper task;
  final Function(TaskHelper) onUpdate;
  final Function() onDelete;

  TaskItem({
    required this.task,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late TextEditingController _titleController;
  late Set<String> _selectedDays;
  late TimeOfDay _selectedTime;
  bool _isExpanded = false;
  late PrayerTimes prayerTimes;
  late DateTime currentTime;
  late final SunnahTimes sunnahTimes;
  final Coordinates coordinates =
      Coordinates(21.2588, 81.6290); // Replace with your coordinates
  final params = CalculationMethod.karachi.getParameters();

  void _updatePrayerTimes() {
    setState(() {
      prayerTimes = PrayerTimes.today(coordinates, params);
      sunnahTimes = SunnahTimes(prayerTimes); // Initialize SunnahTimes
      currentTime = DateTime.now();
    });
  }

  // List of days in order
  final List<String> _weekDaysOrder = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];

  @override
  void initState() {
    super.initState();
    _updatePrayerTimes();
    _titleController = TextEditingController(text: widget.task.title);
    // Convert days to uppercase for consistency
    _selectedDays =
        widget.task.daysOfWeek.map((day) => day.toUpperCase()).toSet();
    _selectedTime =
        TimeOfDay.fromDateTime(widget.task.time); // Initialize with task's time
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Function to get days in order
  String _getOrderedDaysOfWeek(List<String> daysOfWeek) {
    List<String> orderedDays = _weekDaysOrder
        .where((day) => daysOfWeek.contains(day.toUpperCase()))
        .toList();
    return orderedDays.isEmpty
        ? 'No days selected'
        : orderedDays.length == 7
            ? 'Everyday'
            : orderedDays.join(', ').toLowerCase();
  }

// Example of passing prayerTimes and sunnahTimes to _selectTime
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        // Update the task's time
        widget.task.time = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        // Assuming prayerTimes and sunnahTimes are available
        widget.task.associatedPrayer = PrayerUtils.getAssociatedPrayer(
          widget.task.time,
          prayerTimes, // Ensure prayerTimes is properly initialized
          sunnahTimes, // Ensure sunnahTimes is properly initialized
        );
        widget.onUpdate(widget.task); // Notify parent to update task
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded; // Update the expansion state
          });
        },
        backgroundColor:
            Theme.of(context).colorScheme.onSecondary.withOpacity(0.34),
        leading: Icon(Icons.circle_outlined),
        title: Opacity(
          opacity: _isExpanded ? 0.21 : 0.89,
          child: Text(
            widget.task.title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: Opacity(
          opacity: _isExpanded ? 0.21 : 0.89,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 16),
                  SizedBox(width: 4),
                  Text(
                    DateFormat('hh:mm a').format(
                      DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        widget.task.time.hour,
                        widget.task.time.minute,
                      ),
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.notifications_outlined, size: 16),
                  SizedBox(width: 4),
                  Text(
                    widget.task.associatedPrayer,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 4),
                  Text(
                    _getOrderedDaysOfWeek(widget.task.daysOfWeek),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  onChanged: (value) {
                    setState(() {
                      widget.task.title = value;
                    });
                    widget
                        .onUpdate(widget.task); // Notify parent to update task
                  },
                ),
                SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 1.0,
                    children: _weekDaysOrder
                        .map((day) => ChoiceChip(
                              showCheckmark: false,
                              label: Text(day
                                  .substring(0, 1)
                                  .toUpperCase()), // Use uppercase
                              selected: _selectedDays.contains(day
                                  .toUpperCase()), // Convert day to uppercase for comparison
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(day
                                        .toUpperCase()); // Convert to uppercase
                                  } else {
                                    _selectedDays.remove(day
                                        .toUpperCase()); // Convert to uppercase
                                  }
                                  // Update task's daysOfWeek
                                  widget.task.daysOfWeek =
                                      _selectedDays.toList();
                                  widget.onUpdate(widget
                                      .task); // Notify parent to update task
                                });
                              },
                              shape: CircleBorder(),
                            ))
                        .toList(),
                  ),
                ),
                SizedBox(height: 10),
                ListTile(
                  title: Text('${DateFormat('hh:mm a').format(DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ))}'),
                  leading: Icon(Icons.access_time_outlined),
                  onTap: () => _selectTime(context),
                ),
                ListTile(
                  title: Text('Delete'),
                  leading: Icon(Icons.delete_outline),
                  onTap: () => widget.onDelete(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
