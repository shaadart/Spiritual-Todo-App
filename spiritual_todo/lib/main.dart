import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Home Screen/main_screen.dart';

void main() {
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
     
        brightness: Brightness.light,
        fontFamily: GoogleFonts.notoSansHanifiRohingya().fontFamily,
        // colorSchemeSeed: Color(0xff6BBF59),
        colorSchemeSeed: Color(0xff3454D1),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}
