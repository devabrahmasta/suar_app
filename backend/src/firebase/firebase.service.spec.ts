import * as admin from 'firebase-admin';
import { FirebaseService } from './firebase.service';

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  credential: { cert: jest.fn() },
  messaging: jest.fn(),
}));

describe('FirebaseService', () => {
  const sendEachForMulticast = jest.fn();
  let service: FirebaseService;

  beforeEach(() => {
    jest.clearAllMocks();
    sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 0,
    });
    (admin.messaging as unknown as jest.Mock).mockReturnValue({
      sendEachForMulticast,
    });
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = '{}';
    service = new FirebaseService();
    service.onModuleInit();
  });

  afterEach(() => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  });

  it('should send with high priority on the emergency notification channel', async () => {
    await service.sendPushNotification(['real-token'], 'Judul', 'Isi', {
      type: 'EARTHQUAKE_ALERT',
    });

    expect(sendEachForMulticast).toHaveBeenCalledWith({
      tokens: ['real-token'],
      notification: { title: 'Judul', body: 'Isi' },
      data: { type: 'EARTHQUAKE_ALERT' },
      android: {
        priority: 'high',
        notification: { channelId: 'suar_darurat_v5' },
      },
    });
  });

  it('should filter out mock tokens before sending', async () => {
    await service.sendPushNotification(
      ['mock_token_abcd1234', 'real-token'],
      'Judul',
      'Isi',
    );

    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({ tokens: ['real-token'] }),
    );
  });

  it('should not send when every token is a mock token', async () => {
    await service.sendPushNotification(['mock_token_abcd1234'], 'Judul', 'Isi');

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('should not send when Firebase is not initialized', async () => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const uninitializedService = new FirebaseService();
    uninitializedService.onModuleInit();

    await uninitializedService.sendPushNotification(['real-token'], 'a', 'b');

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });
});
