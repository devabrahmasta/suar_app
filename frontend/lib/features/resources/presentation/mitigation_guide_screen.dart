import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';

class MitigationGuideScreen extends ConsumerStatefulWidget {
  const MitigationGuideScreen({super.key});

  @override
  ConsumerState<MitigationGuideScreen> createState() => _MitigationGuideScreenState();
}

class _MitigationGuideScreenState extends ConsumerState<MitigationGuideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _protocolData;
  bool _isLoading = true;

  // State Checklist Tas Siaga Bencana
  final Set<String> _checkedItems = {};
  String _selectedDisabilityCategory = 'umum'; // umum, netra, tuli, intelektual, fisik

  // State Search & Filter Protokol Evakuasi
  String _searchQuery = '';
  String _selectedDisasterFilter = 'all'; // all, earthquake, tsunami

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadJsonData();
    _loadChecklistState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJsonData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/protokol_mitigasi.json');
      final data = jsonDecode(jsonString);
      setState(() {
        _protocolData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('MitigationGuideScreen: Gagal memuat asset json: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChecklistState() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedList = prefs.getStringList('tsb_checked_items') ?? [];
    setState(() {
      _checkedItems.addAll(savedList);
    });
  }

  Future<void> _toggleCheckItem(String itemId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      if (_checkedItems.contains(itemId)) {
        _checkedItems.remove(itemId);
      } else {
        _checkedItems.add(itemId);
      }
    });
    await prefs.setStringList('tsb_checked_items', _checkedItems.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Mitigasi & Tas Siaga AI'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(icon: Icon(Icons.backpack_rounded), text: 'Tas Siaga Bencana'),
            Tab(icon: Icon(Icons.menu_book_rounded), text: 'Protokol Evakuasi AI'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTasSiagaTab(),
                _buildProtokolEvakuasiTab(),
              ],
            ),
    );
  }

  // ================= TAB 1: TAS SIAGA BENCANA =================
  Widget _buildTasSiagaTab() {
    if (_protocolData == null || _protocolData!['tas_siaga_bencana'] == null) {
      return const Center(child: Text('Data Tas Siaga Bencana tidak ditemukan.'));
    }

    final tsb = _protocolData!['tas_siaga_bencana'];
    final List umumItems = tsb['perlengkapan_umum'] ?? [];
    final Map<String, dynamic> disabilitasMap = tsb['perlengkapan_khusus_disabilitas'] ?? {};

    List currentItems = [];
    if (_selectedDisabilityCategory == 'umum') {
      currentItems = umumItems;
    } else if (_selectedDisabilityCategory == 'netra') {
      currentItems = disabilitasMap['disabilitas_netra'] ?? [];
    } else if (_selectedDisabilityCategory == 'tuli') {
      currentItems = disabilitasMap['disabilitas_tuli'] ?? [];
    } else if (_selectedDisabilityCategory == 'intelektual') {
      currentItems = disabilitasMap['disabilitas_intelektual_dan_mental'] ?? [];
    } else if (_selectedDisabilityCategory == 'fisik') {
      currentItems = disabilitasMap['disabilitas_fisik'] ?? [];
    }

    int checkedCount = currentItems.where((item) => _checkedItems.contains(item['id'])).length;
    double progress = currentItems.isEmpty ? 0.0 : checkedCount / currentItems.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Info Tas Siaga
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tsb['deskripsi'] ?? 'Tas siaga bencana disiapkan untuk bertahan hidup minimal 3 hari saat evakuasi.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selector Kategori Disabilitas / Umum
          const Text(
            'PILIH KATEGORI PERLENGKAPAN',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilterChip('Umum (17 Item)', 'umum'),
                _buildCategoryFilterChip('Disabilitas Netra', 'netra'),
                _buildCategoryFilterChip('Disabilitas Tuli', 'tuli'),
                _buildCategoryFilterChip('Intelektual & Mental', 'intelektual'),
                _buildCategoryFilterChip('Disabilitas Fisik', 'fisik'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kesiapan Tas Siaga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '$checkedCount / ${currentItems.length} Terpenuhi (${(progress * 100).round()}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: progress == 1.0 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? AppColors.success : AppColors.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List Checkbox Item
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = currentItems[index];
              final isChecked = _checkedItems.contains(item['id']);
              return CheckboxListTile(
                tileColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isChecked ? AppColors.success : AppColors.border,
                    width: isChecked ? 1.5 : 1.0,
                  ),
                ),
                activeColor: AppColors.success,
                value: isChecked,
                onChanged: (val) => _toggleCheckItem(item['id']),
                title: Text(
                  item['nama'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? AppColors.textHint : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  item['catatan'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                secondary: Icon(
                  isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isChecked ? AppColors.success : AppColors.textHint,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label, String value) {
    final isSelected = _selectedDisabilityCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedDisabilityCategory = value;
            });
          }
        },
      ),
    );
  }

  // ================= TAB 2: PROTOKOL EVAKUASI AI =================
  Widget _buildProtokolEvakuasiTab() {
    if (_protocolData == null || _protocolData!['protokol_evakuasi'] == null) {
      return const Center(child: Text('Data protokol tidak ditemukan.'));
    }

    final List rawProtocols = _protocolData!['protokol_evakuasi'] ?? [];

    // Filter Protokol berdasarkan Search Query & Disaster Type
    final filteredProtocols = rawProtocols.where((p) {
      final matchesDisaster = _selectedDisasterFilter == 'all' || p['disaster_type'] == _selectedDisasterFilter;
      final query = _searchQuery.toLowerCase();
      final titleMatches = (p['title'] ?? '').toString().toLowerCase().contains(query);
      final descMatches = (p['description'] ?? '').toString().toLowerCase().contains(query);
      final locationMatches = (p['location_context'] ?? '').toString().toLowerCase().contains(query);
      return matchesDisaster && (titleMatches || descMatches || locationMatches);
    }).toList();

    return Column(
      children: [
        // Search & Filter Box
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.white,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari protokol (contoh: Dapur, Lift, Mobil, Tsunami)...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Jenis Bencana: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Semua'),
                      selected: _selectedDisasterFilter == 'all',
                      onSelected: (val) => setState(() => _selectedDisasterFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Gempa Bumi'),
                      selected: _selectedDisasterFilter == 'earthquake',
                      onSelected: (val) => setState(() => _selectedDisasterFilter = 'earthquake'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Tsunami'),
                      selected: _selectedDisasterFilter == 'tsunami',
                      onSelected: (val) => setState(() => _selectedDisasterFilter = 'tsunami'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List Protocols
        Expanded(
          child: filteredProtocols.isEmpty
              ? const Center(child: Text('Tidak ada protokol yang sesuai dengan pencarian.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProtocols.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredProtocols[index];
                    final isTsunami = item['disaster_type'] == 'tsunami';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isTsunami ? AppColors.danger.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isTsunami ? AppColors.dangerLight : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (item['disaster_type'] ?? '').toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isTsunami ? AppColors.danger : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: ${item['id']}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['description'] ?? '',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.verified, size: 14, color: AppColors.success),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Sumber: ${item['official_source'] ?? 'PUPR / BMKG'}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
