import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'chat_screen.dart';
import 'package:skipit/features/chat/data/chat_provider.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
        child: conversationsAsync.when(
          data: (conversations) {
            if (conversations.isEmpty) {
              return ListView(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 24),
                        const Text('No messages yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Send a message to a listing owner to start chatting about a rental item!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final chat = conversations[index];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: chat.otherUserAvatar != null ? NetworkImage(chat.otherUserAvatar!) : null,
                      child: chat.otherUserAvatar == null
                          ? Text(
                              chat.otherUserName.isNotEmpty ? chat.otherUserName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                            )
                          : null,
                    ),
                    title: Text(
                      chat.otherUserName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: chat.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMM d').format(chat.createdAt),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: const TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: chat.otherUserId,
                            otherUserName: chat.otherUserName,
                            otherUserAvatar: chat.otherUserAvatar,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(
            child: Text('Error loading inbox: $err', style: const TextStyle(color: AppColors.error)),
          ),
        ),
      ),
    );
  }
}
