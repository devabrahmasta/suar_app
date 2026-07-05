import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import * as dns from 'dns';

// Force Node.js to prefer IPv4 addresses over IPv6.
// This avoids ENETUNREACH errors on cloud platforms like Hugging Face that lack IPv6 routing.
dns.setDefaultResultOrder('ipv4first');

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
