import 'dart:io';
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

  DatabaseHelper({
    required this.dbName,
    required this.dbVersion,
    required this.dbTable,
    required this.columnId,
    required this.columnName,
    required this.columnTime,
    required this.columnAssociatedPrayer,
    required this.columnDaysOfWeek,
  });

  Future<Database> get database async {
    return openDatabase(
      join(await getDatabasesPath(), dbName),
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        // Example of adding a new column
        await db.execute('''
          ALTER TABLE $dbTable ADD COLUMN $columnDaysOfWeek TEXT
        ''');
      }
      // Add other schema migrations here if needed
    }
  }

  Future<void> deleteDatabase(String s) async {
    final path = await getDatabasesPath();
    await deleteDatabase('$path/$dbName');
  }

  Future<void> initDB() async {
    await database;
  }

  Future<int> insertRecord(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(dbTable, row);
  }

  Future<List<Map<String, dynamic>>> queryDatabase() async {
    final db = await database;
    return await db.query(dbTable);
  }

  Future<int> updateRecord(Map<String, dynamic> row) async {
    final db = await database;
    int id = row[columnId];
    return await db.update(dbTable, row, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete(dbTable, where: '$columnId = ?', whereArgs: [id]);
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
