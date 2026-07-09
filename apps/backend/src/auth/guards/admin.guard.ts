import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { SupabaseService } from '../../common/supabase/supabase.service';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly supabaseService: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new UnauthorizedException('Authentication required');
    }

    const { data: profile, error } = await this.supabaseService.client
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (error || !profile || profile.role !== 'admin') {
      throw new ForbiddenException('Admin access required');
    }

    return true;
  }
}
