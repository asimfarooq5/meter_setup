import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/grok_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await GrokService.instance.getApiKey();
    if (key != null && key.isNotEmpty) {
      setState(() {
        _hasKey = true;
        _keyController.text = key;
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _snack('Please enter your xAI API key');
      return;
    }
    if (!key.startsWith('sk-')) {
      _snack('Key "sk-" se shuru honi chahiye — check your key');
      return;
    }
    setState(() => _saving = true);
    await GrokService.instance.saveApiKey(key);
    setState(() {
      _saving = false;
      _hasKey = true;
    });
    _snack('API key saved!');
  }

  Future<void> _clearKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Remove API Key?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Your xAI API key will be deleted from this device.',
            style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Remove', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await GrokService.instance.clearApiKey();
      _keyController.clear();
      setState(() => _hasKey = false);
      _snack('API key removed');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text('Settings',
            style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF))),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            if (_hasKey)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Text('OpenAI API key set hai — AI Edit active hai',
                        style: GoogleFonts.poppins(
                            color: Colors.green, fontSize: 13)),
                  ],
                ),
              ),

            // Title
            Text('OpenAI API Key',
                style: GoogleFonts.orbitron(
                    fontSize: 16, color: const Color(0xFF00E5FF))),
            const SizedBox(height: 6),
            Text(
              'AI Edit ke liye zaruri. platform.openai.com se milegi.',
              style:
                  GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Key input
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              style: GoogleFonts.sourceCodePro(
                  color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'sk-proj-xxxxxxxxxxxxxxxxxxxxxxxx',
                hintStyle: GoogleFonts.sourceCodePro(
                    color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF00E5FF), width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveKey,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save API Key',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            if (_hasKey) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearKey,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  label: Text('Remove API Key',
                      style: GoogleFonts.poppins(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 36),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),

            // How to get key
            Text('OpenAI API Key Kaise Milegi?',
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _Step(
              n: '1',
              text: 'platform.openai.com par jao',
            ),
            _Step(n: '2', text: 'Account banao ya login karo (free signup)'),
            _Step(
                n: '3',
                text:
                    '"API Keys" section → "Create new secret key" button dabao'),
            _Step(n: '4', text: 'Key copy karo (sirf ek baar dikhti hai!)'),
            _Step(n: '5', text: 'Yahaan paste karo → Save!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Models used:\n'
                      '• gpt-image-1 (best quality)\n'
                      '• dall-e-2 (fallback)\n'
                      '• dall-e-3 + gpt-4o vision (last resort)\n\n'
                      'Ek image edit mein ~\$0.04–0.08 kharch hota hai.',
                      style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD600).withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFD600).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Color(0xFFFFD600), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'API key sirf aapke phone par store hoti hai. '
                      'Kisi server ya internet par nahi jaati.',
                      style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(n,
                  style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: const Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    color: Colors.white60, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
