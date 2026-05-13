import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'mesh_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    // TODO: implement send message logic
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final connectedPeers = ref.watch(connectedPeersProvider);
    final isConnected = connectedPeers.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Channel (Mesh)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              Iconsax.wifi,
              color: isConnected ? AppColors.success : AppColors.textHint,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isConnected
                ? ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Center(
                        child: Text(
                          'Terhubung dengan ${connectedPeers.length} peer(s).',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/chat/dm/user_123'),
                        child: const Text('Chat Private dengan Budi'),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada pengguna di sekitarmu.\nMenunggu koneksi...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: isConnected,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      filled: true,
                      fillColor: isConnected ? AppColors.background : AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isConnected ? _sendMessage : null,
                  icon: Icon(
                    Iconsax.send_1,
                    color: isConnected ? AppColors.primary : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
