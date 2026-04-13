import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'backup_app_files.dart';
import 'backup_file_saver.dart';

class BackupOperationResult {
  final bool success;
  final bool cancelled;
  final String message;
  final String? filePath;

  const BackupOperationResult({
    required this.success,
    required this.cancelled,
    required this.message,
    this.filePath,
  });
}

class AppBackupService {
  AppBackupService(this._db);

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _magic = 'tod-backup-v1';

  Future<BackupOperationResult> createBackupFile() async {
    try {
      final payload = await _buildBackupPayload();
      final encoded = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
      final fileName = 'tod_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.todbackup';

      final savePath = await saveBackupFile(Uint8List.fromList(encoded), fileName);

      if (savePath == null || savePath.trim().isEmpty) {
        return const BackupOperationResult(
          success: false,
          cancelled: true,
          message: 'Backup cancelled',
        );
      }

      return BackupOperationResult(
        success: true,
        cancelled: false,
        message: 'Backup saved: $savePath',
        filePath: savePath,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        cancelled: false,
        message: 'Backup failed: $e',
      );
    }
  }

  Future<BackupOperationResult> restoreFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select TOD Backup File',
        // Some Android file managers disable items when using custom extension filters.
        // We accept any file here and validate payload signature after reading.
        type: FileType.any,
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) {
        return const BackupOperationResult(
          success: false,
          cancelled: true,
          message: 'Restore cancelled',
        );
      }

      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        return const BackupOperationResult(
          success: false,
          cancelled: false,
          message: 'Selected backup file is empty',
        );
      }

      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        return const BackupOperationResult(
          success: false,
          cancelled: false,
          message: 'Invalid backup format',
        );
      }

      if (decoded['magic'] != _magic) {
        return const BackupOperationResult(
          success: false,
          cancelled: false,
          message: 'This is not a valid TOD backup file',
        );
      }

      await _restoreDatabase(decoded['database']);
      await restoreAppFilesFromBackup(decoded['appFiles']);
      await _restoreSharedPreferences(decoded['sharedPreferences']);
      await _restoreSecureStorage(decoded['secureStorage']);

      return const BackupOperationResult(
        success: true,
        cancelled: false,
        message: 'Restore completed successfully',
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        cancelled: false,
        message: 'Restore failed: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final tables = await _getUserTableNames();
    final databaseDump = <String, List<Map<String, dynamic>>>{};

    for (final table in tables) {
      final query = 'SELECT * FROM "${_quote(table)}"';
      final rows = await _db.customSelect(query).get();
      databaseDump[table] = rows
          .map((r) => Map<String, dynamic>.from(r.data).map((k, v) => MapEntry(k, _encodeDbValue(v))))
          .toList();
    }

    final prefs = await SharedPreferences.getInstance();
    final prefDump = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys().toList()..sort()) {
      final value = prefs.get(key);
      if (value == null) continue;

      if (value is bool) {
        prefDump.add({'key': key, 'type': 'bool', 'value': value});
      } else if (value is int) {
        prefDump.add({'key': key, 'type': 'int', 'value': value});
      } else if (value is double) {
        prefDump.add({'key': key, 'type': 'double', 'value': value});
      } else if (value is String) {
        prefDump.add({'key': key, 'type': 'string', 'value': value});
      } else if (value is List<String>) {
        prefDump.add({'key': key, 'type': 'stringList', 'value': value});
      }
    }

    final secureDump = await _secureStorage.readAll();
    final appFilesDump = await collectAppFilesForBackup();

    return {
      'magic': _magic,
      'createdAt': DateTime.now().toIso8601String(),
      'database': databaseDump,
      'appFiles': appFilesDump,
      'sharedPreferences': prefDump,
      'secureStorage': secureDump,
    };
  }

  Future<List<String>> _getUserTableNames() async {
    const sql = """
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
        AND name NOT LIKE 'drift_%'
        AND name NOT LIKE 'moor_%'
    """;
    final rows = await _db.customSelect(sql).get();
    return rows
        .map((r) => r.data['name'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty && name != 'android_metadata')
        .toList()
      ..sort();
  }

  Future<void> _restoreDatabase(dynamic dbSection) async {
    if (dbSection is! Map) {
      throw const FormatException('Database section is missing');
    }

    final incoming = Map<String, dynamic>.from(dbSection);
    final existingTables = await _getUserTableNames();
    final existingTableSet = existingTables.toSet();

    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        for (final table in existingTables) {
          await _db.customStatement('DELETE FROM "${_quote(table)}"');
        }

        for (final entry in incoming.entries) {
          final table = entry.key;
          if (!existingTableSet.contains(table)) {
            continue;
          }

          final rowsDynamic = entry.value;
          if (rowsDynamic is! List) {
            continue;
          }

          for (final rowDynamic in rowsDynamic) {
            if (rowDynamic is! Map) continue;

            final row = Map<String, dynamic>.from(rowDynamic);
            if (row.isEmpty) continue;

            final columns = row.keys.toList();
            final placeholders = List.filled(columns.length, '?').join(', ');
            final quotedColumns = columns.map((c) => '"${_quote(c)}"').join(', ');
            final sql = 'INSERT INTO "${_quote(table)}" ($quotedColumns) VALUES ($placeholders)';
            final args = columns.map((c) => _decodeDbValue(row[c])).toList();

            await _db.customStatement(sql, args);
          }
        }
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _restoreSharedPreferences(dynamic prefSection) async {
    if (prefSection is! List) return;

    final prefs = await SharedPreferences.getInstance();
    final currentKeys = prefs.getKeys().toList();
    for (final key in currentKeys) {
      await prefs.remove(key);
    }

    for (final item in prefSection) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = map['key'];
      final type = map['type'];
      final value = map['value'];
      if (key is! String || type is! String) continue;

      switch (type) {
        case 'bool':
          if (value is bool) {
            await prefs.setBool(key, value);
          }
          break;
        case 'int':
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is num) {
            await prefs.setInt(key, value.toInt());
          }
          break;
        case 'double':
          if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is num) {
            await prefs.setDouble(key, value.toDouble());
          }
          break;
        case 'string':
          if (value is String) {
            await prefs.setString(key, value);
          }
          break;
        case 'stringList':
          if (value is List) {
            await prefs.setStringList(key, value.map((e) => e.toString()).toList());
          }
          break;
      }
    }
  }

  Future<void> _restoreSecureStorage(dynamic secureSection) async {
    if (secureSection is! Map) return;

    final map = Map<String, dynamic>.from(secureSection);
    await _secureStorage.deleteAll();
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      await _secureStorage.write(key: key, value: value.toString());
    }
  }

  Object? _encodeDbValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) {
      return {'__type': 'datetime', 'value': value.toIso8601String()};
    }
    if (value is Uint8List) {
      return {'__type': 'bytes', 'value': base64Encode(value)};
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num || value is String) {
      return value;
    }
    return value.toString();
  }

  Object? _decodeDbValue(Object? value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final type = map['__type'];
      if (type == 'datetime' && map['value'] is String) {
        return map['value'] as String;
      }
      if (type == 'bytes' && map['value'] is String) {
        try {
          return base64Decode(map['value'] as String);
        } catch (_) {
          return null;
        }
      }
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    return value;
  }

  String _quote(String s) => s.replaceAll('"', '""');
}
