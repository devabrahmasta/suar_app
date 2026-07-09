import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private isInitialized = false;

  onModuleInit() {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

    if (!serviceAccountJson) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT_JSON tidak ditemukan di env. Pengiriman push notification asli akan di-bypass.',
      );
      return;
    }

    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      this.isInitialized = true;
      this.logger.log('Firebase Admin SDK berhasil diinisialisasi.');
    } catch (error: any) {
      this.logger.error(
        `Gagal menginisialisasi Firebase Admin SDK: ${error.message}`,
      );
    }
  }

  async sendPushNotification(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.isInitialized || tokens.length === 0) {
      this.logger.warn(
        `Bypass pengiriman notifikasi (Firebase tidak aktif atau daftar token kosong). Penerima: ${tokens.length} perangkat.`,
      );
      return;
    }

    // Filter token tiruan/mock agar tidak memicu error dari Firebase
    const realTokens = tokens.filter((t) => !t.startsWith('mock_token_'));
    if (realTokens.length === 0) {
      this.logger.log(
        'Seluruh token penerima adalah token tiruan (mock). Pengiriman di-bypass.',
      );
      return;
    }

    try {
      this.logger.log(
        `Mengirim push notification ke ${realTokens.length} perangkat asli...`,
      );
      const response = await admin.messaging().sendEachForMulticast({
        tokens: realTokens,
        notification: {
          title,
          body,
        },
        data,
      });

      this.logger.log(
        `Push notification terkirim. Sukses: ${response.successCount}, Gagal: ${response.failureCount}`,
      );
    } catch (error: any) {
      this.logger.error(
        `Gagal mengirim push notification: ${error.message}`,
      );
    }
  }
}
