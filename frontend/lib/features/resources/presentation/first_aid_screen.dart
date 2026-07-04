import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P3K Bencana')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prosedur berdasarkan panduan PMI & Kemenkes RI',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
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
                _buildTile(
                  icon: Icons.warning_amber,
                  judul: 'Tertimpa Reruntuhan',
                  langkah: [
                    'Jangan panik — berteriak hanya saat dengar suara penolong',
                    'Lindungi mulut & hidung dari debu dengan kain',
                    'Ketuk pipa atau dinding agar penolong dapat mendengar posisi kamu',
                    'Jangan nyalakan korek atau api — waspadai kebocoran gas',
                    'Tunggu bantuan — jangan paksa bergerak jika tulang terasa sakit',
                  ],
                ),
                _buildTile(
                  icon: Icons.bloodtype,
                  judul: 'Pendarahan',
                  langkah: [
                    'Tekan kuat luka dengan kain bersih atau kasa steril',
                    'Jangan lepas tekanan meski kain sudah basah darah — tambah lapisan',
                    'Angkat bagian yang luka lebih tinggi dari jantung jika memungkinkan',
                    'Ikat dengan kain sebagai pembalut tekan — jangan terlalu kencang',
                    'Segera bawa ke pos kesehatan terdekat',
                  ],
                ),
                _buildTile(
                  icon: Icons.monitor_heart,
                  judul: 'Tidak Sadar / Henti Napas (CPR)',
                  langkah: [
                    'Pastikan area aman — jauhkan dari reruntuhan',
                    'Miringkan kepala korban ke belakang, angkat dagu',
                    'Periksa napas maksimal 10 detik',
                    'Jika tidak bernapas: tiup 2x napas ke mulut, tutup hidung',
                    'Tekan dada 30x (kuat, cepat, di tengah dada)',
                    'Ulangi 30 tekanan + 2 tiupan hingga bantuan datang',
                  ],
                ),
                _buildTile(
                  icon: Icons.healing,
                  judul: 'Patah Tulang',
                  langkah: [
                    'JANGAN gerakkan atau luruskan tulang yang patah',
                    'Stabilkan dengan papan, tongkat, atau benda kaku lain',
                    'Ikat bidai longgar di atas & bawah patahan — jangan di titik patah',
                    'Jika tulang terlihat keluar, tutup dengan kain bersih — jangan tekan',
                    'Bawa ke pos medis dengan hati-hati, kepala tetap terlindung',
                  ],
                ),
                _buildTile(
                  icon: Icons.water,
                  judul: 'Terseret/Tenggelam Arus Tsunami',
                  langkah: [
                    'Jika korban tidak sadar dan basah — miringkan tubuh agar air keluar',
                    'Periksa napas — jika tidak bernapas, segera lakukan CPR',
                    'Jaga tubuh tetap hangat — tutupi dengan kain atau pakaian kering',
                    'Jangan beri makan atau minum jika korban tidak sadar penuh',
                    'Segera bawa ke pos kesehatan terdekat',
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'P3K hanya tindakan sementara. Segera serahkan ke tenaga medis.\nSumber: PMI, Kemenkes RI, BNPB',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String judul,
    required List<String> langkah,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(
            judul,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: langkah.asMap().entries.map((entry) {
            int index = entry.key;
            String teks = entry.value;
            return _StepItem(nomor: index + 1, teks: teks);
          }).toList(),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int nomor;
  final String teks;

  const _StepItem({required this.nomor, required this.teks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              '$nomor',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
