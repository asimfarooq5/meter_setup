import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_item.dart';
import '../models/meter_template.dart';
import '../services/storage_service.dart';

// 7-segment: [top, top-right, bot-right, bottom, bot-left, top-left, middle]
const Map<String, List<bool>> _segs = {
  '0': [true,  true,  true,  true,  true,  true,  false],
  '1': [false, true,  true,  false, false, false, false],
  '2': [true,  true,  false, true,  true,  false, true ],
  '3': [true,  true,  true,  true,  false, false, true ],
  '4': [false, true,  true,  false, false, true,  true ],
  '5': [true,  false, true,  true,  false, true,  true ],
  '6': [true,  false, true,  true,  true,  true,  true ],
  '7': [true,  true,  true,  false, false, false, false],
  '8': [true,  true,  true,  true,  true,  true,  true ],
  '9': [true,  true,  true,  true,  false, true,  true ],
};

enum _Step { pick, select, edit }

class OfflineEditScreen extends StatefulWidget {
  const OfflineEditScreen({super.key});
  @override
  State<OfflineEditScreen> createState() => _OfflineEditScreenState();
}

class _OfflineEditScreenState extends State<OfflineEditScreen> {
  _Step _step = _Step.pick;

  ui.Image? _uiImage;

  Offset? _selA, _selB;
  bool _dragging = false;
  Rect _imgRect = Rect.zero;

  final _ctrl = TextEditingController();
  MeterTemplate _tmpl = MeterTemplate.presets[0];

