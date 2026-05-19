import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_shell.dart';

class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends ConsumerState<AdminAnnouncementsScreen> {
  final _api = AdminApiService.instance;
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _api.fetchAnnouncements();
    if (mounted) setState(() { _items = (data['items'] as List?) ?? []; _loading = false; });
  }

  Future<void> _edit(Map<String, dynamic>? item) async {
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final contentCtrl = TextEditingController(text: item?['content'] ?? '');
    var status = item?['status'] ?? 'draft';
    var pinned = item?['pinned'] ?? false;
    Uint8List? imageBytes;
    String? imageName;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(item == null ? '新建公告' : '编辑公告'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder())),
                  const SizedBox(height: 14),
                  TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 12),
                  if (imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(imageBytes!, height: 160, fit: BoxFit.contain),
                      ),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (picker == null || picker.files.isEmpty) return;
                      final bytes = picker.files.single.bytes;
                      if (bytes == null) return;
                      setDlg(() { imageBytes = bytes; imageName = picker.files.single.name; });
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(imageBytes != null ? '已选择 $imageName' : '上传图片'),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Text('状态: '),
                    DropdownButton<String>(value: status, items: const [
                      DropdownMenuItem(value: 'draft', child: Text('草稿')),
                      DropdownMenuItem(value: 'published', child: Text('已发布')),
                      DropdownMenuItem(value: 'archived', child: Text('已归档')),
                    ], onChanged: (v) => setDlg(() => status = v!)),
                    const Spacer(),
                    const Text('置顶 '),
                    Switch(value: pinned, onChanged: (v) => setDlg(() => pinned = v)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final data = {
      'title': titleCtrl.text,
      'content': contentCtrl.text,
      'status': status,
      'pinned': pinned,
    };
    if (imageBytes != null) {
      data['image'] = 'data:image/png;base64,' + base64Encode(imageBytes!);
    }

    if (item == null) {
      await _api.createAnnouncement(data);
    } else {
      await _api.updateAnnouncement(item['id'] as String, data);
    }
    _load();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('删除公告'), content: const Text('确定删除？'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
    ]));
    if (ok != true) return;
    await _api.deleteAnnouncement(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: '公告管理',
      subtitle: '发布、编辑和管理系统公告',
      selectedIndex: 2,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('新建公告')),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['status']} | ${item['created_at'] ?? ''}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _edit(item)),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _delete(item['id'])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
