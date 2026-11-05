import '../models/models.dart';
import 'goal_service.dart';
import 'memory_service.dart';
import 'reminder_service.dart';
import 'scheduled_job_service.dart';

/// Aggregated briefing for ONE chat (v1.51.0, Fase E/F): the personal-
/// agent greeting card — this chat's active goals, due reminders, next
/// scheduled job and pinned memories. Pure aggregation over the other
/// per-chat services, unit-testable without any UI.
class BriefingData {
  const BriefingData({
    required this.goals,
    required this.dueReminders,
    required this.nextJob,
    required this.pinnedMemories,
  });

  final List<GoalEntry> goals;
  final List<ReminderEntry> dueReminders;
  final ScheduledJob? nextJob;
  final List<MemoryEntry> pinnedMemories;

  bool get isEmpty =>
      goals.isEmpty &&
      dueReminders.isEmpty &&
      nextJob == null &&
      pinnedMemories.isEmpty;
}

class BriefingService {
  BriefingService({
    required this.goals,
    required this.reminders,
    required this.memory,
    required this.jobs,
  });

  final GoalService goals;
  final ReminderService reminders;
  final MemoryService memory;
  final ScheduledJobService jobs;

  BriefingData build(String sessionId, {DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return BriefingData(
      goals: goals.active(sessionId),
      dueReminders: reminders.due(sessionId, at),
      nextJob: jobs.nextUpcoming(sessionId, at),
      pinnedMemories: memory
          .list(sessionId)
          .where((MemoryEntry e) => e.pinned)
          .toList(),
    );
  }
}
