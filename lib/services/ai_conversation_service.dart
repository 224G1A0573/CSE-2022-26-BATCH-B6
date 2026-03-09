import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI-powered conversation service using LLM API
/// Supports OpenAI, Anthropic, or any OpenAI-compatible API
class AIConversationService {
  static final AIConversationService _instance = AIConversationService._internal();
  factory AIConversationService() => _instance;
  AIConversationService._internal();

  String? _apiKey;
  String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  String _model = 'gpt-3.5-turbo'; // Can be changed to gpt-4, claude, etc.
  bool _useAI = false; // Toggle to enable/disable AI

  // Conversation history for context
  final List<Map<String, String>> _conversationHistory = [];

  /// Initialize the service with API key
  Future<void> initialize({String? apiKey}) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKey = apiKey;
      _useAI = true;
      await _saveApiKey(apiKey);
    } else {
      // Try to load from preferences
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('ai_api_key');
      if (savedKey != null && savedKey.isNotEmpty) {
        _apiKey = savedKey;
        _useAI = true;
      }
    }
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', key);
  }

  /// Generate a dynamic conversation response
  Future<String> generatePeerResponse({
    required String peerName,
    required String childResponse,
    required String context,
    required String scenario,
    int age = 8,
  }) async {
    if (!_useAI || _apiKey == null) {
      // Fallback to rule-based responses
      return _generateFallbackResponse(peerName, childResponse, scenario);
    }

    try {
      // Build conversation context
      final systemPrompt = '''You are $peerName, a friendly virtual peer for an autistic child aged $age.
Your role is to:
- Be patient, kind, and encouraging
- Use simple, clear language appropriate for the child's age
- Respond naturally to what the child says
- Keep responses short (1-2 sentences)
- Be supportive and positive
- Help the child practice social skills in a safe environment

Context: $context
Scenario: $scenario

Respond as $peerName would, in a friendly and age-appropriate way.''';

      // Add to conversation history
      _conversationHistory.add({
        'role': 'user',
        'content': childResponse,
      });

      // Limit history to last 5 exchanges
      if (_conversationHistory.length > 10) {
        _conversationHistory.removeRange(0, _conversationHistory.length - 10);
      }

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;
        
        // Add AI response to history
        _conversationHistory.add({
          'role': 'assistant',
          'content': aiResponse,
        });

        return aiResponse.trim();
      } else {
        print('AI API Error: ${response.statusCode} - ${response.body}');
        return _generateFallbackResponse(peerName, childResponse, scenario);
      }
    } catch (e) {
      print('Error calling AI API: $e');
      return _generateFallbackResponse(peerName, childResponse, scenario);
    }
  }

  /// Fallback rule-based response generator
  String _generateFallbackResponse(String peerName, String childResponse, String scenario) {
    final lowerResponse = childResponse.toLowerCase();
    
    // Positive responses
    if (lowerResponse.contains('yes') || lowerResponse.contains('okay') || lowerResponse.contains('sure')) {
      return 'That\'s great! I\'m happy you agree!';
    }
    
    // Questions
    if (lowerResponse.contains('?') || lowerResponse.contains('what') || lowerResponse.contains('how')) {
      return 'That\'s a good question! Let me think...';
    }
    
    // Sharing
    if (lowerResponse.contains('like') || lowerResponse.contains('love') || lowerResponse.contains('favorite')) {
      return 'That sounds really interesting! Tell me more about it!';
    }
    
    // Default friendly response
    return 'That\'s cool! I like talking with you!';
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Set API configuration
  void configureAPI({String? url, String? model}) {
    if (url != null) _apiUrl = url;
    if (model != null) _model = model;
  }

  /// Check if AI is enabled
  bool get isAIEnabled => _useAI && _apiKey != null;
}

