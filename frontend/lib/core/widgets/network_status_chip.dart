import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../features/map_evacuation/presentation/map_provider.dart';

/// Chip penanda status koneksi (Online/Offline) yang melayang di bagian atas layar.
class NetworkStatusChip extends ConsumerStatefulWidget {
  const NetworkStatusChip({super.key});

  @override
  ConsumerState<NetworkStatusChip> createState() => _NetworkStatusChipState();
}

class _NetworkStatusChipState extends ConsumerState<NetworkStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    // Nafas chip: turun ke hampir transparan (bukan 0 penuh) supaya konten
    // di belakangnya tetap kelihatan tanpa chip-nya benar-benar hilang.
    _breathAnimation = Tween<double>(begin: 0.18, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(networkStatusProvider);
    final networkState = networkAsync.value ?? [ConnectivityResult.none];
    final isOnline = !networkState.contains(ConnectivityResult.none);

    final bgColor = isOnline ? AppColors.successLight : AppColors.dangerLight;
    final borderColor = isOnline
        ? AppColors.success.withValues(alpha: 0.4)
        : AppColors.danger.withValues(alpha: 0.4);
    final textColor = isOnline ? AppColors.success : AppColors.danger;
    final labelText = isOnline ? 'Online' : 'Offline';
    final iconData = isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 14.0),
          child: AnimatedBuilder(
            animation: _breathAnimation,
            builder: (context, child) {
              return Opacity(opacity: _breathAnimation.value, child: child);
            },
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData, size: 13, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      labelText,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
