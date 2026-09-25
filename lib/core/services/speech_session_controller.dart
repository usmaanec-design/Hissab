import 'package:flutter/material.dart';
import 'speech_to_text_service.dart';

enum SpeechSessionStatus {
  idle,
  listening,
  paused,
  processing,
  completed,
  error,
}

enum SpeechLanguageMode {
  auto,
  urdu,
  english,
  arabic,
}

extension SpeechLanguageModeExt on SpeechLanguageMode {
  String get displayName {
    switch (this) {
      case SpeechLanguageMode.auto:
        return 'Auto';
      case SpeechLanguageMode.urdu:
        return 'اردو';
      case SpeechLanguageMode.english:
        return 'English';
      case SpeechLanguageMode.arabic:
        return 'العربية';
    }
  }

  String? get localeId {
    switch (this) {
      case SpeechLanguageMode.auto:
        return null;
      case SpeechLanguageMode.urdu:
        return 'ur_PK';
      case SpeechLanguageMode.english:
        return 'en_US';
      case SpeechLanguageMode.arabic:
        return 'ar_SA';
    }
  }
}

/// Production controller managing live voice transcription sessions with:
/// - Real-time progressive typing (committedText + partialText = visibleTranscript)
/// - Manual edit protection: manual user edits during speech are NEVER overwritten by subsequent speech results
/// - Pause, resume, and done controls
/// - Multilingual support (Auto, Urdu, English, Arabic)
/// - Safe offline fallback
class SpeechSessionController extends ChangeNotifier {
  final SpeechToTextService _speechService = SpeechToTextService.instance;

  SpeechSessionStatus _status = SpeechSessionStatus.idle;
  SpeechLanguageMode _languageMode = SpeechLanguageMode.auto;
  String _committedText = '';
  String _partialText = '';
  bool _hasManualEdits = false;
  String? _errorMessage;

  SpeechSessionStatus get status => _status;
  SpeechLanguageMode get languageMode => _languageMode;
  String get committedText => _committedText;
  String get partialText => _partialText;
  bool get hasManualEdits => _hasManualEdits;
  String? get errorMessage => _errorMessage;
  bool get isListening => _status == SpeechSessionStatus.listening;
  bool get isPaused => _status == SpeechSessionStatus.paused;

  String get visibleTranscript {
    final cleanCommitted = _committedText.trim();
    final cleanPartial = _partialText.trim();
    if (cleanCommitted.isEmpty) return cleanPartial;
    if (cleanPartial.isEmpty) return cleanCommitted;
    return '$cleanCommitted $cleanPartial';
  }

  void setLanguageMode(SpeechLanguageMode mode) {
    _languageMode = mode;
    notifyListeners();
  }

  /// Called when the user manually types or corrects text in the TextField.
  /// Locks the user's manual correction so incoming speech events will not overwrite it.
  void notifyUserManualEdit(String newText) {
    _hasManualEdits = true;
    _committedText = newText;
    _partialText = '';
    notifyListeners();
  }

  /// Begins a real-time live transcription session.
  Future<bool> startSession({
    required BuildContext context,
    required String initialText,
    required Function(String fullTranscript) onTranscriptUpdate,
  }) async {
    _committedText = initialText.trim();
    _partialText = '';
    _hasManualEdits = false;
    _errorMessage = null;
    _status = SpeechSessionStatus.listening;
    notifyListeners();

    final targetLocale = _resolveLocale();

    final success = await _speechService.startListening(
      context: context,
      preferredLocale: targetLocale,
      onResult: (words, isFinal) {
        if (_status != SpeechSessionStatus.listening) return;

        // If the user manually edited during speech, protect their edits!
        // We only append new distinct words to their committed text.
        if (_hasManualEdits) {
          // Keep user manual text and append newly recognized segment
          _partialText = words;
        } else {
          _partialText = words;
        }

        if (isFinal) {
          if (_committedText.isNotEmpty && words.isNotEmpty) {
            if (!_committedText.endsWith(words)) {
              _committedText = '$_committedText $words'.trim();
            }
          } else if (words.isNotEmpty) {
            _committedText = words.trim();
          }
          _partialText = '';
          _hasManualEdits = false;
        }

        onTranscriptUpdate(visibleTranscript);
        notifyListeners();
      },
    );

    if (!success) {
      _status = SpeechSessionStatus.error;
      _errorMessage = 'Speech recognition unavailable';
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Temporarily pause speech listening while preserving the current transcript.
  Future<void> pauseSession() async {
    if (_status != SpeechSessionStatus.listening) return;
    await _speechService.stopListening();
    _status = SpeechSessionStatus.paused;
    notifyListeners();
  }

  /// Resume listening after pause, retaining all previous text.
  Future<bool> resumeSession({
    required BuildContext context,
    required String currentFieldText,
    required Function(String fullTranscript) onTranscriptUpdate,
  }) async {
    _committedText = currentFieldText.trim();
    _partialText = '';
    _hasManualEdits = false;
    _status = SpeechSessionStatus.listening;
    notifyListeners();

    return startSession(
      context: context,
      initialText: currentFieldText,
      onTranscriptUpdate: onTranscriptUpdate,
    );
  }

  /// Conclude voice recording, commit all pending text, and return to idle state.
  Future<void> stopSession({required Function(String finalTranscript) onFinal}) async {
    await _speechService.stopListening();
    final finalText = visibleTranscript;
    _committedText = finalText;
    _partialText = '';
    _status = SpeechSessionStatus.completed;
    onFinal(finalText);
    notifyListeners();

    // Reset back to idle after brief completion state
    Future.delayed(const Duration(milliseconds: 600), () {
      _status = SpeechSessionStatus.idle;
      notifyListeners();
    });
  }

  String? _resolveLocale() {
    if (_languageMode == SpeechLanguageMode.auto) {
      // In auto mode, inspect existing text for Arabic/Urdu script
      if (_committedText.isNotEmpty) {
        final hasArabicScript = RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(_committedText);
        if (hasArabicScript) {
          return 'ur_PK'; // Or system Arabic/Urdu
        }
      }
      return null; // System default auto
    }
    return _languageMode.localeId;
  }
}
