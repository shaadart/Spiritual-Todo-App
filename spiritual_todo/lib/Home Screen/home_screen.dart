import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spiritual_todo/Models/prayer_model.dart';
import 'package:spiritual_todo/Todo/premium_page.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_grid_view.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_tile.dart';
import '../Service/db_helper.dart';

import '../Todo/prayer_details.dart';
import '../settings/setting_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Coordinates? _currentCoordinates;
  PrayerTimes? prayerTimes;
  SunnahTimes? sunnahTimes;
  late DateTime currentTime;
  final PrayerTimesDatabaseHelper prayerDbHelper = PrayerTimesDatabaseHelper();
  final DatabaseHelper dbHelper = DatabaseHelper(
    dbName: "userDatabase.db",
    dbVersion: 3,
    dbTable: "TaskTable",
    columnId: 'id',
    columnName: 'task',
    columnTime: 'time',
    columnAssociatedPrayer: 'associatedPrayer',
    columnDaysOfWeek: 'daysOfWeek',
  );
  Future<void> _initializeCoordinates() async {
    final permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentCoordinates = Coordinates(position.latitude, position.longitude);
        });
        await _fetchPrayerTimes(); // Ensure this completes
      } catch (e) {
        print('Error fetching coordinates: $e');
      }
    } else {
      print('Location permission denied.');

    }
  }
  PrayerTime? _closestPrayerTime;

  @override
  void initState() {
    super.initState();
    _initializeCoordinates();
  }

  Future<void> _fetchPrayerTimes() async {
    if (_currentCoordinates == null) {
      print('Error: Current coordinates are not set.');
      _initializeCoordinates();

      return;
    }

    print("Fetching prayer times...");

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final storedPrayerTimes = await prayerDbHelper.getPrayerTimesByDate(today);

    if (storedPrayerTimes != null) {
      double? latitude = storedPrayerTimes['latitude'];
      double? longitude = storedPrayerTimes['longitude'];

      if (latitude == null || longitude == null) {
        print("Error: Latitude or Longitude is null.");
        _initializeCoordinates();
        return;
      }

      _currentCoordinates = Coordinates(latitude, longitude);

      var dateComponents = DateComponents.from(DateTime.now());
      final calculationParameters =
          CalculationMethod.muslim_world_league.getParameters();
      calculationParameters.madhab = Madhab.shafi;

      setState(() {
        prayerTimes = PrayerTimes(
            _currentCoordinates!, dateComponents, calculationParameters);
        sunnahTimes = SunnahTimes(prayerTimes!);
        currentTime = DateTime.now();

        // currentTime = DateTime(DateTime.now().year, DateTime.now().month,
        //     DateTime.now().day, 4, 17);
      });
    } else {
      print("No prayer times found for today. Fetching new times.");

      if (_currentCoordinates == null) {
        print('Error: Current coordinates are not set.');
        _initializeCoordinates();
        return;
      }

      final fetchedPrayerTimes = PrayerTimes.today(
        _currentCoordinates!,
        CalculationMethod.karachi.getParameters(),
      );

      sunnahTimes = SunnahTimes(fetchedPrayerTimes);
      await prayerDbHelper.insertPrayerTimes({
        'date': today,
        'fajr': fetchedPrayerTimes.fajr.toIso8601String(),
        'sunrise': fetchedPrayerTimes.sunrise.toIso8601String(),
        'dhuhr': fetchedPrayerTimes.dhuhr.toIso8601String(),
        'asr': fetchedPrayerTimes.asr.toIso8601String(),
        'maghrib': fetchedPrayerTimes.maghrib.toIso8601String(),
        'isha': fetchedPrayerTimes.isha.toIso8601String(),
        'midnight': sunnahTimes!.lastThirdOfTheNight.toIso8601String(),
        'latitude': _currentCoordinates?.latitude ?? 0.0,
        'longitude': _currentCoordinates?.longitude ?? 0.0,
      });

      setState(() {
        prayerTimes = fetchedPrayerTimes;
        currentTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
      });
    }

    // Set the closest prayer time
    setState(() {
      _closestPrayerTime = _findAssociatedPrayerTime();
    });
  }

  PrayerTime? _findAssociatedPrayerTime() {
    if (prayerTimes == null || sunnahTimes == null) return null;

    final associatedPrayerLabel = PrayerUtils.getAssociatedPrayer(
      DateTime.now(),
      prayerTimes!,
      sunnahTimes!,
    );

    final List<PrayerTime> prayerTimesList = [
      PrayerTime('Fajr', prayerTimes!.fajr),
      PrayerTime('Sunrise', prayerTimes!.sunrise),
      PrayerTime('Dhuhr', prayerTimes!.dhuhr),
      PrayerTime('Asr', prayerTimes!.asr),
      PrayerTime('Maghrib', prayerTimes!.maghrib),
      PrayerTime('Isha', prayerTimes!.isha),
      PrayerTime('Last Night', sunnahTimes!.lastThirdOfTheNight),
    ];

    return prayerTimesList.firstWhere(
      (prayer) => prayer.label == associatedPrayerLabel,
      orElse: () => PrayerTime('None', DateTime.now()), // Fallback
    );
  }

  void _showPrayerDetailsDialog(PrayerTime prayer) async {
    // Fetch all tasks from the database
    final records = await dbHelper.queryDatabase();
    final allTasks = records.map((map) => TaskHelper.fromMap(map)).toList();

    // Filter tasks associated with the selected prayer
    final tasksForPrayer = allTasks
        .where((task) =>
            task.associatedPrayer.replaceAll("'", "").toLowerCase() ==
            prayer.label.replaceAll("'", "").toLowerCase())
        .toList();

    // Show the dialog with filtered tasks
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          child: PrayerDetailsScreen(
            prayer: prayer,
            tasks: tasksForPrayer,
          ),
        );
      },
    );
  }

  void _showPremiumPageDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        
        return Dialog(
          insetAnimationCurve: Curves.linear,
          insetAnimationDuration: Duration(milliseconds: 1000),
          insetPadding: EdgeInsets.zero,
          child: PremiumPage(),
        );
      },
    );
  }

  List<T> rotateList<T>(List<T> list, int index) {
    if (list.isEmpty) return list;

    int n = list.length;
    index = index % n;

    return [...list.sublist(index), ...list.sublist(0, index)];
  }

  List<PrayerTime> rotateListBasedOnCurrentTime(
      List<PrayerTime> list, DateTime currentTime) {
    if (list.isEmpty) return list;

    // Find the index of the prayer time that matches the current time

// Find the index of the prayer time that matches or is closest to the current time
    int index = list.indexWhere((prayer) =>
        prayer.time.isBefore(currentTime) &&
        (prayer.time.add(Duration(minutes: 1)).isAfter(currentTime) ||
            prayer.time == currentTime));

// If no prayer time matches or is closest, start from the beginning
    if (index == -1) {
      // Find the closest prayer time to the current time
      index = list.indexWhere((prayer) => prayer.time.isAfter(currentTime));

      // If no future prayer time is found, fallback to the last prayer time
      if (index == -1) index = list.length - 1;
    }

// In case the index is still -1, ensure it defaults to 0
    if (index < 0) index = 0;

// Output the result for debugging
    print('Index: $index');

    print('Current Time: ${DateFormat.jm().format(currentTime)}');
    print('Rotating from index: $index');

    return rotateList(list, index - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCoordinates == null) {
      _initializeCoordinates();

      return Center(child: Text('Error: Current coordinates are not set.'));
    }

    if (prayerTimes == null || sunnahTimes == null) {
      return Center(child: CircularProgressIndicator());
    }

    final List<PrayerTime> prayerTimesList = [
      PrayerTime('Fajr', prayerTimes!.fajr),
      PrayerTime('Sunrise', prayerTimes!.sunrise),
      PrayerTime('Dhuhr', prayerTimes!.dhuhr),
      PrayerTime('Asr', prayerTimes!.asr),
      PrayerTime('Maghrib', prayerTimes!.maghrib),
      PrayerTime('Isha', prayerTimes!.isha),
      PrayerTime('Last Night', sunnahTimes!.lastThirdOfTheNight),
    ];

    final rotatedPrayers =
        rotateListBasedOnCurrentTime(prayerTimesList, currentTime);
    print('Closest Prayer Time: ${_closestPrayerTime?.label}');
// Debug print statements
    rotatedPrayers.forEach((prayer) {
      print('${prayer.label}: ${DateFormat.jm().format(prayer.time)}');
    });
    final sizes = List<double>.generate(
        rotatedPrayers.length,
        (index) =>
            (rotatedPrayers.length - index - 0.4) / rotatedPrayers.length +
            0.2);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              _showPremiumPageDialog();
            },
            label: Text("Premium"),
            icon: Icon(Icons.star),
          ),
          Text("\t\t"),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.leftToRight,
                    child: SettingsPage(),
                  ));
            },
            child: CircleAvatar(
              backgroundImage: NetworkImage(
                  'https://avatars.githubusercontent.com/u/47231161?v=4'),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              widget.title + "\t",
              style: GoogleFonts.pixelifySans(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: StaggeredGridView.countBuilder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            itemCount: rotatedPrayers.length,
            itemBuilder: (context, index) {
              final prayer = rotatedPrayers[index];
              final isMainTile = prayer == _closestPrayerTime;
              return GestureDetector(
                onTap: () {
                  _showPrayerDetailsDialog(prayer);
                },
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  elevation: isMainTile ? 4 : 0,
                  child: ListTile(
                    title: Text(
                      prayer.label,
                      style: TextStyle(
                        fontSize: isMainTile ? 20 : 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    trailing: Text(
                      DateFormat.jm().format(prayer.time),
                      style: GoogleFonts.lato(
                        fontStyle: FontStyle.italic,
                        fontSize: isMainTile ? 16 : 12,
                      ),
                    ),
                  ),
                ),
              );
            },
            staggeredTileBuilder: (index) {
              if (index == 0) {
                return StaggeredTile.count(
                    2, 2); // Full width for the first tile
              }
              final size = sizes[index] * 2;
              if (rotatedPrayers[index] == _closestPrayerTime) {
                return StaggeredTile.count(
                    2, size); // Larger tile for closest prayer
              }
              return StaggeredTile.count(1, size);
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
        ),
      ),
    );
  }
}
