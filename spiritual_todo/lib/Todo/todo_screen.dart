import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spiritual_todo/Service/db_helper.dart'; // Import your DB helper
import '../Models/prayer_model.dart'; // Import your TaskHelper model

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.title});

  final String title;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _tasksController = StreamController<List<TaskHelper>>.broadcast();
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

  Set<int> _expandedTasks = {}; // Track expanded task IDs
  List<TaskHelper> _deletedTasks = []; // Track deleted tasks

  @override
  void initState() {
    super.initState();

    _loadTasks();
  }

  @override
  void dispose() {
    _tasksController.close();
    super.dispose();
  }

  Future<Object> getMaxId() async {
    return await _dbHelper.getMaxId();
  }

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
    _tasksController.add(tasks);
  }

  void _scheduleNotification(TaskHelper task) {
    DateTime upcomingDateTime = task.getUpcomingDateTime(DateTime.now());

    print(
        "Scheduling notification for: $upcomingDateTime"); // Debug print to check scheduled time

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
        payload: {
          'associatedPrayer': task.associatedPrayer,
          'daysOfWeek': task.daysOfWeek.join(','),
        },
      ),
      schedule:
          NotificationCalendar.fromDate(date: upcomingDateTime, repeats: true),
    );
  }

  Future<void> _updateTask(TaskHelper task) async {
    await _dbHelper.updateRecord(task.toMap());

    // Cancel existing notification
    AwesomeNotifications().cancel(task.id);

    // Schedule new notification
    _scheduleNotification(task);
  }


  Future<void> _deleteTask(int id) async {
    final deletedTaskMap =
        await _dbHelper.getTask(id); // Get the task to delete
    if (deletedTaskMap != null) {
      final deletedTask = TaskHelper.fromMap(deletedTaskMap);
      await _dbHelper.deleteRecord(id);
      AwesomeNotifications().cancel(id); // Cancel the notification
      setState(() {
        _deletedTasks.add(deletedTask); // Add to deleted tasks list
        _expandedTasks.remove(id); // Remove from expanded tasks when deleted
      });
    }
  }

  void _toggleExpansion(int taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
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
            key: ValueKey(task.id),
            task: task,
            onUpdate: (updatedTask) {
              _updateTask(updatedTask);
            },
            onDelete: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
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
  final Function() onCollapse;

  TaskItem({
    required Key key, // Ensure unique key is passed
    required this.task,
    required this.onUpdate,
    required this.onDelete,
    required this.onCollapse,
  }) : super(key: key);

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late TextEditingController _titleController;
  late Set<String> _selectedDays;
  late TimeOfDay _selectedTime;
  bool _isExpanded = false;
  bool _needsUpdate = false; // Track if updates are needed
  late PrayerTimes prayerTimes;
  late DateTime currentTime;
  late final SunnahTimes sunnahTimes;
  final Coordinates coordinates =
      Coordinates(21.2588, 81.6290); // Replace with your coordinates
  final params = CalculationMethod.karachi.getParameters();
  bool _isNotificationEnabled = true;

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

  void _toggleNotification() {
    setState(() {
      _applyUpdates(); // Apply updates to the task
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _needsUpdate = true; // Flag that an update is needed
      });
    }
  }

  void _applyUpdates() {
    widget.task.daysOfWeek = _selectedDays.toList();
    widget.task.title = _titleController.text;
    widget.task.time = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    widget.onUpdate(widget.task);
    setState(() {
      _needsUpdate = false; // Reset flag after update
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        key: widget.key, // Use passed key
        trailing: Icon(Icons.keyboard_arrow_down_rounded),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
            if (!expanded && _needsUpdate) {
              _applyUpdates();
            }
          });
        },
        backgroundColor:
            Theme.of(context).colorScheme.onSecondary.withOpacity(0.34),
        leading: Icon(Icons.circle_outlined),
        title: Opacity(
          opacity: _isExpanded ? 0.34 : 0.89,
          child: Text(
            widget.task.title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: Opacity(
          opacity: _isExpanded ? 0.34 : 0.89,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 16),
                  SizedBox(width: 4),
                  Text(
                    DateFormat('hh:mm a').format(widget.task.time),
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 10),
                  Icon(
                      _isNotificationEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      size: 16),
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
                      _needsUpdate = true; // Flag that an update is needed
                    });
                  },
                ),
                SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 1.0,
                    children: _weekDaysOrder
                        .map((day) => ChoiceChip(
                              labelStyle: GoogleFonts.silkscreen(),
                              showCheckmark: false,
                              label: Text(day.substring(0, 1).toUpperCase()),
                              selected:
                                  _selectedDays.contains(day.toUpperCase()),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(day.toUpperCase());
                                  } else {
                                    _selectedDays.remove(day.toUpperCase());
                                  }
                                  _needsUpdate =
                                      true; // Flag that an update is needed
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
                  title: Text(_isNotificationEnabled
                      ? 'Notification On'
                      : 'Notification Off'),
                  leading: Icon(_isNotificationEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined),
                  onTap: _toggleNotification,
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                child: Text('Delete'),
                onPressed: () {
                  widget.onCollapse(); // Notify parent to collapse this tile
                  widget.onDelete();
                },
              ),
              ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                        Theme.of(context).colorScheme.primary),
                    foregroundColor: MaterialStateProperty.all<Color>(
                        Theme.of(context).colorScheme.onPrimary)),
                child: Text('Update'),
                onPressed: _needsUpdate // Enable button only when needed
                    ? () {
                        widget
                            .onCollapse(); // Notify parent to collapse this tile
                        _applyUpdates();
                      }
                    : null,
              ),
            ],
          ),
          Text(" "),
        ],
      ),
    );
  }
}
