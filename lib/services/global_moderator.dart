import 'dart:convert';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class GlobalLanguageShield {
  final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
  Map<String, dynamic>? textBlacklist;
  Map<String, dynamic>? visualTriggerList;

  GlobalLanguageShield({this.textBlacklist, this.visualTriggerList});

  Future<String> getLanguage(String text) async {
    try {
      return await languageIdentifier.identifyLanguage(text);
    } catch (e) {
      print("Error identifying language: $e");
      return "unknown";
    }
  }

  /// Check if text is toxic using local blacklist + cloud API
  Future<bool> isToxic(String text, String langCode) async {
    // First check: Local blacklist lookup
    if (textBlacklist != null) {
      bool foundInLocal = _checkLocalBlacklist(text, langCode);
      if (foundInLocal) return true;
    }

    // Second check: Cloud toxicity API (2026 Standard)
    try {
      var toxicityScore = await _getAIToxicityScore(text, langCode);
      return toxicityScore > 0.85;
    } catch (e) {
      print("Error checking toxicity: $e");
      return false;
    }
  }

  /// Check text against local blacklist
  bool _checkLocalBlacklist(String text, String langCode) {
    if (textBlacklist == null) return false;

    String cleanText = text.toLowerCase();
    Map<String, dynamic> blacklists = textBlacklist!['blacklists'] ?? {};

    // Check specific language or all languages
    for (var lang in blacklists.keys) {
      if (langCode.isNotEmpty && lang != langCode && lang != "global") continue;

      List<dynamic> words = blacklists[lang] ?? [];
      for (var word in words) {
        if (cleanText.contains(word.toString().toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Simulate AI Provider toxicity scoring (replace with real API)
  Future<double> _getAIToxicityScore(String text, String langCode) async {
    // In production, call your LLM API (OpenAI, Cohere, etc.)
    // For now, return a mock score
    await Future.delayed(Duration(milliseconds: 100));
    return 0.5; // Mock response
  }

  /// Get violation reason
  String getViolationReason(String text, String langCode) {
    String cleanText = text.toLowerCase();
    
    if (textBlacklist != null) {
      Map<String, dynamic> blacklists = textBlacklist!['blacklists'] ?? {};
      for (var lang in blacklists.keys) {
        List<dynamic> words = blacklists[lang] ?? [];
        for (var word in words) {
          if (cleanText.contains(word.toString().toLowerCase())) {
            return "OFFENSIVE_CONTENT_${lang.toUpperCase()}";
          }
        }
      }
    }
    return "TOXICITY_DETECTED_$langCode";
  }

  void dispose() {
    languageIdentifier.close();
  }
}

/// Unified Moderation Engine combining text + vision
class UnifiedModerationEngine {
  final GlobalLanguageShield textShield;
  final List<String> visualBlacklist;
  
  UnifiedModerationEngine({
    required this.textShield,
    this.visualBlacklist = const ["weapon", "offensive_sign", "hateful_gesture"],
  });

  /// Check if object detected is in visual trigger list
  bool isVisualThreat(List<String> detectedLabels) {
    for (var label in detectedLabels) {
      for (var trigger in visualBlacklist) {
        if (label.toLowerCase().contains(trigger.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Comprehensive moderation result
  Future<ModerationResult> moderate(String? text, List<String>? detectedObjects) async {
    bool textViolation = false;
    bool visualViolation = false;
    String reason = "CLEAN";
    String language = "unknown";

    // Text moderation
    if (text != null && text.isNotEmpty) {
      language = await textShield.getLanguage(text);
      textViolation = await textShield.isToxic(text, language);
      if (textViolation) {
        reason = textShield.getViolationReason(text, language);
      }
    }

    // Visual moderation
    if (detectedObjects != null && detectedObjects.isNotEmpty) {
      visualViolation = isVisualThreat(detectedObjects);
      if (visualViolation) {
        reason = "PROHIBITED_OBJECT_DETECTED";
      }
    }

    return ModerationResult(
      isBlocked: textViolation || visualViolation,
      reason: reason,
      detectedLanguage: language,
      visualThreatDetected: visualViolation,
      detectedObjects: detectedObjects ?? [],
      severity: (textViolation && visualViolation) ? "CRITICAL" : 
                (textViolation || visualViolation) ? "HIGH" : "NONE",
    );
  }
}

class ModerationResult {
  final bool isBlocked;
  final String reason;
  final String detectedLanguage;
  final bool visualThreatDetected;
  final List<String> detectedObjects;
  final String severity;

  ModerationResult({
    required this.isBlocked,
    required this.reason,
    required this.detectedLanguage,
    required this.visualThreatDetected,
    required this.detectedObjects,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    "blocked": isBlocked,
    "reason": reason,
    "language": detectedLanguage,
    "visual_threat": visualThreatDetected,
    "objects": detectedObjects,
    "severity": severity,
  };
}