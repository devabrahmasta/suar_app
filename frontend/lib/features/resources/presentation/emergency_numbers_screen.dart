import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class EmergencyNumbersScreen extends StatelessWidget {
  const EmergencyNumbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nomor Darurat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tekan kartu untuk langsung menelepon',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCard(
                  label: 'Panggilan Darurat',
                  nomor: '112',
                  icon: Icons.warning,
                  color: AppColors.danger,
                ),
                _buildCard(
                  label: 'Ambulans',
                  nomor: '118',
                  icon: Icons.local_hospital,
                  color: AppColors.danger,
                ),
                _buildCard(
                  label: 'Pemadam Kebakaran',
                  nomor: '113',
                  icon: Icons.local_fire_department,
                  color: AppColors.warning,
                ),
                _buildCard(
                  label: 'Kepolisian',
                  nomor: '110',
                  icon: Icons.local_police,
                  color: AppColors.textPrimary,
                ),
                _buildCard(
                  label: 'SAR / Basarnas',
                  nomor: '115',
                  icon: Icons.support,
                  color: AppColors.info,
                ),
                _buildCard(
                  label: 'Posko Bencana Alam',
                  nomor: '129',
                  icon: Icons.campaign,
                  color: AppColors.warning,
                ),
                _buildCard(
                  label: 'Posko Kewaspadaan',
                  nomor: '122',
                  icon: Icons.shield,
                  color: AppColors.info,
                ),
                _buildCard(
                  label: 'Gangguan Listrik PLN',
                  nomor: '123',
                  icon: Icons.electric_bolt,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String label,
    required String nomor,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final url = Uri(scheme: 'tel', path: nomor);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nomor,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
