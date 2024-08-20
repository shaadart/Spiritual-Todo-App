import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spiritual_todo/Service/background_task.dart';
import 'package:workmanager/workmanager.dart';
import 'Home Screen/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    '1',
    'updatePrayerTimesTask',
    frequency: Duration(minutes: 15),
  );
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Todo Notifications',
        channelDescription:
            'Notification channel for daily or weekly todo notification',
        defaultColor: Color.fromARGB(255, 34, 0, 255),
        ledColor: Colors.white,
        enableVibration: true,
        playSound: true,
         importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Public,
        channelShowBadge: true,
        enableLights: true,
      )
    ],
    debug: true,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(TextTheme(
          bodySmall:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        )),
        //   colorSchemeSeed: Color(0xff6BBF59),
        colorSchemeSeed: Color(0xff164300),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}
