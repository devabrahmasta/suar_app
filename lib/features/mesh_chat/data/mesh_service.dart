import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../user/domain/user_model.dart';
import '../domain/message_model.dart';
import 'chat_repository.dart';

class MeshService {
  final ChatRepository chatRepository;
  
  static const Strategy strategy = Strategy.P2P_CLUSTER;
  static const String serviceId = 'com.suar.mesh';

  final _messageController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get messageStream => _messageController.stream;

  // Endpoint ID -> Display Name
  final Map<String, String> connectedEndpoints = {};
  final Map<String, String> _pendingEndpoints = {};

  final Map<String, String> endpointToDeviceId = {}; // endpointId -> deviceId lawan
  final Map<String, String> endpointToName = {};      // endpointId -> fullName lawan (untuk UI)

  String? getDeviceIdByEndpoint(String endpointId) => endpointToDeviceId[endpointId];

  VoidCallback? onPeersUpdated;

  MeshService({required this.chatRepository});

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
  }

  void _updatePeers() {
    if (onPeersUpdated != null) {
      onPeersUpdated!();
    }
  }

  void _onConnectionResult(String id, Status status, UserModel user) {
    if (status == Status.CONNECTED) {
      if (_pendingEndpoints.containsKey(id)) {
        connectedEndpoints[id] = 'Unknown';
        _pendingEndpoints.remove(id);
      }
      print('✅ [Mesh] Terhubung dengan: $id (deviceId: ${endpointToDeviceId[id]})');
      
      final handshakePayload = {
        'type': 'handshake',
        'deviceId': user.deviceId,
        'fullName': user.fullName,
      };
      Nearby().sendBytesPayload(
        id, 
        Uint8List.fromList(utf8.encode(jsonEncode(handshakePayload)))
      );
      
      _updatePeers();
    } else {
      _pendingEndpoints.remove(id);
      connectedEndpoints.remove(id);
      _updatePeers();
    }
  }

  Future<bool> startAdvertising(UserModel user) async {
    print('🔵 [Mesh] Mulai advertising sebagai deviceId: ${user.deviceId}');
    try {
      final bool a = await Nearby().startAdvertising(
        user.deviceId,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          _onConnectionResult(id, status, user);
        },
        onDisconnected: (id) {
          print('🔴 [Mesh] Terputus dari: $id');
          _pendingEndpoints.remove(id);
          connectedEndpoints.remove(id);
          _updatePeers();
        },
        serviceId: serviceId,
      );
      return a;
    } catch (e) {
      return false;
    }
  }

  Future<bool> startDiscovery(UserModel user) async {
    print('🔵 [Mesh] Mulai discovery...');
    try {
      final bool a = await Nearby().startDiscovery(
        user.deviceId,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            user.deviceId,
            id,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: (id, status) {
              _onConnectionResult(id, status, user);
            },
            onDisconnected: (id) {
              print('🔴 [Mesh] Terputus dari: $id');
              _pendingEndpoints.remove(id);
              connectedEndpoints.remove(id);
              _updatePeers();
            },
          );
        },
        onEndpointLost: (id) {
          // Endpoint is out of range or lost
        },
        serviceId: serviceId,
      );
      return a;
    } catch (e) {
      return false;
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    print('🤝 [Mesh] Koneksi masuk dari endpointId: $endpointId, name: ${info.endpointName}');
    // We accept all incoming connections for the mesh
    _pendingEndpoints[endpointId] = info.endpointName;
    endpointToDeviceId[endpointId] = info.endpointName;
    
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _handleIncomingPayload(endpointId, payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
  }

  Future<void> _handleIncomingPayload(String senderEndpointId, Uint8List bytes) async {
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr);

      if (map['type'] == 'handshake') {
        final fullName = map['fullName'] as String;
        endpointToName[senderEndpointId] = fullName;
        connectedEndpoints[senderEndpointId] = fullName;
        _updatePeers();
        return;
      }

      final message = MessageModel.fromMap(map);
      print('📨 [Mesh] Payload masuk dari $senderEndpointId, type: ${message.type}, id: ${message.id}');

      // 1. DEDUPLICATION CHECK
      final exists = await chatRepository.hasMessage(message.id);
      if (exists) {
        print('⚠️ [Mesh] Duplikat diabaikan: ${message.id}');
        return; // Abaikan jika sudah ada
      }

      // 2. Simpan ke database
      await chatRepository.saveMessage(message);
      _messageController.add(message);

      // 3. Relay (Forward) jika hopCount < 5
      if (message.hopCount < 5) {
        final forwardedMessage = message.copyWith(hopCount: message.hopCount + 1);
        _forwardMessage(forwardedMessage, excludeEndpointId: senderEndpointId);
      }
    } catch (e) {
      // Abaikan jika payload bukan json yang valid
    }
  }

  Future<void> sendMessage(MessageModel message) async {
    print('📤 [Mesh] Kirim pesan ke ${connectedEndpoints.length} peer(s), id: ${message.id}');
    final exists = await chatRepository.hasMessage(message.id);
    if (!exists) {
      await chatRepository.saveMessage(message);
    }
    _messageController.add(message);
    _forwardMessage(message);
  }

  Future<void> _forwardMessage(MessageModel message, {String? excludeEndpointId}) async {
    final bytes = utf8.encode(jsonEncode(message.toMap()));
    for (final endpointId in connectedEndpoints.keys) {
      if (endpointId != excludeEndpointId) {
        try {
          print('🔁 [Mesh] Forward ke endpointId: $endpointId');
          await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(bytes));
        } catch (e) {
          // Gagal kirim ke satu peer, lanjutkan ke peer lain
        }
      }
    }
  }

  Future<void> disconnect() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _pendingEndpoints.clear();
    connectedEndpoints.clear();
    _updatePeers();
  }
}
