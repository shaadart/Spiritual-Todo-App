import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pixelarticons/pixel.dart';
import 'package:shimmer/shimmer.dart';
import 'package:spiritual_todo/Todo/todo_screen.dart';

import '../Models/prayer_model.dart';
import 'add_todo.dart';

class PremiumPage extends StatefulWidget {
  @override
  _PremiumPageState createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: Icon(Pixel.arrowdown),
        ),
        appBar: AppBar(
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Pixel.close)),
        ),
        body: SingleChildScrollView(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(21.0),
                child: RichText(
                  text: TextSpan(
                    text: 'Lifetime',
                    style: GoogleFonts.poppins(
                      color: 
                      ThemeData.estimateBrightnessForColor(Theme.of(context).colorScheme.onSurface) == Brightness.light
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 55,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: ' Romance with Tasks for Less Than a ',
                        style: GoogleFonts.poppins(
                          fontSize: 55,
                        ),
                      ),
                      TextSpan(
                        text: 'Notebook',
                        style: GoogleFonts.poppins(
                          fontSize: 55,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.all(21.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      children: [
                        OutlinedButton(
                          autofocus: true,
                          onPressed: () {},
                          child: Shimmer.fromColors(
                            direction: ShimmerDirection.ltr,
                            baseColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                            highlightColor:
                                Theme.of(context).colorScheme.primaryFixed,
                            child: Text(
                              "Go Premium",
                              style: GoogleFonts.poppins(
                                fontSize: 21, // Increase the font size here
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            "restore purchase",
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ));
  }
}
