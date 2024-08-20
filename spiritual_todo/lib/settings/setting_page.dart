import 'dart:ffi';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:pixelarticons/pixel.dart';
import 'package:spiritual_todo/Home%20Screen/main_screen.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      
        title: Text('Settings', style: GoogleFonts.pixelifySans()),
        leading: GestureDetector(
            onTap: () {
              Navigator.pop(context,
                  PageTransition(type: PageTransitionType.fade, child: MainScreen()));
            },
            child: Icon(Pixel.arrowleft)),
      ),
      body: ListView(
        children: [
          ListTile(
              leading: const Icon(Pixel.lock),
              title:  Text('Account and Privacy', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
           ) ),
              subtitle:  Text('Privacy and Security', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
           )),
              onTap: () {}),
          ExpansionTileCard(
            leading: const Icon(Pixel.fillhalf),
            title:  Text('Themes', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,)),
            subtitle:  Text('Theme, wallpapers'
            , style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
            children: [
              ListTile(
                title: Text('Theme Mode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                subtitle: Text('Light, Dark, System Default',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: () {
                    // AdaptiveTheme.of(context).toggleThemeMode();
                  },
                ),
              ),
            ],
          ),
          ExpansionTileCard(
            leading: const Icon(Pixel.notification),
            title: Text(
              'Notifications',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text('Daily Reminders',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            children: [
              ListTile(
                subtitle: const Text('Remind me to write daily at'),
                // trailing: Text(savedNotificationTime ?? 'Not set'),
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Pixel.inbox),
            title: const Text('Help'),
            subtitle: const Text('Community and Support'),
            onTap: () {
              // Navigate to Help settings
            },
          ),
          ListTile(
            leading: const Icon(Pixel.userplus),
            title: const Text('Invite a friend'),
            onTap: () {
              // Navigate to Invite a friend settings
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
