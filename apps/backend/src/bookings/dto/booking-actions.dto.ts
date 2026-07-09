import { IsOptional, IsString, IsArray } from 'class-validator';

export class ApproveBookingDto {
  // No additional data needed — the booking ID comes from the URL param
}

export class RejectBookingDto {
  @IsString()
  reason: string;
}

export class ActivateBookingDto {
  @IsString()
  otp: string;
}

export class ReturnBookingDto {
  @IsArray()
  @IsOptional()
  evidenceUrls?: string[];
}

export class CompleteReturnDto {
  @IsOptional()
  @IsString()
  damageClaim?: string;

  @IsOptional()
  damageDeduction?: number;
}

export class CancelBookingDto {
  @IsString()
  reason: string;
}

export class DisputeBookingDto {
  @IsString()
  reason: string;

  @IsArray()
  @IsOptional()
  evidenceUrls?: string[];
}
