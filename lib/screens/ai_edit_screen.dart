import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/grok_service.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import 'settings_screen.dart';

class AiEditScreen extends StatefulWidget {
  const AiEditScreen({super.key});

  @override
  State<AiEditScreen> createState() => _AiEditScreenState();
}

class _AiEditScreenState extends State<AiEditScreen> {
  File? _sourceImage;
  Uint8List? _resultImage;
  final TextEditingController _readingCtrl = TextEditingController();
  bool _loading = false;
  String _statusMsg = '';
  String? _apiKey;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  // TODO: Replace with your real AdMob Banner Ad Unit ID
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test ID

  @override
  void initState() {
    super.initState();
    _initApiKey();
    _loadBannerAd();
  }

  Future<void> _initApiKey() async {
    final key = await GrokService.instance.getApiKey();
    setState(() => _apiKey = key);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _bannerLoaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  // ── Pick image ────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 100);
    if (file != null && mounted) {
      setState(() {
        _sourceImage = File(file.path);
        _resultImage = null;
        _statusMsg = '';
      });
    }
  }

  // ── Run AI edit ───────────────────────────────────────────────────────────

  Future<void> _runAiEdit() async {
    if (_sourceImage == null) {
      _snack('Pehle meter ki photo select karein');
      return;
    }
    if (_readingCtrl.text.trim().isEmpty) {
      _snack('Jo reading dikhani hai woh number darj karein');
      return;
    }
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showNoKeyDialog();
      return;
    }

    setState(() {
      _loading = true;
      _resultImage = null;
      _statusMsg = 'Meter image Grok AI ko bhej raha hai...';
    });

    try {
      final imageBytes = await _sourceImage!.readAsBytes();

      setState(() => _statusMsg =
          'AI meter ki LCD display edit kar raha hai...\n(30-60 seconds lag sakte hain)');

      final result = await GrokService.instance.editMeterReading(
        imageBytes: imageBytes,
        desiredReading: _readingCtrl.text.trim(),
        apiKey: _apiKey!,
      );

      setState(() {
        _resultImage = result;
        _statusMsg = 'Tayyar! Dekhein aur share karein.';
      });
    } on GrokException catch (e) {
      setState(() => _statusMsg = '');
      _showErrorDialog(e.message);
    } catch (e) {
      setState(() => _statusMsg = '');
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Save & Share ──────────────────────────────────────────────────────────

  Future<void> _saveAndShare() async {
    if (_resultImage == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/meter_ai_$stamp.png';
      await File(path).writeAsBytes(_resultImage!);

      await StorageService.instance.addHistory(HistoryItem(
        filePath: path,
        reading: _readingCtrl.text.trim(),
        timestamp: DateTime.now(),
      ));

      await Share.shareXFiles(
        [XFile(path)],
        text:
            'Meter Reading: ${_readingCtrl.text.trim()} kWh\nEdited with MeterSet Pro (AI)',
      );
    } catch (e) {
      _snack('Save error: $e');
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showNoKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('API Key Required',
            style: GoogleFonts.orbitron(
                color: const Color(0xFFFFD600), fontSize: 16)),
        content: Text(
          'AI Edit ke liye xAI (Grok) API key darj karein.\n\n'
          'Settings → "xAI API Key" mein apni key save karein.',
          style: GoogleFonts.poppins(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              ).then((_) => _initApiKey());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD600),
              foregroundColor: Colors.black,
            ),
            child: Text('Open Settings',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('AI Edit Failed',
            style: GoogleFonts.orbitron(color: Colors.red, fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(msg,
              style: GoogleFonts.sourceCodePro(
                  color: Colors.white70, fontSize: 12, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('OK', style: GoogleFonts.poppins(color: const Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _readingCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text('AI Edit',
            style: GoogleFonts.orbitron(color: const Color(0xFFFFD600))),
        iconTheme: const IconThemeData(color: Color(0xFFFFD600)),
        elevation: 0,
        actions: [
          // API key indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _apiKey != null && _apiKey!.isNotEmpty
                  ? Icons.key
                  : Icons.key_off,
              color: _apiKey != null && _apiKey!.isNotEmpty
                  ? Colors.green
                  : Colors.red,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _initApiKey()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── API key warning ────────────────────────────────────
                  if (_apiKey == null || _apiKey!.isEmpty)
                    _ApiKeyBanner(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ).then((_) => _initApiKey()),
                    ),

                  // ── Image picker ───────────────────────────────────────
                  _SectionLabel(label: 'Step 1: Meter Photo'),
                  const SizedBox(height: 8),
                  _ImagePickerCard(
                    image: _sourceImage,
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                  ),

                  const SizedBox(height: 20),

                  // ── Reading input ──────────────────────────────────────
                  _SectionLabel(label: 'Step 2: New Reading (kWh)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _readingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF4CAF50),
                      fontSize: 24,
                      letterSpacing: 3,
                    ),
                    decoration: InputDecoration(
                      hintText: '02603.36',
                      hintStyle: GoogleFonts.orbitron(
                          color: Colors.white12,
                          fontSize: 24,
                          letterSpacing: 3),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color:
                                const Color(0xFF4CAF50).withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF4CAF50), width: 2),
                      ),
                      suffixText: 'kWh',
                      suffixStyle: GoogleFonts.orbitron(
                          color: Colors.white30, fontSize: 11),
                      prefixIcon: const Icon(Icons.speed,
                          color: Color(0xFF4CAF50), size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── AI Edit button ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _runAiEdit,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black),
                            )
                          : const Icon(Icons.auto_awesome, size: 22),
                      label: Text(
                        _loading ? 'AI Edit ho raha hai...' : 'AI Edit Karo',
                        style: GoogleFonts.orbitron(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            const Color(0xFFFFD600).withOpacity(0.4),
                        disabledForegroundColor: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // ── Status message ─────────────────────────────────────
                  if (_loading && _statusMsg.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD600).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFFFFD600).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFD600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMsg,
                              style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Result image ───────────────────────────────────────
                  if (_resultImage != null) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Result — AI Edited Image'),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _resultImage!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAndShare,
                        icon: const Icon(Icons.share_rounded),
                        label: Text('Save & Share',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _resultImage = null;
                          _sourceImage = null;
                          _readingCtrl.clear();
                          _statusMsg = '';
                        }),
                        icon: const Icon(Icons.refresh,
                            color: Colors.white54, size: 18),
                        label: Text('Naya Edit Karo',
                            style: GoogleFonts.poppins(
                                color: Colors.white54)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Banner Ad
          if (_bannerLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.orbitron(
          fontSize: 13,
          color: const Color(0xFFFFD600),
          letterSpacing: 0.5),
    );
  }
}

class _ApiKeyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ApiKeyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_off, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'HuggingFace API key nahi mili — Settings mein darj karein',
                style:
                    GoogleFonts.poppins(color: Colors.red, fontSize: 12),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.red, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final File? image;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _ImagePickerCard({
    required this.image,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _SmallBtn(icon: Icons.camera_alt, onTap: onCamera),
                const SizedBox(width: 6),
                _SmallBtn(icon: Icons.photo_library, onTap: onGallery),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFD600).withOpacity(0.3),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PickBtn(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: onCamera,
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white12),
          Expanded(
            child: _PickBtn(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: onGallery,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFD600), size: 36),
          const SizedBox(height: 8),
          Text(label,
              style:
                  GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
