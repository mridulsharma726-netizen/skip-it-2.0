import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/chat/data/chat_provider.dart';
import 'package:skipit/features/chat/data/chat_repository.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatUserIdProvider.notifier).setActive(widget.otherUserId);
      ref.read(chatHistoryProvider.notifier).load(widget.otherUserId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await ref.read(chatHistoryProvider.notifier).sendMessage(widget.otherUserId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e', style: const TextStyle(color: AppColors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatHistoryAsync = ref.watch(chatHistoryProvider);
    final authState = ref.watch(authProvider);
    final myUserId = authState.user?.id;

    // Trigger scroll to bottom on new messages
    chatHistoryAsync.whenData((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            ref.read(activeChatUserIdProvider.notifier).setActive(null);
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: widget.otherUserAvatar != null ? NetworkImage(widget.otherUserAvatar!) : null,
              child: widget.otherUserAvatar == null
                  ? Text(
                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatHistoryAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Start chatting with ${widget.otherUserName}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.content,
                              style: TextStyle(
                                color: isMe ? AppColors.white : AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                DateFormat('jm').format(msg.createdAt),
                                style: TextStyle(
                                  color: isMe ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(
                child: Text('Error loading history: $err', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.background)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.white, size: 18),
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
