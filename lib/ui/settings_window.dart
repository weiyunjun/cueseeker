import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_path_entry.dart';
import '../view_models/home_view_model.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isEditing = false;
  bool _isLoading = true;
  List<SearchPathEntry> _paths = [];

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final service = ref.read(searchPathServiceProvider);
    final loaded = await service.loadPaths();
    if (!mounted) return;
    setState(() {
      _paths = loaded;
      _isLoading = false;
    });
  }

  Future<void> _savePaths(List<SearchPathEntry> paths) async {
    await ref.read(reindexStateProvider.notifier).savePathsAndReindex(paths);
    if (!mounted) return;
    setState(() {
      _paths = paths;
    });
  }

  Future<void> _chooseAddType() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('添加本地文件夹'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewLocalPath();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_queue),
                title: const Text('添加 WebDAV 网盘'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewWebdavPath();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addNewLocalPath() async {
    final directoryPath = await getDirectoryPath();
    if (directoryPath == null) return;
    if (_paths.any((entry) => entry.type == PathEntryType.local && entry.path == directoryPath)) {
      return;
    }
    final nextPaths = List<SearchPathEntry>.from(_paths)
      ..add(SearchPathEntry(type: PathEntryType.local, path: directoryPath));
    await _savePaths(nextPaths);
  }

  Future<void> _addNewWebdavPath() async {
    String url = '';
    String user = '';
    String pass = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('连接 WebDAV 服务器'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'WebDAV URL (如: http://192.168.1.5:5244/dav)',
                ),
                onChanged: (value) => url = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: '用户名'),
                onChanged: (value) => user = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
                onChanged: (value) => pass = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || url.trim().isEmpty) return;
    final nextPaths = List<SearchPathEntry>.from(_paths)
      ..add(
        SearchPathEntry(
          type: PathEntryType.webdav,
          path: url.endsWith('/') ? url : '$url/',
          username: user,
          password: pass,
        ),
      );
    await _savePaths(nextPaths);
  }

  Future<void> _removePath(SearchPathEntry path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('移除路径'),
          content: Text('是否移除该路径？\n${path.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                '确定',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    final nextPaths = List<SearchPathEntry>.from(_paths)..remove(path);
    await _savePaths(nextPaths);
  }

  @override
  Widget build(BuildContext context) {
    final reindexState = ref.watch(reindexStateProvider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                  child: Text(_isEditing ? '退出编辑' : '编辑'),
                ),
              ],
            ),
          ),
          if (reindexState.isRunning || reindexState.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
              child: Text(
                reindexState.message.isEmpty
                    ? '正在重建索引...'
                    : reindexState.message,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              itemCount: _paths.length + 1,
              separatorBuilder: (_, separatorIndex) =>
                  const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _paths.length) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.indigoAccent,
                    ),
                    title: const Text(
                      '添加路径...',
                      style: TextStyle(color: Colors.indigoAccent),
                    ),
                    onTap: _chooseAddType,
                  );
                }

                final path = _paths[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(path.toString()),
                  trailing: _isEditing
                      ? IconButton(
                          onPressed: () => _removePath(path),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
