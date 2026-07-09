import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const logger = new Logger('Bootstrap');

  // Global prefix — all routes become /api/...
  app.setGlobalPrefix('api');

  // Enable CORS for mobile & web clients
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // Validation pipe — auto-validates all incoming DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,           // strip unknown properties
      forbidNonWhitelisted: true, // throw if unknown properties sent
      transform: true,            // auto-transform payloads to DTO types
    }),
  );

  // Global exception filter
  app.useGlobalFilters(new GlobalExceptionFilter());

  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  logger.log(`🚀 SkipIt API running on http://0.0.0.0:${port}/api`);
}
bootstrap();
