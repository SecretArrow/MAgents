import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magents/di.dart';
import 'package:magents/l10n/app_strings.dart';
import 'package:magents/models/models.dart';
import 'package:magents/services/local_ai/external_ollama_scanner.dart';
import 'package:magents/services/settings_repository.dart';
import 'package:magents/ui/screens/ollama_manage_screen.dart';

/// Port Fase 2 — the initial Local AI screen: probe an external Ollama
/// server and, on success, upsert + activate an `Ollama` provider
/// preset pointing at its OpenAI-compatible endpoint.
class _FakeScanner extends ExternalOllamaScanner {
  _FakeScanner(this.scan);

  final ExternalOllamaScan scan;
  String? probedHost;

  @override
  Future<ExternalOllamaScan> probe(String host) async {
    probedHost = host;
    return scan;
  }
}

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    _FakeScanner scanner,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(
          MemorySettingsRepository(),
        ),
        externalOllamaScannerProvider.overrideWithValue(scanner),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            zLocalizationsDelegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OllamaManageScreen(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('probe success offers Use as provider and activates it', (
    tester,
  ) async {
    final _FakeScanner scanner = _FakeScanner(
      const ExternalOllamaScan(
        host: '127.0.0.1:11434',
        ok: true,
        version: '0.12.6',
      ),
    );
    final ProviderContainer container = await pumpScreen(tester, scanner);

    expect(find.byKey(const Key('ollama-external-host')), findsOneWidget);
    expect(find.byKey(const Key('ollama-use-as-provider')), findsNothing);

    await tester.tap(find.byKey(const Key('ollama-probe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scanner.probedHost, '127.0.0.1:11434');
    expect(find.byKey(const Key('ollama-probe-result')), findsOneWidget);
    expect(find.textContaining('reachable'), findsWidgets);
    expect(find.byKey(const Key('ollama-use-as-provider')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ollama-use-as-provider')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final AppSettings settings = container.read(settingsProvider);
    expect(settings.providerName, 'Ollama');
    expect(settings.baseUrl, 'http://127.0.0.1:11434/v1');
    expect(
      settings.presets.where((ProviderPreset p) => p.name == 'Ollama').length,
      1,
    );
    expect(
      settings.presets
          .singleWhere((ProviderPreset p) => p.name == 'Ollama')
          .baseUrl,
      'http://127.0.0.1:11434/v1',
    );
  });

  testWidgets('probe failure shows the error and no provider button', (
    tester,
  ) async {
    final _FakeScanner scanner = _FakeScanner(
      const ExternalOllamaScan(host: '127.0.0.1:11434', error: 'HTTP 404'),
    );
    await pumpScreen(tester, scanner);

    await tester.tap(find.byKey(const Key('ollama-probe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('No Ollama server found'), findsWidgets);
    expect(find.byKey(const Key('ollama-use-as-provider')), findsNothing);
  });

  test('providerBaseUrlFor appends the default port only when missing', () {
    expect(
      OllamaManageScreen.providerBaseUrlFor('127.0.0.1:11434'),
      'http://127.0.0.1:11434/v1',
    );
    expect(
      OllamaManageScreen.providerBaseUrlFor('192.168.1.42'),
      'http://192.168.1.42:11434/v1',
    );
    expect(
      OllamaManageScreen.providerBaseUrlFor('https://ollama.lan:9999/'),
      'https://ollama.lan:9999/v1',
    );
  });
}
