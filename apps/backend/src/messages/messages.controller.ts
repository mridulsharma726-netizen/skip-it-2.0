import { Controller, Get, Post, Body, Param, UseGuards, Req } from '@nestjs/common';
import { MessagesService } from './messages.service';
import { SendMessageDto } from './dto/send-message.dto';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('messages')
@UseGuards(SupabaseAuthGuard)
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Post()
  async sendMessage(@Req() req: any, @Body() dto: SendMessageDto) {
    return this.messagesService.sendMessage(req.user.id, dto);
  }

  @Get('conversations')
  async getConversations(@Req() req: any) {
    return this.messagesService.getConversations(req.user.id);
  }

  @Get('history/:chatUserId')
  async getChatHistory(@Req() req: any, @Param('chatUserId') chatUserId: string) {
    return this.messagesService.getChatHistory(req.user.id, chatUserId);
  }
}
