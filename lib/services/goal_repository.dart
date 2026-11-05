import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Abstraction over the persistent goals storage (v1.50.0).
/// Same shape as the memory/context repositories.
abstract class GoalRepository {
  List<GoalEntry> load();
  Future<void> save(List<GoalEntry> entries);
}

/// SharedPreferences-backed store used in production (new `magents.` key).
class PrefsGoalRepository implements GoalRepository {
  PrefsGoalRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String key = 'magents.goals.v1';

  static Future<PrefsGoalRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsGoalRepository(prefs);
  }

  @override
  List<GoalEntry> load() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const <GoalEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return <GoalEntry>[
          for (final item in decoded)
            if (item is Map<String, dynamic>) GoalEntry.fromJson(item),
        ];
      }
    } catch (_) {
      // Corrupted store: behave like an empty list, never crash.
    }
    return const <GoalEntry>[];
  }

  @override
  Future<void> save(List<GoalEntry> entries) async {
    await _prefs.setString(
      key,
      jsonEncode(<Map<String, dynamic>>[
        for (final GoalEntry e in entries) e.toJson(),
      ]),
    );
  }
}

/// In-memory repository for unit and widget tests.
class InMemoryGoalRepository implements GoalRepository {
  InMemoryGoalRepository([List<GoalEntry>? initial])
    : _entries = initial ?? const <GoalEntry>[];

  List<GoalEntry> _entries;

  @override
  List<GoalEntry> load() => List<GoalEntry>.of(_entries);

  @override
  Future<void> save(List<GoalEntry> entries) async {
    _entries = List<GoalEntry>.of(entries);
  }
}
