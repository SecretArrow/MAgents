# Muse ↔ MAgents — Parity Analysis

How Muse (the personal agent) works, and where MAgents stands after
v1.51.0. Status legend: **exists** (already there before this round),
**added** (this round: v1.50.0/v1.51.0), **not yet** (with the honest
technical reason).

| Muse way of working | MAgents status |
| --- | --- |
| Long-term memory that helps in later conversations | **added, deliberately different**: memory is **per chat** (key `magents.memory.v1.<sessionId>`), NOT global. The user explicitly decided (2026-11-05) that data must never mix between chats — *"jangan mengingat antar chat … jangan bercampur2 datanya nanti"* — matching this app's per-session sandbox philosophy (files/browser/modules are already per chat). Tools `memory_save/recall/list/forget` + prompt injection operate on the active chat only. The short-lived global build (v1.50.0 pre-release) was abandoned; its storage key is never migrated into any chat. |
| Goals with progress tracking | **added** (per chat, same user decision): `GoalEntry` + `goal_create/list/update/complete`, overdue/due-soon logic, prompt summary, Goals screen. Key `magents.goals.v1.<sessionId>`. |
| Plan / todos before working, run-until-done | **exists**: the agent loop plans with todo-style tool calls and runs until the task is done or genuinely blocked. |
| Parallel sub-agents | **exists**: `spawn_subagents` tool with per-chat isolation. |
| Skills: reusable SKILL.md playbooks the agent can save & reuse | **added**: Skills registry + Skills screen already existed (install from file/URL/bundled); the missing piece — saving a NEW skill from chat — is now the `skill_save` tool (validated front-matter, source recorded as `chat:<name>`). |
| Reminders & scheduled tasks (cron) running in the background | **added (best-effort)**: per-chat `ReminderEntry` (`reminder_create/list/complete`, repeat none/daily/weekly) and, since v1.52.0, a real **cron engine** owned per chat (`CronJob`, store `magents.cronjobs.v1.<sessionId>`): standard 5-field cron expressions, four actions (notification, Telegram with per-job credentials + global fallback, headless agent runs on the ACTIVE provider, chat injection defaulting to the OWNING chat), per-chat master switch + run history, automatic migration of the v1.51.0 once/daily/weekly/interval jobs (unmigratable ones stay visible in a Legacy section), `cron_create/list/update/delete/toggle` tools. Engine = check on app start/resume + a 1-minute timer while the app lives. **Honest limit**: Android kills background apps — precise firing while the app is dead needs AlarmManager/WorkManager, which is NOT wired yet, so jobs are best-effort (they catch up on next launch), never claimed as 100% background-reliable. |
| Proactive briefing (greets you with your context) | **added**: Briefing screen (drawer icon / Settings) aggregating the ACTIVE chat's active goals + progress, due reminders, next scheduled job and pinned memories via a pure-Dart `BriefingService`. Read-only by design. |
| Deliverables / artifacts: export the work | **exists + added**: Markdown chat export existed; v1.51.0 adds a self-contained **HTML export** (single file, inline CSS, long-press the drawer's export-chat button). |
| Voice in (dictation / STT) | **exists**. |
| Voice out (TTS read-back) | **not yet**: would need either a new TTS dependency or a hand-rolled Android TextToSpeech MethodChannel + lifecycle handling; judged too risky for this round, skipped deliberately rather than half-wired. |
| Connectors / multi-provider | **exists**: custom providers, modules/plugins, the JS module SDK, MCP-style tooling — not rebuilt. |
| Global chat search | **exists** (drawer search). |
| Encrypted backup | **exists** (`.zabak`, name kept for compatibility). |
| Biometric app lock | **exists**. |
| Per-session isolation | **exists** — and is the reason memory/goals/reminders/jobs are per-chat (see row 1). |
| Auto-retry | **exists** in the agent loop / provider layer. |
| Update checker | **exists**. |

## The one deliberate deviation

Muse remembers across conversations; MAgents (per the user's
explicit instruction) remembers **inside each chat only**. Everything
personal — memory, goals, reminders, scheduled jobs, briefing — is
scoped to the active chat so data can never leak or mix between chats.

## Local AI (v1.52.0) — beyond Muse parity

Not a Muse feature: two local-model routes under **Settings → Local AI →
Ollama Manage**. (1) External Ollama servers, probed over HTTP and
activated as an `Ollama` provider preset. (2) A bundled llama.cpp
`llama-server` (pinned b12182) cross-compiled per ABI by CI
(`.github/actions/llama-runtime`) and hosted by an Android foreground
service; the `Local AI` provider preset (`http://127.0.0.1:11434/v1`)
is filled from the running server, so chats, subagents and cron
agent/chat actions can all run fully on-device. Honest limits:
armeabi-v7a builds ship without the runtime (graceful
`runtimeAvailable = false`), the universal APK grows by the runtime
size, and cron precision stays best-effort as documented above.
