import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:adhan/adhan.dart';
import 'package:pixelarticons/pixel.dart';
import 'package:spiritual_todo/Service/db_helper.dart';
import '../Models/prayer_model.dart';
import '../Todo/add_todo.dart';
import '../Todo/todo_screen.dart';
import 'home_screen.dart'; // Import your HomeScreen

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Coordinates? _currentCoordinates;
  late PrayerTimes prayerTimes;
  late final SunnahTimes sunnahTimes;
  late DateTime currentTime;
  final PrayerTimesDatabaseHelper dbHelper = PrayerTimesDatabaseHelper();
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

  @override
  void initState() {
    super.initState();
    // _loadTasks();
    _initLocation();
  }

  void _initLocation() async {
    if (await Permission.location.request().isGranted) {
      final location = await Geolocator.getCurrentPosition();
      final coordinates = Coordinates(location.latitude, location.longitude);

      await dbHelper.insertCoordinates(
          coordinates.latitude, coordinates.longitude);

      setState(() {
        _currentCoordinates = coordinates;
        _loadPrayerTimes();
      });
    } else {
      print("Location permission denied.");
    }
  }

  Future<void> _loadPrayerTimes() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final storedPrayerTimes = await dbHelper.getPrayerTimesByDate(today);

    if (storedPrayerTimes != null) {
      print("Fetched prayer times from database: $storedPrayerTimes");

      double? latitude = storedPrayerTimes['latitude'];
      double? longitude = storedPrayerTimes['longitude'];

      if (latitude == null || longitude == null) {
        print("Error: Latitude or Longitude is null.");
        // Handle missing coordinates case here
        // For example, set a default or prompt user to input coordinates
        return;
      }

      var coordinates = Coordinates(latitude, longitude);
      var dateComponents = DateComponents.from(DateTime.now());
      final calculationParameters =
          CalculationMethod.muslim_world_league.getParameters();
      calculationParameters.madhab = Madhab.shafi;

      setState(() {
        prayerTimes =
            PrayerTimes(coordinates, dateComponents, calculationParameters);
        sunnahTimes = SunnahTimes(prayerTimes!);
        currentTime = DateTime.now();
      });
    } else {
      print("No prayer times found for today. Fetching new times.");

      final fetchedPrayerTimes = PrayerTimes.today(
        _currentCoordinates!,
        CalculationMethod.karachi.getParameters(),
      );

      sunnahTimes = SunnahTimes(fetchedPrayerTimes);
      await dbHelper.insertPrayerTimes({
        'date': today,
        'fajr': fetchedPrayerTimes.fajr.toIso8601String(),
        'sunrise': fetchedPrayerTimes.sunrise.toIso8601String(),
        'dhuhr': fetchedPrayerTimes.dhuhr.toIso8601String(),
        'asr': fetchedPrayerTimes.asr.toIso8601String(),
        'maghrib': fetchedPrayerTimes.maghrib.toIso8601String(),
        'isha': fetchedPrayerTimes.isha.toIso8601String(),
        'midnight': sunnahTimes.lastThirdOfTheNight.toIso8601String(),
        'latitude': _currentCoordinates?.latitude ?? 0.0, // Default value
        'longitude': _currentCoordinates?.longitude ?? 0.0, // Default value
      });

      setState(() {
        prayerTimes = fetchedPrayerTimes;
        currentTime = DateTime.now();
      });
    }
  }

  void _updatePrayerTimes() {
    if (prayerTimes != null) {
      setState(() {
        currentTime = DateTime.now();
      });
      print("""
      All prayer times: 
      Fajr: ${prayerTimes!.fajr}
      Sunrise: ${prayerTimes!.sunrise}
      Dhuhr: ${prayerTimes!.dhuhr}
      Asr: ${prayerTimes!.asr}
      Maghrib: ${prayerTimes!.maghrib}
      Isha: ${prayerTimes!.isha}
      Last Night: ${sunnahTimes.lastThirdOfTheNight}
      """);
    } else {
      print("Prayer times are not loaded.");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  retrieveScheduledNotifications() async {
    final AwesomeNotifications awesomeNotifications = AwesomeNotifications();
    List<NotificationModel> activeNotifications =
        await awesomeNotifications.listScheduledNotifications();
    print('Scheduled Notifications: $activeNotifications');
  }

  void _showAddTaskSheet() {
    retrieveScheduledNotifications();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return AddTaskSheet(
          onAddTask: (title, time) {
            setState(() {
              // Update tasks list or state
            });
          },
          prayerTimes: prayerTimes ??
              PrayerTimes.today(
                  _currentCoordinates!,
                  CalculationMethod.karachi
                      .getParameters()), // Handle null if needed
        );
      },
    );
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

  void _addTask(String title, DateTime time, String associatedPrayer) async {
    final newId = (await _dbHelper.getMaxId() as int) + 1;

    final newTask = TaskHelper(
      newId,
      title,
      time,
      associatedPrayer,
      [], // Initialize with empty days, can be updated later
    );

    await _dbHelper.insertRecord(newTask.toMap());
    _scheduleNotification(newTask);
    _loadTasks(); // Refresh task list
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

  @override
  Widget build(BuildContext context) {
    bool isFabVisible = true;
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        shape: CircleBorder(),
        elevation: 0.3,
        onPressed: () {
          _showAddTaskSheet();


        },
        child: Icon(Pixel.plus),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          HomeScreen(
            title: 'Spiritual Todo',
          ),
          TodoScreen(
            title: 'Todo',
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.onInverseSurface,
        unselectedFontSize: 14,
        selectedFontSize: 14,
        selectedLabelStyle:
            GoogleFonts.pixelifySans(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.pixelifySans(),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Pixel.home),
            activeIcon: Icon(Icons.home),
            label: ('Home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Pixel.checklist),
            activeIcon: Icon(Icons.checklist),
            label: ('Todo'),
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _onItemTapped(index);
          });
        },
        elevation: 3,
      ),
    );
  }
}
