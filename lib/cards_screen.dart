import 'package:flutter/material.dart';

import 'catalogue_models.dart';
import 'catalogue_repo.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repo,
    required this.folder,
  });

  final CatalogueRepo repo;
  final Folder folder;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CatalogueCard>? _cards;

  bool _busy = false;
  String _feedback = '';
  String? _readError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshList() async {
    try {
      final cards = await widget.repo.getCards(widget.folder.id!);

      if (!mounted) return;

      setState(() {
        _cards = cards;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Card read failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _readError = 'Could not refresh cards. Tap Refresh.';
      });
    }
  }

  Future<void> _load() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _refreshList();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openForm([CatalogueCard? card]) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final folders = await widget.repo.getFoldersWithCounts();

      if (!mounted) return;

      if (folders.isEmpty) {
        setState(() {
          _feedback = 'Create a folder before adding a card.';
        });
        return;
      }

      final message = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _CardFormScreen(
            repo: widget.repo,
            folders: folders,
            initialFolderId: widget.folder.id!,
            card: card,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _feedback = message ?? 'Form canceled. No changes saved.';
      });

      await _refreshList();
    } catch (error, stackTrace) {
      debugPrint('Opening card form failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedback = 'Could not open the card form. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(CatalogueCard card) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete card?'),
          content: Text(
            'Delete "${card.title}" (ID ${card.id})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmed != true) {
        setState(() {
          _feedback = 'Deletion canceled. Nothing was removed.';
        });
        return;
      }

      final deleted = await widget.repo.deleteCard(card.id!);

      if (!mounted) return;

      setState(() {
        _feedback = deleted == 1
            ? 'Deleted card ID ${card.id}. Rows deleted: 1.'
            : 'Card ID ${card.id} no longer exists. '
                'Rows deleted: $deleted.';
      });

      await _refreshList();
    } catch (error, stackTrace) {
      debugPrint('Card delete failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedback = 'Could not delete the card. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Folder ID: ${widget.folder.id}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _openForm(),
                  child: const Text('Add card'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (_feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_feedback),
              ),
            if (_busy)
              const Center(child: CircularProgressIndicator()),
            if (_readError != null) Text(_readError!),
            const SizedBox(height: 16),
            if (!_busy &&
                _readError == null &&
                _cards?.isEmpty == true)
              const Text('No cards in this folder yet.'),
            for (final card in _cards ?? <CatalogueCard>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardImage(card: card),
                      Text(
                        card.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'ID: ${card.id} | Folder ID: ${card.folderId}',
                      ),
                      Text('Suit: ${card.suit}'),
                      if (card.notes.isNotEmpty)
                        Text('Notes: ${card.notes}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed:
                                _busy ? null : () => _openForm(card),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed:
                                _busy ? null : () => _delete(card),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardFormScreen extends StatefulWidget {
  const _CardFormScreen({
    required this.repo,
    required this.folders,
    required this.initialFolderId,
    this.card,
  });

  final CatalogueRepo repo;
  final List<Folder> folders;
  final int initialFolderId;
  final CatalogueCard? card;

  @override
  State<_CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<_CardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _image = TextEditingController();

  int? _folderId;
  String? _suit;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final card = widget.card;

    _title.text = card?.title ?? '';
    _notes.text = card?.notes ?? '';
    _image.text = card?.imageRef ?? '';

    _suit = supportedSuits.contains(card?.suit)
        ? card!.suit
        : 'hearts';

    final folderId = card?.folderId ?? widget.initialFolderId;

    _folderId = widget.folders.any(
      (folder) => folder.id == folderId,
    )
        ? folderId
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final imageRef = _image.text.trim();

    final card = CatalogueCard(
      id: widget.card?.id,
      title: _title.text.trim(),
      suit: _suit!,
      notes: _notes.text,
      imageRef: imageRef.isEmpty ? null : imageRef,
      folderId: _folderId!,
    );

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = widget.card == null
          ? await widget.repo.insertCard(card)
          : await widget.repo.updateCard(card);

      if (!mounted) return;

      if (widget.card != null && result != 1) {
        setState(() {
          _error = 'Card ID ${card.id} no longer exists. '
              'Rows updated: $result.';
        });
        return;
      }

      setState(() => _busy = false);

      Navigator.pop<String>(
        context,
        widget.card == null
            ? 'Added card ID $result.'
            : 'Saved card ID ${card.id}. Rows updated: 1.',
      );
    } catch (error, stackTrace) {
      debugPrint('Card save failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _error = 'Could not save. Your input was kept. '
            'Check the folder and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<String>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.card == null ? 'Add card' : 'Edit card'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a card title.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _suit,
                      decoration: const InputDecoration(
                        labelText: 'Suit',
                      ),
                      items: [
                        for (final suit in supportedSuits)
                          DropdownMenuItem(
                            value: suit,
                            child: Text(suit),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() => _suit = value);
                            },
                      validator: (value) {
                        if (!supportedSuits.contains(value)) {
                          return 'Select a supported suit.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _folderId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Folder',
                      ),
                      items: [
                        for (final folder in widget.folders)
                          DropdownMenuItem(
                            value: folder.id!,
                            child: Text(
                              '${folder.name} (ID ${folder.id})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() => _folderId = value);
                            },
                      validator: (value) {
                        if (value == null ||
                            !widget.folders.any(
                              (folder) => folder.id == value,
                            )) {
                          return 'Select a valid folder.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      enabled: !_busy,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _image,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Image reference (optional)',
                        hintText:
                            'Asset path or https:// URL; may be left blank',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!),
              if (_busy)
                const Center(child: CircularProgressIndicator()),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Save'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.card});

  final CatalogueCard card;

  Widget _placeholder() {
    const symbols = {
      'hearts': '♥',
      'diamonds': '♦',
      'clubs': '♣',
      'spades': '♠',
    };

    return SizedBox(
      width: 72,
      height: 72,
      child: Center(
        child: Text(
          symbols[card.suit] ?? '?',
          style: TextStyle(
            fontSize: 48,
            color: card.suit == 'hearts' || card.suit == 'diamonds'
                ? Colors.red
                : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = card.imageRef?.trim();

    if (ref == null || ref.isEmpty) {
      return _placeholder();
    }

    final uri = Uri.tryParse(ref);

    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return Image.network(
        ref,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          return progress == null ? child : _placeholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _placeholder();
        },
      );
    }

    if (uri == null || uri.hasScheme || ref.startsWith('/')) {
      return _placeholder();
    }

    return Image.asset(
      ref,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _placeholder();
      },
    );
  }
}