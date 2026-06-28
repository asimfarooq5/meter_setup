import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Free AI image editing via HuggingFace Inference API.
/// Uses instruct-pix2pix to naturally replace meter LCD display numbers.
/// API key: free from huggingface.co/settings/tokens
class GrokService {
  static final GrokService instance = GrokService._();
  GrokService._();

  static const String _apiKeyPref = 'hf_api_key';

  // Primary model — instruction-based image editing (no mask needed)
  static const String _primaryModel = 'timbrooks/instruct-pix2pix';

  // Fallback — general image-to-image
  static const String _fallbackModel =
      'CompVis/stable-diffusion-v1-4';

  static const String _hfBase =
      'https://api-inference.huggingface.co/models';

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

  // ── Main entry ────────────────────────────────────────────────────────────

  Future<Uint8List> editMeterReading({
    required Uint8List imageBytes,
    required String desiredReading,
    required String apiKey,
  }) async {
    // Try primary model with warm-up retry
    try {
      return await _callWithRetry(
        model: _primaryModel,
        imageBytes: imageBytes,
        reading: desiredReading,
        apiKey: apiKey,
      );
    } catch (e) {
      // Fallback model
      try {
        return await _callWithRetry(
          model: _fallbackModel,
          imageBytes: imageBytes,
          reading: desiredReading,
          apiKey: apiKey,
        );
      } catch (e2) {
        throw AiEditException(
          'Dono models fail ho gaye.\n'
          'Primary ($e)\n'
          'Fallback ($e2)\n\n'
          'Hint: HuggingFace free tier mein thodi der baad try karein.',
        );
      }
    }
  }

  // ── Core HuggingFace call (with warm-up retry) ────────────────────────────

  Future<Uint8List> _callWithRetry({
    required String model,
    required Uint8List imageBytes,
    required String reading,
    required String apiKey,
    int maxRetries = 4,
  }) async {
    final b64 = base64Encode(imageBytes);
    final prompt = _buildPrompt(reading);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final response = await http
          .post(
            Uri.parse('$_hfBase/$model'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': b64,
              'parameters': {
                'prompt': prompt,
                'negative_prompt':
                    'blurry, distorted, low quality, text artifacts, '
                    'different meter, changed background',
                'num_inference_steps': 30,
                'image_guidance_scale': 1.5,
                'guidance_scale': 8.5,
              },
              'options': {'wait_for_model': true},
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        // HuggingFace returns raw image bytes directly
        if (response.bodyBytes.isEmpty) {
          throw AiEditException('Empty response received');
        }
        return response.bodyBytes;
      }

      // Model still loading — wait and retry
      if (response.statusCode == 503) {
        double waitSec = 20;
        try {
          final body =
              jsonDecode(response.body) as Map<String, dynamic>;
          waitSec = (body['estimated_time'] as num?)?.toDouble() ?? 20;
        } catch (_) {}
        if (attempt < maxRetries - 1) {
          await Future.delayed(
              Duration(seconds: waitSec.clamp(5, 60).toInt()));
          continue;
        }
        throw AiEditException(
            'Model abhi load ho raha hai. 1 minute baad try karein.');
      }

      // Auth error
      if (response.statusCode == 401) {
        throw AiEditException(
            'API key galat hai ya expired. Settings mein check karein.');
      }

      // Rate limit
      if (response.statusCode == 429) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 15));
          continue;
        }
        throw AiEditException(
            'Bahut zyada requests. Thodi der baad try karein.');
      }

      // Other error
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errMsg = body['error'] as String? ?? errMsg;
      } catch (_) {}
      throw AiEditException(errMsg);
    }

    throw AiEditException('Max retries reached');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildPrompt(String reading) =>
      'Change ONLY the LCD digital display of this electricity meter '
      'to show the reading: $reading kWh. '
      'The digits must look exactly like real LCD segments — '
      'same color, brightness, and style as the original display. '
      'Keep the entire meter body, brand label, LED indicators, '
      'screws, wires, and wall background completely unchanged. '
      'The final result must look like a genuine unedited photograph.';
}

class AiEditException implements Exception {
  final String message;
  const AiEditException(this.message);
  @override
  String toString() => message;
}

// Alias so other files don't break
typedef GrokException = AiEditException;
