import 'package:flutter/material.dart';
import 'database_help.dart';
import 'catalogue_repo.dart';
import 'catalogue_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. '
              'Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: DirectoryScreen(helper: helper),
    );
  }
}

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _selectedId;

  bool _busy = false;
  bool _hasLoaded = false;

  String? _readError;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Refresh reads the database without repeating a write.
  Future<void> _readRecords() async {
    final rows = await widget.helper.queryAllRows();
    final count = await widget.helper.queryRowCount();

    if (!mounted) return;

    setState(() {
      _rows = rows;
      _count = count;
      _hasLoaded = true;
      _readError = null;
    });
  }

  Future<void> _load() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _readError = null;
    });

    try {
      await _readRecords();
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _readError = 'Could not load guests. Tap Refresh to retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _clearForm() {
    _selectedId = null;
    _nameController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;

    setState(() {
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = 'Editing guest ID $_selectedId.';
    });
  }

  void _cancelEdit() {
    if (_busy) return;

    setState(() {
      _clearForm();
      _feedback = 'Edit canceled. No changes saved.';
    });
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim())!;
    final selectedId = _selectedId;
    bool writeSucceeded = false;

    setState(() {
      _busy = true;
      _feedback = '';
    });

    try {
      if (selectedId == null) {
        // Omit the ID so SQLite assigns it.
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) return;

        writeSucceeded = true;

        setState(() {
          _clearForm();
          _feedback = 'Added guest with ID $id.';
        });
      } else {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) return;

        writeSucceeded = updated == 1;

        setState(() {
          if (updated == 1) {
            _clearForm();
            _feedback = 'Saved guest ID $selectedId. Rows updated: 1.';
          } else {
            _feedback =
                'Guest ID $selectedId no longer exists. '
                'Rows updated: $updated. Cancel edit to add a new guest.';
          }
        });
      }

      // Handle refresh failure separately from write failure.
      try {
        await _readRecords();
      } catch (error, stackTrace) {
        debugPrint('Refresh after save failed: $error\n$stackTrace');

        if (!mounted) return;

        setState(() {
          _readError = 'Refresh failed. Tap Refresh to retry.';
          _feedback += writeSucceeded
              ? ' Saved, but refresh failed.'
              : ' Could not refresh the list.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedback =
            'Could not save the guest. '
            'Your input was kept; try Add/Save again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;

    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id: $name?'),
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
          _feedback = 'Deletion canceled. No guest was removed.';
        });
        return;
      }

      final deleted = await widget.helper.delete(id);

      if (!mounted) return;

      setState(() {
        if (deleted == 1) {
          if (_selectedId == id) _clearForm();
          _feedback = 'Deleted guest ID $id. Rows deleted: 1.';
        } else {
          _feedback =
              'Guest ID $id no longer exists. '
              'Rows deleted: $deleted.';
        }
      });

      try {
        await _readRecords();
      } catch (error, stackTrace) {
        debugPrint('Refresh after delete failed: $error\n$stackTrace');

        if (!mounted) return;

        setState(() {
          _readError = 'Refresh failed. Tap Refresh to retry.';
          _feedback += deleted == 1
              ? ' Deleted, but refresh failed.'
              : ' Could not refresh the list.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedback = 'Could not delete guest ID $id. Try Delete again.';
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
      appBar: AppBar(
  title: const Text('Fall Festival Roster'),
  actions: [
    TextButton(
      onPressed: _busy
          ? null
          : () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CatalogueScreen(
                    repo: CatalogueRepo(widget.helper.database),
                  ),
                ),
              );
            },
      child: const Text('Catalogue'),
    ),
  ],
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
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value?.trim() ?? '');

                      if (age == null) {
                        return 'Enter a whole-number age.';
                      }
                      if (age < 0 || age > 130) {
                        return 'Age must be between 0 and 130.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_selectedId == null ? 'Add' : 'Save'),
                ),
                OutlinedButton(
                  onPressed: _busy || _selectedId == null ? null : _cancelEdit,
                  child: const Text('Cancel edit'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _hasLoaded
                  ? 'Record count: $_count'
                        '${_readError != null ? ' (last successful read)' : ''}'
                  : 'Record count: unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_feedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_feedback),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_readError != null) ...[
              const SizedBox(height: 12),
              Text(_readError!),
            ],
            const SizedBox(height: 16),
            if (!_busy && _hasLoaded && _readError == null && _rows.isEmpty)
              const Text('No festival guests yet'),
            for (final row in _rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${row[DatabaseHelper.columnId]}'),
                      Text('Name: ${row[DatabaseHelper.columnName]}'),
                      Text('Age: ${row[DatabaseHelper.columnAge]}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _edit(row),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _delete(row),
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
