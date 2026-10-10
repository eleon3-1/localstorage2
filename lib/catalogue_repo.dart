import 'package:sqflite/sqflite.dart';

import 'catalogue_models.dart';

class CatalogueRepo {
  CatalogueRepo(this.db);

  final Database db;

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await db.rawQuery('''
      SELECT
        f.id,
        f.name,
        f.createdAt,
        COUNT(c.id) AS cardCount
      FROM folders AS f
      LEFT JOIN cards AS c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.createdAt
      ORDER BY f.name COLLATE NOCASE ASC
    ''');

    return rows.map((row) => Folder.fromMap(row)).toList();
  }

  Future<int> insertFolder(String name) async {
    _validateFolderName(name);

    final folder = Folder(
      name: name.trim(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    return db.insert(
      'folders',
      folder.toMap(includeId: false),
    );
  }

  Future<int> updateFolder(Folder folder) async {
    final id = folder.id;

    if (id == null) {
      throw ArgumentError('A folder ID is required.');
    }

    _validateFolderName(folder.name);

    return db.update(
      'folders',
      folder.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFolder(int id) async {
    return db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CatalogueCard>> getCards(int folderId) async {
    final rows = await db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return rows.map((row) => CatalogueCard.fromMap(row)).toList();
  }

  Future<int> insertCard(CatalogueCard card) async {
    _validateCard(card);

    return db.insert(
      'cards',
      card.toMap(includeId: false),
    );
  }

  Future<int> updateCard(CatalogueCard card) async {
    final id = card.id;

    if (id == null) {
      throw ArgumentError('A card ID is required.');
    }

    _validateCard(card);

    return db.update(
      'cards',
      card.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCard(int id) async {
    return db.delete(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  void _validateFolderName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Enter a folder name.');
    }
  }

  void _validateCard(CatalogueCard card) {
    if (card.title.trim().isEmpty) {
      throw ArgumentError('Enter a card title.');
    }

    if (!supportedSuits.contains(card.suit)) {
      throw ArgumentError('Select a supported suit.');
    }

    if (card.folderId <= 0) {
      throw ArgumentError('Select a valid folder.');
    }
  }
}