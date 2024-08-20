import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spiritual_todo/Models/prayer_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  final String dbName;
  final int dbVersion;
  final String dbTable;
  final String columnId;
  final String columnName;
  final String columnTime;
  final String columnAssociatedPrayer;
  final String columnDaysOfWeek;

  final StreamController<List<Map<String, dynamic>>> _streamController =
      StreamController.broadcast();

  DatabaseHelper({
    required this.dbName,
    required this.dbVersion,
    required this.dbTable,
    required this.columnId,
    required this.columnName,
    required this.columnTime,
    required this.columnAssociatedPrayer,
    required this.columnDaysOfWeek,
  }) {
    _init();
  }

  Future<Database> get database async {
    return openDatabase(
      join(await getDatabasesPath(), dbName),
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _init() async {
    try {
      final db = await database;
      final records = await db.query(dbTable);
      _streamController.add(records);
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  // Future<void> _notifyChange() async {
  //   try {
  //     final db = await database;
  //     final records = await db.query(dbTable);
  //     _streamController.add(records);
  //   } catch (e) {
  //     print('Error notifying change: $e');
  //   }
  // }

  Stream<List<Map<String, dynamic>>> get stream => _streamController.stream;

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
        CREATE TABLE $dbTable (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnName TEXT NOT NULL,
          $columnTime TEXT,
          $columnAssociatedPrayer TEXT,
          $columnDaysOfWeek TEXT
        )
      ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      if (oldVersion < 2) {
        await db.execute('''
            ALTER TABLE $dbTable ADD COLUMN $columnDaysOfWeek TEXT
          ''');
      }
    }
  }

  Stream<List<TaskHelper>> getTasksStream() async* {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('TaskTable');
    final tasks = maps.map((map) => TaskHelper.fromMap(map)).toList();
    tasks.sort((a, b) {
      DateTime now = DateTime.now();
      DateTime aUpcoming = a.getUpcomingDateTime(now);
      DateTime bUpcoming = b.getUpcomingDateTime(now);
      return aUpcoming.compareTo(bUpcoming);
    });
    yield tasks;
  }

  Future<void> deleteDatabase(String s) async {
    final path = await getDatabasesPath();
    await deleteDatabase('$path/$dbName');
  }

  Future<int> insertRecord(Map<String, dynamic> row) async {
    final db = await database;
    int id = await db.insert(dbTable, row);
    print('Inserted record: $row with ID: $id');
    // _notifyChange();
    return id;
  }

  Future<List<Map<String, dynamic>>> queryDatabase() async {
    final db = await database;
    final result = await db.query(dbTable);
    return result;
  }

  Future<Object> getMaxId() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as maxId FROM $dbTable');
    if (result.isNotEmpty) {
      return result.first['maxId'] ?? 0;
    }
    return 0;
  }

  Future<int> updateRecord(Map<String, dynamic> row) async {
    print("Updating record with: $row"); // Debugging print
    final db = await database;
    return await db.update(dbTable, row,
        where: '$columnId = ?', whereArgs: [row[columnId]]);
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    int result =
        await db.delete(dbTable, where: '$columnId = ?', whereArgs: [id]);
    // _notifyChange(); // Notify stream of changes
    return result;
  }

  Future<Map<String, dynamic>?> getTask(int id) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      dbTable,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  void dispose() {
    _streamController.close();
  }

  Future<int> countTasksForPrayer(String prayerLabel) async {
    final db = await database;
    final normalizedPrayerLabel = prayerLabel.replaceAll("'", "").toLowerCase();

    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $dbTable WHERE LOWER($columnAssociatedPrayer) = ?',
      [normalizedPrayerLabel],
    ));

    return count ?? 0;
  }
}

class PrayerTimesDatabaseHelper {
  final String dbName = 'prayer_times.db';
  final int dbVersion = 3; // Increment version to trigger upgrade
  final String dbTablePrayerTimes = 'prayer_times';
  final String dbTableCoordinates = 'coordinates';

  // Columns for prayer_times table
  final String columnId = 'id';
  final String columnDate = 'date';
  final String columnFajr = 'fajr';
  final String columnSunrise = 'sunrise';
  final String columnDhuhr = 'dhuhr';
  final String columnAsr = 'asr';
  final String columnMaghrib = 'maghrib';
  final String columnIsha = 'isha';
  final String columnMidnight = 'midnight';
  final String columnLatitude = 'latitude'; // Added for coordinates
  final String columnLongitude = 'longitude'; // Added for coordinates

  // Columns for coordinates table
  final String columnIdCoord = 'id';
  final String columnLatitudeCoord = 'latitude';
  final String columnLongitudeCoord = 'longitude';

