import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const String _historyKey = 'meter_edit_history';

  final _historyChangedController = StreamController<void>.broadcast();
  Stream<void> get onHistoryChanged => _historyChangedController.stream;

  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    final items = <HistoryItem>[];
    for (final s in jsonList) {
      try {
        items.add(HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return items;
  }

  Future<void> addHistory(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    jsonList.add(jsonEncode(item.toJson()));
    if (jsonList.length > 50) jsonList.removeAt(0);
    await prefs.setStringList(_historyKey, jsonList);
    _historyChangedController.add(null);
  }

  Future<void> removeHistory(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    jsonList.removeWhere((s) {
      try {
        final item =
            HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
        return item.timestamp.toIso8601String() ==
            timestamp.toIso8601String();
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_historyKey, jsonList);
    _historyChangedController.add(null);
  }
}
