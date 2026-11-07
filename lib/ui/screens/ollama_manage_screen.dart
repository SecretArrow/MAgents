import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/local_ai/external_ollama_scanner.dart';
import '../theme.dart';
import '../widgets/app_message.dart';

/// Local AI manager — initial version (port Fase 2, from ZAgents).
///
/// The full four-tab manager (bundled llama.cpp runtime, catalog,
/// installed models, downloads) lands with the Dart core + native
/// service in later phases. This first version covers Route D —
/// detecting an EXTERNAL Ollama server (on this device or the LAN):
///
/// * probe a host with `GET /api/version` (2.5 s timeout),
/// * on success, offer "Use as provider": upserts an `Ollama` provider
///   preset pointing at the server's OpenAI-compatible endpoint
///   (`http://<host>:11434/v1`, no API key) and activates it, exactly
///   like the providers screen activation.
///
/// The on-device runtime section is informational for now: without the
/// native `magents/llmserver` service the bundled runtime is
/// unavailable and the UI says so instead of pretending.
class OllamaManageScreen extends ConsumerStatefulWidget {
  const OllamaManageScreen({super.key});

  /// OpenAI-compatible base URL for a probed host: the scanner's
  /// normalized base, with the conventional Ollama port appended when
  /// the user typed a bare host, plus the `/v1` API prefix.
  static String providerBaseUrlFor(String host) {
    String base = ExternalOllamaScanner.normalizeHost(host);
    final Uri? uri = Uri.tryParse(base);
    if (uri != null && !uri.hasPort) base = '$base:11434';
    return '$base/v1';
  }

  @override
  ConsumerState<OllamaManageScreen> createState() =>
      _OllamaManageScreenState();
}

class _OllamaManageScreenState extends ConsumerState<OllamaManageScreen> {
  final TextEditingController _host = TextEditingController(
    text: '127.0.0.1:11434',
  );
  bool _probing = false;
  ExternalOllamaScan? _scan;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    if (_probing) return;
    final String host = _host.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _probing = true;
      _scan = null;
    });
    final ExternalOllamaScan scan = await ref
        .read(externalOllamaScannerProvider)
        .probe(host);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _scan = scan;
    });
    final AppStrings strings = stringsOf(context);
    showAppMessage(
      context,
      scan.ok
          ? strings.ollamaProbeOk(scan.version)
          : strings.ollamaProbeFail(scan.error ?? ''),
      error: !scan.ok,
    );
  }

  /// Upserts the `Ollama` preset for the probed host and activates it
  /// (same field combination as the providers screen activation).
  Future<void> _useAsProvider() async {
    final ExternalOllamaScan? scan = _scan;
    if (scan == null || !scan.ok) return;
    final AppSettings settings = ref.read(settingsProvider);
    final String baseUrl = OllamaManageScreen.providerBaseUrlFor(_host.text);
    ProviderPreset? existing;
    for (final ProviderPreset p in settings.presets) {
      if (p.name == 'Ollama') {
        existing = p;
        break;
      }
    }
    final ProviderPreset preset = (existing ??
            ProviderPreset(id: newId(), name: 'Ollama'))
        .copyWith(baseUrl: baseUrl, apiKey: '');
    final List<ProviderPreset> presets = existing == null
        ? <ProviderPreset>[...settings.presets, preset]
        : <ProviderPreset>[
            for (final ProviderPreset p in settings.presets)
              if (p.id == preset.id) preset else p,
          ];
    await ref
        .read(settingsProvider.notifier)
        .update(
          settings.copyWith(
            providerName: preset.name,
            baseUrl: preset.baseUrl,
            apiKey: preset.apiKey,
            model: preset.model,
            engine: preset.engine,
            presets: presets,
          ),
        );
    if (!mounted) return;
    showAppMessage(
      context,
      stringsOf(context).providerActivatedSnack(preset.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = stringsOf(context);
    final ZPalette palette = context.palette;
    final ExternalOllamaScan? scan = _scan;
    return Scaffold(
      appBar: AppBar(title: Text(strings.ollamaScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // -- On-device runtime (native service lands in a later
            // phase; degrade gracefully until then) -------------------
            Text(
              strings.ollamaOnDeviceTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.muted.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.ollamaOnDevicePending,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -- External Ollama server probe --------------------------
            Text(
              strings.ollamaExternalServerLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('ollama-external-host'),
              controller: _host,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('ollama-probe'),
                  onPressed: _probing ? null : _probe,
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: Text(strings.ollamaProbe),
                ),
                if (_probing) ...<Widget>[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ],
            ),
            if (scan != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                scan.ok
                    ? strings.ollamaProbeOk(scan.version)
                    : strings.ollamaProbeFail(scan.error ?? ''),
                key: const Key('ollama-probe-result'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: scan.ok ? null : palette.muted,
                ),
              ),
              if (scan.ok) ...<Widget>[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('ollama-use-as-provider'),
                    onPressed: _useAsProvider,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(strings.ollamaUseAsProvider),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