  final StreamController<List<Map<String, dynamic>>> _streamController =
      StreamController.broadcast();

  PrayerTimesDatabaseHelper() {
    _init();
  }

  Future<Database> get database async {
    return openDatabase(
      join(await getDatabasesPath(), dbName),
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _init() async {
    try {
      final db = await database;
      final records = await db.query(dbTablePrayerTimes);
      print('Fetched initial records: $records');
      _streamController.add(records);
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
          CREATE TABLE $dbTablePrayerTimes (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnDate TEXT NOT NULL,
            $columnFajr TEXT,
            $columnSunrise TEXT,
            $columnDhuhr TEXT,
            $columnAsr TEXT,
            $columnMaghrib TEXT,
            $columnIsha TEXT,
            $columnMidnight TEXT,
            $columnLatitude REAL,  -- Add new columns
            $columnLongitude REAL  -- Add new columns
          )
        ''');

      await db.execute('''
          CREATE TABLE $dbTableCoordinates (
            $columnIdCoord INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnLatitudeCoord REAL NOT NULL,
            $columnLongitudeCoord REAL NOT NULL
          )
        ''');
      print('Database tables created successfully.');
    } catch (e) {
      print('Error creating database tables: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      if (oldVersion < 3) {
        await db.execute('''
            ALTER TABLE $dbTablePrayerTimes
            ADD COLUMN $columnLatitude REAL
          ''');
        await db.execute('''
            ALTER TABLE $dbTablePrayerTimes
            ADD COLUMN $columnLongitude REAL
          ''');
      }
    }
  }

  Future<int> insertPrayerTimes(Map<String, dynamic> row) async {
    try {
      final db = await database;
      int id = await db.insert(dbTablePrayerTimes, row);
      print('Inserted prayer times: $row with ID: $id');
      _notifyChange(); // Notify stream of changes
      return id;
    } catch (e) {
      print('Error inserting prayer times: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> queryPrayerTimes() async {
    try {
      final db = await database;
      final result = await db.query(dbTablePrayerTimes);
      print('Queried prayer times: $result');
      return result;
    } catch (e) {
      print('Error querying prayer times: $e');
      return [];
    }
  }

  Future<int> updatePrayerTimes(Map<String, dynamic> row) async {
    try {
      final db = await database;
      int id = row[columnId];
      int result = await db.update(dbTablePrayerTimes, row,
          where: '$columnId = ?', whereArgs: [id]);
      print('Updated prayer times with ID: $id');
      _notifyChange(); // Notify stream of changes
      return result;
    } catch (e) {
      print('Error updating prayer times: $e');
      return 0;
    }
  }

  Future<int> deletePrayerTimes(int id) async {
    try {
      final db = await database;
      int result = await db
          .delete(dbTablePrayerTimes, where: '$columnId = ?', whereArgs: [id]);
      print('Deleted prayer times with ID: $id');
      _notifyChange(); // Notify stream of changes
      return result;
    } catch (e) {
      print('Error deleting prayer times: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getPrayerTimes(int id) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        dbTablePrayerTimes,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        print('Fetched prayer times with ID: $id: ${maps.first}');
        return maps.first;
      }
      print('No prayer times found with ID: $id');
      return null;
    } catch (e) {
      print('Error fetching prayer times with ID: $id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPrayerTimesByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      dbTablePrayerTimes, // Table name
      where: 'date = ?',
      whereArgs: [date],
    );

    if (result.isNotEmpty) {
      print("Fetched prayer times from database: ${result.first}");
      return result.first;
    }
    print("No prayer times found for date $date");
    return null;
  }

  Future<void> insertCoordinates(double latitude, double longitude) async {
    final db = await database;
    await db.insert(
      dbTableCoordinates, // Use dbTableCoordinates for consistency
      {'latitude': latitude, 'longitude': longitude},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("Coordinates inserted: Latitude=$latitude, Longitude=$longitude");
  }

  Future<Coordinates?> getStoredCoordinates() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query(dbTableCoordinates);
      if (maps.isNotEmpty) {
        final coordinates = Coordinates(
          maps.first[columnLatitudeCoord],
          maps.first[columnLongitudeCoord],
        );
        print('Fetched stored coordinates: $coordinates');
        return coordinates;
      }
      print('No stored coordinates found.');
      return null;
    } catch (e) {
      print('Error fetching stored coordinates: $e');
      return null;
    }
  }

  void _notifyChange() async {
    final db = await database;
    final records = await db.query(dbTablePrayerTimes);
    _streamController.add(records);
  }

  Stream<List<Map<String, dynamic>>> get stream => _streamController.stream;

  void dispose() {
    _streamController.close();
  }
}
