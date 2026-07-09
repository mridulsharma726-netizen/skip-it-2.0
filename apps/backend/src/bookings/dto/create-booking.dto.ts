import { IsNotEmpty, IsString, IsDateString, IsNumber } from 'class-validator';

export class CreateBookingDto {
  @IsString()
  @IsNotEmpty()
  listingId: string;

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsNumber()
  @IsNotEmpty()
  totalPrice: number;

  @IsNumber()
  @IsNotEmpty()
  depositPaid: number;
}
