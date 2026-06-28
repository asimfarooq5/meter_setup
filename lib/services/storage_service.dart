import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const String _historyKey = 'meter_edit_history';

  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    return jsonList
        .map((s) => HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addHistory(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    jsonList.add(jsonEncode(item.toJson()));
    if (jsonList.length > 50) jsonList.removeAt(0);
    await prefs.setStringList(_historyKey, jsonList);
  }

  Future<void> removeHistory(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = prefs.getStringList(_historyKey) ?? [];
    jsonList.removeWhere((s) {
      final item = HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
      return item.timestamp.toIso8601String() == timestamp.toIso8601String();
    });
    await prefs.setStringList(_historyKey, jsonList);
  }
}
