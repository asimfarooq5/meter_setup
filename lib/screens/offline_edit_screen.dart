import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_item.dart';
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

  Uint8List? _imgBytes;   // original file bytes for Image.memory display
  ui.Image?  _uiImage;    // decoded ui.Image for canvas rendering
  Uint8List? _rawPx;      // RGBA pixels for detection + color sampling

  Rect?  _lcdRect;        // LCD area in image pixel coords
  Color  _digitColor = const Color(0xFF00FF40);
  Color  _bgColor    = Colors.black;

  // Manual select fallback
  Offset? _selA, _selB;
  Rect    _imgRect = Rect.zero;

  final _ctrl    = TextEditingController();
  Uint8List? _preview;
  bool _detecting = false;
  bool _rendering = false;
  bool _saving    = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _uiImage?.dispose();
    super.dispose();
  }

  // ─── Pick & auto-detect ────────────────────────────────────────────

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 95);
    if (x == null || !mounted) return;

    final bytes = await File(x.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) { frame.image.dispose(); return; }

    _uiImage?.dispose();
    final img = frame.image;
    final bd  = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (!mounted) { img.dispose(); return; }

    setState(() {
      _imgBytes  = bytes;
      _uiImage   = img;
      _rawPx     = bd?.buffer.asUint8List();
      _lcdRect   = null;
      _selA = _selB = null;
      _preview   = null;
      _detecting = true;
      _step      = _Step.pick;
    });

    // Yield so spinner paints before detection blocks the thread
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final det = _rawPx != null ? _detect(img, _rawPx!) : null;

    if (!mounted) return;
    if (det != null) {
      setState(() {
        _lcdRect    = det.$1;
        _digitColor = det.$2;
        _bgColor    = det.$3;
        _detecting  = false;
        _step       = _Step.edit;
      });
    } else {
      setState(() { _detecting = false; _step = _Step.select; });
    }
  }

  // ─── Detection: returns (lcdRect, digitColor, bgColor) or null ─────

  (Rect, Color, Color)? _detect(ui.Image img, Uint8List px) {
    final w = img.width;
    final h = img.height;

    // Only scan upper 55% — LCD is always in the upper portion of a meter
    final hScan = (h * 0.55).toInt();

    const gx = 48; const gy = 28;
    final cw = w / gx; final ch = hScan / gy;
    final candCnt  = List.filled(gx * gy, 0);
    final edgeSum  = List.filled(gx * gy, 0);
    final totalCnt = List.filled(gx * gy, 0);

    for (int y = 0; y < hScan; y += 3) {
      for (int x = 0; x < w; x += 3) {
        final i  = (y * w + x) * 4;
        final r  = px[i]; final g = px[i + 1]; final b = px[i + 2];
        final mx = max(r, max(g, b));
        final mn = min(r, min(g, b));
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        final sat = mx > 0 ? (mx - mn) / mx : 0.0;

        final ci = (y / ch).floor().clamp(0, gy - 1) * gx +
            (x / cw).floor().clamp(0, gx - 1);
        totalCnt[ci]++;

        // Horizontal edge (digit segments create strong local contrast)
        if (x >= 3) {
          final li   = (y * w + (x - 3)) * 4;
          final llum = 0.299 * px[li] + 0.587 * px[li + 1] + 0.114 * px[li + 2];
          edgeSum[ci] += (lum - llum).abs().toInt();
        }

        // LCD candidate pixel types (ordered: most common first)
        final lcd =
            (lum > 115 && lum < 232 && sat < 0.22) || // grey/white reflective LCD
            (lum > 130 && sat > 0.18) ||               // bright + coloured
            (g > 90  && g > r * 1.35 && g > b * 1.25) || // green backlit
            (r > 140 && r > g * 1.3  && r > b * 2.0)  || // amber
            (lum > 210 && sat < 0.12);                   // white LED

        if (lcd) candCnt[ci]++;
      }
    }

    // Score: high candidate fraction × edge bonus
    // Edge bonus rewards cells with digit-like texture over blank uniform walls
    final grid = List.filled(gx * gy, 0);
    for (int ci = 0; ci < gx * gy; ci++) {
      if (totalCnt[ci] == 0) continue;
      final candFrac = candCnt[ci] / totalCnt[ci];
      final avgEdge  = edgeSum[ci]  / totalCnt[ci];
      final edgeMul  = (avgEdge > 4 && avgEdge < 55) ? 1.6 : 1.0;
      if (candFrac > 0.30) grid[ci] = (candFrac * 100 * edgeMul).toInt();
    }

    final maxV = grid.isEmpty ? 0 : grid.reduce(max);
    if (maxV < 8) return null;

    // Higher threshold → tighter bounding box (avoids whole-image false positives)
    final thr = (maxV * 0.42).toInt().clamp(8, 9999);
    int mnx = gx, mxx = -1, mny = gy, mxy = -1;
    for (int cy = 0; cy < gy; cy++) {
      for (int cx = 0; cx < gx; cx++) {
        if (grid[cy * gx + cx] >= thr) {
          if (cx < mnx) mnx = cx; if (cx > mxx) mxx = cx;
          if (cy < mny) mny = cy; if (cy > mxy) mxy = cy;
        }
      }
    }
    if (mxx < 0) return null;

    double x0 = (mnx       * cw - cw * 0.1).clamp(0.0, w.toDouble());
    double y0 = (mny       * ch - ch * 0.3 ).clamp(0.0, h.toDouble());
    double x1 = ((mxx + 1) * cw + cw * 0.1).clamp(0.0, w.toDouble());
    double y1 = ((mxy + 1) * ch + ch * 0.3 ).clamp(0.0, h.toDouble());
    final rect = Rect.fromLTRB(x0, y0, x1, y1);

    final ar = rect.width / rect.height;
    if (ar < 1.1 || ar > 14) return null;
    if (rect.width < w * 0.05) return null;
    // Reject if detection covers almost the entire scan area (uniform-white scene)
    if (rect.width > w * 0.88 && rect.height > hScan * 0.65) return null;

    final colors = _sampleColors(px, w, h, rect);
    return (rect, colors.$2, colors.$1);
  }

  // Sample average color of LCD region → bg fill color
  // Digit color = bg darkened to ~52% (real reflective LCD look)
  (Color, Color) _sampleColors(Uint8List px, int w, int h, Rect rect) {
    int tr = 0, tg = 0, tb = 0, cnt = 0;
    final y0 = rect.top.round().clamp(0, h - 1);
    final y1 = rect.bottom.round().clamp(0, h);
    final x0 = rect.left.round().clamp(0, w - 1);
    final x1 = rect.right.round().clamp(0, w);
    for (int y = y0; y < y1; y += 3) {
      for (int x = x0; x < x1; x += 3) {
        final i = (y * w + x) * 4;
        tr += px[i]; tg += px[i + 1]; tb += px[i + 2]; cnt++;
      }
    }
    if (cnt == 0) {
      return (const Color(0xFF808080), const Color(0xFF404040));
    }
    final bgR = tr ~/ cnt; final bgG = tg ~/ cnt; final bgB = tb ~/ cnt;
    final bg  = Color.fromARGB(255, bgR, bgG, bgB);
    // Active segments: 52% of bg brightness → naturally darker, same hue
    final dig = Color.fromARGB(255,
        (bgR * 0.52).round(), (bgG * 0.52).round(), (bgB * 0.52).round());
    return (bg, dig);  // (bgColor, digitColor)
  }

  // ─── Manual select (fallback) ──────────────────────────────────────

  Rect? get _selScreen => (_selA != null && _selB != null)
      ? Rect.fromPoints(_selA!, _selB!)
      : null;

  Rect? get _selImage {
    final s = _selScreen;
    if (s == null || _uiImage == null || _imgRect.isEmpty) return null;
    final sw = _uiImage!.width  / _imgRect.width;
    final sh = _uiImage!.height / _imgRect.height;
    return Rect.fromLTRB(
      ((s.left   - _imgRect.left) * sw).clamp(0.0, _uiImage!.width.toDouble()),
      ((s.top    - _imgRect.top)  * sh).clamp(0.0, _uiImage!.height.toDouble()),
      ((s.right  - _imgRect.left) * sw).clamp(0.0, _uiImage!.width.toDouble()),
      ((s.bottom - _imgRect.top)  * sh).clamp(0.0, _uiImage!.height.toDouble()),
    );
  }

  void _confirmManualSelect() {
    final r = _selImage;
    if (r == null || _rawPx == null) return;
    final c = _sampleColors(_rawPx!, _uiImage!.width, _uiImage!.height, r);
    setState(() {
      _lcdRect    = r;
      _digitColor = c.$2; // darkened digit color
      _bgColor    = c.$1; // average bg color
      _step       = _Step.edit;
    });
  }

  // ─── Rendering ─────────────────────────────────────────────────────

  Future<Uint8List> _render(String reading) async {
    final lcd = _lcdRect!;
    final iw  = _uiImage!.width.toDouble();
    final ih  = _uiImage!.height.toDouble();
    final rec = ui.PictureRecorder();
    final can = Canvas(rec, Rect.fromLTWH(0, 0, iw, ih));

    can.drawImage(_uiImage!, Offset.zero, Paint());
    can.drawRect(lcd, Paint()
      ..color = Color.fromARGB(255,
          (_bgColor.r * 255).round(),
          (_bgColor.g * 255).round(),
          (_bgColor.b * 255).round()));
    // Off segments = bgColor (invisible) → natural reflective LCD look
    _drawString(can, reading, lcd, _digitColor, _bgColor);

    final pic = rec.endRecording();
    final out = await pic.toImage(iw.toInt(), ih.toInt());
    pic.dispose();
    final bd = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    return bd!.buffer.asUint8List();
  }

  void _drawString(Canvas can, String text, Rect rect, Color on, Color off) {
    if (text.isEmpty) return;
    double units = 0;
    for (final c in text.characters) units += c == '.' ? 0.35 : 1.0;
    if (units == 0) return;
    final padH = rect.width  * 0.05;
    final padV = rect.height * 0.10;
    final avW  = rect.width  - padH * 2;
    final avH  = rect.height - padV * 2;
    final gapW = avW * 0.04;
    final cW   = (avW - gapW * (text.length - 1)) / units;
    final cH   = avH;
    double cx  = rect.left + padH;
    final cy   = rect.top  + padV;
    for (final c in text.characters) {
      if (c == '.') {
        final dw = cW * 0.35;
        final ds = (cH * 0.14).clamp(3.0, 14.0);
        can.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx + dw * 0.2, cy + cH - ds * 2, ds, ds),
              const Radius.circular(3)),
          Paint()..color = on);
        cx += dw + gapW;
        continue;
      }
      final s = _segs[c];
      if (s != null) _drawDigit(can, s, Offset(cx, cy), Size(cW, cH), on, off);
      cx += cW + gapW;
    }
  }

  void _drawDigit(Canvas can, List<bool> s, Offset o, Size sz,
      Color on, Color off) {
    final t   = (sz.width * 0.14).clamp(2.5, 12.0);
    final w   = sz.width;
    final h   = sz.height;
    final mid = h * 0.5;
    final inn = t * 0.55;

    void hSeg(bool a, double x, double y, double len) =>
        can.drawPath(
            Path()
              ..moveTo(x + inn,       y)
              ..lineTo(x + len - inn, y)
              ..lineTo(x + len,       y + t * 0.5)
              ..lineTo(x + len - inn, y + t)
              ..lineTo(x + inn,       y + t)
              ..lineTo(x,             y + t * 0.5)
              ..close(),
            Paint()..color = a ? on : off);

    void vSeg(bool a, double x, double y, double len) =>
        can.drawPath(
            Path()
              ..moveTo(x,           y + inn)
              ..lineTo(x + t * 0.5, y)
              ..lineTo(x + t,       y + inn)
              ..lineTo(x + t,       y + len - inn)
              ..lineTo(x + t * 0.5, y + len)
              ..lineTo(x,           y + len - inn)
              ..close(),
            Paint()..color = a ? on : off);

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
    if (r.isEmpty || _lcdRect == null) return;
    setState(() { _rendering = true; _preview = null; });
    try {
      final b = await _render(r);
      if (mounted) setState(() => _preview = b);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _saveShare() async {
    final r = _ctrl.text.trim();
    if (r.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reading type karein')));
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _render(r);
      final dir   = await getTemporaryDirectory();
      final ts    = DateTime.now();
      final path  = '${dir.path}/meter_${ts.millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      await StorageService.instance
          .addHistory(HistoryItem(filePath: path, reading: r, timestamp: ts));
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
          _detecting
              ? 'LCD Detect Ho Raha Hai...'
              : ['Meter Photo Lo', 'LCD Area Select Karo',
                  'Reading Likhо'][_step.index],
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_step == _Step.edit)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20,
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

  // Step 1: pick (or spinner while detecting)
  Widget _buildPickView() {
    if (_detecting) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF00E5FF)),
          const SizedBox(height: 20),
          Text('LCD area dhundh raha hai...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ]),
      );
    }
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
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    width: 2),
                color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.electric_meter,
                  size: 72, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 28),
            const Text(
              'Photo lo — LCD area aur rang automatically detect hoga',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 40),
            Row(children: [
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
                color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                onTap: () => _pick(ImageSource.gallery),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // Step 2: manual select fallback
  Widget _buildSelectView() {
    if (_uiImage == null) return const SizedBox();
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.touch_app, color: Colors.orange, size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-detect fail hua. LCD screen pe drag kar ke select karo.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ]),
      ),
      Expanded(
        child: GestureDetector(
          onPanStart:  (d) => setState(() {
            _selA = d.localPosition;
            _selB = d.localPosition;
          }),
          onPanUpdate: (d) => setState(() => _selB = d.localPosition),
          onPanEnd:    (_) {},
          child: LayoutBuilder(builder: (_, cons) {
            final imgW = _uiImage!.width.toDouble();
            final imgH = _uiImage!.height.toDouble();
            final sc   = min(cons.maxWidth / imgW, cons.maxHeight / imgH);
            final rw   = imgW * sc; final rh = imgH * sc;
            final ox   = (cons.maxWidth  - rw) / 2;
            final oy   = (cons.maxHeight - rh) / 2;
            // Update directly — no setState needed; only used for gesture mapping
            _imgRect = Rect.fromLTWH(ox, oy, rw, rh);
            return SizedBox(
              width:  cons.maxWidth,
              height: cons.maxHeight,
              child: CustomPaint(
                painter: _SelectPainter(
                  image:    _uiImage!,
                  imgRect:  _imgRect,
                  selection: _selScreen,
                ),
              ),
            );
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                _selScreen != null ? _confirmManualSelect : null,
            icon: const Icon(Icons.check),
            label: const Text('Confirm'),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ),
    ]);
  }

  // Step 3: edit + preview
  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Auto-detect badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _digitColor.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: _digitColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('LCD auto-detect hua',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _step = _Step.select;
                  _selA = _selB = null;
                  _preview = null;
                }),
                child: const Text('Manually adjust karo',
                    style: TextStyle(
                        color: Color(0xFF00E5FF), fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Image: preview result OR original with LCD highlight
          if (_preview != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_preview!, fit: BoxFit.contain),
            )
          else if (_imgBytes != null)
            _OriginalWithHighlight(
              imgBytes: _imgBytes!,
              uiImage: _uiImage,
              lcdRect: _lcdRect,
              digitColor: _digitColor,
            ),

          const SizedBox(height: 12),

          // Reading input
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 3,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Nai reading type karo (e.g. 2804.5)',
              hintStyle: const TextStyle(
                  color: Colors.white24, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF00E5FF), width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() => _preview = null),
          ),
          const SizedBox(height: 12),

          // Preview button
          OutlinedButton.icon(
            onPressed: _rendering ? null : _buildPreview,
            icon: _rendering
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyan))
                : const Icon(Icons.visibility_outlined,
                    color: Colors.cyan, size: 18),
            label: Text(
              _rendering ? 'Rendering...' : 'Preview Dekho',
              style: const TextStyle(color: Colors.cyan),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E5FF)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Save & Share
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveShare,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save_alt, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save & Share'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

