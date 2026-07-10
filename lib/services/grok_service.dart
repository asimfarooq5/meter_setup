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

  // ── Free automatic fallback (no API key needed) ──────────────────────────
  // Calls the public Gradio API of public HF Spaces — the same demos a
  // browser would hit — no login, no key, no scraping of chat UIs, just
  // each Space's documented public API. These are anonymous ZeroGPU Spaces,
  // which share a limited free GPU quota across ALL anonymous visitors
  // worldwide, so calls can randomly fail with "quota exceeded" even when
  // our code is correct. We try a strong model first, then fall back to an
  // older, usually-less-contended one before giving up.

  Future<Uint8List> editMeterReadingFree({
    required Uint8List imageBytes,
    required String desiredReading,
  }) async {
    final b64 = base64Encode(imageBytes);

    try {
      return await _callGradioSpace(
        host: 'https://black-forest-labs-flux-1-kontext-dev.hf.space',
        endpoint: 'infer',
        data: [
          _imageField(b64),
          'Change ONLY the LCD digital display number to read '
              '"$desiredReading" instead of the current number, keeping the '
              'exact same font style, segment style, and everything else in '
              'the photo (meter body, scratches, marker writing, screws, '
              'wires, background) completely unchanged.',
          0,
          true,
          2.5,
          28,
        ],
        resultIndex: 0,
      );
    } catch (primaryError) {
      try {
        return await _callGradioSpace(
          host: 'https://timbrooks-instruct-pix2pix.hf.space',
          endpoint: 'generate',
          data: [
            _imageField(b64),
            'Change the LCD digital display number to show $desiredReading. '
                'Keep the meter body, wires, and background exactly the same.',
            30,
            'Fix Seed',
            42,
            'Fix CFG',
            7.5,
            1.5,
          ],
          resultIndex: 3,
        );
      } catch (fallbackError) {
        throw AiEditException(
            'Free public AI demos abhi busy hain (anonymous quota khatam '
            'ho gaya, yeh shared hota hai sabhi users mein). Thodi der baad '
            'phir try karein, ya Settings mein apni free HuggingFace key '
            'add karein for reliable results.');
      }
    }
  }

  Map<String, dynamic> _imageField(String b64) => {
        'path': null,
        'url': 'data:image/jpeg;base64,$b64',
        'meta': {'_type': 'gradio.FileData'},
      };

  Future<Uint8List> _callGradioSpace({
    required String host,
    required String endpoint,
    required List<dynamic> data,
    required int resultIndex,
  }) async {
    final http.Response submitResponse;
    try {
      submitResponse = await http
          .post(
            Uri.parse('$host/gradio_api/call/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiEditException('$host tak pahunch nahi payi: $e');
    }

    if (submitResponse.statusCode != 200) {
      throw AiEditException(
          '$host busy hai (HTTP ${submitResponse.statusCode}).');
    }

    final eventId = (jsonDecode(submitResponse.body)
        as Map<String, dynamic>)['event_id'] as String?;
    if (eventId == null) {
      throw AiEditException('$host ne valid response nahi diya.');
    }

    final resultData = await _streamGradioResult(host, endpoint, eventId);

    final imageField = resultData[resultIndex] as Map<String, dynamic>;
    final imageUrl = imageField['url'] as String?;
    if (imageUrl == null) {
      throw AiEditException('Result image nahi mili.');
    }

    final imgResponse = await http
        .get(Uri.parse(imageUrl))
        .timeout(const Duration(seconds: 30));
    if (imgResponse.statusCode != 200 || imgResponse.bodyBytes.isEmpty) {
      throw AiEditException('Result image download nahi hui.');
    }
    return imgResponse.bodyBytes;
  }

  Future<List<dynamic>> _streamGradioResult(
      String host, String endpointName, String eventId) async {
    final client = http.Client();
    try {
      final request = http.Request('GET',
          Uri.parse('$host/gradio_api/call/$endpointName/$eventId'));
      final streamedResponse = await client.send(request);

      final completer = Completer<List<dynamic>>();
      String eventName = '';
      final sub = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (eventName == 'complete') {
            try {
              final parsed = jsonDecode(dataStr) as List<dynamic>;
              if (!completer.isCompleted) completer.complete(parsed);
            } catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(
                    AiEditException('$host response parse error: $e'));
              }
            }
          } else if (eventName == 'error') {
            if (!completer.isCompleted) {
              completer.completeError(
                  AiEditException('$host quota/error: $dataStr'));
            }
          }
        }
      });

      sub.onDone(() {
        if (!completer.isCompleted) {
          completer.completeError(
              AiEditException('$host se result nahi mila.'));
        }
      });
      sub.onError((e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      try {
        return await completer.future.timeout(const Duration(seconds: 150));
      } finally {
        await sub.cancel();
      }
    } finally {
      client.close();
    }
  }
}

class AiEditException implements Exception {
  final String message;
  const AiEditException(this.message);
  @override
  String toString() => message;
}

// Alias so other files don't break
typedef GrokException = AiEditException;
