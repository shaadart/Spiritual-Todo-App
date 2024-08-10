import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spiritual_todo/Todo/premium_page.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_grid_view.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_tile.dart';

import '../Models/prayer_model.dart';
import '../Service/db_helper.dart';
import '../Todo/add_todo.dart';
import '../Todo/prayer_details.dart';

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

  void _showPrayerDetailsDialog(PrayerTime prayer) async {
    final records = await dbHelper.queryDatabase();
    final allTasks = records.map((map) => TaskHelper.fromMap(map)).toList();

    final tasksForPrayer = allTasks
        .where((task) =>
            task.associatedPrayer.replaceAll("'", "").toLowerCase() ==
            prayer.label.replaceAll("'", "").toLowerCase())
        .toList();

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
          insetPadding: EdgeInsets.zero,
          child: PremiumPage(),
        );
      },
    );
  }

Future<void> _initializeCoordinates() async {
  // Request location permissions
  final permissionStatus = await Permission.location.request();

  if (permissionStatus.isGranted) {
    try {
      // Fetch current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentCoordinates = Coordinates(position.latitude, position.longitude);
      });

      // Fetch prayer times
      await _fetchPrayerTimes();
    } catch (e) {
      print('Error fetching coordinates: $e');
    }
  } else {
    print('Location permission denied.');
  }
}
@override
void initState() {
  super.initState();
  _initializeCoordinates();
}
  Future<void> _fetchPrayerTimes() async {

    if (_currentCoordinates == null) {
      print('Error: Current coordinates are not set.');
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
        return;
      }

      // Update _currentCoordinates
      _currentCoordinates = Coordinates(latitude, longitude);
      print(
          'Updated Coordinates: Latitude=${_currentCoordinates?.latitude}, Longitude=${_currentCoordinates?.longitude}');

      // Debug: Verify coordinates immediately after setting
      print(
          'Coordinates immediately after setting: Latitude=${_currentCoordinates?.latitude}, Longitude=${_currentCoordinates?.longitude}');

      var dateComponents = DateComponents.from(DateTime.now());
      final calculationParameters =
          CalculationMethod.muslim_world_league.getParameters();
      calculationParameters.madhab = Madhab.shafi;

      setState(() {
        prayerTimes = PrayerTimes(
            _currentCoordinates!, dateComponents, calculationParameters);
        sunnahTimes = SunnahTimes(prayerTimes!);
        currentTime = DateTime.now();
      });
    } else {
      print("No prayer times found for today. Fetching new times.");

      if (_currentCoordinates == null) {
        print('Error: Current coordinates are not set.');
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
        currentTime = DateTime.now();
      });
    }
  }

  void _updatePrayerTimes() {
    if (_currentCoordinates == null) {
      print('Error: Current coordinates are not set.');
      return;
    }

    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;

    try {
      setState(() {
        prayerTimes = PrayerTimes.today(_currentCoordinates!, params);
        sunnahTimes = SunnahTimes(prayerTimes!);
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
      Midnight: ${sunnahTimes!.lastThirdOfTheNight}
      """);
    } catch (e) {
      print('Error updating prayer times: $e');
    }
  }

  Future<int> _getTaskCountForPrayer(String prayerLabel) async {
    return await dbHelper.countTasksForPrayer(prayerLabel);
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Current Coordinates: Latitude=${_currentCoordinates?.latitude}, Longitude=${_currentCoordinates?.longitude}');

    if (_currentCoordinates == null) {
      // Handle the case where coordinates are not set
      return Center(child: Text('Error: Current coordinates are not set.'));
    }

    if (prayerTimes == null || sunnahTimes == null) {
      // Show a loading spinner or an error message
      return Center(child: CircularProgressIndicator());
    }

    final List<PrayerTime> prayerTimesList = [
      PrayerTime('Fajr', prayerTimes!.fajr),
      PrayerTime('Sunrise', prayerTimes!.sunrise),
      PrayerTime('Dhuhr', prayerTimes!.dhuhr),
      PrayerTime('Asr', prayerTimes!.asr),
      PrayerTime('Maghrib', prayerTimes!.maghrib),
      PrayerTime('Isha', prayerTimes!.isha),
      PrayerTime('Midnight', sunnahTimes!.lastThirdOfTheNight),
    ];

    // Sort prayers based on their proximity to the current time
    prayerTimesList.sort((a, b) {
      final diffA = (a.time.isBefore(currentTime))
          ? currentTime.difference(a.time).inMinutes
          : a.time.difference(currentTime).inMinutes;
      final diffB = (b.time.isBefore(currentTime))
          ? currentTime.difference(b.time).inMinutes
          : b.time.difference(currentTime).inMinutes;
      return diffA.compareTo(diffB);
    });

    // Get the 6 most recent prayers
    final recentPrayers = prayerTimesList.take(7).toList();

    // Determine the size based on chronological order
    // Adjust the prayer sizes
    final Map<String, double> prayerSizes = {
      'Isha': 1.6,
      'Midnight': 1.8,
      'Fajr': 1.4,
      'Sunrise': 1.2,
      'Dhuhr': 1.0,
      'Asr': 0.8,
      'Maghrib': 0.6,
    };

    // Reorder sizes based on the current prayer
    final currentPrayer = recentPrayers.first.label;
    final orderedPrayers = [
      'Isha',
      'Midnight',
      'Fajr',
      'Sunrise',
      'Dhuhr',
      'Asr',
      'Maghrib'
    ];

    final sortedPrayerSizes = Map.fromEntries(
      orderedPrayers.asMap().entries.map((entry) {
        final index = (orderedPrayers.indexOf(currentPrayer) + entry.key) %
            orderedPrayers.length;
        return MapEntry(orderedPrayers[index],
            prayerSizes[orderedPrayers[entry.key]] ?? 1.0);
      }),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        actions: [
          OutlinedButton.icon(
              onPressed: () {
                _showPremiumPageDialog();
              },
              label: Text("Premium"),
              icon: Icon(Icons.star)),
          Text("\t\t"),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage(
                'https://avatars.githubusercontent.com/u/47231161?v=4'),
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
            // Text(
            //   " premium",
            //   style: GoogleFonts.pixelifySans(
            //     fontSize: 13,
            //     fontStyle: FontStyle.italic,
            //     color: Theme.of(context).colorScheme.secondary,
            //   ),
            // ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: FutureBuilder(
            future: Future.wait(recentPrayers
                .map((prayer) => _getTaskCountForPrayer(prayer.label))
                .toList()),
            builder: (context, AsyncSnapshot<List<int>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final taskCounts =
                  snapshot.data ?? List.filled(recentPrayers.length, 0);

              return StaggeredGridView.countBuilder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                itemCount: recentPrayers.length,
                itemBuilder: (context, index) {
                  final prayer = recentPrayers[index];
                  // final isActive = prayer.time.isBefore(currentTime) &&
                  //     prayer.time
                  //         .add(Duration(minutes: 30))
                  //         .isAfter(currentTime);

                  final taskCount = taskCounts[index];

                  return GestureDetector(
                    onTap: () => _showPrayerDetailsDialog(prayer),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      elevation: 0,
                      child: ListTile(
                        title: Text(
                          prayer.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        trailing: Text(
                          DateFormat.jm().format(prayer.time),
                          style: GoogleFonts.lato(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            // Icon(Icons.check, size: 16),
                            // SizedBox(width: 4),
                            Text(
                              '${taskCount} tasks',
                              style: TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                staggeredTileBuilder: (index) {
                  final prayer = recentPrayers[index];
                  final size = sortedPrayerSizes[prayer.label] ?? 1.0;

                  if (index == 0) {
                    return StaggeredTile.count(
                        2, 2); // Full width for the 0th index
                  } else {
                    return StaggeredTile.count(1, size);
                  }
                },
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              );
            },
          ),
        ),
      ),
    );
  }
}