// ─── Original image with LCD highlight border ──────────────────────────

class _OriginalWithHighlight extends StatelessWidget {
  final Uint8List imgBytes;
  final ui.Image? uiImage;
  final Rect? lcdRect;
  final Color digitColor;
  const _OriginalWithHighlight({
    required this.imgBytes,
    required this.uiImage,
    required this.lcdRect,
    required this.digitColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(builder: (_, cons) {
        final img = uiImage;
        return Stack(children: [
          Image.memory(imgBytes,
              fit: BoxFit.fitWidth,
              width: cons.maxWidth),
          if (img != null && lcdRect != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _LcdBorderPainter(
                  imageWidth:  img.width.toDouble(),
                  imageHeight: img.height.toDouble(),
                  lcdRect:     lcdRect!,
                  color:       digitColor,
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

class _LcdBorderPainter extends CustomPainter {
  final double imageWidth, imageHeight;
  final Rect lcdRect;
  final Color color;
  const _LcdBorderPainter({
    required this.imageWidth, required this.imageHeight,
    required this.lcdRect, required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // size.width == displayed image width (fitWidth)
    final sx = size.width  / imageWidth;
    final sy = size.width  / imageWidth; // fitWidth keeps uniform scale
    final r  = Rect.fromLTRB(
      lcdRect.left   * sx, lcdRect.top    * sy,
      lcdRect.right  * sx, lcdRect.bottom * sy,
    );
    // Glow
    canvas.drawRect(r, Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Sharp border
    canvas.drawRect(r, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_LcdBorderPainter o) =>
      o.lcdRect != lcdRect || o.color != color;
}

// ─── Manual select painter ─────────────────────────────────────────────

class _SelectPainter extends CustomPainter {
  final ui.Image image;
  final Rect imgRect;
  final Rect? selection;
  const _SelectPainter(
      {required this.image, required this.imgRect, this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imgRect,
      Paint(),
    );
    if (selection == null) return;
    final s = selection!;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, s.top), dim);
    canvas.drawRect(
        Rect.fromLTRB(0, s.bottom, size.width, size.height), dim);
    canvas.drawRect(Rect.fromLTRB(0, s.top, s.left, s.bottom), dim);
    canvas.drawRect(
        Rect.fromLTRB(s.right, s.top, size.width, s.bottom), dim);
    canvas.drawRect(s, Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Corner handles
    const hs = 14.0;
    final hp = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final c in [
      s.topLeft, s.topRight, s.bottomLeft, s.bottomRight
    ]) {
      final dx = (c.dx == s.left) ? 1 : -1;
      final dy = (c.dy == s.top)  ? 1 : -1;
      canvas.drawLine(c, c + Offset(hs * dx, 0), hp);
      canvas.drawLine(c, c + Offset(0, hs * dy), hp);
    }
  }

  @override
  bool shouldRepaint(_SelectPainter o) =>
      o.image != image || o.imgRect != imgRect || o.selection != selection;
}

// ─── Big pick button ───────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
