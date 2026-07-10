import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/history_item.dart';
import '../models/meter_template.dart';
import '../services/storage_service.dart';

class OfflineEditScreen extends StatefulWidget {
  const OfflineEditScreen({super.key});

  @override
  State<OfflineEditScreen> createState() => _OfflineEditScreenState();
}

class _OfflineEditScreenState extends State<OfflineEditScreen> {
  File? _selectedImage;
  final TextEditingController _readingController = TextEditingController();
  final FocusNode _readingFocus = FocusNode();
  final GlobalKey _repaintKey = GlobalKey();
  Offset _overlayPosition = const Offset(60, 60);
  double _fontSize = 34.0;
  Color _textColor = const Color(0xFF4CAF50);
  bool _hasBg = true;
  bool _isSaving = false;
  bool _showDragHint = true;
  MeterTemplate _selectedTemplate = MeterTemplate.presets.first;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // TODO: Replace with your real AdMob Banner Ad Unit ID
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test ID

  // TODO: Replace with your real AdMob Interstitial Ad Unit ID
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test ID

  InterstitialAd? _interstitialAd;
  int _editCount = 0;

  static const List<Color> _colorOptions = [
    Color(0xFF4CAF50),
    Color(0xFFFFBF00),
    Colors.white,
    Color(0xFF00E5FF),
    Color(0xFFFF5252),
    Color(0xFF448AFF),
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  void _applyTemplate(MeterTemplate t) {
    setState(() {
      _selectedTemplate = t;
      _textColor = t.displayColor;
      _fontSize = t.fontSize;
      _hasBg = t.hasBg;
    });
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _showInterstitialIfReady() {
    _editCount++;
    if (_editCount % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    _readingFocus.unfocus();
    try {
      final XFile? file = await ImagePicker()
          .pickImage(source: source, imageQuality: 100);
      if (file != null && mounted) {
        setState(() {
          _selectedImage = File(file.path);
          _overlayPosition = const Offset(60, 60);
          _showDragHint = true;
        });
      }
    } catch (e) {
      _showSnack('Could not pick image: $e');
    }
  }

  Future<void> _saveAndShare() async {
    if (_selectedImage == null || _readingController.text.trim().isEmpty) {
      _showSnack('Please select a photo and enter a meter reading');
      return;
    }
    _readingFocus.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() => _isSaving = true);
    try {
      final RenderRepaintBoundary boundary = _repaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '\${dir.path}/meter_\$stamp.png';
      await File(filePath).writeAsBytes(pngBytes);

      await StorageService.instance.addHistory(HistoryItem(
        filePath: filePath,
        reading: _readingController.text.trim(),
        timestamp: DateTime.now(),
      ));

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Meter Reading: \${_readingController.text.trim()} kWh\n'
            'Edited with MeterSet Pro',
      );

      _showInterstitialIfReady();
    } catch (e) {
      _showSnack('Error saving: \$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _readingController.dispose();
    _readingFocus.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          'Offline Edit',
          style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        elevation: 0,
        actions: [
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              tooltip: 'New photo',
              onPressed: () => setState(() {
                _selectedImage = null;
                _readingController.clear();
              }),
            ),
        ],
      ),
      body: _selectedImage == null ? _buildPickerView() : _buildEditorView(),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, color: Colors.white38, size: 13),
              const SizedBox(width: 5),
              Text(
                'Display Template',
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MeterTemplate.presets.map((t) {
                final isSelected = _selectedTemplate.id == t.id;
                return GestureDetector(
                  onTap: () => _applyTemplate(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.displayColor.withOpacity(0.18)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? t.displayColor : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: t.displayColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected
                                ? t.displayColor
                                : Colors.white54,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerView() {
    return Column(
      children: [
        _buildTemplateSelector(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera,
                        size: 64, color: Color(0xFF00E5FF)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Meter Photo',
                    style: GoogleFonts.orbitron(
                        fontSize: 20, color: const Color(0xFF00E5FF)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the meter photo you want to edit the reading on',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: Text('Camera',
                              style: GoogleFonts.poppins(fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: Text('Gallery',
                              style: GoogleFonts.poppins(fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Color(0xFF00E5FF)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorView() {
    return Column(
      children: [
        _buildTemplateSelector(),
        _buildReadingInputBar(),
        Expanded(child: _buildImageCanvas()),
        _buildControlsPanel(),
        if (_isBannerAdLoaded && _bannerAd != null)
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
      ],
    );
  }

  Widget _buildReadingInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF141414),
      child: TextField(
        controller: _readingController,
        focusNode: _readingFocus,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.orbitron(
          color: _textColor,
          fontSize: 22,
          letterSpacing: 3,
        ),
        decoration: InputDecoration(
          hintText: '00000.00',
          hintStyle: GoogleFonts.orbitron(
            color: Colors.white12,
            fontSize: 22,
            letterSpacing: 3,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _textColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _textColor.withOpacity(0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _textColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.black,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          suffixText: 'kWh',
          suffixStyle:
              GoogleFonts.orbitron(color: Colors.white30, fontSize: 11),
          prefixIcon: Icon(Icons.speed, color: _textColor, size: 20),
        ),
        onChanged: (_) => setState(() {}),
        onTap: () => setState(() => _showDragHint = false),
      ),
    );
  }

  Widget _buildImageCanvas() {
    return GestureDetector(
      onTap: () => _readingFocus.unfocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RepaintBoundary(
            key: _repaintKey,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_readingController.text.isNotEmpty)
                  Positioned(
                    left: _overlayPosition.dx,
                    top: _overlayPosition.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _showDragHint = false;
                          _overlayPosition = Offset(
                            (_overlayPosition.dx + details.delta.dx)
                                .clamp(0.0, constraints.maxWidth - 40),
                            (_overlayPosition.dy + details.delta.dy)
                                .clamp(0.0, constraints.maxHeight - 30),
                          );
                        });
                      },
                      child: Container(
                        padding: _hasBg
                            ? const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2)
                            : EdgeInsets.zero,
                        decoration: _hasBg
                            ? BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(4),
                              )
                            : null,
                        child: Text(
                          _readingController.text,
                          style: GoogleFonts.orbitron(
                            fontSize: _fontSize,
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: _selectedTemplate.letterSpacing,
                            shadows: [
                              Shadow(
                                color: _textColor.withOpacity(0.7),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showDragHint && _readingController.text.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_with,
                                color: Colors.white60, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Drag number to position',
                              style: GoogleFonts.poppins(
                                  color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text('Size',
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _textColor,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: _textColor,
                    overlayColor: _textColor.withOpacity(0.2),
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _fontSize,
                    min: 14,
                    max: 80,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
              ),
              Text(
                '\${_fontSize.round()}',
                style: GoogleFonts.orbitron(
                    color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          Row(
            children: [
              Text('Color:',
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              ..._colorOptions.map(
                (c) => GestureDetector(
                  onTap: () => setState(() => _textColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == c
                            ? Colors.white
                            : Colors.white24,
                        width: _textColor == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text('BG',
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _hasBg,
                  activeColor: const Color(0xFF00E5FF),
                  inactiveThumbColor: Colors.white38,
                  onChanged: (v) => setState(() => _hasBg = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAndShare,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.share_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save & Share',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white24,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
