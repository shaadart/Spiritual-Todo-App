import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_grid_view.dart';
import 'package:staggered_grid_view_flutter/widgets/staggered_tile.dart';

import '../Models/prayer_model.dart';
import '../Service/db_helper.dart';
import '../Todo/add_todo.dart';
import '../Todo/prayer_details.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Coordinates coordinates =
      Coordinates(21.2588, 81.6290); // Replace with your coordinates
  final params = CalculationMethod.karachi.getParameters();
  late PrayerTimes prayerTimes;
  late final sunnahTimes = SunnahTimes(prayerTimes);

  late DateTime currentTime;
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

  // void _showAddTaskSheet() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) {
  //       return AddTaskSheet(
  //         onAddTask: (title, time) {
  //           setState(() {
  //             // Update tasks list or state
  //           });
  //         },
  //         prayerTimes: prayerTimes,
  //       );
  //     },
  //   );
  // }

  @override
  void initState() {
    super.initState();
    _updatePrayerTimes();
    // print('Midnight Time: ${sunnahTimes.lastThirdOfTheNight}');
  }

  void _updatePrayerTimes() {
    setState(() {
      prayerTimes = PrayerTimes.today(coordinates, params);
      currentTime = DateTime.now();
    });
    print("""
    All prayer times: 
    Fajr: ${prayerTimes.fajr}
    Sunrise: ${prayerTimes.sunrise}
    Dhuhr: ${prayerTimes.dhuhr}
    Asr: ${prayerTimes.asr}
    Maghrib: ${prayerTimes.maghrib}
    Isha: ${prayerTimes.isha}
    Midnight: ${sunnahTimes.lastThirdOfTheNight}
    """);
  }

  Future<int> _getTaskCountForPrayer(String prayerLabel) async {
    return await dbHelper.countTasksForPrayer(prayerLabel);
  }

  @override
  Widget build(BuildContext context) {
    final List<PrayerTime> prayerTimesList = [
      PrayerTime('Fajr', prayerTimes.fajr),
      PrayerTime('Sunrise', prayerTimes.sunrise),
      PrayerTime('Dhuhr', prayerTimes.dhuhr),
      PrayerTime('Asr', prayerTimes.asr),
      PrayerTime('Maghrib', prayerTimes.maghrib),
      PrayerTime('Isha', prayerTimes.isha),
      PrayerTime('Midnight', sunnahTimes.lastThirdOfTheNight), // Add Midnight
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage(
                'https://avatars.githubusercontent.com/u/47231161?v=4'),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Spiritual Todo',
          style: GoogleFonts.pixelifySans(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
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
                  final isActive = prayer.time.isBefore(currentTime) &&
                      prayer.time
                          .add(Duration(minutes: 30))
                          .isAfter(currentTime);

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
                                fontSize: isActive ? 14 : 10,
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
