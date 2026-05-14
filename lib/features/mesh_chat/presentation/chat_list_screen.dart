import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/theme/app_colors.dart';
import 'mesh_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedPeers = ref.watch(connectedPeersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Obrolan'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari pengguna...',
                prefixIcon: const Icon(Iconsax.search_normal),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Public Chat Tile
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Iconsax.global, color: AppColors.white),
                  ),
                  title: const Text(
                    'Public Mesh Chat',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Broadcast ke semua orang di sekitar'),
                  onTap: () => context.pushNamed('public_chat'),
                ),
                const Divider(height: 1),

                // Active Peers
                if (connectedPeers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 64.0),
                    child: Center(
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
                  )
                else
                  ...connectedPeers.entries.map((entry) {
                    final peerId = entry.key;
                    final peerName = entry.value;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        peerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Online di jaringan mesh',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        context.pushNamed(
                          'direct_message',
                          pathParameters: {'peerId': peerId},
                          extra: peerName,
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
