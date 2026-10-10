import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _db;

  Database get database => _db;

  Future<void> init() async {
    final documentsDirectory =
        await getApplicationDocumentsDirectory();

    final path = join(
      documentsDirectory.path,
      _databaseName,
    );

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');

    await _createCatalogueTables(db);
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createCatalogueTables(db);
    }
  }

  Future<void> _onOpen(Database db) async {
    // Safely completes an unfinished version-2 database.
    // Existing tables and records are retained.
    await db.transaction((transaction) async {
      await _createCatalogueTables(transaction);
    });
  }

  Future<void> _createCatalogueTables(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
          CHECK(length(trim(name)) > 0),
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL
          CHECK(length(trim(title)) > 0),
        suit TEXT NOT NULL
          CHECK(suit IN (
            'hearts',
            'diamonds',
            'clubs',
            'spades'
          )),
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES folders(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cards_folder_id
      ON cards(folder_id)
    ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    return _db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return _db.query(table);
  }

  Future<int> queryRowCount() async {
    final results = await _db.rawQuery(
      'SELECT COUNT(*) FROM $table',
    );

    return Sqflite.firstIntValue(results) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final id = row[columnId] as int;

    return _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}