  Uint8List? _preview;
  bool _rendering = false;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _uiImage?.dispose();
    super.dispose();
  }

  // ─── Image load ────────────────────────────────────────────────────

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 95);
    if (x == null || !mounted) return;
    final bytes = await File(x.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) { frame.image.dispose(); return; }
    _uiImage?.dispose();
    setState(() {
      _uiImage = frame.image;
      _step = _Step.select;
      _selA = _selB = null;
      _preview = null;
    });
  }

  // ─── Coordinate helpers ────────────────────────────────────────────

  Rect? get _selScreen {
    if (_selA == null || _selB == null) return null;
    return Rect.fromPoints(_selA!, _selB!);
  }

  Rect? get _selImage {
    final s = _selScreen;
    if (s == null || _uiImage == null || _imgRect.isEmpty) return null;
    final sw = _uiImage!.width  / _imgRect.width;
    final sh = _uiImage!.height / _imgRect.height;
    return Rect.fromLTRB(
      ((s.left   - _imgRect.left) * sw).clamp(0.0, _uiImage!.width .toDouble()),
      ((s.top    - _imgRect.top)  * sh).clamp(0.0, _uiImage!.height.toDouble()),
      ((s.right  - _imgRect.left) * sw).clamp(0.0, _uiImage!.width .toDouble()),
      ((s.bottom - _imgRect.top)  * sh).clamp(0.0, _uiImage!.height.toDouble()),
    );
  }

  // ─── Rendering ─────────────────────────────────────────────────────

  Future<Uint8List> _render(String reading) async {
    final lcd = _selImage!;
    final iw  = _uiImage!.width.toDouble();
    final ih  = _uiImage!.height.toDouble();

    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, iw, ih));

    // Draw original image
    canvas.drawImage(_uiImage!, Offset.zero, Paint());

    // LCD background — very dark tint of the digit colour
    final dc = _tmpl.displayColor;
    canvas.drawRect(
        lcd,
        Paint()
          ..color = Color.fromARGB(255,
              (dc.r * 255 * 0.07).round(),
              (dc.g * 255 * 0.07).round(),
              (dc.b * 255 * 0.07).round()));

    // 7-segment digits
    _drawString(canvas, reading, lcd, dc);

    final pic = rec.endRecording();
    final img = await pic.toImage(iw.toInt(), ih.toInt());
    pic.dispose();
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bd!.buffer.asUint8List();
  }

  void _drawString(Canvas canvas, String text, Rect rect, Color on) {
    if (text.isEmpty) return;
    final off = Color.fromARGB(
        255,
        (on.r * 255 * 0.10).round(),
        (on.g * 255 * 0.10).round(),
        (on.b * 255 * 0.10).round());

    double units = 0;
    for (final c in text.characters) {
      units += c == '.' ? 0.35 : 1.0;
    }
    if (units == 0) return;

    final padH  = rect.width  * 0.05;
    final padV  = rect.height * 0.10;
    final avW   = rect.width  - padH * 2;
    final avH   = rect.height - padV * 2;
    final gapFr = 0.04;
    final n     = text.length;
    final gapW  = avW * gapFr;
    final charW = (avW - gapW * (n - 1)) / units;
    final charH = avH;

    double cx = rect.left + padH;
    final cy  = rect.top  + padV;

    for (final c in text.characters) {
      if (c == '.') {
        final dw = charW * 0.35;
        final ds = (charH * 0.14).clamp(3.0, 14.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx + dw * 0.2, cy + charH - ds * 2, ds, ds),
              const Radius.circular(3)),
          Paint()..color = on);
        cx += dw + gapW;
        continue;
      }
      final s = _segs[c];
      if (s != null) _drawDigit(canvas, s, Offset(cx, cy), Size(charW, charH), on, off);
      cx += charW + gapW;
    }
  }

  void _drawDigit(Canvas canvas, List<bool> s, Offset o,
      Size sz, Color on, Color off) {
    final t   = (sz.width * 0.14).clamp(2.5, 12.0);
    final w   = sz.width;
    final h   = sz.height;
    final mid = h * 0.5;
    final inn = t * 0.55;

    void hSeg(bool active, double x, double y, double len) {
      final p = Path()
        ..moveTo(x + inn,       y)
        ..lineTo(x + len - inn, y)
        ..lineTo(x + len,       y + t * 0.5)
        ..lineTo(x + len - inn, y + t)
        ..lineTo(x + inn,       y + t)
        ..lineTo(x,             y + t * 0.5)
        ..close();
      canvas.drawPath(p, Paint()..color = active ? on : off);
    }

    void vSeg(bool active, double x, double y, double len) {
      final p = Path()
        ..moveTo(x,           y + inn)
        ..lineTo(x + t * 0.5, y)
        ..lineTo(x + t,       y + inn)
        ..lineTo(x + t,       y + len - inn)
        ..lineTo(x + t * 0.5, y + len)
        ..lineTo(x,           y + len - inn)
        ..close();
      canvas.drawPath(p, Paint()..color = active ? on : off);
    }

    hSeg(s[0], o.dx,         o.dy,                 w);
    vSeg(s[1], o.dx + w - t, o.dy,                 mid);
    vSeg(s[2], o.dx + w - t, o.dy + mid,           mid);
    hSeg(s[3], o.dx,         o.dy + h - t,          w);
    vSeg(s[4], o.dx,         o.dy + mid,           mid);
    vSeg(s[5], o.dx,         o.dy,                 mid);
    hSeg(s[6], o.dx,         o.dy + mid - t * 0.5, w);
  }

  Future<void> _buildPreview() async {
    final r = _ctrl.text.trim();
    if (r.isEmpty || _selImage == null) return;
    setState(() { _rendering = true; _preview = null; });
    try {
      final b = await _render(r);
      if (mounted) setState(() => _preview = b);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Preview error: $e')));
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _saveShare() async {
    final r = _ctrl.text.trim();
    if (r.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle reading type karein')));
      return;
    }
    if (_selImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LCD area select karein pehle')));
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _render(r);
      final dir   = await getTemporaryDirectory();
      final ts    = DateTime.now();
      final path  = '${dir.path}/meter_${ts.millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      await StorageService.instance.addHistory(
          HistoryItem(filePath: path, reading: r, timestamp: ts));
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Meter reading: $r');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: _step != _Step.pick
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white70, size: 20),
                onPressed: () => setState(() {
                  if (_step == _Step.edit) {
                    _step = _Step.select;
                    _preview = null;
                  } else {
                    _step = _Step.pick;
                    _uiImage?.dispose();
                    _uiImage = null;
                  }
                }),
              )
            : null,
        title: Text(
          const ['Photo Lo', 'LCD Area Select Karo', 'Reading Edit Karo'][_step.index],
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_step == _Step.edit)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.cyan)))
                : TextButton.icon(
                    onPressed: _saveShare,
                    icon: const Icon(Icons.save_alt,
                        color: Colors.cyan, size: 18),
                    label: const Text('Save',
                        style: TextStyle(color: Colors.cyan, fontSize: 14)),
                  ),
        ],
      ),
      body: switch (_step) {
        _Step.pick   => _buildPickView(),
        _Step.select => _buildSelectView(),
        _Step.edit   => _buildEditView(),
      },
    );
  }

  Widget _buildPickView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 2),
                color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.electric_meter,
                  size: 72, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 28),
            const Text(
              'Meter ki photo lo ya gallery se upload karo',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(child: _BigBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF00E5FF),
                  onTap: () => _pick(ImageSource.camera),
                )),
                const SizedBox(width: 16),
                Expanded(child: _BigBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFFFFD600),
                  onTap: () => _pick(ImageSource.gallery),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectView() {
    if (_uiImage == null) return const SizedBox();
    return Column(
      children: [
        Container(
          color: const Color(0xFF161616),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('LCD digits pe finger rakh ke drag karo',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              if (_selScreen != null) ...[
                GestureDetector(
                  onTap: () => setState(() { _selA = _selB = null; }),
                  child: const Text('Reset',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _step = _Step.edit),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Aage →',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final iw = _uiImage!.width.toDouble();
            final ih = _uiImage!.height.toDouble();
            final scale = min(c.maxWidth / iw, c.maxHeight / ih);
            final dw = iw * scale;
            final dh = ih * scale;
            _imgRect = Rect.fromLTWH(
                (c.maxWidth - dw) / 2, (c.maxHeight - dh) / 2, dw, dh);

            return GestureDetector(
              onPanStart: (d) {
                if (!_imgRect.contains(d.localPosition)) return;
                setState(() {
                  _selA = d.localPosition;
                  _selB = d.localPosition;
                  _dragging = true;
                });
              },
              onPanUpdate: (d) {
                if (!_dragging) return;
                setState(() => _selB = Offset(
                      d.localPosition.dx.clamp(_imgRect.left, _imgRect.right),
                      d.localPosition.dy.clamp(_imgRect.top,  _imgRect.bottom),
                    ));
              },
              onPanEnd: (_) => setState(() => _dragging = false),
              child: CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _SelectPainter(
                    image: _uiImage!, imgRect: _imgRect, sel: _selScreen),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nai Reading:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _preview = null),
            style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 26,
                letterSpacing: 6,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '12345.6',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15), letterSpacing: 2),
              filled: true,
              fillColor: const Color(0xFF0D1A1A),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF00E5FF), width: 2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('LCD Style:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MeterTemplate.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t   = MeterTemplate.presets[i];
                final sel = t.id == _tmpl.id;
                return GestureDetector(
                  onTap: () => setState(() { _tmpl = t; _preview = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? t.displayColor.withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      border: Border.all(
                          color: sel
                              ? t.displayColor
                              : const Color(0xFF2A2A2A),
                          width: sel ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: t.displayColor,
                              shape: BoxShape.circle,
                              boxShadow: sel
                                  ? [BoxShadow(
                                      color: t.displayColor.withValues(alpha: 0.6),
                                      blurRadius: 8)]
                                  : null)),
                      const SizedBox(width: 7),
                      Text(t.name,
                          style: TextStyle(
                              color: sel ? t.displayColor : Colors.white38,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _rendering ? null : _buildPreview,
            icon: _rendering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.cyan))
                : const Icon(Icons.remove_red_eye_outlined,
                    color: Colors.cyan, size: 18),
            label: Text(_rendering ? 'Bana raha hai...' : 'Preview Dekho',
                style: const TextStyle(color: Colors.cyan)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.cyan),
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_preview!, fit: BoxFit.contain),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveShare,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save_alt, color: Colors.black, size: 20),
            label: Text(_saving ? 'Save ho raha hai...' : 'Save & Share',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectPainter extends CustomPainter {
  final ui.Image image;
  final Rect imgRect;
  final Rect? sel;
  const _SelectPainter(
      {required this.image, required this.imgRect, this.sel});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble()),
        imgRect,
        Paint());

    if (sel == null) return;
    final s   = sel!;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);

    canvas.drawRect(Rect.fromLTRB(imgRect.left, imgRect.top, imgRect.right, s.top), dim);
    canvas.drawRect(Rect.fromLTRB(imgRect.left, s.bottom, imgRect.right, imgRect.bottom), dim);
    canvas.drawRect(Rect.fromLTRB(imgRect.left, s.top, s.left, s.bottom), dim);
    canvas.drawRect(Rect.fromLTRB(s.right, s.top, imgRect.right, s.bottom), dim);

    canvas.drawRect(
        s,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    const hs = 8.0;
    final hp = Paint()..color = const Color(0xFF00E5FF);
    for (final pt in [s.topLeft, s.topRight, s.bottomLeft, s.bottomRight]) {
      canvas.drawRect(Rect.fromCenter(center: pt, width: hs, height: hs), hp);
    }
  }

  @override
  bool shouldRepaint(_SelectPainter o) =>
      o.sel != sel || o.imgRect != imgRect;
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
