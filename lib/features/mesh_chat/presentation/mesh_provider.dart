import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../domain/message_model.dart';
import '../data/chat_repository.dart';
import '../data/mesh_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final meshServiceProvider = Provider<MeshService>((ref) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  final service = MeshService(chatRepository: chatRepository);

  service.onPeersUpdated = () {
    // Memperbarui map endpointId -> nama peer aktif
    ref.read(connectedPeersProvider.notifier).state = Map.from(
      service.connectedEndpoints,
    );
  };

  return service;
});

final connectedPeersProvider = StateProvider<Map<String, String>>((ref) {
  return {};
});

final publicMessagesProvider = StreamProvider<List<MessageModel>>((ref) async* {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final meshService = ref.watch(meshServiceProvider);

  // 1. Fetch awal dari ChatRepository
  List<MessageModel> messages = await chatRepo.getPublicMessages();
  yield messages;

  // 2. Yield data baru jika ada message event bertipe public
  await for (final msg in meshService.messageStream) {
    if (msg.type == MessageType.public) {
      // Refresh dari DB untuk menjaga konsistensi urutan
      messages = await chatRepo.getPublicMessages();
      yield messages;
    }
  }
});

final dmMessagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  peerId,
) async* {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final meshService = ref.watch(meshServiceProvider);

  List<MessageModel> messages = await chatRepo.getDmMessages(peerId);
  yield messages;

  await for (final msg in meshService.messageStream) {
    if (msg.type == MessageType.dm &&
        (msg.peerId == peerId || msg.senderId == peerId)) {
      messages = await chatRepo.getDmMessages(peerId);
      yield messages;
    }
  }
});
