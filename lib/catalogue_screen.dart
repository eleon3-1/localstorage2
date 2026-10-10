import 'package:flutter/material.dart';

import 'catalogue_models.dart';
import 'catalogue_repo.dart';
import 'cards_screen.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key, required this.repo});

  final CatalogueRepo repo;

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  List<Folder>? _folders;
  Folder? _editing;

  bool _busy = false;
  String _feedback = '';
  String? _readError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final folders = await widget.repo.getFoldersWithCounts();

    if (!mounted) return;

    setState(() {
      _folders = folders;
      _readError = null;
    });
  }

  Future<void> _refreshList() async {
    try {
      await _read();
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _readError = 'Could not refresh folders. Tap Refresh.';
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

  void _clearForm() {
    _editing = null;
    _formKey.currentState?.reset();
    _nameController.clear();
  }

  void _edit(Folder folder) {
    setState(() {
      _editing = folder;
      _nameController.text = folder.name;
      _feedback = 'Editing folder ID ${folder.id}.';
    });
  }

  // A refresh failure does not repeat the database write.
  Future<void> _write(
    Future<int> Function() operation,
    String Function(int) describe,
    String failure, {
    VoidCallback? onSuccess,
  }) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _feedback = '';
    });

    try {
      final result = await operation();

      if (!mounted) return;

      setState(() {
        if (result > 0) onSuccess?.call();
        _feedback = describe(result);
      });

      if (result >= 0) {
        await _refreshList();
      }
    } catch (error, stackTrace) {
      debugPrint('Folder write failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() => _feedback = failure);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final editing = _editing;

    await _write(
      () => editing == null
          ? widget.repo.insertFolder(name)
          : widget.repo.updateFolder(
              Folder(
                id: editing.id,
                name: name,
                createdAt: editing.createdAt,
              ),
            ),
      (result) => editing == null
          ? 'Added folder ID $result.'
          : result == 1
              ? 'Saved folder ID ${editing.id}. Rows updated: 1.'
              : 'Folder ID ${editing.id} no longer exists. '
                  'Rows updated: $result.',
      'Could not save. The name may already exist. Your input was kept.',
      onSuccess: _clearForm,
    );
  }

  Future<void> _delete(Folder folder) async {
    await _write(
      () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete folder?'),
            content: Text(
              'Delete "${folder.name}" (ID ${folder.id})? '
              'All cards in this folder will also be deleted.',
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

        if (!mounted || confirmed != true) return -1;

        return widget.repo.deleteFolder(folder.id!);
      },
      (result) => result < 0
          ? 'Deletion canceled. Nothing was removed.'
          : result == 1
              ? 'Deleted folder ID ${folder.id} and its cards.'
              : 'Folder ID ${folder.id} no longer exists. '
                  'Rows deleted: $result.',
      'Could not delete the folder. Try again.',
      onSuccess: () {
        if (_editing?.id == folder.id) {
          _clearForm();
        }
      },
    );
  }

  Future<void> _open(Folder folder) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CardsScreen(
            repo: widget.repo,
            folder: folder,
          ),
        ),
      );

      if (!mounted) return;

      await _refreshList();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Catalogue')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a folder name.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _editing == null ? 'Add folder' : 'Save folder',
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy || _editing == null
                      ? null
                      : () {
                          setState(() {
                            _clearForm();
                            _feedback = 'Edit canceled. No changes saved.';
                          });
                        },
                  child: const Text('Cancel edit'),
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
                _folders?.isEmpty == true)
              const Text('No folders yet. Add a folder above.'),
            for (final folder in _folders ?? <Folder>[])
              Card(
                child: ListTile(
                  title: Text(folder.name),
                  subtitle: Text(
                    'ID: ${folder.id} | Cards: ${folder.cardCount}',
                  ),
                  onTap: _busy ? null : () => _open(folder),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit folder',
                        icon: const Icon(Icons.edit),
                        onPressed: _busy ? null : () => _edit(folder),
                      ),
                      IconButton(
                        tooltip: 'Delete folder',
                        icon: const Icon(Icons.delete),
                        onPressed: _busy ? null : () => _delete(folder),
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