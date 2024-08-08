import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:adhan/adhan.dart';
import '../Todo/add_todo.dart';
import '../Todo/todo_screen.dart';
import 'home_screen.dart'; // Import your HomeScreen

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late Coordinates _currentCoordinates; // Holds current coordinates
  late PrayerTimes prayerTimes;
  late final sunnahTimes;

  late DateTime currentTime;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _updatePrayerTimes();
  }

  Future<void> _initLocation() async {
    // Request location permission if not granted
    if (await Permission.location.request().isGranted) {
      // Get current location coordinates
      final location = await Geolocator.getCurrentPosition();
      setState(() {
        _currentCoordinates =
            Coordinates(location.latitude, location.longitude);
        prayerTimes = PrayerTimes.today(
            _currentCoordinates, CalculationMethod.karachi.getParameters());
        sunnahTimes = SunnahTimes(prayerTimes);
      });
    }
  }

  void _updatePrayerTimes() {
    setState(() {
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return AddTaskSheet(
          onAddTask: (title, time) {
            setState(() {
              // Update tasks list or state
            });
          },
          prayerTimes: prayerTimes,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        shape: CircleBorder(),
        elevation: 0.3,
        onPressed: _showAddTaskSheet,
        child: Icon(Icons.add),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          HomeScreen(),
          TodoScreen(),
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: ('Home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rounded),
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
