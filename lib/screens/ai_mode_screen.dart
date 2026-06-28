import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AIModeScreen extends StatefulWidget {
  const AIModeScreen({super.key});

  @override
  State<AIModeScreen> createState() => _AIModeScreenState();
}

class _AIModeScreenState extends State<AIModeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // TODO: Replace with your real AdMob Banner Ad Unit ID
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test ID

  static const String _aiChatUrl = 'https://claude.ai';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
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

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _openAIChat() async {
    final uri = Uri.parse(_aiChatUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          'AI Perfect Mode',
          style: GoogleFonts.orbitron(color: const Color(0xFFFFD600)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD600)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD600).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD600).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          size: 56, color: Color(0xFFFFD600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'AI Perfect Mode',
                      style: GoogleFonts.orbitron(
                        fontSize: 22,
                        color: const Color(0xFFFFD600),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Get photorealistic high-quality meter edits',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _StepCard(
                    step: '1',
                    icon: Icons.photo_camera,
                    title: 'Meter Photo Lein',
                    description:
                        'Apni meter ki saaf aur clear photo lein ya gallery se select karein',
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    step: '2',
                    icon: Icons.open_in_browser,
                    title: 'AI Chat Open Karein',
                    description:
                        'Neeche "Open Claude AI" button dabao — browser mein Claude AI khul jaega',
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    step: '3',
                    icon: Icons.upload_file,
                    title: 'Photo + Number Bhejein',
                    description:
                        'Meter ki photo attach karein aur likho: "Is meter display par [YOUR NUMBER] likho" — perfect result milega!',
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    step: '4',
                    icon: Icons.download_rounded,
                    title: 'Download & Share',
                    description:
                        'AI ka edited image save karein aur share karein — bilkul real jaisa dikhega',
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openAIChat,
                      icon: const Icon(Icons.open_in_browser, size: 22),
                      label: Text(
                        'Open Claude AI Chat',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Opens Claude AI in your browser',
                      style: GoogleFonts.poppins(
                          color: Colors.white30, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Banner Ad
          if (_isBannerAdLoaded && _bannerAd != null)
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

class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
