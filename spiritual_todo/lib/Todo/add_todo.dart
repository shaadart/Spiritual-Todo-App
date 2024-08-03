import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  TimeOfDay _selectedTime = TimeOfDay.now();
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

// String _getAssociatedPrayer(DateTime taskTime) {
//   DateTime taskDate = DateTime(taskTime.year, taskTime.month, taskTime.day);

//   DateTime fajrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                                widget.prayerTimes.sunrise.hour, widget.prayerTimes.sunrise.minute);
//   DateTime sunriseEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                                   widget.prayerTimes.dhuhr.hour, widget.prayerTimes.dhuhr.minute);
//   DateTime dhuhrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                                 widget.prayerTimes.asr.hour, widget.prayerTimes.asr.minute);
//   DateTime asrEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                               widget.prayerTimes.maghrib.hour, widget.prayerTimes.maghrib.minute);
//   DateTime maghribEnd = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                                   widget.prayerTimes.isha.hour, widget.prayerTimes.isha.minute);
//   DateTime ishaEnd = sunnahTimes.lastThirdOfTheNight; // Isha ends at the start of Midnight
//   DateTime MidnightStart = DateTime(taskDate.year, taskDate.month, taskDate.day,
//                                       sunnahTimes.lastThirdOfTheNight.hour,
//                                       sunnahTimes.lastThirdOfTheNight.minute);

//   print('Task Time: $taskTime');
//   print('Fajr End: $fajrEnd');
//   print('Sunrise End: $sunriseEnd');
//   print('Dhuhr End: $dhuhrEnd');
//   print('Asr End: $asrEnd');
//   print('Maghrib End: $maghribEnd');
//   print('Isha End: $ishaEnd');
//   print('Midnight Start: $MidnightStart');

//   if (taskTime.isAfter(widget.prayerTimes.fajr) && taskTime.isBefore(fajrEnd)) {
//     return "Fajr";
//   } else if (taskTime.isAfter(widget.prayerTimes.sunrise) && taskTime.isBefore(sunriseEnd)) {
//     return "Sunrise";
//   } else if (taskTime.isAfter(widget.prayerTimes.dhuhr) && taskTime.isBefore(dhuhrEnd)) {
//     return "Dhuhr";
//   } else if (taskTime.isAfter(widget.prayerTimes.asr) && taskTime.isBefore(asrEnd)) {
//     return "Asr";
//   } else if (taskTime.isAfter(widget.prayerTimes.maghrib) && taskTime.isBefore(maghribEnd)) {
//     return "Maghrib";
//   } else if (taskTime.isAfter(ishaEnd) && taskTime.isBefore(MidnightStart)) {
//     return "Isha";
//   } else if (taskTime.isAfter(MidnightStart)) {
//     return "Midnight";
//   }

//   return "";
// }

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
          "this is teh get Associated Prayer: ${PrayerUtils.getAssociatedPrayer(taskTime, widget.prayerTimes, sunnahTimes)}");

      List<Map<String, dynamic>> records = await dbHelper.queryDatabase();
      print(records);

      await dbHelper.insertRecord({
        'id': records.length + 1,
        'task': _taskController.text,
        'time': _formatTime(taskTime),
        'associatedPrayer': associatedPrayer,
        'daysOfWeek':
            _selectedDays.join(','), // Store days as a comma-separated string
      });

      widget.onAddTask(_taskController.text, taskTime);
      setState(() {
        _taskController.clear();
        _selectedTime = TimeOfDay.now();
        _selectedDays.clear();
      });

      Navigator.pop(context);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime); // 24-hour format
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            'Add Task',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: _taskController,
            decoration: InputDecoration(
              labelText: 'Task Title',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Text('Time: ${_formatTime(DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                ))}'),
              ),
              IconButton(
                icon: Icon(Icons.access_time),
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
                },
              ),
            ],
          ),
          SizedBox(height: 16.0),
          Wrap(
            spacing: 5.0,
            runSpacing: 5.0,
            children: _daysOfWeek.map((day) {
              return ChoiceChip(
                showCheckmark: false,
                label: Text(day.substring(0, 1)),
                selected: _selectedDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
                shape: CircleBorder(),
              );
            }).toList(),
          ),
          ElevatedButton(
              onPressed: () {
                print('The Selected Time is: ${_selectedTime.format(context)}');
                print("Associated Prayer is: ${PrayerUtils.getAssociatedPrayer(
                  DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ),
                  widget.prayerTimes,
                  sunnahTimes,
                )}");
              },
              child: Text("Check time")),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: _submit,
            child: Text('Add Task'),
          ),
        ],
      ),
    );
  }
}
