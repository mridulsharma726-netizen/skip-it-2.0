import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';
import { SendMessageDto } from './dto/send-message.dto';

@Injectable()
export class MessagesService {
  private readonly logger = new Logger(MessagesService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  private get client() {
    return this.supabaseService.client;
  }

  /**
   * Send a message to another user.
   */
  async sendMessage(senderId: string, dto: SendMessageDto) {
    if (senderId === dto.receiverId) {
      throw new BadRequestException('You cannot send a message to yourself');
    }

    const { data, error } = await this.client
      .from('messages')
      .insert({
        sender_id: senderId,
        receiver_id: dto.receiverId,
        content: dto.content,
        booking_id: dto.bookingId || null,
        is_read: false,
      })
      .select()
      .single();

    if (error) {
      this.logger.error(`Failed to send message: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    return data;
  }

  /**
   * Get direct message chat history between current user and another user.
   */
  async getChatHistory(userId: string, chatUserId: string) {
    const { data, error } = await this.client
      .from('messages')
      .select('*, sender:profiles!sender_id(full_name, avatar_url), receiver:profiles!receiver_id(full_name, avatar_url)')
      .or(`and(sender_id.eq.${userId},receiver_id.eq.${chatUserId}),and(sender_id.eq.${chatUserId},receiver_id.eq.${userId})`)
      .order('created_at', { ascending: true });

    if (error) {
      this.logger.error(`Failed to get chat history: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    // Mark incoming messages as read
    await this.client
      .from('messages')
      .update({ is_read: true })
      .eq('sender_id', chatUserId)
      .eq('receiver_id', userId)
      .eq('is_read', false);

    return data || [];
  }

  /**
   * Get all active conversations for the current user.
   */
  async getConversations(userId: string) {
    const { data, error } = await this.client
      .from('messages')
      .select('*, sender:profiles!sender_id(id, full_name, avatar_url), receiver:profiles!receiver_id(id, full_name, avatar_url)')
      .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
      .order('created_at', { ascending: false });

    if (error) {
      this.logger.error(`Failed to get conversations: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    // Group by unique chat users
    const conversationsMap = new Map<string, any>();
    
    for (const msg of (data || [])) {
      const otherUser = msg.sender_id === userId ? msg.receiver : msg.sender;
      if (!otherUser) continue;
      
      if (!conversationsMap.has(otherUser.id)) {
        conversationsMap.set(otherUser.id, {
          otherUser,
          lastMessage: msg.content,
          createdAt: msg.created_at,
          unreadCount: msg.receiver_id === userId && !msg.is_read ? 1 : 0,
        });
      } else {
        if (msg.receiver_id === userId && !msg.is_read) {
          conversationsMap.get(otherUser.id).unreadCount++;
        }
      }
    }

    return Array.from(conversationsMap.values());
  }
}
