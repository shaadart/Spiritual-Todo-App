import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler

import '../Models/prayer_model.dart';

Future<void> scheduleNotification(TaskHelper task) async {
  // Check permissions before scheduling
  var status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
    status = await Permission.notification.status;
    if (!status.isGranted) {
      print("Notification permission not granted.");
      return;
    }
  }

  DateTime upcomingDateTime = task.getUpcomingDateTime(DateTime.now());
  int taskHour = upcomingDateTime.hour;
  int taskMinute = upcomingDateTime.minute;

  NotificationContent notificationContent = NotificationContent(
    id: task.id,
    channelKey: 'basic_channel',
    body: 'Reminder',
    title: task.title,
    autoDismissible: true,
    displayOnForeground: true,
    displayOnBackground: true,
    wakeUpScreen: true,
    fullScreenIntent: true,
    payload: {
      'associatedPrayer': task.associatedPrayer,
      'daysOfWeek': task.daysOfWeek.join(','),
    },
  );

  try {
    if (task.daysOfWeek.isEmpty) {
      // One-time notification
      await AwesomeNotifications().createNotification(
        content: notificationContent,
        schedule: NotificationCalendar(
          year: upcomingDateTime.year,
          month: upcomingDateTime.month,
          day: upcomingDateTime.day,
          hour: taskHour,
          minute: taskMinute,
     
        ),
      );
      print("Scheduling one-time notification for ${_formatDate(upcomingDateTime)} at $taskHour:$taskMinute");
    } else {
      // Weekly notifications
      for (String day in task.daysOfWeek) {
        int dayOfWeek = _convertDayToInt(day);

        await AwesomeNotifications().createNotification(
          content: notificationContent,
          schedule: NotificationCalendar(
            hour: taskHour,
            minute: taskMinute,
            second: 0,
            millisecond: 0,
            repeats: true,
            weekday: dayOfWeek,
          ),
        );
        print("Scheduling weekly notification for $day at $taskHour:$taskMinute");
      }
    }
  } catch (e) {
    print("Error scheduling notification: $e");
  }
}

// Convert day abbreviation to int (1 = Monday, 7 = Sunday)
int _convertDayToInt(String day) {
  const days = {
    'SUN': 7,
    'MON': 1,
    'TUE': 2,
    'WED': 3,
    'THU': 4,
    'FRI': 5,
    'SAT': 6,
  };
  return days[day] ?? 1; // Default to Monday if the day is not found
}

String _formatDate(DateTime dateTime) {
  return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}
