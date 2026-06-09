// 历史记录列表页
//
// 功能：
//   - 列表显示所有历史（星标置顶 + 时间倒序）
//   - 点击 → 回主页并应用该条参数（Navigator.pop 返回 entry）
//   - 长按 / 星标按钮：标记置顶
//   - 左滑删除（Dismissible）
//   - 清空：AppBar 右上垃圾桶 + 确认 dialog

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('混气历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空所有',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<String>>(
        valueListenable: HistoryService.listenable(),
        builder: (_, __, ___) {
          final entries = HistoryService.all();
          if (entries.isEmpty) return _emptyState(context);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _HistoryTile(entry: entries[i]),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('还没有保存的混气记录',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Text('在主页计算后点「保存」即可记录',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空所有历史？'),
        content: const Text('此操作不可恢复，已星标置顶的记录也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '清空',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await HistoryService.clear();
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStarred = entry.starredAt != null;
    return Dismissible(
      key: ValueKey(entry.syncId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('删除这条记录？'),
            content: Text(
                '${entry.presetName} · ${_fmtTime(entry.time)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDismissed: (_) => HistoryService.delete(entry.syncId),
      child: ListTile(
        onTap: () => Navigator.pop(context, entry), // 应用到主页
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            entry.presetName.length > 4
                ? entry.presetName.substring(0, 4)
                : entry.presetName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Row(
          children: [
            if (isStarred)
              Icon(Icons.star, size: 14, color: Colors.amber.shade600),
            if (isStarred) const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${entry.targetO2.toStringAsFixed(0)}/'
                '${entry.targetHe.toStringAsFixed(0)} → '
                '${entry.targetPressure.toStringAsFixed(0)} bar',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '残 ${entry.currentPressure.toStringAsFixed(0)} bar '
              '${entry.currentO2.toStringAsFixed(0)}/${entry.currentHe.toStringAsFixed(0)}'
              '  →  He ${entry.heliumToFill.toStringAsFixed(1)}  '
              'O₂ ${entry.oxygenToFill.toStringAsFixed(1)}  '
              'Air ${entry.airToFill.toStringAsFixed(1)} bar',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _fmtTime(entry.time),
              style: TextStyle(
                fontSize: 11,
                color: scheme.outline,
              ),
            ),
            if (entry.notes != null && entry.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '📝 ${entry.notes}',
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isStarred ? Icons.star : Icons.star_border,
            color: isStarred ? Colors.amber.shade600 : scheme.outline,
          ),
          onPressed: () => HistoryService.toggleStar(entry.syncId),
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
