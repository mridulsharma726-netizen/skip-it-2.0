import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { Request } from 'express';
import { SupabaseService } from '../../common/supabase/supabase.service';

/**
 * JWT Guard — validates the Bearer token via Supabase and attaches
 * the authenticated user to `request.user`.
 */
@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  private readonly logger = new Logger(SupabaseAuthGuard.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractToken(request);

    if (!token) {
      throw new UnauthorizedException('No authorization token provided');
    }

    try {
      const { data, error } = await this.supabaseService.client.auth.getUser(token);

      if (error || !data.user) {
        throw new UnauthorizedException('Invalid or expired token');
      }

      // Attach user to request for downstream use
      (request as any).user = data.user;
      return true;
    } catch (err) {
      this.logger.error(`Auth guard error: ${err.message}`);
      throw new UnauthorizedException('Authentication failed');
    }
  }

  private extractToken(request: Request): string | null {
    const authHeader = request.headers.authorization;
    if (!authHeader) return null;
    const [type, token] = authHeader.split(' ');
    return type === 'Bearer' ? token : null;
  }
}
