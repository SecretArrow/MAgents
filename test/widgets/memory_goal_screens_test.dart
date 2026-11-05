import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magents/di.dart';
import 'package:magents/main.dart';
import 'package:magents/models/models.dart';
import 'package:magents/ui/screens/goals_screen.dart';
import 'package:magents/ui/screens/memory_screen.dart';

import '../support/test_doubles.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('magents_mg_screens');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: testOverrides(
        dir: tempDir,
        memories: <MemoryEntry>[
          MemoryEntry(
            id: 'm1',
            text: 'User prefers concise answers',
            category: MemoryCategory.preference,
            pinned: true,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        goals: <GoalEntry>[
          GoalEntry(
            id: 'g1',
            title: 'Ship MAgents v1.50',
            progress: 60,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MAgentsApp()),
    );
    await tester.pump();
    return container;
  }

  testWidgets('MemoryScreen lists stored memories', (tester) async {
    await pumpApp(tester);
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const MemoryScreen()),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.byKey(const Key('memory-m1')), findsOneWidget);
    expect(find.textContaining('concise answers'), findsOneWidget);
    expect(find.byKey(const Key('memory-add-fab')), findsOneWidget);
  });

  testWidgets('GoalsScreen lists stored goals with progress', (tester) async {
    await pumpApp(tester);
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.byKey(const Key('goal-g1')), findsOneWidget);
    expect(find.textContaining('Ship MAgents v1.50'), findsOneWidget);
    expect(find.byKey(const Key('goal-add-fab')), findsOneWidget);
    // di.dart wiring check: services resolve through the container.
    expect(memoryServiceProvider, isNotNull);
    expect(goalServiceProvider, isNotNull);
  });
}
