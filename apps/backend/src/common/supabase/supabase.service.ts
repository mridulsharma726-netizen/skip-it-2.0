import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService implements OnModuleInit {
  private readonly logger = new Logger(SupabaseService.name);
  private clientInstance: SupabaseClient;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    const url = this.configService.get<string>('SUPABASE_URL');
    const key = this.configService.get<string>('SUPABASE_SERVICE_ROLE_KEY');

    if (!url || !key) {
      this.logger.error('Supabase URL or Service Role Key is missing');
      throw new Error('Supabase configuration missing — cannot start server');
    }

    this.clientInstance = createClient(url, key, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    this.logger.log('Supabase client initialized successfully');
  }

  get client(): SupabaseClient {
    if (!this.clientInstance) {
      throw new Error('Supabase client not initialized — did onModuleInit run?');
    }
    return this.clientInstance;
  }
}
