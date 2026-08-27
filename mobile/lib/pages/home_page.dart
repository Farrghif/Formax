// lib/pages/home_page.dart
// Halaman utama aplikasi Form4x.
// Berisi Dashboard, Template, dan History dalam satu layar dengan BottomNavigationBar.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/form_model.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../data/mock_data.dart';
import '../widgets/template_card.dart';
import '../widgets/search_results_view.dart';
import 'login_page.dart';
import 'formmakerpage.dart';
import 'historypage.dart';
import 'join_link_page.dart';
import 'scan_qr_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _fullName = 'User';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  bool _isLoadingSearch = false;
  Map<String, dynamic> _searchData = {};

  List<FormTemplate> _myTemplates = [];
  bool _isLoadingTemplates = false;
  bool _templatesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // FIX: Template tidak di-load otomatis saat refresh/app start.
    // Hanya di-load saat user masuk tab Template atau setelah konfirmasi simpan.
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _ensureTemplatesLoaded() async {
    // FIX: setiap ke TemplatePage selalu reload otomatis (sesuai request user)
    _templatesLoaded = true;
    await _loadMyTemplates();
  }

  Future<void> _loadMyTemplates() async {
    setState(() {
      _isLoadingTemplates = true;
    });
    final res = await ApiService.getMyTemplates();
    if (!mounted) return;
    setState(() {
      _isLoadingTemplates = false;
      if (res['success'] == true) {
        final rawList = res['data'] as List<dynamic>;
        _myTemplates = rawList.map((e) => FormTemplate.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        debugPrint('[Home] getMyTemplates gagal: ${res['message']}');
      }
    });
  }

  Future<void> _refreshTemplatesImmediately() async {
    _templatesLoaded = true;
    await _loadMyTemplates();
  }

  void _addTemplateOptimistically(FormTemplate t) {
    // Langsung terload otomatis tanpa menunggu fetch server
    setState(() {
      // Hindari duplikat id
      if (t.id != null && _myTemplates.any((e) => e.id == t.id)) return;
      _myTemplates = [..._myTemplates, t];
    });
    // Sync dengan server di background untuk pastikan konsisten
    _refreshTemplatesImmediately();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _isLoadingSearch = false;
        _searchData = {};
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await ApiService.search(query);
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
          if (result['success'] == true) {
            _searchData = result['data'] as Map<String, dynamic>;
          } else {
            _searchData = {};
          }
        });
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final result = await ApiService.getMe();
    if (result['success'] == true && mounted) {
      setState(() {
        _fullName = result['data']['full_name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      endDrawer: _buildEndDrawer(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFB4C5D4),
      foregroundColor: Colors.white,
      centerTitle: false,
      leading: GestureDetector(
        onTap: () {},
        child: Container(
          margin: const EdgeInsets.all(5),
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: SvgPicture.asset(
              'assets/icons/logoss.svg',
              width: 27,
              height: 27,
              fit: BoxFit.cover,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Form4x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Tempat membuat Form terlengkap',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Cari formulir...',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black38),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocus.unfocus();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) {
        // FIX: setiap ke TemplatePage selalu reload otomatis
        if (i == 1) {
          _ensureTemplatesLoaded();
        }
        setState(() {
          _selectedIndex = i;
        });
      },
      selectedItemColor: const Color(0xFF3B82F6),
      unselectedItemColor: const Color(0xFF94A3B8),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Template',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
      ],
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isSearching) {
      if (_isLoadingSearch) {
        return const Center(child: CircularProgressIndicator());
      }
      return SearchResultsView(
        searchData: _searchData,
        onRefresh: () {
          // You could re-trigger search here, or just let them clear it
          _onSearchChanged();
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildTemplateTab();
      case 2:
        return const HistoryPage();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Dashboard Tab ────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getMyForms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<FormModel> forms = [];
        if (snapshot.data?['success'] == true) {
          final rawList = snapshot.data!['data'] as List<dynamic>;
          forms = rawList
              .map((e) => FormModel.fromJson(e as Map<String, dynamic>))
              .toList();
          // Sort by createdAt DESC, take 10
          forms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (forms.length > 10) forms = forms.sublist(0, 10);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card
              _buildGreetingCard(),
              const SizedBox(height: 24),
              // Recently created forms
              Row(
                children: [
                  const Text(
                    'Formulir Terbaru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 2;
                      });
                    },
                    child: const Text('Lihat semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (forms.isEmpty)
                _buildEmptyState(
                  icon: Icons.article_outlined,
                  title: 'Belum ada formulir',
                  subtitle: 'Buat formulir pertamamu dari tab Template',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: forms.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => _buildFormCard(forms[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB4C5D4), Color.fromARGB(255, 141, 184, 253)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $_fullName! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Buat formulir baru hari ini?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Buat Formulir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E40AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(FormModel form) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFFF9FAFB),
              appBar: AppBar(
                title: const Text(
                  'Detail Form',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0.5,
              ),
              body: HistoryPage(highlightFormId: form.id),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF1E40AF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${form.totalSubmissions} responden · ${_formatDate(form.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(form.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isPublished = status == 'published';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublished ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPublished ? 'Aktif' : 'Draft',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPublished
              ? const Color(0xFF065F46)
              : const Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.black12),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─── Template Tab ─────────────────────────────────────────────────────────

  Widget _buildTemplateTab() {
    // FIX: setiap ke TemplatePage selalu auto-reload (sesuai request user)
    if (!_templatesLoaded && !_isLoadingTemplates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureTemplatesLoaded();
      });
    }
    return RefreshIndicator(
      onRefresh: _loadMyTemplates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Template Bawaan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: MockData.builtInTemplates.length,
              itemBuilder: (context, index) {
                final t = MockData.builtInTemplates[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TemplateCard(template: t, isBuiltIn: true),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Template Saya',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<FormTemplate>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FormMakerPage(),
                    ),
                  );
                  // FIX: langsung terload otomatis — optimistic add tanpa tunggu fetch
                  if (!mounted) return;
                  if (result != null) {
                    _addTemplateOptimistically(result);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${result.plainTitle} berhasil disimpan!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  } else {
                    // Tetap sync walau result null (mis PATCH)
                    _refreshTemplatesImmediately();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Template tersimpan — daftar diperbarui'), backgroundColor: Color(0xFF059669)),
                    );
                  }
                  // Otomatis tetap di tab Template agar user langsung lihat hasilnya
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Buat Baru'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingTemplates)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_myTemplates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      'Belum ada template yang disimpan.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadMyTemplates,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _myTemplates.length,
              itemBuilder: (context, index) {
                return TemplateCard(
                  template: _myTemplates[index],
                  isBuiltIn: false,
                  onSaved: (result) async {
                    // FIX: back dari FormMaker (baik save maupun back biasa) → auto reload
                    if (result != null) {
                      _addTemplateOptimistically(result);
                    } else {
                      await _refreshTemplatesImmediately();
                    }
                  },
                );
              },
            ),
        ],
      ),
    ),
    );
  }

  // ─── Drawer ───────────────────────────────────────────────────────────────

  Widget _buildEndDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 52,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Form4x',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _drawerItem(Icons.grid_view_rounded, 'Dashboard', () {
            setState(() { _selectedIndex = 0; });
            Navigator.pop(context);
          }, _selectedIndex == 0),
          _drawerItem(Icons.link, 'Join with Link', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinLinkPage()),
            );
          }, false),
          _drawerItem(Icons.qr_code_scanner, 'Scan QR', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQRPage()),
            );
          }, false),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ).then((updated) {
                      if (updated == true && mounted) {
                        _loadUserProfile();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE5E7EB),
                        child: Icon(Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF9CA3AF)),
                  onPressed: () async {
                    await ApiService.removeToken();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isSelected,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: isSelected ? const Color(0xFF1E40AF) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF1E40AF)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
