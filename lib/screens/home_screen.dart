import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // TODO: Replace with your real AdMob Banner Ad Unit ID
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test ID

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
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
    _glowController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A1A),
                  Color(0xFF061206),
                  Color(0xFF0A0A0A),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, _) => Column(
                    children: [
                      Icon(
                        Icons.electric_bolt,
                        size: 64,
                        color: Color(0xFF00E5FF)
                            .withOpacity(_glowAnimation.value),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MeterSet Pro',
                        style: GoogleFonts.orbitron(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00E5FF),
                          shadows: [
                            Shadow(
                              color: const Color(0xFF00E5FF)
                                  .withOpacity(_glowAnimation.value),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Meter Reading Editor',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 52),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _ModeCard(
                        icon: Icons.auto_awesome,
                        title: 'AI Edit',
                        subtitle:
                            'HuggingFace AI se bilkul natural\nLCD display edit',
                        color: const Color(0xFFFFD600),
                        badge: 'BEST',
                        onTap: () =>
                            Navigator.pushNamed(context, '/ai-edit'),
                      ),
                      const SizedBox(height: 14),
                      _ModeCard(
                        icon: Icons.offline_bolt,
                        title: 'Offline Edit',
                        subtitle:
                            'Internet ke baghair\nText overlay editing',
                        color: const Color(0xFF00E5FF),
                        onTap: () =>
                            Navigator.pushNamed(context, '/offline-edit'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isBannerAdLoaded && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  )
                else
                  const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.orbitron(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        if (badge != null) ...[  
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: color.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
