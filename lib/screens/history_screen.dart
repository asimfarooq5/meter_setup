import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  bool _loading = true;
  StreamSubscription<void>? _historySub;

  @override
  void initState() {
    super.initState();
    _load();
    _historySub = StorageService.instance.onHistoryChanged.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _historySub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final all = await StorageService.instance.getHistory();
      // Filter out items whose files no longer exist
      final valid = <HistoryItem>[];
      for (final item in all) {
        if (await File(item.filePath).exists()) valid.add(item);
      }
      if (mounted) setState(() => _history = valid.reversed.toList());
    } catch (_) {
      if (mounted) setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(HistoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete?', style: TextStyle(color: Colors.white)),
        content: const Text('Yeh entry hata dein?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.instance.removeHistory(item.timestamp);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('History',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 56, color: Colors.white12),
                      SizedBox(height: 16),
                      Text('Koi history nahi',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 15)),
                      SizedBox(height: 8),
                      Text('Pehle koi meter edit karo',
                          style:
                              TextStyle(color: Colors.white12, fontSize: 12)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF00E5FF),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _history.length,
                    itemBuilder: (_, i) => _HistoryCard(
                      item: _history[i],
                      onShare: () async {
                        final f = File(_history[i].filePath);
                        if (await f.exists()) {
                          await Share.shareXFiles([XFile(f.path)],
                              text: 'Meter: ${_history[i].reading}');
                        }
                      },
                      onDelete: () => _delete(_history[i]),
                    ),
                  ),
                ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _HistoryCard(
      {required this.item,
      required this.onShare,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final file = File(item.filePath);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF1A1A1A),
                  child: Icon(Icons.broken_image, color: Colors.white12, size: 40),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reading,
                  style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _fmt(item.timestamp),
                  style:
                      const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onShare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.share,
                        color: Color(0xFF00E5FF), size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 16),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
