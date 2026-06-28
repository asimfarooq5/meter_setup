import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps OpenAI image-editing API (gpt-image-1 / dall-e-2).
/// Replaces meter LCD display numbers naturally in the original photo.
class GrokService {
  static final GrokService instance = GrokService._();
  GrokService._();

  static const String _apiKeyPref = 'openai_api_key';
  static const String _baseUrl = 'https://api.openai.com/v1';

  // ── API key storage ───────────────────────────────────────────────────────

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }

  // ── Main entry point ──────────────────────────────────────────────────────

  Future<Uint8List> editMeterReading({
    required Uint8List imageBytes,
    required String desiredReading,
    required String apiKey,
  }) async {
    // Primary: gpt-image-1 inpainting (best quality, understands context)
    try {
      return await _imageEdit(
        imageBytes: imageBytes,
        reading: desiredReading,
        apiKey: apiKey,
        model: 'gpt-image-1',
      );
    } catch (e1) {
      // Fallback: dall-e-2 edit endpoint
      try {
        return await _imageEdit(
          imageBytes: imageBytes,
          reading: desiredReading,
          apiKey: apiKey,
          model: 'dall-e-2',
        );
      } catch (e2) {
        // Last resort: vision analysis → dall-e-3 generation
        try {
          return await _visionThenGenerate(
            imageBytes: imageBytes,
            reading: desiredReading,
            apiKey: apiKey,
          );
        } catch (e3) {
          throw AiEditException(
            'Sab tarike fail ho gaye.\n'
            'gpt-image-1: $e1\n'
            'dall-e-2: $e2\n'
            'generation: $e3',
          );
        }
      }
    }
  }

  // ── Approach 1: /v1/images/edits ─────────────────────────────────────────

  Future<Uint8List> _imageEdit({
    required Uint8List imageBytes,
    required String reading,
    required String apiKey,
    required String model,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/images/edits'),
    )
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'meter.png',
        contentType: MediaType('image', 'png'),
      ))
      ..fields['model'] = model
      ..fields['prompt'] = _editPrompt(reading)
      ..fields['n'] = '1'
      ..fields['size'] = '1024x1024'
      ..fields['response_format'] = 'b64_json';

    final streamed =
        await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    _assertOk(response);
    return _extractB64Image(response.body);
  }

  // ── Approach 2: vision → dall-e-3 generation ─────────────────────────────

  Future<Uint8List> _visionThenGenerate({
    required Uint8List imageBytes,
    required String reading,
    required String apiKey,
  }) async {
    final b64 = base64Encode(imageBytes);

    // Step A: GPT-4o vision — describe the meter in detail
    final vRes = await http
        .post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-4o',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/png;base64,$b64'},
                  },
                  {
                    'type': 'text',
                    'text':
                        'Describe this electricity meter in precise photographic detail: '
                        'brand, model label, body color and material, shape, '
                        'mounting screws, LED indicators (color/position), '
                        'wire colors, wall/background, and especially the LCD display '
                        '(digit color, glow, background color, size, position). '
                        'Be very specific — this description will be used to recreate it.',
                  },
                ],
              },
            ],
            'max_tokens': 600,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _assertOk(vRes);

    final vJson = jsonDecode(vRes.body) as Map<String, dynamic>;
    final description =
        (vJson['choices'] as List).first['message']['content'] as String;

    // Step B: DALL-E 3 — generate with new reading
    final gRes = await http
        .post(
          Uri.parse('$_baseUrl/images/generations'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'dall-e-3',
            'prompt': 'Photorealistic photograph of an electricity meter. '
                'Exact description: $description. '
                'CRITICAL: The LCD digital display must show the reading '
                '"$reading kWh" in the exact same digit color, font, and style '
                'as described. Everything else must be identical to the description.',
            'n': 1,
            'size': '1024x1024',
            'quality': 'hd',
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 90));
    _assertOk(gRes);
    return _extractB64Image(gRes.body);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _editPrompt(String reading) =>
      'Edit ONLY the LCD digital display of this electricity meter. '
      'Replace the current reading with: $reading kWh. '
      'The new digits must match the original LCD style exactly — '
      'same segment color, brightness, background, and font weight. '
      'Do NOT change anything else: meter body, brand labels, LED indicators, '
      'screws, wires, or background wall must remain pixel-perfect. '
      'The result must look like an authentic unedited photograph.';

  void _assertOk(http.Response res) {
    if (res.statusCode == 200) return;
    String msg = 'HTTP ${res.statusCode}';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      msg = (body['error'] as Map?)?['message'] as String? ?? msg;
    } catch (_) {}
    throw AiEditException(msg);
  }

  Uint8List _extractB64Image(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) {
      throw AiEditException('API ne koi image return nahi ki');
    }
    final b64 = data.first['b64_json'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw AiEditException('API response mein image data nahi mila');
    }
    return base64Decode(b64);
  }
}

class AiEditException implements Exception {
  final String message;
  const AiEditException(this.message);

  @override
  String toString() => message;
}

// Keep old name as alias so nothing else breaks
typedef GrokException = AiEditException;
