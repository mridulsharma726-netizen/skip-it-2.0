import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { SupabaseModule } from './common/supabase/supabase.module';
import { AuthModule } from './auth/auth.module';
import { ListingsModule } from './listings/listings.module';
import { BookingsModule } from './bookings/bookings.module';
import { StorageModule } from './storage/storage.module';
import { KycModule } from './kyc/kyc.module';
import { WishlistModule } from './wishlist/wishlist.module';
import { AdminModule } from './admin/admin.module';
import { MessagesModule } from './messages/messages.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '../../.env',
    }),
    SupabaseModule,
    AuthModule,
    ListingsModule,
    BookingsModule,
    StorageModule,
    KycModule,
    WishlistModule,
    AdminModule,
    MessagesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
