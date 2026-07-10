import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    if (mounted) setState(() => _apiKey = key);
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

  Future<void> _pickImage(ImageSource source) async {
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 100);
    if (file != null && mounted) {
      setState(() {
        _sourceImage = File(file.path);
        _resultImage = null;
        _statusMsg = '';
      });
    }
  }

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
      _snack(
          'Settings tab se HuggingFace API key add karein, ya neeche browser option use karein');
      return;
    }

    setState(() {
      _loading = true;
      _resultImage = null;
      _statusMsg = 'Meter image HuggingFace AI ko bhej raha hai...';
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

  Future<void> _saveAndShare() async {
    if (_resultImage == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = '\${dir.path}/meter_ai_\$stamp.png';
      await File(path).writeAsBytes(_resultImage!);
      await StorageService.instance.addHistory(HistoryItem(
        filePath: path,
        reading: _readingCtrl.text.trim(),
        timestamp: DateTime.now(),
      ));
      await Share.shareXFiles(
        [XFile(path)],
        text:
            'Meter Reading: \${_readingCtrl.text.trim()} kWh\nEdited with MeterSet Pro (AI)',
      );
    } catch (e) {
      _snack('Save error: \$e');
    }
  }

  void _showBrowserSheet() {
    final reading = _readingCtrl.text.trim();
    final prompt = reading.isEmpty
        ? 'Is meter ki photo mein LCD display ka number badal do. '
            'Sirf digits change karo, baaki sab same rakho.'
        : 'Is meter ki photo mein LCD display "$reading kWh" kar do. '
            'Sirf LCD digits change karo — meter body, wires, background sab same rakhna. '
            'Result bilkul real photo jaisa lagna chahiye.';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.open_in_browser,
                    color: Color(0xFFFFD600), size: 20),
                const SizedBox(width: 10),
                Text('Browser se AI Edit',
                    style: GoogleFonts.orbitron(
                        color: const Color(0xFFFFD600), fontSize: 14)),
              ],
            ),
            const SizedBox(height: 14),
            Text('1. Yeh prompt copy karo:',
                style: GoogleFonts.poppins(
                    color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(prompt,
                  style: GoogleFonts.sourceCodePro(
                      color: Colors.white70, fontSize: 11, height: 1.5)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prompt));
                _snack('Prompt copy ho gaya!');
              },
              icon: const Icon(Icons.copy, size: 14, color: Colors.white54),
              label: Text('Prompt Copy Karo',
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),
            Text('2. Ek AI mein kholo, photo + prompt bhejo:',
                style: GoogleFonts.poppins(
                    color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse('https://claude.ai'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.auto_awesome, size: 15),
                    label: Text('Claude.ai',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse('https://chat.openai.com'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.chat_bubble_outline,
                        size: 15, color: Colors.white54),
                    label: Text('ChatGPT',
                        style: GoogleFonts.poppins(
                            color: Colors.white54, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('AI Edit Failed',
            style:
                GoogleFonts.orbitron(color: Colors.red, fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(msg,
              style: GoogleFonts.sourceCodePro(
                  color: Colors.white70, fontSize: 12, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF00E5FF))),
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

  @override
  Widget build(BuildContext context) {
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text('AI Edit',
            style:
                GoogleFonts.orbitron(color: const Color(0xFFFFD600))),
        iconTheme: const IconThemeData(color: Color(0xFFFFD600)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser,
                color: Colors.white54, size: 22),
            tooltip: 'Browser se AI Edit',
            onPressed: _showBrowserSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              hasKey ? Icons.key : Icons.key_off,
              color: hasKey ? Colors.green : Colors.red,
              size: 20,
            ),
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
                  if (!hasKey) _NoKeyBanner(onSettings: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ).then((_) => _initApiKey());
                  }, onBrowser: _showBrowserSheet),

                  _Label('Step 1: Meter Photo'),
                  const SizedBox(height: 8),
                  _ImagePickerCard(
                    image: _sourceImage,
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(height: 20),

                  _Label('Step 2: New Reading (kWh)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _readingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: GoogleFonts.orbitron(
                        color: const Color(0xFF4CAF50),
                        fontSize: 24,
                        letterSpacing: 3),
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
                        borderSide: const BorderSide(
                            color: Color(0xFF4CAF50)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: const Color(0xFF4CAF50)
                                .withOpacity(0.4)),
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
                  const SizedBox(height: 20),

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
                                  color: Colors.black))
                          : const Icon(Icons.auto_awesome, size: 22),
                      label: Text(
                        _loading
                            ? 'AI Edit ho raha hai...'
                            : 'AI Edit Karo (HuggingFace)',
                        style: GoogleFonts.orbitron(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            const Color(0xFFFFD600).withOpacity(0.4),
                        disabledForegroundColor: Colors.black54,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showBrowserSheet,
                      icon: const Icon(Icons.open_in_browser,
                          color: Colors.white54, size: 18),
                      label: Text('Browser se AI Edit (Claude / ChatGPT)',
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  if (_loading && _statusMsg.isNotEmpty) ...[  
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD600).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFD600)
                                .withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFD600)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_statusMsg,
                                style: GoogleFonts.poppins(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_resultImage != null) ...[  
                    const SizedBox(height: 24),
                    _Label('Result — AI Edited Image'),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_resultImage!,
                          width: double.infinity,
                          fit: BoxFit.contain),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.orbitron(
          fontSize: 13,
          color: const Color(0xFFFFD600),
          letterSpacing: 0.5));
}

class _NoKeyBanner extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onBrowser;
  const _NoKeyBanner(
      {required this.onSettings, required this.onBrowser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HuggingFace API key nahi mili — app is ke baghair bhi chalti hai',
                  style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BannerBtn(
                  icon: Icons.settings,
                  label: 'API Key Add Karo',
                  color: const Color(0xFF00E5FF),
                  onTap: onSettings,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BannerBtn(
                  icon: Icons.open_in_browser,
                  label: 'Browser Use Karo',
                  color: const Color(0xFFFFD600),
                  onTap: onBrowser,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BannerBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      color: color, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
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
  const _ImagePickerCard(
      {required this.image,
      required this.onCamera,
      required this.onGallery});

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
            color: const Color(0xFFFFD600).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PickBtn(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: onCamera),
          ),
          Container(width: 1, height: 60, color: Colors.white12),
          Expanded(
            child: _PickBtn(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: onGallery),
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
  const _PickBtn(
      {required this.icon, required this.label, required this.onTap});
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
              style: GoogleFonts.poppins(
                  color: Colors.white54, fontSize: 13)),
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
