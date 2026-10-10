const supportedSuits = [
  'hearts',
  'diamonds',
  'clubs',
  'spades',
];

class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['createdAt'] as String,
      cardCount: map['cardCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId && id != null) 'id': id,
      'name': name.trim(),
      'createdAt': createdAt,
    };
  }
}

class CatalogueCard {
  const CatalogueCard({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  factory CatalogueCard.fromMap(Map<String, dynamic> map) {
    return CatalogueCard(
      id: map['id'] as int?,
      title: map['title'] as String,
      suit: map['suit'] as String,
      notes: map['notes'] as String,
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId && id != null) 'id': id,
      'title': title.trim(),
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}