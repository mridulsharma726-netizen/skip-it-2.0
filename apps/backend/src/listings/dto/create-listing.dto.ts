import { IsNotEmpty, IsString, IsNumber, IsOptional, IsArray, IsBoolean } from 'class-validator';

export class CreateListingDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsNumber()
  @IsNotEmpty()
  pricePerDay: number;

  @IsNumber()
  @IsNotEmpty()
  depositAmount: number;

  @IsString()
  @IsNotEmpty()
  category: string;

  @IsArray()
  @IsOptional()
  images?: string[];

  @IsNumber()
  @IsOptional()
  locationLat?: number;

  @IsNumber()
  @IsOptional()
  locationLng?: number;

  @IsString()
  @IsOptional()
  locationName?: string;

  @IsString()
  @IsOptional()
  condition?: string;
}
