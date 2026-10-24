import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputSessionState {
  final bool isInitialized;
  final bool isListening;
  final bool hasPermission;
  final String recognizedWords;
  final double confidence;
  final String? errorMessage;

  const VoiceInputSessionState({
    this.isInitialized = false,
    this.isListening = false,
    this.hasPermission = false,
    this.recognizedWords = '',
    this.confidence = 0.0,
    this.errorMessage,
  });

  VoiceInputSessionState copyWith({
    bool? isInitialized,
    bool? isListening,
    bool? hasPermission,
    String? recognizedWords,
    double? confidence,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceInputSessionState(
      isInitialized: isInitialized ?? this.isInitialized,
      isListening: isListening ?? this.isListening,
      hasPermission: hasPermission ?? this.hasPermission,
      recognizedWords: recognizedWords ?? this.recognizedWords,
      confidence: confidence ?? this.confidence,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoiceInputService {
  final SpeechToText _speechToText = SpeechToText();
  VoiceInputSessionState _state = const VoiceInputSessionState();

  VoiceInputSessionState get state => _state;

  Future<VoiceInputSessionState> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    try {
      final available = await _speechToText.initialize(
        onStatus: (String status) {
          final listening = _speechToText.isListening;
          _state = _state.copyWith(isListening: listening);
          onStatus?.call(status);
        },
        onError: (SpeechRecognitionError error) {
          _state = _state.copyWith(
            isListening: false,
            errorMessage: 'Speech recognition error: ${error.errorMsg}',
          );
          onError?.call(error.errorMsg);
        },
      );
      final hasPerm = await _speechToText.hasPermission;
      _state = _state.copyWith(
        isInitialized: available,
        hasPermission: hasPerm,
        clearError: available,
        errorMessage: available
            ? null
            : 'Speech recognition service or microphone permission is unavailable on this device. Please use manual keyboard entry.',
      );
      return _state;
    } catch (e) {
      debugPrint('[VoiceInputService] initialize failed: $e');
      _state = _state.copyWith(
        isInitialized: false,
        isListening: false,
        hasPermission: false,
        errorMessage:
            'Microphone speech recognition is unavailable in this environment ($e). You can enter or edit reminder text manually.',
      );
      return _state;
    }
  }

  Future<List<LocaleName>> getAvailableLocales() async {
    try {
      if (!_state.isInitialized) {
        await initialize();
      }
      if (_state.isInitialized) {
        return await _speechToText.locales();
      }
    } catch (_) {}
    return <LocaleName>[
      LocaleName('en_US', 'English (United States)'),
      LocaleName('ur_PK', 'Urdu (Pakistan)'),
      LocaleName('hi_IN', 'Hindi (India)'),
    ];
  }

  Future<VoiceInputSessionState> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_state.isInitialized) {
      await initialize();
    }
    if (!_state.isInitialized) {
      return _state;
    }

    try {
      await _speechToText.listen(
        // ignore: deprecated_member_use
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (SpeechRecognitionResult result) {
          _state = _state.copyWith(
            recognizedWords: result.recognizedWords,
            confidence: result.confidence,
            isListening: !result.finalResult,
            clearError: true,
          );
          onResult(result.recognizedWords, result.finalResult);
        },
      );
      _state = _state.copyWith(isListening: true, clearError: true);
    } catch (e) {
      _state = _state.copyWith(
        isListening: false,
        errorMessage: 'Failed to start listening: $e',
      );
    }
    return _state;
  }

  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
    _state = _state.copyWith(isListening: false);
  }

  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
    } catch (_) {}
    _state = _state.copyWith(isListening: false);
  }
}
