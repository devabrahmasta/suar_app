import json
import os

data = {
    "metadata": {
        "title": "Single Source of Truth - Kumpulan Protokol Resmi Mitigasi Bencana Gempa Bumi & Tsunami",
        "description": "Basis data protokol mitigasi, evakuasi, perlengkapan tas siaga, dan tindakan darurat resmi yang diekstrak dari dokumen Kementerian PUPR, BMKG, BPBD/BNPB, dan Hasil Kajian Manajemen Bencana Tsunami.",
        "version": "1.0.0",
        "last_updated": "2026-08-13",
        "sources": [
            "Surat Edaran Direktur Jenderal Bina Marga Nomor 04/SE/Db/2023 tentang Pedoman Perencanaan Jalur Evakuasi Bencana Alam Tsunami - Kementerian Pekerjaan Umum dan Perumahan Rakyat (PUPR)",
            "Buku Saku Mengenal Gempabumi dan Tsunami - Badan Meteorologi, Klimatologi, dan Geofisika (BMKG)",
            "Potensi Gempabumi dan Tsunami Indonesia - BMKG (2024)",
            "Petunjuk Status Tingkat Ancaman Tsunami bagi Pemerintah Daerah - BMKG (2012)",
            "Panduan Kesiapsiagaan dan Penanganan Tanggap Darurat Bencana - BPBD / BNPB / Kemenag RI",
            "Upaya Mitigasi Bencana Tsunami - Jurnal IURIS STUDIA (2024)"
        ],
        "emergency_contacts": {
            "panggilan_darurat_nasional": "112",
            "ambulans": ["118", "119"],
            "kepolisian": "110",
            "basarnas_sar": "115",
            "pemadam_kebakaran": "113",
            "bpom_info_keracunan": "129",
            "posko_bencana_alam": "122",
            "posko_kewaspadaan_nasional": "1500-533",
            "pmi": "021-7992325"
        }
    },
    "tas_siaga_bencana": {
        "deskripsi": "Tas Siaga Bencana (TSB) adalah tas tahan air yang disiapkan untuk bertahan hidup minimal 3 hari saat terjadi evakuasi bencana.",
        "perlengkapan_umum": [
            {"id": "TSB-GEN-01", "nama": "Dokumen dan surat berharga", "catatan": "KTP, KK, Ijazah, Surat Tanah/Surat Penting dalam plastik klip tahan air"},
            {"id": "TSB-GEN-02", "nama": "Foto Keluarga", "catatan": "Memudahkan pencarian jika terpisah dari anggota keluarga"},
            {"id": "TSB-GEN-03", "nama": "Kotak P3K", "catatan": "Obat luka, perban, plester, minyak kayu putih, antiseptik"},
            {"id": "TSB-GEN-04", "nama": "Masker medis / kain", "catatan": "Melindungi dari asap, debu reruntuhan, dan serpihan material"},
            {"id": "TSB-GEN-05", "nama": "Air minum siap konsumsi", "catatan": "Minimal untuk kebutuhan awal evakuasi"},
            {"id": "TSB-GEN-06", "nama": "Makanan tahan lama", "catatan": "Biskuit, mi instan, roti tahan lama, atau makanan kaleng"},
            {"id": "TSB-GEN-07", "nama": "Uang cash / tunai", "catatan": "Pecahan kecil dan sedang untuk kondisi ATM / mesin listrik mati"},
            {"id": "TSB-GEN-08", "nama": "Handphone & Charger", "catatan": "Untuk komunikasi darurat"},
            {"id": "TSB-GEN-09", "nama": "Senter LED & Baterai cadangan", "catatan": "Penerangan saat listrik padam di malam hari"},
            {"id": "TSB-GEN-10", "nama": "Pakaian ganti untuk 3 hari", "catatan": "Termasuk pakaian dalam, celana, kaos, dan jaket hangat"},
            {"id": "TSB-GEN-11", "nama": "Radio Portable", "catatan": "Memantau perkembangan informasi BMKG/BNPB jika internet terputus"},
            {"id": "TSB-GEN-12", "nama": "Perlengkapan mandi pribadi", "catatan": "Sabun, sikat gigi, pasta gigi, handuk kecil"},
            {"id": "TSB-GEN-13", "nama": "Tissue basah & kering", "catatan": "Sanitasi darurat saat air terbatas"},
            {"id": "TSB-GEN-14", "nama": "Jas hujan / poncho", "catatan": "Pelindung diri dari hujan saat berjalan evakuasi"},
            {"id": "TSB-GEN-15", "nama": "Peluit", "catatan": "Digantung pada zipper tas untuk memberi sinyal suara jika terjebak reruntuhan"},
            {"id": "TSB-GEN-16", "nama": "Daftar kontak darurat tertulis", "catatan": "Nomor keluarga, BPBD, polisi, rumah sakit"},
            {"id": "TSB-GEN-17", "nama": "Powerbank terisi penuh", "catatan": "Sumber daya daya baterai HP saat listrik padam"}
        ],
        "perlengkapan_khusus_disabilitas": {
            "disabilitas_netra": [
                {"id": "TSB-NET-01", "nama": "Kartu Penyandang Disabilitas (KPD)", "catatan": "Identitas resmi saat di pengungsian"},
                {"id": "TSB-NET-02", "nama": "Alat bantu lihat cadangan & Tongkat lipat cadangan", "catatan": "Memastikan mobilitas mandiri tetap terjaga"},
                {"id": "TSB-NET-03", "nama": "Tali pengaman & makanan anjing penolong (jika ada)", "catatan": "Untuk mendampingi evakuasi"}
            ],
            "disabilitas_tuli": [
                {"id": "TSB-TUL-01", "nama": "Kartu Penyandang Disabilitas (KPD)", "catatan": "Identitas resmi"},
                {"id": "TSB-TUL-02", "nama": "Alat bantu dengar cadangan & baterai ekstra", "catatan": "Memastikan alat komunikasi pendengaran berfungsi"},
                {"id": "TSB-TUL-03", "nama": "Alat penanda disabilitas tuli (Pin / Name Tag 'HELP / TULI')", "catatan": "Agar tim penyelamat memahami kondisi darurat pengguna"},
                {"id": "TSB-TUL-04", "nama": "Alat bantu komunikasi fisik (Buku catatan kecil & pulpen)", "catatan": "Untuk berkomunikasi via tulisan"}
            ],
            "disabilitas_intelektual_dan_mental": [
                {"id": "TSB-INT-01", "nama": "Kartu Penyandang Disabilitas (KPD)", "catatan": "Identitas resmi beserta kontak darurat pendamping"},
                {"id": "TSB-INT-02", "nama": "Obat rutin khusus darurat", "catatan": "Obat penenang / perawatan khusus rutin"},
                {"id": "TSB-INT-03", "nama": "Bahan makanan khusus non-pemicu gangguan", "catatan": "Makanan bebas alergen atau pemicu sensitivitas"},
                {"id": "TSB-INT-04", "nama": "Buku catatan medis & riwayat alergi / instruksi minum obat", "catatan": "Memudahkan tenaga medis pengungsian"}
            ],
            "disabilitas_fisik": [
                {"id": "TSB-FIS-01", "nama": "Kartu Penyandang Disabilitas (KPD)", "catatan": "Identitas resmi"},
                {"id": "TSB-FIS-02", "nama": "Alat bantu jalan cadangan (tongkat / komponen roda)", "catatan": "Memastikan mobilitas darurat"},
                {"id": "TSB-FIS-03", "nama": "Obat rutin khusus", "catatan": "Pereda nyeri atau obat peredam kejang/otot"},
                {"id": "TSB-FIS-04", "nama": "Kain penutup / sarung ganti pakaian", "catatan": "Privasi saat berganti pakaian di posko darurat"},
                {"id": "TSB-FIS-05", "nama": "Popok sekali pakai (dewasa/anak)", "catatan": "Sanitasi saat akses toilet terbatas"},
                {"id": "TSB-FIS-06", "nama": "Kain panjang / gendongan alat bantu", "catatan": "Memudahkan pendamping menggendong/memindahkan penyintas"}
            ]
        }
    },
    "skala_dan_peringatan_dini": {
        "status_ancaman_tsunami_bmkg": [
            {
                "status": "AWAS",
                "warna": "Merah",
                "ketinggian_gelombang": "> 3.0 meter",
                "tindakan_rekomendasi": "Segera lakukan evakuasi mandiri menuju tempat yang lebih tinggi (TEA/TES tinggi) atau titik kumpul aman daratan tinggi. Jauhi seluruh area pesisir pantai dan sungai."
            },
            {
                "status": "SIAGA",
                "warna": "Kuning/Jingga",
                "ketinggian_gelombang": "0.5 meter hingga 3.0 meter",
                "tindakan_rekomendasi": "Segera lakukan evakuasi mandiri menuju tempat yang lebih tinggi atau titik kumpul sementara. Jauhi wilayah pantai."
            },
            {
                "status": "WASPADA",
                "warna": "Kuning Muda/Hijau",
                "ketinggian_gelombang": "< 0.5 meter",
                "tindakan_rekomendasi": "Segera jauhi pantai, tepian sungai, dan badan air lainnya yang terhubung dengan laut."
            }
        ],
        "skala_intensitas_gempa_sig_bmkg": [
            {"skala_sig": "I", "skala_mmi": "I-II", "deskripsi": "Tidak Dirasakan (Non Felt). PGA < 2.9 gal.", "dampak": "Tidak dirasakan atau dirasakan hanya oleh beberapa orang, terekam alat."},
            {"skala_sig": "II", "skala_mmi": "III-V", "deskripsi": "Dirasakan (Felt). PGA 2.9 - 88 gal.", "dampak": "Dirasakan orang banyak, tidak menimbulkan kerusakan. Benda gantung bergoyang."},
            {"skala_sig": "III", "skala_mmi": "VI", "deskripsi": "Kerusakan Ringan (Slight Damage). PGA 89 - 167 gal.", "dampak": "Non-struktur rusak ringan, retak rambut dinding, atap bergeser/jatuh."},
            {"skala_sig": "IV", "skala_mmi": "VII-VIII", "deskripsi": "Kerusakan Sedang (Moderate Damage). PGA 168 - 564 gal.", "dampak": "Banyak retakan dinding sederhana, sebagian roboh, kaca pecah, plester lepas, atap jatuh."},
            {"skala_sig": "V", "skala_mmi": "IX-XII", "deskripsi": "Kerusakan Berat (Heavy Damage). PGA > 564 gal.", "dampak": "Sebagian besar dinding roboh, struktur rusak berat, rel kereta melengkung, likuifaksi."}
        ]
    },
    "protokol_evakuasi": [
        {
            "id": "EQ-DUR-GEN-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "all",
            "special_target_group": "general",
            "category": "action_to_do",
            "title": "Tindakan Kunci Utama Saat Terjadi Gempa Bumi (Drop, Cover, Hold On)",
            "description": "Lakukan 3 langkah keselamatan utama: 1. DROP (Berlutut/berjongkok/menunduk). 2. COVER (Lindungi kepala & leher dengan tas atau berlindung di bawah meja yang kuat). 3. HOLD ON (Bertahan sambil berpegangan pada kaki meja/struktur hingga guncangan berhenti total). Jauhi reruntuhan dan pecahan kaca.",
            "official_source": "Buku Saku BMKG 2020 & SE Dirjen Bina Marga 2023"
        },
        {
            "id": "EQ-DUR-GEN-02",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "all",
            "special_target_group": "general",
            "category": "action_to_do",
            "title": "Pengendalian Panik & Urutan Evakuasi",
            "description": "Tetap tenang dan jangan panik. Saat keluar ruangan: jangan berisik, jangan berlari, dan jangan saling mendorong. Utamakan membantu anggota keluarga penyandang disabilitas, ibu hamil, anak kecil, dan lansia untuk keluar terlebih dahulu.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-HOME-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "home",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan Gempa di Dapur",
            "description": "Jika berada di dapur saat gempa, segera matikan kompor gas atau kompor listrik untuk mencegah korsleting/kebakaran. Menjauhlah dari tempat penyimpanan barang yang mudah jatuh (rak piring, lemari gantung, tabung gas).",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-HOME-02",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "home",
            "category": "action_to_do",
            "title": "Pengamanan Arus Listrik Saat Gempa di Rumah",
            "description": "Matikan aliran atau saklar listrik terdekat dari posisi Anda berlindung. Cabut colokan listrik dan tutuplah stop kontak dengan pengaman stop kontak untuk mencegah korsleting listrik pemicu kebakaran.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-HOME-03",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "home",
            "category": "action_to_do",
            "title": "Tindakan Jika Berada di Tangga Rumah / Gedung",
            "description": "Jika berada di tangga saat guncangan terjadi, segera berpegangan erat pada railing atau dinding kokoh. JANGN menuruni tangga secara terburu-buru sampai guncangan berhenti total untuk menghindari risiko jatuh atau tertimpa runtuhan.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-HOME-04",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "home",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan di Toilet / Kamar Mandi",
            "description": "Segera lindungi kepala menggunakan baskom, handuk tebal, atau tangan. Hindari pecahan cermin/kaca. Segera keluar dari kamar mandi menuju lorong atau area depan rumah yang lebih aman agar tidak terjebak jika pintu melengkung akibat deformasi bangunan.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-OFFICE-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "office",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan Gempa di Ruang Kerja / Ruang Kantor",
            "description": "Menjauhlah dari jendela kaca, partisi kaca, rak arsip, dan peralatan yang mudah jatuh. Buka pintu ruangan kerja jika memungkinkan agar jalur keluar tidak terkunci akibat pintu melengkung. Berlindung di bawah meja kerja yang kokoh.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-ELEV-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "elevator",
            "category": "action_to_do",
            "title": "Protokol Darurat Gempa Bumi di Dalam Lift",
            "description": "Tekan semua tombol lantai pada panel lift. Segera keluar begitu pintu lift terbuka di lantai terdekat. Jika terjebak di dalam lift, gunakan tombol darurat/intercom untuk menghubungi petugas gedung, lalu posisikan tubuh berjongkok atau merebah serendah mungkin hingga bantuan datang.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-HIGH-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "high_rise_building",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan di Gedung Bertingkat / Tinggi",
            "description": "Segera pergi menuju ruang bersama, area dekat inti lift, atau di dekat kolom pilar struktur utama bangunan. Lindungi kepala dan posisikan tubuh serendah mungkin. Jangan mencoba turun ke lantai bawah saat guncangan masih berlangsung.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-STORE-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "mall",
            "category": "action_to_do",
            "title": "Tindakan di Pusat Perbelanjaan, Gudang, atau Pabrik",
            "description": "Waspadai barang belanjaan atau material yang terlempar dan berjatuhan dari rak tinggi. Segera dekati kolom struktur bangunan/pilar, gunakan barang solid (seperti keranjang tebal/tas) untuk melindungi kepala, dan berjongkoklah.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-STAD-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "stadium_theater",
            "category": "action_to_do",
            "title": "Tindakan di Stadion, Teater, atau Tempat Konser (Kerumunan Besar)",
            "description": "JANGN PANIK! Terburu-buru berlari menuju pintu keluar sangat membahayakan karena berpotensi terhimpit, terinjak, dan kehabisan napas. Segera berjongkok di antara bangku penonton, lindungi kepala dari benda jatuh, dan tunggu instruksi petugas untuk evakuasi tertib setelah guncangan mereda.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-OUT-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "outdoor",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan Gempa di Luar Ruangan (Open Space)",
            "description": "Jangan panik. Segera cari tempat terbuka dengan menjauhi gedung bertingkat, dinding/tembok tua, tiang/gardu listrik, pohon tinggi, jembatan penyeberangan, dan lereng rawan longsor. Hindari arus kerumunan massa yang panik.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-SCH-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "school",
            "category": "action_to_do",
            "title": "Protokol Evakuasi Gempa di Sekolah / Kelas",
            "description": "Siswa dan guru segera berlindung di bawah meja kelas, pegang kaki meja (Drop, Cover, Hold On). Jauhi jendela kaca. Jika di aula/lapangan, jauhi bangunan dan tiang basket. Setelah guncangan selesai, lakukan evakuasi tertib menuju titik kumpul sekolah mengikuti petunjuk guru/petugas.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-BASE-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "basement",
            "category": "action_to_do",
            "title": "Tindakan di Area Parkir Bawah Tanah (Basement)",
            "description": "Jangan panik dan jangan saling berebut menuju tangga/ramp keluar. Segera berlindung di samping/balik kolom pilar beton struktur utama bangunan atau dinding geser (shear wall). Lindungi kepala dari pipa atau instalasi gantung yang berpotensi jatuh.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-AIRP-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "airport_station",
            "category": "action_to_do",
            "title": "Tindakan di Bandara, Stasiun Kereta, dan Terminal Bus",
            "description": "Jauhi dinding kaca besar, layar papan informasi tinggi, dan lampu gantung. Jauhi pula tepian peron stasiun agar tidak terdorong jatuh ke rel. Berjongkoklah mendampingi tembok struktur terkuat dan lindungi kepala.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-TRAIN-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "train",
            "category": "action_to_do",
            "title": "Tindakan Saat Berada di Dalam Kereta Api / MRT",
            "description": "Waspadai pengereman darurat kereta. Jangan saling mendorong penumpang lain. Jika duduk: menunduk dan lindungi kepala dengan tas. Jika berdiri: pegang handgrip/tiang dengan sangat kuat, jika memungkinkan berjongkoklah. JANGN memaksa keluar sebelum kereta berhenti sempurna.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-CAR-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "vehicle",
            "category": "action_to_do",
            "title": "Tindakan Keselamatan Gempa di Dalam Mobil / Bus",
            "description": "Nyalakan lampu hazard (bahaya), kurangi kecepatan secara bertahap, dan menepilah di tempat yang aman (jauhi jembatan layang/underpass/pohon/tiang). Setelah kendaraan berhenti sempurna, penumpang dan pengemudi segera keluar dan berlindung di luar. JANGN tinggalkan kendaraan di tengah jalan.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-DUR-MOUN-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "mountain",
            "category": "action_to_do",
            "title": "Tindakan Gempa di Area Pegunungan / Perbukitan",
            "description": "Segera jauhi area lereng tebing, gunungan batu, atau tebing tanah yang rentan longsor dan rontokan batu. Berpindahlah ke area perbukitan yang lebih stabil atau tanah lapang datar.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "TSU-EVAC-WARN-01",
            "disaster_type": "tsunami",
            "phase": "during_disaster",
            "location_context": "coastal_river",
            "category": "evacuation_step",
            "title": "Evakuasi Mandiri Tsunami Berdasarkan Tanda-Tanda Alam",
            "description": "Segera lakukan evakuasi mandiri TANPA MENUNGGU PERINGATAN RESMI jika menemukan salah satu tanda: 1. Merasakan gempa kuat atau berlangsung lama (≥ 1 menit hingga sulit berdiri). 2. Air laut surut mendadak secara anomali hingga dasar laut/ikan kelihatan. 3. Menerima suara dentuman/gemuruh keras dari arah laut. Berlarilah menjauhi pantai dan sungai menuju tempat tinggi (minimal 20 meter dpl) atau gedung Tempat Evakuasi Sementara (TES).",
            "official_source": "Buku Saku BMKG 2020 & SE Dirjen Bina Marga 2023"
        },
        {
            "id": "TSU-EVAC-RIVER-01",
            "disaster_type": "tsunami",
            "phase": "during_disaster",
            "location_context": "coastal_river",
            "category": "action_to_avoid",
            "title": "Peringatan Bahaya Mengikuti Aliran Muara Sungai Saat Tsunami",
            "description": "JAUHI tepian sungai dan muara sungai! Gelombang tsunami mendesak masuk ke dalam daratan melalui aliran sungai dengan kecepatan sangat tinggi. Berada di sekitar sungai sama berbahayanya dengan berada di garis pantai saat tsunami menerjang.",
            "official_source": "Buku Saku BMKG 2020 & SE Dirjen Bina Marga 2023"
        },
        {
            "id": "TSU-EVAC-SHELTER-01",
            "disaster_type": "tsunami",
            "phase": "during_disaster",
            "location_context": "coastal_river",
            "category": "evacuation_step",
            "title": "Pilihan Perlindungan Darurat Tsunami",
            "description": "Jika tidak sempat mencapai dataran tinggi sebelum gelombang datang: 1. Naiklah ke lantai atas gedung TES (Tempat Evakuasi Sementara) bertingkat yang berstruktur beton tahan tsunami. 2. Jika tidak ada gedung, panjatlah pohon tinggi berakar kuat (seperti pohon kelapa/cemara udang). 3. Jika terseret arus, raihlah benda terapung yang besar (pintu/kasur/batang kayu).",
            "official_source": "Buku Saku BMKG 2020 & SE Dirjen Bina Marga 2023"
        },
        {
            "id": "EQ-DIS-ASSIST-01",
            "disaster_type": "earthquake",
            "phase": "during_disaster",
            "location_context": "all",
            "special_target_group": "disability_all",
            "category": "action_to_do",
            "title": "Protokol Pendampingan Evakuasi Penyandang Disabilitas",
            "description": "Bantu penyandang disabilitas evakuasi ke tempat aman dengan memperhatikan kebutuhan spesifik mereka. Pastikan alat bantu (tongkat, alat dengar, kursi roda) tidak tertinggal. Pastikan mengantongi KPD (Kartu Penyandang Disabilitas) & obat rutin. Perhatikan kondisi emosional untuk mencegah trauma berlebih.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-FOOT-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "all",
            "category": "action_to_do",
            "title": "Perlindungan Kaki Sesaat Setelah Gempa Berhenti",
            "description": "JANGN berjalan dengan telanjang kaki! Guncangan gempa sering melempar barang dan memecahkan kaca di lantai. Segera gunakan alas kaki tertutup (seperti sepatu atau sandal gunung) sebelum melangkah mencari jalan keluar.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-ELEC-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "home_office",
            "category": "action_to_avoid",
            "title": "Pencegahan Kebakaran & Kebocoran Gas Pasca Gempa",
            "description": "1. JANGN menyalakan saklar lampu atau menaikkan MCB/CB box sesaat setelah gempa untuk menghindari percikan api. 2. Cabut sambungan alat elektronik. 3. Matikan keran air agar tidak berpotensi menjadi konduktor atau membuat licin. 4. Waspadai bau gas membumbung; jangan menyalakan korek/api.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-BUILD-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "indoor",
            "category": "evacuation_step",
            "title": "Protokol Keluar Bangunan Pasca Gempa",
            "description": "Segera keluar bangunan secara teratur melalui TANGGA DARURAT. JANGN gunakan lift atau eskalator karena risiko listrik padam atau tali lift terputus. Periksa sekeliling jika ada orang yang terjebak/butuh bantuan, dan hubungi panggilan darurat 112.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-COMM-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "all",
            "category": "action_to_avoid",
            "title": "Manajemen Jaringan Komunikasi Darurat",
            "description": "Jaringan telepon dan seluler akan sangat padat sesaat setelah bencana. TUNDA melakukan siaran langsung (live streaming) atau mengunggah video berat di media sosial agar trafik bandwidth jaringan dapat diprioritaskan untuk komunikasi dan koordinasi darurat SAR/BPBD. Hanya lakukan panggilan telepon singkat yang benar-benar penting.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-AFTER-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "outdoor",
            "category": "action_to_avoid",
            "title": "Waspada Gempa Susulan & Bahaya Kelistrikan Khusus",
            "description": "Selalu ingat potensi gempa susulan. JANGN masuk atau mendekati bangunan yang sudah retak/runtuh. Jauhi gardu listrik, tiang listrik, menara SUTET, dan kabel yang terkulai ke tanah. JANGN menggunakan mobil pribadi untuk evakuasi di jalan raya agar tidak memicu kemacetan parah yang menghambat mobil ambulans/SAR.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-NIGHT-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "outdoor",
            "category": "action_to_do",
            "title": "Protokol Evakuasi di Malam Hari",
            "description": "Saat evakuasi malam hari di mana listrik padam, gunakan senter atau penerangan portabel. Bergeraklah dengan penuh hati-hati, utamakan memilih jalur jalan raya yang lebar untuk menghindari potensi tersandung reruntuhan atau kabel listrik terputus.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "EQ-POST-HOAX-01",
            "disaster_type": "earthquake",
            "phase": "post_disaster",
            "location_context": "all",
            "category": "verification",
            "title": "Verifikasi Informasi & Penangkalan Berita Hoaks Bencana",
            "description": "Dapatkan informasi bencana resmi HANYA dari saluran terpercaya seperti BMKG, BNPB, BPBD, atau pemerintah daerah. Kenali ciri hoaks: diawali kata 'Sebarkan berita ini' dan berisi ramalan waktu pasti gempa susulan yang memicu kepanikan. Gunakan aplikasi InfoBMKG atau WRS Mobile untuk memantau data gempa terkini.",
            "official_source": "Buku Saku BMKG 2020"
        },
        {
            "id": "TSU-ROUTE-PUPR-01",
            "disaster_type": "tsunami",
            "phase": "pre_disaster",
            "location_context": "coastal_river",
            "category": "evacuation_step",
            "title": "Standar Jalur Evakuasi Tsunami (Kementerian PUPR)",
            "description": "Jalur evakuasi ditentukan berdasarkan prinsip rute terpendek, tercepat, teraman, dan mudah diakses. Menggunakan jalan umum (arteri, kolektor, lokal). Jalur harus menjauhi zona rawan (garis pantai & muara sungai). Lebar standar jalur pejalan kaki minimal 3.5 meter memiliki kapasitas mengalirkan 70 orang/menit.",
            "official_source": "SE Dirjen Bina Marga No 04/SE/Db/2023 Kementerian PUPR"
        },
        {
            "id": "TSU-SHELTER-PUPR-01",
            "disaster_type": "tsunami",
            "phase": "all",
            "location_context": "coastal_river",
            "category": "shelter_info",
            "title": "Definisi Tempat Evakuasi Sementara (TES) vs Tempat Evakuasi Akhir (TEA)",
            "description": "1. TES (Tempat Evakuasi Sementara): Lokasi titik kumpul/gedung bertingkat terdekat yang mudah dijangkau dalam waktu < 15-30 menit setelah peringatan dini gempa/tsunami. 2. TEA (Tempat Evakuasi Akhir): Posko pengungsian utama yang dilengkapi fasilitas hunian sementara, dapur umum, dan posko kesehatan yang dibangun pemerintah di luar zona bahaya.",
            "official_source": "SE Dirjen Bina Marga No 04/SE/Db/2023 & Buku Saku BMKG"
        },
        {
            "id": "RECOVERY-PHYSICAL-01",
            "disaster_type": "all",
            "phase": "post_disaster",
            "location_context": "shelter_camp",
            "category": "first_aid",
            "title": "Standar Minimal Pemulihan & Kebutuhan Dasar Pengungsi",
            "description": "Sesuai standar pemulihan bencana resmi: 1. Pangan: Minimal 2.100 kalori per orang per hari. 2. Air Bersih: Minimal 15 liter per orang per hari. 3. Hunian Sementara: Minimal area 3 meter persegi per orang dengan privasi yang memadai.",
            "official_source": "Jurnal IURIS STUDIA (2024) & Standar NFPA/GITEWS"
        },
        {
            "id": "RECOVERY-PSYCH-01",
            "disaster_type": "all",
            "phase": "post_disaster",
            "location_context": "shelter_camp",
            "category": "first_aid",
            "title": "Pemulihan Psikologis & Trauma Healing Pasca Bencana",
            "description": "Pentingnya intervensi psikologi untuk mengatasi kecemasan, depresi, dan PTSD pada penyintas bencana. Dilakukan melalui kegiatan trauma healing, konseling individu/kelompok (CBT/ACT), psikoedukasi, penguatan dukungan sosial, dan penyusunan rutinitas harian.",
            "official_source": "Jurnal IURIS STUDIA (2024) & Pusat Krisis Kemenkes RI"
        }
    ]
}

target_file = r"d:\KULIAH\kursus\dicoding\challenge\suar_app\protokol_mitigasi.json"
backend_file = r"d:\KULIAH\kursus\dicoding\challenge\suar_app\backend\data\protokol_mitigasi.json"

with open(target_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

with open(backend_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Successfully generated single source of truth json files!")
