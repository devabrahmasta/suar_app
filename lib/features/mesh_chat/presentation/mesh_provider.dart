import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../domain/message_model.dart';
import '../data/chat_repository.dart';
import '../data/mesh_service.dart';
import '../../user/presentation/user_notifier.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final meshServiceProvider = Provider<MeshService>((ref) {
  ref.keepAlive();
  final chatRepository = ref.watch(chatRepositoryProvider);
  final service = MeshService(chatRepository: chatRepository);
  
  service.onPeersUpdated = () {
    // Memperbarui map endpointId -> nama peer aktif
    ref.read(connectedPeersProvider.notifier).state = Map.from(service.connectedEndpoints);
  };
  
  return service;
});

final connectedPeersProvider = StateProvider<Map<String, String>>((ref) {
  return {};
});

final meshLifecycleProvider = AsyncNotifierProvider<MeshLifecycleNotifier, void>(MeshLifecycleNotifier.new);

class MeshLifecycleNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() async {
    final user = ref.watch(userProvider);
    if (user == null) {
      return;
    }

    print('🔵 Mesh: Memulai...');

    final meshService = ref.read(meshServiceProvider);

    ref.onDispose(() {
      meshService.disconnect();
    });

    final results = await Future.wait([
      meshService.startAdvertising(user),
      meshService.startDiscovery(user),
    ]);

    if (results[0] && results[1]) {
      print('✅ Mesh: Aktif');
    } else {
      print('❌ Mesh: Gagal');
    }
  }
}

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

typedef DmParams = ({String myDeviceId, String peerId});

final dmMessagesProvider = StreamProvider.family<List<MessageModel>, DmParams>((ref, params) async* {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final meshService = ref.watch(meshServiceProvider);

  List<MessageModel> messages = await chatRepo.getDmMessages(params.myDeviceId, params.peerId);
  yield messages;

  await for (final msg in meshService.messageStream) {
    if (msg.type == MessageType.dm && (msg.peerId == params.peerId || msg.senderId == params.peerId)) {
      messages = await chatRepo.getDmMessages(params.myDeviceId, params.peerId);
      yield messages;
    }
  }
});
