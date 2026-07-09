import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_repository.dart';

final conversationsProvider = AsyncNotifierProvider<ConversationsNotifier, List<ChatConversation>>(() {
  return ConversationsNotifier();
});

class ConversationsNotifier extends AsyncNotifier<List<ChatConversation>> {
  @override
  Future<List<ChatConversation>> build() async {
    return ref.read(chatRepositoryProvider).getConversations();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(chatRepositoryProvider).getConversations());
  }
}

class ActiveChatUserIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? userId) => state = userId;
}

final activeChatUserIdProvider = NotifierProvider<ActiveChatUserIdNotifier, String?>(
  ActiveChatUserIdNotifier.new,
);

class ChatHistoryNotifier extends Notifier<AsyncValue<List<ChatMessage>>> {
  Timer? _timer;
  String? _currentUserId;

  @override
  AsyncValue<List<ChatMessage>> build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const AsyncValue.loading();
  }

  Future<void> load(String chatUserId) async {
    _currentUserId = chatUserId;
    state = const AsyncValue.loading();
    
    // Set up timer for background polling if not already set
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final activeUser = ref.read(activeChatUserIdProvider);
      if (activeUser == _currentUserId && _currentUserId != null) {
        await poll(_currentUserId!);
      }
    });

    try {
      final messages = await ref.read(chatRepositoryProvider).getChatHistory(chatUserId);
      if (_currentUserId == chatUserId) {
        state = AsyncValue.data(messages);
      }
      ref.read(conversationsProvider.notifier).refresh();
    } catch (e, stack) {
      if (_currentUserId == chatUserId) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> poll(String chatUserId) async {
    try {
      final messages = await ref.read(chatRepositoryProvider).getChatHistory(chatUserId);
      if (_currentUserId == chatUserId) {
        state = AsyncValue.data(messages);
      }
    } catch (_) {}
  }

  Future<void> sendMessage(String chatUserId, String content, {String? bookingId}) async {
    final newMessage = await ref.read(chatRepositoryProvider).sendMessage(
          receiverId: chatUserId,
          content: content,
          bookingId: bookingId,
        );

    state.whenData((currentList) {
      if (_currentUserId == chatUserId) {
        state = AsyncValue.data([...currentList, newMessage]);
      }
    });

    ref.read(conversationsProvider.notifier).refresh();
  }
}

final chatHistoryProvider = NotifierProvider<ChatHistoryNotifier, AsyncValue<List<ChatMessage>>>(
  ChatHistoryNotifier.new,
);
