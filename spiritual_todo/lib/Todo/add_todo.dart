import 'package:adhan/adhan.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pixelarticons/pixel.dart';
import '../Models/prayer_model.dart';
import '../Service/db_helper.dart';

List<TaskHelper> tasks = [];

class AddTaskSheet extends StatefulWidget {
  final Function(String, DateTime) onAddTask;
  final PrayerTimes prayerTimes;

  AddTaskSheet({required this.onAddTask, required this.prayerTimes});

  @override
  _AddTaskSheetState createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode(); // Step 1: Create a FocusNode
  final DatabaseHelper dbHelper = DatabaseHelper(
    dbName: "userDatabase.db",
    dbVersion: 6,
    dbTable: "TaskTable",
    columnId: 'id',
    columnName: 'task',
    columnTime: 'time',
    columnAssociatedPrayer: 'associatedPrayer',
    columnDaysOfWeek: 'daysOfWeek',
  );

  TimeOfDay _selectedTime =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 5)));
  Set<String> _selectedDays = Set<String>();
  late final sunnahTimes = SunnahTimes(widget.prayerTimes);
  final List<String> _daysOfWeek = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT'
  ];
// Schedule notification
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

  void askForNotificationPermission() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  Future<void> _submit() async {
    if (_taskController.text.isNotEmpty && _selectedDays.isNotEmpty) {
      final taskTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final associatedPrayer = PrayerUtils.getAssociatedPrayer(
          taskTime, widget.prayerTimes, sunnahTimes);
      print(
          "this is the get Associated Prayer: ${PrayerUtils.getAssociatedPrayer(taskTime, widget.prayerTimes, sunnahTimes)}");

      List<Map<String, dynamic>> records = await dbHelper.queryDatabase();
      print(records);

      _scheduleNotification(
        TaskHelper(
          await dbHelper.insertRecord({
            'task': _taskController.text,
            'time': _formatTime(taskTime),
            'associatedPrayer': associatedPrayer,
            'daysOfWeek': _selectedDays
                .join(','), // Store days as a comma-separated string
          }),
          _taskController.text,
          taskTime,
          associatedPrayer,
          _selectedDays.toList(),
        ),
      );

      // Inside _submit method in AddTaskSheet
      widget.onAddTask(_taskController.text, taskTime);

      // setState(() {
      //   _taskController.clear();
      //   _selectedTime = TimeOfDay.now();
      //   _selectedDays.clear();
      // });

      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _taskFocusNode
          .requestFocus(); // Step 2: Request focus after the widget is built
    });
  }

  @override
  void dispose() {
    _taskFocusNode.dispose(); // Step 3: Dispose of the FocusNode
    _taskController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime); // 12-hour format
  }

  @override
  Widget build(BuildContext context) {
    // Get the keyboard height
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 16.0 + keyboardHeight, // Adjust for the keyboard height
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize
              .min, // Ensure the column only takes up necessary space
          children: [
            const SizedBox(height: 8.0),
            TextField(
              controller: _taskController,
              focusNode: _taskFocusNode,
              onChanged: (value) => setState(() {
                _taskController.text = value;
              }),
              decoration: InputDecoration(
                labelText: 'Add task',
                border: InputBorder.none,
                suffixIcon: TextButton(
                  onPressed: () => _submit(), // Ensure _submit() is defined
                  child: _taskController.text.isEmpty
                      ? Icon(
                          Pixel.check,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        )
                      : const Icon(Pixel.check),
                ),
              ),
            ),

            TextButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              }, // Ensure _submit() is defined
              icon: const Icon(Pixel.clock),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${_formatTime(DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ))} ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Ensure the Wrap widget has enough space to be visible
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                // spacing: 5.0,
                // runSpacing: 5.0,
                children: _daysOfWeek.map((day) {
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(day.substring(0, 1)),
                    selected: _selectedDays.contains(day),
                    labelStyle: GoogleFonts.silkscreen(),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                    shape: const CircleBorder(),
                  );
                }).toList(),
              ),
            ),
            // SizedBox(height: 21.0),
          ],
        ),
      ),
    );
  }
}
