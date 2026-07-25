import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.15)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                ),
                child: const Icon(Icons.electric_meter,
                    color: Color(0xFF00E5FF), size: 32),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MeterSet Pro',
                    style: GoogleFonts.orbitron(
                        color: const Color(0xFF00E5FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Version 1.0.0',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

          const _SectionTitle('App Ke Baare Mein'),
          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.wifi_off,
            title: '100% Offline',
            subtitle: 'Koi internet connection nahi chahiye',
            color: Colors.green,
          ),
          _InfoRow(
            icon: Icons.lock_outline,
            title: 'Private',
            subtitle: 'Koi data server pe nahi jata',
            color: Colors.blue,
          ),
          _InfoRow(
            icon: Icons.speed,
            title: 'Fast',
            subtitle: 'Seedha device pe process hota hai',
            color: Colors.orange,
          ),
          _InfoRow(
            icon: Icons.display_settings,
            title: '6 LCD Styles',
            subtitle: 'Green, Amber, White, Cyan, Red, Blue',
            color: Colors.cyan,
          ),

          const SizedBox(height: 24),

          const _SectionTitle('Features'),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final f in [
                  'Meter ki photo lo ya gallery se upload karo',
                  'LCD display area drag karke select karo',
                  'Authentic 7-segment LCD digits render hote hain',
                  'Nai reading bilkul natural lagti hai',
                  'Save karke directly share karo',
                  'Edit history saved rehti hai',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(f,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13))),
                      ],
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 1));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _InfoRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }
}
