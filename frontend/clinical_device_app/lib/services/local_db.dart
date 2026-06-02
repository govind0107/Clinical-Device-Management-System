import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'clinical_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_sessions (
            sessionId TEXT PRIMARY KEY,
            deviceId TEXT NOT NULL,
            patientId TEXT,
            startTime TEXT NOT NULL,
            endTime TEXT,
            patientName TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            channel TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_alerts (
            alertId TEXT PRIMARY KEY,
            deviceId TEXT NOT NULL,
            severity TEXT NOT NULL,
            message TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            acknowledged INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> saveSession(SessionModel session, {String? patientName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listRaw = prefs.getString('web_cached_sessions') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(listRaw) as List);

      final idx = list.indexWhere((item) => item['sessionId'] == session.sessionId);
      final map = {
        'sessionId': session.sessionId,
        'deviceId': session.deviceId,
        'patientId': session.patientId,
        'startTime': session.startTime.toIso8601String(),
        'endTime': session.endTime?.toIso8601String(),
        'patientName': patientName ?? list.where((item) => item['sessionId'] == session.sessionId).firstOrNull?['patientName'],
      };

      if (idx >= 0) {
        list[idx] = map;
      } else {
        list.add(map);
      }

      await prefs.setString('web_cached_sessions', jsonEncode(list));
      return;
    }

    final db = await instance();
    await db.insert(
      'cached_sessions',
      {
        'sessionId': session.sessionId,
        'deviceId': session.deviceId,
        'patientId': session.patientId,
        'startTime': session.startTime.toIso8601String(),
        'endTime': session.endTime?.toIso8601String(),
        'patientName': patientName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<SessionModel>> getCompletedSessions() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listRaw = prefs.getString('web_cached_sessions') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(listRaw) as List);

      final completed = list
          .where((item) => item['endTime'] != null)
          .map((item) => SessionModel(
                sessionId: item['sessionId'] as String,
                deviceId: item['deviceId'] as String,
                patientId: item['patientId'] as String?,
                startTime: DateTime.parse(item['startTime'] as String),
                endTime: DateTime.parse(item['endTime'] as String),
              ))
          .toList();

      completed.sort((a, b) => b.endTime!.compareTo(a.endTime!));
      return completed;
    }

    final db = await instance();
    final rows = await db.query(
      'cached_sessions',
      where: 'endTime IS NOT NULL',
      orderBy: 'endTime DESC',
    );
    return rows.map((r) {
      return SessionModel(
        sessionId: r['sessionId'] as String,
        deviceId: r['deviceId'] as String,
        patientId: r['patientId'] as String?,
        startTime: DateTime.parse(r['startTime'] as String),
        endTime: r['endTime'] != null ? DateTime.parse(r['endTime'] as String) : null,
      );
    }).toList();
  }

  static Future<String?> getPatientNameForSession(String sessionId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listRaw = prefs.getString('web_cached_sessions') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(listRaw) as List);
      final idx = list.indexWhere((item) => item['sessionId'] == sessionId);
      if (idx >= 0) {
        return list[idx]['patientName'] as String?;
      }
      return null;
    }

    final db = await instance();
    final rows = await db.query(
      'cached_sessions',
      columns: ['patientName'],
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['patientName'] as String?;
  }

  static Future<void> cacheReading(Map<String, dynamic> telemetry) async {
    if (kIsWeb) {
      final sessionId = telemetry['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'web_readings_$sessionId';
      final readingsRaw = prefs.getString(key) ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(readingsRaw) as List);

      list.add({
        'sessionId': sessionId,
        'timestamp': telemetry['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        'channel': telemetry['channel']?.toString() ?? '',
        'value': (telemetry['value'] as num?)?.toDouble() ?? 0.0,
        'unit': telemetry['unit']?.toString() ?? '',
      });

      await prefs.setString(key, jsonEncode(list));
      return;
    }

    final db = await instance();
    await db.insert('cached_readings', {
      'sessionId': telemetry['sessionId']?.toString() ?? '',
      'timestamp': telemetry['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'channel': telemetry['channel']?.toString() ?? '',
      'value': (telemetry['value'] as num?)?.toDouble() ?? 0,
      'unit': telemetry['unit']?.toString() ?? '',
    });
  }

  static Future<void> cacheReadingsBatch(String sessionId, List<ReadingModel> readings) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'web_readings_$sessionId';
      final readingsRaw = prefs.getString(key) ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(readingsRaw) as List);

      for (final r in readings) {
        list.add({
          'sessionId': sessionId,
          'timestamp': r.timestamp.toIso8601String(),
          'channel': r.channel,
          'value': r.value,
          'unit': r.unit,
        });
      }

      await prefs.setString(key, jsonEncode(list));
      return;
    }

    final db = await instance();
    final batch = db.batch();
    for (final r in readings) {
      batch.insert('cached_readings', {
        'sessionId': sessionId,
        'timestamp': r.timestamp.toIso8601String(),
        'channel': r.channel,
        'value': r.value,
        'unit': r.unit,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> cacheAlert(AlertModel alert) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final alertsRaw = prefs.getString('web_cached_alerts') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(alertsRaw) as List);

      final idx = list.indexWhere((item) => item['alertId'] == alert.alertId);
      final map = {
        'alertId': alert.alertId,
        'deviceId': alert.deviceId,
        'severity': alert.severity,
        'message': alert.message,
        'createdAt': alert.createdAt.toIso8601String(),
        'acknowledged': alert.acknowledged ? 1 : 0,
      };

      if (idx >= 0) {
        list[idx] = map;
      } else {
        list.add(map);
      }

      await prefs.setString('web_cached_alerts', jsonEncode(list));
      return;
    }

    final db = await instance();
    await db.insert(
      'cached_alerts',
      {
        'alertId': alert.alertId,
        'deviceId': alert.deviceId,
        'severity': alert.severity,
        'message': alert.message,
        'createdAt': alert.createdAt.toIso8601String(),
        'acknowledged': alert.acknowledged ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AlertModel>> getCachedAlerts() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final alertsRaw = prefs.getString('web_cached_alerts') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(alertsRaw) as List);

      final alerts = list.map((r) {
        return AlertModel(
          alertId: r['alertId'] as String,
          deviceId: r['deviceId'] as String,
          severity: r['severity'] as String,
          message: r['message'] as String,
          createdAt: DateTime.parse(r['createdAt'] as String),
          acknowledged: (r['acknowledged'] as int) == 1,
        );
      }).toList();

      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return alerts;
    }

    final db = await instance();
    final rows = await db.query(
      'cached_alerts',
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) {
      return AlertModel(
        alertId: r['alertId'] as String,
        deviceId: r['deviceId'] as String,
        severity: r['severity'] as String,
        message: r['message'] as String,
        createdAt: DateTime.parse(r['createdAt'] as String),
        acknowledged: (r['acknowledged'] as int) == 1,
      );
    }).toList();
  }

  static Future<List<ReadingModel>> getCachedReadings(String sessionId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'web_readings_$sessionId';
      final readingsRaw = prefs.getString(key) ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(readingsRaw) as List);

      final readings = list.map((r) {
        return ReadingModel(
          readingId: 0,
          sessionId: r['sessionId'] as String,
          timestamp: DateTime.parse(r['timestamp'] as String),
          channel: r['channel'] as String,
          value: (r['value'] as num).toDouble(),
          unit: r['unit'] as String,
        );
      }).toList();

      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return readings;
    }

    final db = await instance();
    final rows = await db.query(
      'cached_readings',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) {
      return ReadingModel(
        readingId: r['id'] as int,
        sessionId: r['sessionId'] as String,
        timestamp: DateTime.parse(r['timestamp'] as String),
        channel: r['channel'] as String,
        value: (r['value'] as num).toDouble(),
        unit: r['unit'] as String,
      );
    }).toList();
  }

  static Future<void> setAlertAcknowledged(String alertId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final alertsRaw = prefs.getString('web_cached_alerts') ?? '[]';
      final list = List<Map<String, dynamic>>.from(jsonDecode(alertsRaw) as List);

      final idx = list.indexWhere((item) => item['alertId'] == alertId);
      if (idx >= 0) {
        list[idx]['acknowledged'] = 1;
        await prefs.setString('web_cached_alerts', jsonEncode(list));
      }
      return;
    }

    final db = await instance();
    await db.update(
      'cached_alerts',
      {'acknowledged': 1},
      where: 'alertId = ?',
      whereArgs: [alertId],
    );
  }
}

