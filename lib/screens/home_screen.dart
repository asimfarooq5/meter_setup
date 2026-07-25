import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'offline_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      width: 2),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                ),
                child: const Icon(Icons.electric_meter,
                    size: 56, color: Color(0xFF00E5FF)),
              ),
              const SizedBox(height: 20),
              Text(
                'MeterSet Pro',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00E5FF),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Offline Meter Reading Editor',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 60),

              // Main edit button
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const OfflineEditScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        const Color(0xFF00E5FF).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.edit_rounded,
                          color: Color(0xFF00E5FF), size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Edit Meter Reading',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Photo lo • LCD area select karo • Reading likhо',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // How it works
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kaise Kaam Karta Hai:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final step in [
                      ('1', 'Meter ki photo lo ya gallery se upload karo'),
                      ('2', 'LCD area auto-detect hoga — ya manually select karo'),
                      ('3', 'Nai reading type karo aur preview dekho'),
                      ('4', 'Save karo aur share karo'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Text(step.$1,
                                style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(step.$2,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12))),
                        ]),
                      ),
                  ],
                ),
              ),

              const Spacer(),
              const Text('100% Offline • Koi Internet Nahi Chahiye',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
