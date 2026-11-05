import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/scheduled_job_runner.dart';
import '../../services/telegram_sender.dart';
import '../theme.dart';
import '../widgets/app_message.dart';

/// CronJobs of the ACTIVE chat (v1.51.0, Fase F) — full-screen manager
/// reached from Settings (right below Appearance) and the drawer.
/// Holds BOTH the job list/editor AND the Telegram channel config, so
/// everything scheduled lives on one roomy page. Jobs are a LIST: a
/// chat can own many independent jobs (see service cap of 100).
class CronJobsScreen extends ConsumerStatefulWidget {
  const CronJobsScreen({super.key});

  @override
  ConsumerState<CronJobsScreen> createState() => _CronJobsScreenState();
}

class _CronJobsScreenState extends ConsumerState<CronJobsScreen> {
  final TextEditingController _token = TextEditingController();
  final TextEditingController _chatId = TextEditingController();
  bool _configLoaded = false;
  String _testStatus = '';

  String get _sessionId => ref.read(activeSessionIdProvider) ?? '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _token.dispose();
    _chatId.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final TelegramConfig config = await ref
          .read(telegramConfigStoreProvider)
          .load();
      if (!mounted) return;
      _token.text = config.botToken;
      _chatId.text = config.chatId;
    } catch (_) {
      // Config storage unavailable (tests): fields stay empty.
    }
    if (mounted) setState(() => _configLoaded = true);
  }

  Future<void> _saveConfig() async {
    await ref
        .read(telegramConfigStoreProvider)
        .save(
          TelegramConfig(
            botToken: _token.text.trim(),
            chatId: _chatId.text.trim(),
          ),
        );
    if (mounted) showAppMessage(context, 'Telegram settings saved');
  }

  Future<void> _sendTest() async {
    setState(() => _testStatus = 'Sending…');
    final TelegramResult result = await TelegramSender().send(
      botToken: _token.text,
      chatId: _chatId.text,
      text: 'MAgents CronJobs test message — your Telegram channel works.',
    );
    if (!mounted) return;
    setState(
      () => _testStatus = result.ok
          ? 'Test message sent ✓'
          : 'Failed: ${result.message}',
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(scheduledJobListProvider(_sessionId));
    if (mounted) setState(() {});
  }

  Future<void> _openEditor([ScheduledJob? existing]) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CronJobEditorScreen(existing: existing),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _delete(ScheduledJob job) async {
    final AppStrings strings = stringsOf(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: context.zSurface,
        title: const Text('Delete job?'),
        content: Text('Job "${job.title}" will be removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(scheduledJobServiceProvider).remove(_sessionId, job.id);
    await _refresh();
  }

  String _scheduleSummary(ScheduledJob j) {
    final String time =
        '${j.hour.toString().padLeft(2, '0')}:${j.minute.toString().padLeft(2, '0')}';
    return switch (j.kind) {
      JobScheduleKind.once =>
        'once · ${j.runAt?.toIso8601String().substring(0, 16).replaceAll('T', ' ') ?? '—'}',
      JobScheduleKind.daily => 'daily · $time',
      JobScheduleKind.weekly => 'weekly · day ${j.weekday} · $time',
      JobScheduleKind.interval => 'every ${j.intervalMinutes} min',
    };
  }

  @override
  Widget build(BuildContext context) {
    final String? sessionId = ref.watch(activeSessionIdProvider);
    if (sessionId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('CronJobs')),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: context.zMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Open a chat first',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'CronJobs belong to one chat each, so data never mixes '
                'between chats. Open a chat to manage its jobs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.zMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    final List<ScheduledJob> jobs =
        ref.watch(scheduledJobListProvider(sessionId)).value ??
        const <ScheduledJob>[];
    return Scaffold(
      appBar: AppBar(title: const Text('CronJobs')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('cron-add-fab'),
        heroTag: 'cron-add',
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New job'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          // -- Telegram channel -------------------------------------------
          Container(
            key: const Key('telegram-card'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.zSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.zBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.send_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Telegram (for telegram / both jobs)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('telegram-token-field'),
                  controller: _token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Bot token (stored encrypted)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('telegram-chat-id-field'),
                  controller: _chatId,
                  decoration: const InputDecoration(labelText: 'Chat ID'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton(
                      key: const Key('telegram-save-button'),
                      onPressed: _configLoaded ? _saveConfig : null,
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('telegram-test-button'),
                      onPressed: _sendTest,
                      child: const Text('Send test'),
                    ),
                  ],
                ),
                if (_testStatus.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_testStatus, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No jobs yet for THIS chat. Add as many as you like — '
                'each job fires independently.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.zMuted),
              ),
            ),
          for (final ScheduledJob job in jobs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: context.zSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.zBorder),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: Key('cron-job-${job.id}'),
                  title: Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    <String>[
                      _scheduleSummary(job),
                      job.action.name,
                      if (job.nextRunAt != null)
                        'next ${job.nextRunAt!.toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
                      if (job.lastStatus.isNotEmpty) 'last: ${job.lastStatus}',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Switch(
                        key: Key('cron-switch-${job.id}'),
                        value: job.enabled,
                        onChanged: (bool v) async {
                          await ref
                              .read(scheduledJobServiceProvider)
                              .update(sessionId, job.id, enabled: v);
                          await _refresh();
                        },
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        onSelected: (String action) {
                          if (action == 'edit') _openEditor(job);
                          if (action == 'delete') _delete(job);
                        },
                        itemBuilder: (BuildContext menuContext) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(job),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-page job editor (v1.51.0): roomy form, not a dialog.
class CronJobEditorScreen extends ConsumerStatefulWidget {
  const CronJobEditorScreen({super.key, this.existing});

  final ScheduledJob? existing;

  @override
  ConsumerState<CronJobEditorScreen> createState() =>
      _CronJobEditorScreenState();
}

class _CronJobEditorScreenState extends ConsumerState<CronJobEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _runAt;
  late final TextEditingController _interval;
  late JobScheduleKind _kind;
  late JobAction _action;
  late TimeOfDay _time;
  late int _weekday;

  @override
  void initState() {
    super.initState();
    final ScheduledJob? e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _message = TextEditingController(text: e?.message ?? '');
    _runAt = TextEditingController(
      text: (e?.runAt ?? DateTime.now().add(const Duration(hours: 1)))
          .toIso8601String()
          .substring(0, 16)
          .replaceAll('T', ' '),
    );
    _interval = TextEditingController(text: '${e?.intervalMinutes ?? 60}');
    _kind = e?.kind ?? JobScheduleKind.once;
    _action = e?.action ?? JobAction.notify;
    _time = TimeOfDay(hour: e?.hour ?? 9, minute: e?.minute ?? 0);
    _weekday = e?.weekday ?? 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _runAt.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final String sessionId = ref.read(activeSessionIdProvider) ?? '';
    final service = ref.read(scheduledJobServiceProvider);
    final DateTime? runAt = DateTime.tryParse(_runAt.text.trim());
    if (widget.existing == null) {
      await service.create(
        sessionId,
        title: _title.text,
        message: _message.text,
        kind: _kind,
        hour: _time.hour,
        minute: _time.minute,
        weekday: _weekday,
        intervalMinutes: int.tryParse(_interval.text.trim()) ?? 60,
        runAt: runAt,
        action: _action,
      );
    } else {
      await service.update(
        sessionId,
        widget.existing!.id,
        title: _title.text,
        message: _message.text,
        kind: _kind,
        hour: _time.hour,
        minute: _time.minute,
        weekday: _weekday,
        intervalMinutes: int.tryParse(_interval.text.trim()) ?? 60,
        runAt: runAt,
        action: _action,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New job' : 'Edit job'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            key: const Key('cron-title-field'),
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cron-message-field'),
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message (sent / shown when the job fires)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JobScheduleKind>(
            key: const Key('cron-kind-field'),
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Schedule'),
            items: <DropdownMenuItem<JobScheduleKind>>[
              for (final JobScheduleKind k in JobScheduleKind.values)
                DropdownMenuItem<JobScheduleKind>(
                  value: k,
                  child: Text(k.name),
                ),
            ],
            onChanged: (JobScheduleKind? v) =>
                setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JobAction>(
            key: const Key('cron-action-field'),
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'Action'),
            items: <DropdownMenuItem<JobAction>>[
              for (final JobAction a in JobAction.values)
                DropdownMenuItem<JobAction>(value: a, child: Text(a.name)),
            ],
            onChanged: (JobAction? v) => setState(() => _action = v ?? _action),
          ),
          const SizedBox(height: 12),
          if (_kind == JobScheduleKind.once)
            TextField(
              key: const Key('cron-runat-field'),
              controller: _runAt,
              decoration: const InputDecoration(
                labelText: 'Fire at (YYYY-MM-DD HH:MM)',
              ),
            ),
          if (_kind == JobScheduleKind.daily || _kind == JobScheduleKind.weekly)
            ListTile(
              key: const Key('cron-time-tile'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Time of day'),
              subtitle: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),
          if (_kind == JobScheduleKind.weekly)
            DropdownButtonFormField<int>(
              key: const Key('cron-weekday-field'),
              initialValue: _weekday,
              decoration: const InputDecoration(
                labelText: 'Weekday (1 = Mon … 7 = Sun)',
              ),
              items: <DropdownMenuItem<int>>[
                for (int d = 1; d <= 7; d++)
                  DropdownMenuItem<int>(value: d, child: Text('$d')),
              ],
              onChanged: (int? v) => setState(() => _weekday = v ?? _weekday),
            ),
          if (_kind == JobScheduleKind.interval)
            TextField(
              key: const Key('cron-interval-field'),
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Interval (minutes)',
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('cron-save-button'),
            onPressed: _save,
            child: const Text('Save job'),
          ),
        ],
      ),
    );
  }
}
