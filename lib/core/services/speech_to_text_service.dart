import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Robust Speech-To-Text service supporting English, Arabic, and Urdu.
/// Offline-first design with graceful fallback to manual entry.
class SpeechToTextService {
  static final SpeechToTextService instance = SpeechToTextService._internal();

  SpeechToTextService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _currentLocaleId;
  List<stt.LocaleName> _availableLocales = [];

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;
  String? get currentLocaleId => _currentLocaleId;
  List<stt.LocaleName> get availableLocales => _availableLocales;

  /// Initializes speech recognition engine with status listener.
  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          _isListening = _speech.isListening;
          onStatus?.call(status);
        },
        onError: (errorNotification) {
          _isListening = false;
          onError?.call(errorNotification.errorMsg);
        },
      );

      if (_isInitialized) {
        _availableLocales = await _speech.locales();
        final systemLocale = await _speech.systemLocale();
        _currentLocaleId = systemLocale?.localeId;
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('SpeechToText init exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Sets the preferred language for speech recognition (e.g. 'ar_SA', 'ur_PK', 'en_US').
  void setLocale(String localeId) {
    _currentLocaleId = localeId;
  }

  /// Begins listening and invokes onResult callback with transcribed text.
  Future<bool> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    required BuildContext context,
    String? preferredLocale,
  }) async {
    final ready = await initialize(
      onError: (msg) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Voice recognition could not be completed ($msg). You can enter the description manually.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );

    if (!ready) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone or speech service is currently unavailable. Please enter the description manually.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    try {
      final targetLocale = preferredLocale ?? _currentLocaleId;

      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: targetLocale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );

      _isListening = true;
      return true;
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice recognition could not be started. You can enter the description manually.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Stops active speech listening session.
  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
      }
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
  }

  /// Cancels listening session.
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _isListening = false;
    } catch (e) {
      debugPrint('Speech cancel error: $e');
    }
  }
}
