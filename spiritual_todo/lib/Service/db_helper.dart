import 'dart:async';
import 'package:path_provider/path_provider.dart';
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
    final db = await database;
    // Fetch initial data and broadcast to the stream
    final records = await db.query(dbTable);
    _streamController.add(records);
  }

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

  Future<void> deleteDatabase(String s) async {
    final path = await getDatabasesPath();
    await deleteDatabase('$path/$dbName');
  }

  Future<int> insertRecord(Map<String, dynamic> row) async {
    final db = await database;
    int id = await db.insert(dbTable, row);
    _notifyChange(); // Notify stream of changes
    return id;
  }

  Future<List<Map<String, dynamic>>> queryDatabase() async {
    final db = await database;
    final result = await db.query(dbTable);
    return result;
  }

  Future<int> updateRecord(Map<String, dynamic> row) async {
    final db = await database;
    int id = row[columnId];
    int result =
        await db.update(dbTable, row, where: '$columnId = ?', whereArgs: [id]);
    _notifyChange(); // Notify stream of changes
    return result;
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    int result =
        await db.delete(dbTable, where: '$columnId = ?', whereArgs: [id]);
    _notifyChange(); // Notify stream of changes
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

  void _notifyChange() async {
    final db = await database;
    final records = await db.query(dbTable);
    _streamController.add(records);
  }

  Stream<List<Map<String, dynamic>>> get stream => _streamController.stream;

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
