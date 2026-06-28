import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final items = await StorageService.instance.getHistory();
    if (mounted) {
      setState(() {
        _history = items.reversed.toList();
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(HistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delete?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Remove this edit from history?',
            style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.instance.removeHistory(item.timestamp);
      _loadHistory();
    }
  }

  Future<void> _shareItem(HistoryItem item) async {
    final file = File(item.filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(item.filePath)],
        text: 'Meter Reading: ${item.reading} kWh\nEdited with MeterSet Pro',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File no longer exists')),
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
          'Edit History',
          style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _loadHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : _history.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _history.length,
                  itemBuilder: (context, i) => _HistoryCard(
                    item: _history[i],
                    onShare: () => _shareItem(_history[i]),
                    onDelete: () => _deleteItem(_history[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 72, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            'No history yet',
            style: GoogleFonts.orbitron(
                color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved edits will appear here',
            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(item.filePath);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: file.existsSync()
                  ? Image.file(file,
                      fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: Colors.white12,
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white24, size: 36),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reading,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _fmtDate(item.timestamp),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.white30),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconBtn(
                        icon: Icons.share_rounded,
                        color: const Color(0xFF00E5FF),
                        onTap: onShare),
                    _IconBtn(
                        icon: Icons.delete_outline,
                        color: Colors.red,
                        onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  '
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
