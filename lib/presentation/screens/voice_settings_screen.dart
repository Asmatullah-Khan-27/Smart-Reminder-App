import 'package:flutter/material.dart';
import '../../domain/models/alarm.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';

class VoiceSettingsScreen extends StatefulWidget {
  final AppController controller;

  const VoiceSettingsScreen({super.key, required this.controller});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late final TextEditingController _testPhraseController;

  @override
  void initState() {
    super.initState();
    _testPhraseController = TextEditingController(
      text: Alarm.defaultRomanUrduMessage,
    );
  }

  @override
  void dispose() {
    widget.controller.ttsService.stop();
    _testPhraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final s = widget.controller.speechSettings;

        return GlassScaffold(
          themeSettings: widget.controller.themeSettings,
          appBar: AppBar(
            title: const Text('Voice & TTS Engine Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Text-to-Speech (TTS) Alarm Defaults',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: SpeechLanguageOption.supported
                              .any((e) => e.code == s.defaultLanguage)
                          ? s.defaultLanguage
                          : 'ur-PK',
                      decoration: const InputDecoration(
                        labelText: 'Default Spoken Alarm Language',
                        prefixIcon: Icon(Icons.language_rounded),
                      ),
                      items: SpeechLanguageOption.supported.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt.code,
                          child: Text(opt.label),
                        );
                      }).toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          widget.controller.updateSpeechSettings(
                            s.copyWith(defaultLanguage: val),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 115,
                          child: Text('Default Rate'),
                        ),
                        Expanded(
                          child: Slider(
                            value: s.defaultSpeechRate.clamp(0.25, 1.5),
                            min: 0.25,
                            max: 1.5,
                            divisions: 25,
                            onChanged: (double val) {
                              widget.controller.updateSpeechSettings(
                                s.copyWith(defaultSpeechRate: val),
                              );
                            },
                          ),
                        ),
                        Text('${s.defaultSpeechRate.toStringAsFixed(2)}x'),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 115,
                          child: Text('Default Pitch'),
                        ),
                        Expanded(
                          child: Slider(
                            value: s.defaultSpeechPitch.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            divisions: 30,
                            onChanged: (double val) {
                              widget.controller.updateSpeechSettings(
                                s.copyWith(defaultSpeechPitch: val),
                              );
                            },
                          ),
                        ),
                        Text(s.defaultSpeechPitch.toStringAsFixed(2)),
                      ],
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Request Transient Audio Focus'),
                      subtitle: const Text(
                        'Ducks background media playback while speaking alarm message',
                      ),
                      value: s.respectAudioFocus,
                      onChanged: (bool val) {
                        widget.controller.updateSpeechSettings(
                          s.copyWith(respectAudioFocus: val),
                        );
                      },
                    ),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Spoken Loop Count During Native Alarm',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DropdownButton<int>(
                          value: s.repeatCountOnAlarm,
                          items: const <int>[1, 2, 3, 5, 10]
                              .map(
                                (c) => DropdownMenuItem<int>(
                                  value: c,
                                  child: Text('$c time(s)'),
                                ),
                              )
                              .toList(),
                          onChanged: (int? v) {
                            if (v != null) {
                              widget.controller.updateSpeechSettings(
                                s.copyWith(repeatCountOnAlarm: v),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Live TTS Test Bench
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Live TTS Voice Synthesis Bench',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _testPhraseController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sample Phrase to Speak',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final res = await widget.controller.ttsService
                                  .speakText(
                                text: _testPhraseController.text,
                                language: s.defaultLanguage,
                                rate: s.defaultSpeechRate,
                                pitch: s.defaultSpeechPitch,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message)),
                                );
                              }
                            },
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Test Voice Synthesis'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => widget.controller.ttsService.stop(),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Speech-to-Text Input Locale
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Speech-to-Text (Microphone Dictation) Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Used when dictating reminder titles and notes via microphone (distinct from TTS output).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: const <String>['en_US', 'ur_PK', 'hi_IN']
                              .contains(s.voiceInputLocale)
                          ? s.voiceInputLocale
                          : 'en_US',
                      decoration: const InputDecoration(
                        labelText: 'Default Speech Recognition Locale',
                        prefixIcon: Icon(Icons.mic_rounded),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'en_US',
                          child: Text('English — United States (en_US)'),
                        ),
                        DropdownMenuItem(
                          value: 'ur_PK',
                          child: Text('Urdu — Pakistan (ur_PK)'),
                        ),
                        DropdownMenuItem(
                          value: 'hi_IN',
                          child: Text('Hindi — India (hi_IN)'),
                        ),
                      ],
                      onChanged: (String? val) {
                        if (val != null) {
                          widget.controller.updateSpeechSettings(
                            s.copyWith(voiceInputLocale: val),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
