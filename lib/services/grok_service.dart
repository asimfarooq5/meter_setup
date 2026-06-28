import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrokService {
  static final GrokService instance = GrokService._();
  GrokService._();

  static const String _apiKeyPref = 'xai_api_key';
  static const String _baseUrl = 'https://api.x.ai/v1';

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

  // ── Main edit function ────────────────────────────────────────────────────

  /// Sends [imageBytes] to Grok API and returns edited image bytes
  /// where the LCD display shows [desiredReading].
  Future<Uint8List> editMeterReading({
    required Uint8List imageBytes,
    required String desiredReading,
    required String apiKey,
  }) async {
    // Try image-edit endpoint first (preserves original image best)
    try {
      return await _callImageEdit(imageBytes, desiredReading, apiKey);
    } catch (editErr) {
      // Fallback: vision analysis → image generation
      try {
        return await _callVisionThenGenerate(
            imageBytes, desiredReading, apiKey);
      } catch (genErr) {
        throw GrokException(
          'Image editing failed.\n'
          'Edit error: $editErr\n'
          'Generate error: $genErr',
        );
      }
    }
  }

  // ── Approach 1: /v1/images/edits (inpainting) ────────────────────────────

  Future<Uint8List> _callImageEdit(
    Uint8List imageBytes,
    String reading,
    String apiKey,
  ) async {
    final uri = Uri.parse('$_baseUrl/images/edits');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'meter.png',
        contentType: MediaType('image', 'png'),
      ))
      ..fields['model'] = 'aurora'
      ..fields['prompt'] = _buildEditPrompt(reading)
      ..fields['n'] = '1'
      ..fields['response_format'] = 'b64_json';

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    _assertOk(response);
    return _extractImage(response.body);
  }

  // ── Approach 2: vision → text → image generation ─────────────────────────

  Future<Uint8List> _callVisionThenGenerate(
    Uint8List imageBytes,
    String reading,
    String apiKey,
  ) async {
    final b64 = base64Encode(imageBytes);

    // Step A: vision model describes the meter in detail
    final visionRes = await http
        .post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'grok-2-vision-1212',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/png;base64,$b64',
                    },
                  },
                  {
                    'type': 'text',
                    'text':
                        'Describe this electricity meter in detail: brand, model, color, '
                            'body shape, label text, wire colors, background wall, and the '
                            'exact style/color of the LCD display digits. Be very specific '
                            'so that someone could recreate it exactly.',
                  },
                ],
              },
            ],
            'max_tokens': 500,
          }),
        )
        .timeout(const Duration(seconds: 30));

    _assertOk(visionRes);
    final visionJson =
        jsonDecode(visionRes.body) as Map<String, dynamic>;
    final description = (visionJson['choices'] as List)
        .first['message']['content'] as String;

    // Step B: generate image with the description + new reading
    final genRes = await http
        .post(
          Uri.parse('$_baseUrl/images/generations'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'aurora',
            'prompt': 'Photorealistic photograph of an electricity meter. '
                'Meter description: $description. '
                'IMPORTANT: The LCD digital display must clearly show the reading '
                '"$reading" kWh in the exact same font, color, and style as described. '
                'Everything else must match the description exactly.',
            'n': 1,
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 90));

    _assertOk(genRes);
    return _extractImage(genRes.body);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildEditPrompt(String reading) =>
      'Edit this electricity meter photo. '
      'Change ONLY the LCD digital display to show the reading: $reading kWh. '
      'The digits must look like real LCD segments — same color, brightness, '
      'and style as the original display. '
      'Keep the meter body, brand label, indicator LEDs, wires, screws, '
      'and background wall completely unchanged. '
      'The result must look like a genuine unmodified photograph.';

  void _assertOk(http.Response res) {
    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = body['error']?['message'] as String? ?? msg;
      } catch (_) {}
      throw GrokException(msg);
    }
  }

  Uint8List _extractImage(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final data = json['data'] as List;
    if (data.isEmpty) throw GrokException('No image returned from API');
    final b64 = data.first['b64_json'] as String?;
    if (b64 == null) throw GrokException('API returned no image data');
    return base64Decode(b64);
  }
}

class GrokException implements Exception {
  final String message;
  const GrokException(this.message);

  @override
  String toString() => message;
}
