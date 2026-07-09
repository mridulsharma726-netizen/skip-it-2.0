import { Injectable, Logger, UnauthorizedException, ConflictException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Register a new user with email/password and create their profile.
   */
  async signup(email: string, password: string, fullName: string) {
    const supabase = this.supabaseService.client;

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });

    if (authError) {
      this.logger.error(`Signup failed: ${authError.message}`);
      if (authError.message.includes('already')) {
        throw new ConflictException('A user with this email already exists');
      }
      throw new UnauthorizedException(authError.message);
    }

    // Create profile record
    const { error: profileError } = await supabase.from('profiles').insert({
      id: authData.user.id,
      full_name: fullName,
      updated_at: new Date().toISOString(),
    });

    if (profileError) {
      this.logger.error(`Profile creation failed: ${profileError.message}`);
      // Rollback: delete the auth user if profile creation fails
      await supabase.auth.admin.deleteUser(authData.user.id);
      throw new Error('Failed to create user profile');
    }

    // Sign in the user to get tokens
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      this.logger.error(`Auto sign-in after signup failed: ${signInError.message}`);
      throw new UnauthorizedException('Account created but login failed');
    }

    return {
      user: {
        id: authData.user.id,
        email: authData.user.email,
        fullName,
      },
      session: {
        accessToken: signInData.session.access_token,
        refreshToken: signInData.session.refresh_token,
        expiresAt: signInData.session.expires_at,
      },
    };
  }

  /**
   * Sign in an existing user with email/password.
   */
  async login(email: string, password: string) {
    const supabase = this.supabaseService.client;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      this.logger.error(`Login failed for ${email}: ${error.message}`);
      throw new UnauthorizedException('Invalid email or password');
    }

    // Fetch user profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .single();

    return {
      user: {
        id: data.user.id,
        email: data.user.email,
        fullName: profile?.full_name ?? '',
        avatarUrl: profile?.avatar_url ?? null,
        isVerified: profile?.is_verified ?? false,
        trustScore: profile?.trust_score ?? 50,
      },
      session: {
        accessToken: data.session.access_token,
        refreshToken: data.session.refresh_token,
        expiresAt: data.session.expires_at,
      },
    };
  }

  /**
   * Send a password reset email.
   */
  async forgotPassword(email: string) {
    const supabase = this.supabaseService.client;

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: 'skipit://reset-password', // deep link
    });

    if (error) {
      this.logger.error(`Password reset failed: ${error.message}`);
      // Don't leak whether user exists or not
    }

    return { message: 'If an account with that email exists, a reset link has been sent.' };
  }

  /**
   * Get the current user's profile using a JWT.
   */
  async getProfile(userId: string) {
    const supabase = this.supabaseService.client;

    let { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error || !data) {
      this.logger.warn(`Profile for user ${userId} not found, provisioning default profile...`);
      
      let fullName = 'User';
      try {
        const { data: authData } = await supabase.auth.admin.getUserById(userId);
        if (authData?.user) {
          fullName = authData.user.user_metadata?.full_name || 
                     authData.user.user_metadata?.name || 
                     authData.user.email?.split('@')[0] || 
                     'User';
        }
      } catch (e) {
        this.logger.error(`Failed to fetch auth user details for provisioning: ${e.message}`);
      }

      const { data: newProfile, error: insertError } = await supabase
        .from('profiles')
        .insert({
          id: userId,
          full_name: fullName,
          is_verified: false,
          rating: 5.0,
          trust_score: 50,
          updated_at: new Date().toISOString()
        })
        .select()
        .single();

      if (insertError) {
        this.logger.error(`Failed to provision default profile: ${insertError.message}`);
        throw new UnauthorizedException('Profile not found and could not be provisioned');
      }

      data = newProfile;
    }

    return {
      ...data,
      role: data.role || 'user',
      kyc_status: data.kyc_status || 'none',
      is_banned: data.is_banned || false,
      total_rentals: data.total_rentals ?? 0,
      total_listings: data.total_listings ?? 0,
      location: data.location || null,
      phone: data.phone || data.phone_number || null,
    };
  }

  /**
   * Refresh a session using a refresh token.
   */
  async refreshSession(refreshToken: string) {
    const supabase = this.supabaseService.client;

    const { data, error } = await supabase.auth.refreshSession({ refresh_token: refreshToken });

    if (error || !data.session) {
      throw new UnauthorizedException('Session expired. Please log in again.');
    }

    return {
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
      expiresAt: data.session.expires_at,
    };
  }

  /**
   * Update the current user's profile.
   */
  async updateProfile(userId: string, updates: {
    fullName?: string;
    phone?: string;
    bio?: string;
    location?: string;
  }) {
    const supabase = this.supabaseService.client;

    const updateData: any = { updated_at: new Date().toISOString() };
    if (updates.fullName !== undefined) updateData.full_name = updates.fullName;
    if (updates.phone !== undefined) {
      updateData.phone_number = updates.phone;
      updateData.phone = updates.phone;
    }
    if (updates.bio !== undefined) updateData.bio = updates.bio;
    if (updates.location !== undefined) updateData.location = updates.location;

    const { data, error } = await supabase
      .from('profiles')
      .update(updateData)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      this.logger.error(`Profile update failed: ${error.message}`);
      throw new Error('Failed to update profile');
    }

    return {
      ...data,
      role: data.role || 'user',
      kyc_status: data.kyc_status || 'none',
      is_banned: data.is_banned || false,
      total_rentals: data.total_rentals ?? 0,
      total_listings: data.total_listings ?? 0,
      location: data.location || null,
      phone: data.phone || data.phone_number || null,
    };
  }

  /**
   * Update the user's avatar URL in their profile.
   */
  async updateAvatar(userId: string, avatarUrl: string) {
    const supabase = this.supabaseService.client;

    const { data, error } = await supabase
      .from('profiles')
      .update({ avatar_url: avatarUrl, updated_at: new Date().toISOString() })
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      this.logger.error(`Avatar update failed: ${error.message}`);
      throw new Error('Failed to update avatar');
    }

    return {
      ...data,
      role: data.role || 'user',
      kyc_status: data.kyc_status || 'none',
      is_banned: data.is_banned || false,
      total_rentals: data.total_rentals ?? 0,
      total_listings: data.total_listings ?? 0,
      location: data.location || null,
      phone: data.phone || data.phone_number || null,
    };
  }
}
