import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Abstraction over the persistent long-term memory storage (v1.50.0).
/// Follows the [ContextRepository] pattern: synchronous load, async save.
abstract class MemoryRepository {
  List<MemoryEntry> load();
  Future<void> save(List<MemoryEntry> entries);
}

/// SharedPreferences-backed store used in production. Uses the NEW
/// `magents.` key prefix; legacy `zagents.` keys are never touched.
class PrefsMemoryRepository implements MemoryRepository {
  PrefsMemoryRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String key = 'magents.memory.v1';

  static Future<PrefsMemoryRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsMemoryRepository(prefs);
  }

  @override
  List<MemoryEntry> load() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const <MemoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return <MemoryEntry>[
          for (final item in decoded)
            if (item is Map<String, dynamic>) MemoryEntry.fromJson(item),
        ];
      }
    } catch (_) {
      // Corrupted store: behave like an empty list, never crash.
    }
    return const <MemoryEntry>[];
  }

  @override
  Future<void> save(List<MemoryEntry> entries) async {
    await _prefs.setString(
      key,
      jsonEncode(<Map<String, dynamic>>[
        for (final MemoryEntry e in entries) e.toJson(),
      ]),
    );
  }
}

/// In-memory repository for unit and widget tests.
class InMemoryMemoryRepository implements MemoryRepository {
  InMemoryMemoryRepository([List<MemoryEntry>? initial])
    : _entries = initial ?? const <MemoryEntry>[];

  List<MemoryEntry> _entries;

  @override
  List<MemoryEntry> load() => List<MemoryEntry>.of(_entries);

  @override
  Future<void> save(List<MemoryEntry> entries) async {
    _entries = List<MemoryEntry>.of(entries);
  }
}
