import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Home Screen/home_screen.dart';
import 'Home Screen/main_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.notoSansHanifiRohingya().fontFamily,
        colorSchemeSeed: Color(0xff6BBF59),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}
