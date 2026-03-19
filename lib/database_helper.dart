import 'dart:async';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models/swimmer.dart';
import 'models/meet.dart';
import 'models/event.dart';
import 'models/qualifying_time.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static String? _testPath;

  @visibleForTesting
  static set testPath(String? path) => _testPath = path;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = _testPath ?? join(await getDatabasesPath(), 'swimpb_tracker.db');
    return await openDatabase(
      path,
      version: 7,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTablesIfNotExist(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _createTablesIfNotExist(db);
    
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE swimmers ADD COLUMN club TEXT'); } catch (_) {}
    }
    if (oldVersion < 3) {
      await _createQualifyingTimesTable(db);
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE swimmers ADD COLUMN gender TEXT'); } catch (_) {}
    }
    if (oldVersion < 7) {
      // Unify IM naming (ensuring it runs for all current users)
      await db.execute("UPDATE events SET stroke = 'IM' WHERE stroke = 'Individual Medley'");
      await db.execute("UPDATE qualifying_times SET stroke = 'IM' WHERE stroke = 'Individual Medley'");
    }
  }

  Future<void> _createTablesIfNotExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS swimmers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        surname TEXT,
        photoPath TEXT,
        dob TEXT,
        nationality TEXT,
        gender TEXT,
        club TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        date TEXT,
        course TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meetId INTEGER,
        swimmerId INTEGER,
        distance INTEGER,
        stroke TEXT,
        timeMs INTEGER,
        FOREIGN KEY (meetId) REFERENCES meets (id) ON DELETE CASCADE,
        FOREIGN KEY (swimmerId) REFERENCES swimmers (id) ON DELETE CASCADE
      )
    ''');
    await _createQualifyingTimesTable(db);
  }

  Future<void> _createQualifyingTimesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS qualifying_times(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        standardName TEXT,
        gender TEXT,
        ageMin INTEGER,
        ageMax INTEGER,
        distance INTEGER,
        stroke TEXT,
        course TEXT,
        timeMs INTEGER
      )
    ''');
  }

  // Swimmer CRUD
  Future<int> insertSwimmer(Swimmer swimmer) async {
    Database db = await database;
    return await db.insert('swimmers', swimmer.toMap());
  }

  Future<List<Swimmer>> getSwimmers() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('swimmers');
    return List.generate(maps.length, (i) => Swimmer.fromMap(maps[i]));
  }

  Future<int> updateSwimmer(Swimmer swimmer) async {
    Database db = await database;
    return await db.update(
      'swimmers',
      swimmer.toMap(),
      where: 'id = ?',
      whereArgs: [swimmer.id],
    );
  }

  Future<int> deleteSwimmer(int id) async {
    Database db = await database;
    return await db.delete(
      'swimmers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Meet CRUD
  Future<int> insertMeet(SwimMeet meet) async {
    Database db = await database;
    return await db.insert('meets', meet.toMap());
  }

  Future<List<SwimMeet>> getMeets() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('meets', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => SwimMeet.fromMap(maps[i]));
  }

  // Event CRUD
  Future<int> insertEvent(SwimEvent event) async {
    Database db = await database;
    return await db.insert(
      'events', 
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SwimEvent>> getEventsBySwimmer(int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'swimmerId = ?',
      whereArgs: [swimmerId],
    );
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<List<SwimEvent>> getEventsByMeet(int meetId, int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'meetId = ? AND swimmerId = ?',
      whereArgs: [meetId, swimmerId],
    );
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<List<SwimMeet>> getMeetsBySwimmer(int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT m.* 
      FROM meets m
      JOIN events e ON m.id = e.meetId
      WHERE e.swimmerId = ?
      ORDER BY m.date DESC
    ''', [swimmerId]);
    return List.generate(maps.length, (i) => SwimMeet.fromMap(maps[i]));
  }

  Future<List<SwimEvent>> getPBsBySwimmer(int swimmerId) async {
    Database db = await database;
    // Get the minimum time grouped by course (from meet), distance, and stroke
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, m.course, m.date, m.title
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ?
      GROUP BY m.course, e.distance, e.stroke
      HAVING e.timeMs = MIN(e.timeMs)
    ''', [swimmerId]);
    
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }


  Future<List<SwimEvent>> getRecentBests(int swimmerId, int distance, String stroke, String course) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, m.title, m.date, m.course
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ? AND e.distance = ? AND e.stroke = ? AND m.course = ?
      ORDER BY e.timeMs ASC
      LIMIT 5
    ''', [swimmerId, distance, stroke, course]);
    
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<List<SwimEvent>> getProgression(int swimmerId, int distance, String stroke, String course, {DateTime? sinceDate}) async {
    Database db = await database;
    String query = '''
      SELECT e.*, m.date, m.course, m.title
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ? AND e.distance = ? AND e.stroke = ? AND m.course = ?
    ''';
    List<dynamic> args = [swimmerId, distance, stroke, course];

    if (sinceDate != null) {
      query += ' AND m.date >= ?';
      args.add(sinceDate.toIso8601String());
    }

    query += ' ORDER BY m.date ASC';
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<int> getMeetCountBySwimmer(int swimmerId) async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT meetId) as count FROM events WHERE swimmerId = ?
    ''', [swimmerId]);
    return result.first['count'] as int;
  }

  Future<int> getScmMeetCountBySwimmer(int swimmerId) async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT m.id) as count 
      FROM meets m
      JOIN events e ON m.id = e.meetId
      WHERE e.swimmerId = ? AND m.course = 'SCM'
    ''', [swimmerId]);
    return result.first['count'] as int;
  }

  Future<int> getLcmMeetCountBySwimmer(int swimmerId) async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT m.id) as count 
      FROM meets m
      JOIN events e ON m.id = e.meetId
      WHERE e.swimmerId = ? AND m.course = 'LCM'
    ''', [swimmerId]);
    return result.first['count'] as int;
  }

  Future<int> getEventCountBySwimmer(int swimmerId) async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM events WHERE swimmerId = ?
    ''', [swimmerId]);
    return result.first['count'] as int;
  }

  Future<int> getOrCreateSwimmer(Swimmer swimmer) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'swimmers',
      where: 'firstName = ? AND surname = ?',
      whereArgs: [swimmer.firstName, swimmer.surname],
    );

    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    } else {
      return await insertSwimmer(swimmer);
    }
  }

  Future<int> getOrCreateMeet(SwimMeet meet) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meets',
      where: 'title = ? AND date = ? AND course = ?',
      whereArgs: [meet.title, meet.date.toIso8601String(), meet.course],
    );

    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    } else {
      return await insertMeet(meet);
    }
  }

  // Qualifying Times CRUD
  Future<int> insertQualifyingTime(QualifyingTime qt) async {
    Database db = await database;
    return await db.insert('qualifying_times', qt.toMap());
  }

  Future<List<QualifyingTime>> getQualifyingTimesByEvent(int distance, String stroke, String gender) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'qualifying_times',
      where: 'distance = ? AND stroke = ? AND gender = ?',
      whereArgs: [distance, stroke, gender],
    );
    return List.generate(maps.length, (i) => QualifyingTime.fromMap(maps[i]));
  }

  Future<QualifyingTime?> getQualifyingTimeForEvent(int distance, String stroke, String gender, int age, String course) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'qualifying_times',
      where: 'distance = ? AND stroke = ? AND gender = ? AND ageMin <= ? AND ageMax >= ? AND course = ?',
      whereArgs: [distance, stroke, gender, age, age, course],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return QualifyingTime.fromMap(maps.first);
  }

  Future<List<QualifyingTime>> getStandardsForSwimmer(int age, String gender) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'qualifying_times',
      where: 'gender = ? AND ageMin <= ? AND ageMax >= ?',
      whereArgs: [gender, age, age],
    );
    return List.generate(maps.length, (i) => QualifyingTime.fromMap(maps[i]));
  }

  Future<int> getQualifyingTimesCount() async {
    Database db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM qualifying_times');
    return result.first['count'] as int;
  }

  Future<void> deleteEventsBySwimmerAndCourse(int swimmerId, String course) async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM events 
      WHERE swimmerId = ? AND meetId IN (
        SELECT id FROM meets WHERE course = ?
      )
    ''', [swimmerId, course]);
  }

  Future<List<Map<String, dynamic>>> getEventsForExport(int swimmerId, String course) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT s.firstName, s.surname, s.dob, s.nationality, s.club,
             m.title as meetTitle, m.date as meetDate, m.course,
             e.distance, e.stroke, e.timeMs
      FROM events e
      JOIN swimmers s ON e.swimmerId = s.id
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ? AND m.course = ?
      ORDER BY m.date DESC, e.stroke ASC, e.distance ASC
    ''', [swimmerId, course]);
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('events');
    await db.delete('meets');
    await db.delete('swimmers');
  }
}
