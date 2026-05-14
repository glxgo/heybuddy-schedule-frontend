import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.get('/messages/${widget.friendId}');
    if (res.isSuccess && res.data != null) {
      setState(() {
        _messages = (res.data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final api = ref.read(apiServiceProvider);
    final res = await api.post(
      '/messages',
      data: {
        'receiverId': widget.friendId,
        'content': text,
        'contentType': 'text',
      },
    );

    if (res.isSuccess && res.data != null) {
      setState(() => _messages.add(res.data as Map<String, dynamic>));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).userId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.friendName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            '开始聊天吧~',
                            style: TextStyle(
                              color: AppColorTokens.textTertiary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final msg = _messages[i];
                            final isMe = msg['sender_id'] == userId;
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColorTokens.primary
                                      : AppColorTokens.background,
                                  borderRadius: BorderRadius.circular(14)
                                      .copyWith(
                                        bottomRight: isMe
                                            ? const Radius.circular(4)
                                            : null,
                                        bottomLeft: isMe
                                            ? null
                                            : const Radius.circular(4),
                                      ),
                                ),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe
                                        ? Colors.white
                                        : AppColorTokens.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Input bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  decoration: BoxDecoration(
                    color: AppColorTokens.surface,
                    border: Border(
                      top: BorderSide(color: AppColorTokens.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: InputDecoration(
                            hintText: '发消息...',
                            filled: true,
                            fillColor: AppColorTokens.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColorTokens.primary,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
