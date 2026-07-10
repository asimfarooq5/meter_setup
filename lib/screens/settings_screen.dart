import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/grok_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hfController = TextEditingController();
  bool _hfObscure = true;
  bool _hfSaving = false;
  bool _hfHasKey = false;

  final _openAiController = TextEditingController();
  bool _openAiObscure = true;
  bool _openAiSaving = false;
  bool _openAiHasKey = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final hfKey = await GrokService.instance.getApiKey();
    final openAiKey = await StorageService.instance.getOpenAiKey();
    if (!mounted) return;
    setState(() {
      if (hfKey != null && hfKey.isNotEmpty) {
        _hfHasKey = true;
        _hfController.text = hfKey;
      }
      if (openAiKey != null && openAiKey.isNotEmpty) {
        _openAiHasKey = true;
        _openAiController.text = openAiKey;
      }
    });
  }

  Future<void> _saveHfKey() async {
    final key = _hfController.text.trim();
    if (key.isEmpty) { _snack('API key darj karein'); return; }
    if (!key.startsWith('hf_')) {
      _snack('Key "hf_" se shuru honi chahiye — huggingface.co se copy karein');
      return;
    }
    setState(() => _hfSaving = true);
    await GrokService.instance.saveApiKey(key);
    setState(() { _hfSaving = false; _hfHasKey = true; });
    _snack('HuggingFace key save ho gayi!');
  }

  Future<void> _clearHfKey() async {
    await GrokService.instance.clearApiKey();
    _hfController.clear();
    setState(() => _hfHasKey = false);
    _snack('HuggingFace key hata di gayi');
  }

  Future<void> _saveOpenAiKey() async {
    final key = _openAiController.text.trim();
    if (key.isEmpty) { _snack('API key darj karein'); return; }
    if (!key.startsWith('sk-')) {
      _snack('Key "sk-" se shuru honi chahiye — platform.openai.com se copy karein');
      return;
    }
    setState(() => _openAiSaving = true);
    await StorageService.instance.saveOpenAiKey(key);
    setState(() { _openAiSaving = false; _openAiHasKey = true; });
    _snack('OpenAI key save ho gayi!');
  }

  Future<void> _clearOpenAiKey() async {
    await StorageService.instance.clearOpenAiKey();
    _openAiController.clear();
    setState(() => _openAiHasKey = false);
    _snack('OpenAI key hata di gayi');
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _hfController.dispose();
    _openAiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        automaticallyImplyLeading: false,
        title: Text('Settings',
            style: GoogleFonts.orbitron(
                color: const Color(0xFF00E5FF))),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),

            _buildSectionHeader(
              icon: Icons.hub_outlined,
              title: 'HuggingFace',
              badge: 'FREE',
              badgeColor: const Color(0xFF4CAF50),
              subtitle: 'instruct-pix2pix model — unlimited free requests',
            ),
            const SizedBox(height: 12),
            _buildKeyInput(
              controller: _hfController,
              obscure: _hfObscure,
              hint: 'hf_xxxxxxxxxxxxxxxxxxxxxxxx',
              hasKey: _hfHasKey,
              onToggle: () => setState(() => _hfObscure = !_hfObscure),
              onSave: _hfSaving ? null : _saveHfKey,
              onClear: _hfHasKey ? _clearHfKey : null,
              saving: _hfSaving,
              accent: const Color(0xFF00E5FF),
            ),
            const SizedBox(height: 8),
            _LinkRow(
              label: 'huggingface.co/settings/tokens — Free account banao',
              url: 'https://huggingface.co/settings/tokens',
              color: const Color(0xFF00E5FF),
            ),

            const SizedBox(height: 28),

            _buildSectionHeader(
              icon: Icons.psychology_outlined,
              title: 'OpenAI',
              badge: 'PAID',
              badgeColor: const Color(0xFFFFD600),
              subtitle: 'GPT-4o — high quality, pay per use',
            ),
            const SizedBox(height: 12),
            _buildKeyInput(
              controller: _openAiController,
              obscure: _openAiObscure,
              hint: 'sk-proj-xxxxxxxxxxxxxxxx',
              hasKey: _openAiHasKey,
              onToggle: () =>
                  setState(() => _openAiObscure = !_openAiObscure),
              onSave: _openAiSaving ? null : _saveOpenAiKey,
              onClear: _openAiHasKey ? _clearOpenAiKey : null,
              saving: _openAiSaving,
              accent: const Color(0xFFFFD600),
            ),
            const SizedBox(height: 8),
            _LinkRow(
              label: 'platform.openai.com/api-keys — Paid account',
              url: 'https://platform.openai.com/api-keys',
              color: const Color(0xFFFFD600),
            ),

            const SizedBox(height: 28),

            _buildSectionHeader(
              icon: Icons.open_in_browser_outlined,
              title: 'Browser AI',
              badge: 'NO SETUP',
              badgeColor: Colors.white54,
              subtitle: 'Claude.ai ya ChatGPT — seedha browser mein kholo',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BrowserBtn(
                    label: 'Claude.ai',
                    color: const Color(0xFFFFD600),
                    url: 'https://claude.ai',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BrowserBtn(
                    label: 'ChatGPT',
                    color: Colors.white54,
                    url: 'https://chat.openai.com',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),

            Center(
              child: Column(
                children: [
                  const Icon(Icons.electric_bolt,
                      color: Color(0xFF00E5FF), size: 28),
                  const SizedBox(height: 8),
                  Text('MeterSet Pro',
                      style: GoogleFonts.orbitron(
                          color: const Color(0xFF00E5FF),
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('v1.0.0 • Meter Reading Editor',
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Providers Status',
              style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _StatusRow(
              label: 'HuggingFace', active: _hfHasKey, tag: 'Free'),
          const SizedBox(height: 8),
          _StatusRow(
              label: 'OpenAI', active: _openAiHasKey, tag: 'Paid'),
          const SizedBox(height: 8),
          _StatusRow(
              label: 'Browser AI (Claude / ChatGPT)',
              active: true,
              tag: 'Always On'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: badgeColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title,
                      style: GoogleFonts.orbitron(
                          color: Colors.white, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Text(badge,
                        style: GoogleFonts.poppins(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyInput({
    required TextEditingController controller,
    required bool obscure,
    required String hint,
    required bool hasKey,
    required VoidCallback onToggle,
    required VoidCallback? onSave,
    required VoidCallback? onClear,
    required bool saving,
    required Color accent,
  }) {
    return Column(
      children: [
        if (hasKey)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 14),
                const SizedBox(width: 8),
                Text('Key set hai — ready!',
                    style: GoogleFonts.poppins(
                        color: Colors.green, fontSize: 11)),
              ],
            ),
          ),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.sourceCodePro(
              color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.sourceCodePro(
                color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF141414),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: accent.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accent, width: 2),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 18),
              onPressed: onToggle,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(saving ? 'Saving...' : 'Save',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: accent.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 16),
                label: Text('Clear',
                    style: GoogleFonts.poppins(
                        color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.red.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool active;
  final String tag;
  const _StatusRow(
      {required this.label, required this.active, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          color: active ? Colors.green : Colors.white24,
          size: 15,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: GoogleFonts.poppins(
                  color: active ? Colors.white70 : Colors.white38,
                  fontSize: 12)),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? Colors.green.withOpacity(0.15)
                : Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            active ? tag : 'Not set',
            style: GoogleFonts.poppins(
              color: active ? Colors.green : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String url;
  final Color color;
  const _LinkRow(
      {required this.label, required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
      child: Text(
        '→ $label',
        style: GoogleFonts.poppins(
          color: color.withOpacity(0.75),
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: color.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _BrowserBtn extends StatelessWidget {
  final String label;
  final Color color;
  final String url;
  const _BrowserBtn(
      {required this.label, required this.color, required this.url});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
      icon: Icon(Icons.open_in_browser, color: color, size: 16),
      label: Text(label,
          style: GoogleFonts.poppins(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
