import * as dns from 'dns';
// Force Node.js to prefer IPv4 addresses over IPv6.
// This avoids ENETUNREACH errors on cloud platforms like Hugging Face that lack IPv6 routing.
dns.setDefaultResultOrder('ipv4first');

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const config = new DocumentBuilder()
    .setTitle('SUAR EWS API')
    .setDescription(
      'Dokumentasi API interaktif untuk backend Early Warning System (EWS) SUAR',
    )
    .setVersion('1.0')
    .addTag('users', 'Operasi terkait pendaftaran perangkat dan update lokasi')
    .addTag(
      'alerts',
      'Operasi terkait polling BMKG dan trigger notifikasi gempa',
    )
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
