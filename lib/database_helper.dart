import 'dart:async';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models/swimmer.dart';
import 'models/meet.dart';
import 'models/event.dart';
import 'models/qualifying_time.dart';
import 'models/goal.dart';

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
      version: 10,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
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
    if (oldVersion < 8) {
      await _createGoalsTable(db);
    }
    if (oldVersion < 9) {
      try { await db.execute('ALTER TABLE swimmer_goals ADD COLUMN targetDate TEXT'); } catch (_) {}
    }
    if (oldVersion < 10) {
      try { await db.execute('ALTER TABLE events ADD COLUMN club TEXT'); } catch (_) {}
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
        club TEXT,
        FOREIGN KEY (meetId) REFERENCES meets (id) ON DELETE CASCADE,
        FOREIGN KEY (swimmerId) REFERENCES swimmers (id) ON DELETE CASCADE
      )
    ''');
    await _createQualifyingTimesTable(db);
    await _createGoalsTable(db);
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

  Future<void> _createGoalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS swimmer_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        swimmerId INTEGER,
        distance INTEGER,
        stroke TEXT,
        course TEXT,
        timeMs INTEGER,
        targetDate TEXT,
        FOREIGN KEY (swimmerId) REFERENCES swimmers (id) ON DELETE CASCADE
      )
    ''');
  }

  // Swimmer CRUD
  Future<int> insertSwimmer(Swimmer swimmer, {DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    return await db.insert('swimmers', swimmer.toMap());
  }

  Future<List<Swimmer>> getSwimmers({DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    final List<Map<String, dynamic>> maps = await db.query('swimmers');
    return List.generate(maps.length, (i) => Swimmer.fromMap(maps[i]));
  }

  Future<Swimmer?> getSwimmerById(int id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'swimmers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Swimmer.fromMap(maps.first);
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
  Future<int> insertMeet(SwimMeet meet, {DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    return await db.insert('meets', meet.toMap());
  }

  Future<int> updateMeet(SwimMeet meet) async {
    Database db = await database;
    return await db.update(
      'meets',
      meet.toMap(),
      where: 'id = ?',
      whereArgs: [meet.id],
    );
  }

  // Event CRUD
  Future<int> insertEvent(SwimEvent event, {DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    return await db.insert(
      'events', 
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateEvent(SwimEvent event) async {
    Database db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEventsByMeetAndSwimmer(int meetId, int swimmerId) async {
    Database db = await database;
    await db.delete(
      'events',
      where: 'meetId = ? AND swimmerId = ?',
      whereArgs: [meetId, swimmerId],
    );
  }

  Future<List<SwimEvent>> getEventsBySwimmer(int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, m.title, m.date, m.course
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ?
      ORDER BY m.date DESC
    ''', [swimmerId]);
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<List<SwimEvent>> getEventsByMeet(int meetId, int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, m.title, m.date, m.course
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.meetId = ? AND e.swimmerId = ?
    ''', [meetId, swimmerId]);
    return List.generate(maps.length, (i) => SwimEvent.fromMap(maps[i]));
  }

  Future<List<SwimMeet>> getMeetsBySwimmer(int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT m.*, e.club
      FROM meets m
      JOIN events e ON m.id = e.meetId
      WHERE e.swimmerId = ?
      GROUP BY m.id
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

  Future<String?> getRecentClubForSwimmer(int swimmerId, {DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.club
      FROM events e
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ? AND e.club IS NOT NULL AND e.club != ''
      ORDER BY m.date DESC, e.id DESC
      LIMIT 1
    ''', [swimmerId]);
    
    if (maps.isEmpty) return null;
    return maps.first['club'] as String?;
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

  Future<Set<int>> getSwimmerIdsWithResults() async {
    Database db = await database;
    final result = await db.rawQuery('SELECT DISTINCT swimmerId FROM events');
    return result.map((row) => row['swimmerId'] as int).toSet();
  }

  Future<int> getOrCreateSwimmer(Swimmer swimmer, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'swimmers',
      where: 'firstName = ? AND surname = ?',
      whereArgs: [swimmer.firstName, swimmer.surname],
    );
  
    if (maps.isNotEmpty) {
      final existingId = maps.first['id'] as int;
      final existing = Swimmer.fromMap(maps.first);
      
      // Update if current data is default/empty but new data is provided
      bool needsUpdate = false;
      String nationality = existing.nationality;
      String? photoPath = existing.photoPath;
      DateTime dob = existing.dob;
      String gender = existing.gender;
      String? club = existing.club;

      if ((nationality == 'Unknown' || nationality.isEmpty) && swimmer.nationality != 'Unknown' && swimmer.nationality.isNotEmpty) {
        nationality = swimmer.nationality;
        needsUpdate = true;
      }
      if (photoPath == null && swimmer.photoPath != null) {
        photoPath = swimmer.photoPath;
        needsUpdate = true;
      }
      if (existing.dob.year == 2000 && swimmer.dob.year != 2000) {
        dob = swimmer.dob;
        needsUpdate = true;
      }
      if (gender == 'Female' && swimmer.gender != 'Female') { // Simple heuristic or keep if swimmer from import has different gender
        gender = swimmer.gender;
        needsUpdate = true;
      }
      if ((club == null || club.isEmpty) && swimmer.club != null && swimmer.club!.isNotEmpty) {
        club = swimmer.club;
        needsUpdate = true;
      }

      if (needsUpdate) {
        final updated = Swimmer(
          id: existingId,
          firstName: existing.firstName,
          surname: existing.surname,
          photoPath: photoPath,
          dob: dob,
          nationality: nationality,
          gender: gender,
          club: club,
        );
        await db.update('swimmers', updated.toMap(), where: 'id = ?', whereArgs: [existingId]);
      }
      return existingId;
    } else {
      return await insertSwimmer(swimmer, executor: db);
    }
  }

  Future<int> getOrCreateMeet(SwimMeet meet, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meets',
      where: 'title = ? AND date = ? AND course = ?',
      whereArgs: [meet.title, meet.date.toIso8601String(), meet.course],
    );

    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    } else {
      return await insertMeet(meet, executor: db);
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
    if (course == 'All') {
      await db.delete(
        'events',
        where: 'swimmerId = ?',
        whereArgs: [swimmerId],
      );
    } else {
      await db.rawDelete('''
        DELETE FROM events 
        WHERE swimmerId = ? AND meetId IN (
          SELECT id FROM meets WHERE course = ?
        )
      ''', [swimmerId, course]);
    }
  }

  Future<List<Map<String, dynamic>>> getEventsForExport(int swimmerId, {String? course}) async {
    Database db = await database;
    String query = '''
      SELECT s.firstName, s.surname, s.dob, s.nationality, s.club, s.photoPath,
             m.title as meetTitle, m.date as meetDate, m.course,
             e.distance, e.stroke, e.timeMs, 'Result' as dataType
      FROM events e
      JOIN swimmers s ON e.swimmerId = s.id
      JOIN meets m ON e.meetId = m.id
      WHERE e.swimmerId = ?
    ''';
    
    List<dynamic> args = [swimmerId];
    if (course != null && course != 'All') {
      query += ' AND m.course = ?';
      args.add(course);
    }
    
    query += ' ORDER BY m.date DESC, e.stroke ASC, e.distance ASC';
    return await db.rawQuery(query, args);
  }

  Future<List<Map<String, dynamic>>> getGoalsForExport(int swimmerId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT s.firstName, s.surname, s.dob, s.nationality, s.club, s.photoPath,
             'Goal' as meetTitle, g.targetDate as meetDate, g.course,
             g.distance, g.stroke, g.timeMs, 'Goal' as dataType
      FROM swimmer_goals g
      JOIN swimmers s ON g.swimmerId = s.id
      WHERE g.swimmerId = ?
    ''', [swimmerId]);
  }

  Future<void> deleteMeetForSwimmer(int meetId, int swimmerId) async {
    Database db = await database;
    // 1. Delete events for this swimmer and meet
    await db.delete(
      'events',
      where: 'meetId = ? AND swimmerId = ?',
      whereArgs: [meetId, swimmerId],
    );

    // 2. Check if any events remain for this meet
    final List<Map<String, dynamic>> remainingEvents = await db.query(
      'events',
      where: 'meetId = ?',
      whereArgs: [meetId],
      limit: 1,
    );

    // 3. If no events remain, delete the meet record itself
    if (remainingEvents.isEmpty) {
      await db.delete(
        'meets',
        where: 'id = ?',
        whereArgs: [meetId],
      );
    }
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('events');
    await db.delete('meets');
    await db.delete('swimmers');
    await db.delete('swimmer_goals');
  }

  // Goals CRUD
  Future<int> insertGoal(SwimmerGoal goal, {DatabaseExecutor? executor}) async {
    DatabaseExecutor db = executor ?? await database;
    return await db.insert(
      'swimmer_goals', 
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateGoal(SwimmerGoal goal) async {
    Database db = await database;
    return await db.update(
      'swimmer_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    Database db = await database;
    return await db.delete(
      'swimmer_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<SwimmerGoal?> getGoalForEvent(int swimmerId, int distance, String stroke, String course) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'swimmer_goals',
      where: 'swimmerId = ? AND distance = ? AND stroke = ? AND course = ?',
      whereArgs: [swimmerId, distance, stroke, course],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SwimmerGoal.fromMap(maps.first);
  }

  Future<List<SwimmerGoal>> getGoalsBySwimmer(int swimmerId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'swimmer_goals',
      where: 'swimmerId = ?',
      whereArgs: [swimmerId],
    );
    return List.generate(maps.length, (i) => SwimmerGoal.fromMap(maps[i]));
  }
}
