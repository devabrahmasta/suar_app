import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Badge bulat kecil untuk menampilkan nilai singkat (mis. magnitudo gempa)
/// dengan warna latar yang menandakan tingkat urgensi/status.
class IconCircleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final double fontSize;

  const IconCircleBadge({
    super.key,
    required this.label,
    required this.color,
    this.size = 40,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
