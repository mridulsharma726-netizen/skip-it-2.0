import {
  Controller,
  Post,
  Patch,
  Body,
  Get,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignupDto, LoginDto, ForgotPasswordDto } from './dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SupabaseAuthGuard } from './guards/supabase-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('signup')
  async signup(@Body() dto: SignupDto) {
    return this.authService.signup(dto.email, dto.password, dto.fullName);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto.email, dto.password);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body('refreshToken') refreshToken: string) {
    return this.authService.refreshSession(refreshToken);
  }

  @Get('profile')
  @UseGuards(SupabaseAuthGuard)
  async getProfile(@Req() req: any) {
    return this.authService.getProfile(req.user.id);
  }

  @Patch('profile')
  @UseGuards(SupabaseAuthGuard)
  async updateProfile(@Req() req: any, @Body() dto: UpdateProfileDto) {
    return this.authService.updateProfile(req.user.id, {
      fullName: dto.fullName,
      phone: dto.phone,
      bio: dto.bio,
      location: dto.location,
    });
  }

  @Post('profile/avatar')
  @UseGuards(SupabaseAuthGuard)
  async updateAvatar(@Req() req: any, @Body('avatarUrl') avatarUrl: string) {
    return this.authService.updateAvatar(req.user.id, avatarUrl);
  }
}
