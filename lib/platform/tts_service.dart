import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/models/alarm.dart';

class TtsSynthesisStatus {
  final bool success;
  final String languageUsed;
  final String message;

  const TtsSynthesisStatus({
    required this.success,
    required this.languageUsed,
    required this.message,
  });
}

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
        debugPrint('[TtsService] Engine error: $msg');
      });
      _initialized = true;
    } catch (e) {
      debugPrint('[TtsService] Initialization warning: $e');
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    try {
      await initialize();
      final dynamic langs = await _flutterTts.getLanguages;
      if (langs is List) {
        return langs.map((e) => e.toString()).toList()..sort();
      }
    } catch (_) {}
    return SpeechLanguageOption.supported.map((e) => e.code).toList();
  }

  Future<TtsSynthesisStatus> speakText({
    required String text,
    String language = 'ur-PK',
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TtsSynthesisStatus(
        success: false,
        languageUsed: '',
        message: 'Cannot speak an empty message.',
      );
    }

    try {
      await initialize();
      await _flutterTts.stop();

      String resolvedLang = language;
      try {
        final available = await _flutterTts.isLanguageAvailable(language);
        if (available != 1 && available != true) {
          // Fallback to hi-IN or en-US if ur-PK voice pack is not installed on device
          final hiAvailable = await _flutterTts.isLanguageAvailable('hi-IN');
          if (hiAvailable == 1 || hiAvailable == true) {
            resolvedLang = 'hi-IN';
          } else {
            resolvedLang = 'en-US';
          }
        }
      } catch (_) {}

      await _flutterTts.setLanguage(resolvedLang);
      await _flutterTts.setSpeechRate(rate.clamp(0.1, 1.5));
      await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
      await _flutterTts.setVolume(1.0);

      _isSpeaking = true;
      await _flutterTts.speak(trimmed);
      return TtsSynthesisStatus(
        success: true,
        languageUsed: resolvedLang,
        message: 'Speaking message using TTS ($resolvedLang).',
      );
    } catch (e) {
      _isSpeaking = false;
      return TtsSynthesisStatus(
        success: false,
        languageUsed: language,
        message:
            'TTS engine unavailable in current environment ($e). On Android devices, install Google Speech Services.',
      );
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
