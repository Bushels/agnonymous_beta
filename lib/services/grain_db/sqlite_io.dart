import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:agnonymous_beta/core/utils/globals.dart' show logger;
import 'sqlite_interface.dart';

class GrainDatabaseImpl implements GrainDatabase {
  static final GrainDatabaseImpl instance = GrainDatabaseImpl._init();
  Database? _database;

  GrainDatabaseImpl._init();

  @override
  Future<void> init() async {
    if (_database != null) return;
    _database = await _initDB('grain_data.sqlite');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    final exists = await File(path).exists();
    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load('assets/\$filePath');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        logger.e("Error copying database from assets", error: e);
      }
    }

    final db = sqlite3.open(path);
    db.execute('''
      PRAGMA journal_mode = WAL;
      PRAGMA synchronous = NORMAL;
      PRAGMA journal_size_limit = 67108864;
      PRAGMA mmap_size = 134217728;
      PRAGMA cache_size = 2000;
      PRAGMA busy_timeout = 5000;
    ''');
    
    return db;
  }

  @override
  List<Map<String, dynamic>> getGrainData({
    String? grain,
    String? region,
    String? metric,
    int? limit = 30,
    int? offset = 0,
  }) {
    if (_database == null) return [];
    
    String query = 'SELECT * FROM grain_data WHERE 1=1';
    List<Object> args = [];

    if (grain != null && grain.isNotEmpty) {
      query += ' AND grain = ?';
      args.add(grain);
    }
    if (region != null && region.isNotEmpty) {
      query += ' AND region = ?';
      args.add(region);
    }
    if (metric != null && metric.isNotEmpty) {
      query += ' AND metric = ?';
      args.add(metric);
    }

    query += ' ORDER BY id DESC LIMIT ? OFFSET ?';
    args.add(limit ?? 30);
    args.add(offset ?? 0);

    final resultSet = _database!.select(query, args);
    return resultSet.toList();
  }

  @override
  List<Map<String, dynamic>> queryGlobalStats() {
    if (_database == null) return [];
    try {
      final resultSet = _database!.select('''
        SELECT grain, SUM(ktonnes) as total_ktonnes
        FROM grain_data
        WHERE period = 'Crop Year' AND metric = 'Deliveries'
        GROUP BY grain
        ORDER BY total_ktonnes DESC
        LIMIT 10
      ''');
      return resultSet.toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _database?.dispose();
    _database = null;
  }
}

GrainDatabase getGrainDatabase() => GrainDatabaseImpl.instance;
