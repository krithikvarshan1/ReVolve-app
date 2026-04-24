import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ChatbotService {
  ChatbotService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<ChatbotMode> getMode() async {
    final uri = Uri.parse('${AppConfig.mlBackendBaseUrl}/health');

    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ChatbotMode.fallbackMode;
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final chatApi = (body['chat_api'] ?? '').toString().toLowerCase();
        return chatApi == 'ollama-active'
          ? ChatbotMode.ollamaActive
          : ChatbotMode.fallbackMode;
    } catch (_) {
      return ChatbotMode.fallbackMode;
    }
  }

  Future<ChatbotReply> ask(String query) async {
    final uri = Uri.parse(
      '${AppConfig.mlBackendBaseUrl}${AppConfig.chatbotEndpoint}',
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'query': query}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Chatbot API failed: ${response.statusCode}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final suggestions =
          (body['suggested_questions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false);
      final source = (body['source'] ?? '').toString().toLowerCase();
        final mode = source == 'ollama'
          ? ChatbotMode.ollamaActive
          : ChatbotMode.fallbackMode;

      return ChatbotReply(
        answer: (body['answer'] ?? '').toString(),
        confidence: (body['confidence'] as num?)?.toDouble() ?? 0.0,
        suggestedQuestions: suggestions,
        mode: mode,
      );
    } on TimeoutException {
      return _fallbackReply(query);
    } catch (_) {
      return _fallbackReply(query);
    }
  }

  ChatbotReply _fallbackReply(String query) {
    final normalized = query.toLowerCase();

    String answer;
    double confidence;

    if (normalized.contains('rul') || normalized.contains('health')) {
      answer = 'RUL is the estimated remaining useful life, and health score shows the overall condition of the device. Lower values mean higher risk.';
      confidence = 0.84;
    } else if (normalized.contains('alert') || normalized.contains('warning')) {
      answer = 'The Alert Center shows threshold and predictive warnings such as vibration, gas, dust, and critical safety events.';
      confidence = 0.83;
    } else if (normalized.contains('relay') || normalized.contains('device')) {
      answer = 'The Devices section shows connected hardware, relay state, and location details. Use it to inspect or toggle controls.';
      confidence = 0.82;
    } else if (normalized.contains('export') || normalized.contains('csv') || normalized.contains('pdf')) {
      answer = 'Use Downloadable Reports to export predictive maintenance data as CSV or PDF.';
      confidence = 0.82;
    } else {
      answer = 'I can help with ReVolve app usage such as login, dashboard sections, alerts, devices, analytics, predictive outputs, and report export.';
      confidence = 0.72;
    }

    return ChatbotReply(
      answer: answer,
      confidence: confidence,
      suggestedQuestions: const [
        'How do I interpret health score and RUL?',
        'How can I export reports to CSV or PDF?',
        'What does the Alert Center show?',
        'How do relay controls work in Devices?',
      ],
      mode: ChatbotMode.fallbackMode,
    );
  }

  void dispose() {
    _client.close();
  }
}

enum ChatbotMode {
  ollamaActive,
  fallbackMode,
}

class ChatbotReply {
  ChatbotReply({
    required this.answer,
    required this.confidence,
    required this.suggestedQuestions,
    required this.mode,
  });

  final String answer;
  final double confidence;
  final List<String> suggestedQuestions;
  final ChatbotMode mode;
}
