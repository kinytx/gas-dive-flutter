// 本地历史记录 CRUD 服务 - 用 Hive Box<String> 存 JSON
//
// 设计：
//   - Box<String>: 每条 entry 一个 JSON 字符串，key = syncId
//   - List 查询：box.values 全取 + 解析 + 排序（星标置顶 + 时间倒序）
//   - 监听变化：Hive box.listenable() 给 ValueListenableBuilder
//
// 容量预估：单条 entry ~1KB，1000 条 = 1MB，本地存储完全够用。

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/history_entry.dart';

class HistoryService {
  static const String boxName = 'history';

  static Box<String> get _box => Hive.box<String>(boxName);

  /// App 启动时调一次
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(boxName);
  }

  /// 所有历史，按 (星标置顶 → 时间倒序) 排序
  static List<HistoryEntry> all() {
    final entries = _box.values
        .map((s) {
          try {
            return HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (e) {
            // 损坏的 JSON 跳过（可能跨版本 schema 变化）
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();
    entries.sort((a, b) {
      // 星标置顶
      if ((a.starredAt != null) != (b.starredAt != null)) {
        return a.starredAt != null ? -1 : 1;
      }
      // 时间倒序
      return b.syncUpdatedAt.compareTo(a.syncUpdatedAt);
    });
    return entries;
  }

  /// 单条
  static HistoryEntry? get(String syncId) {
    final s = _box.get(syncId);
    if (s == null) return null;
    try {
      return HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 保存（新增或覆盖）
  static Future<void> save(HistoryEntry entry) async {
    await _box.put(entry.syncId, jsonEncode(entry.toJson()));
  }

  /// 删除
  static Future<void> delete(String syncId) async {
    await _box.delete(syncId);
  }

  /// 批量删除（清空）
  static Future<void> clear() async {
    await _box.clear();
  }

  /// 切换星标
  static Future<void> toggleStar(String syncId) async {
    final e = get(syncId);
    if (e == null) return;
    final isStarred = e.starredAt != null;
    final updated = e.copyWith(
      clearStarred: isStarred,
      starredAt:
          isStarred ? null : DateTime.now().millisecondsSinceEpoch,
      syncUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await save(updated);
  }

  /// 改备注
  static Future<void> updateNotes(String syncId, String notes) async {
    final e = get(syncId);
    if (e == null) return;
    await save(e.copyWith(
      notes: notes,
      syncUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 监听 Box 变化（给 ValueListenableBuilder 用）
  static ValueListenable<Box<String>> listenable() => _box.listenable();

  /// 总条数
  static int get count => _box.length;
}
