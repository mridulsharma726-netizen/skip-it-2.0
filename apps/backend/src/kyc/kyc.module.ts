import { Module } from '@nestjs/common';
import { KycService } from './kyc.service';
import { KycController } from './kyc.controller';
import { SupabaseModule } from '../common/supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [KycController],
  providers: [KycService],
  exports: [KycService],
})
export class KycModule {}
