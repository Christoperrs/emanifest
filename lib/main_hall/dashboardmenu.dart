import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Penting untuk SystemNavigator.pop
import 'package:emanifest/component/MenuItems.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emanifest/services/auth_service.dart';
import 'dart:async';

class DashboardMenu extends StatefulWidget {
  @override
  _DashboardMenuPageState createState() => _DashboardMenuPageState();
}

class _DashboardMenuPageState extends State<DashboardMenu> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.85);

  bool _isSearching = false;
  List<MenuItemConfig> filteredMenuItems = [];
  List<String> accessPayload = [];
  int _currentPage = 0;
  Timer? _timer;

  // Warna Tema Utama
  final Color primaryDark = const Color(0xFF0D47A1);
  final Color primaryLight = const Color(0xFF1976D2);
  final Color bgColor = const Color(0xFFF8F9FD);

  final List<String> jumbotronImages = [
    'assets/img/IMG_3562.jpg',
    'assets/img/IMG_3577.jpg',
    'assets/img/IMG_3620.jpg',
  ];

  @override
  void initState() {
    super.initState();
    loadMenuWithPermissions();
    _setupSearchListener();
    _startAutoSlider();
  }

  // --- LOGIC SECTION ---

  void _setupSearchListener() {
    _searchController.addListener(() {
      final keyword = _searchController.text.toLowerCase();
      setState(() {
        filteredMenuItems = menuItems
            .where((item) =>
        item.label.toLowerCase().contains(keyword) &&
            accessPayload.any((perm) => item.permissions.contains(perm)))
            .toList();
      });
    });
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % jumbotronImages.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> loadMenuWithPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      final payload = JwtDecoder.decode(token);
      List<String> perms = List<String>.from(payload['payload'] ?? []);
      if (perms.isEmpty) {
        perms = [
          'cross_check_tmmin',
          'cross_check_hmmi',
          'cross_check_adm',
          'job_list',
          'form_sto',
          'sync_data',
          'tarik_data_sap',
        ];
      }
      accessPayload = perms;

      setState(() {
        filteredMenuItems = menuItems.where((item) {
          // Menu tanpa batasan permissions (kosong) selalu tampil
          if (item.permissions.isEmpty) return true;
          return accessPayload.any((perm) => item.permissions.contains(perm));
        }).toList();
      });
    }
  }

  void exitSearchMode() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
    loadMenuWithPermissions();
  }

  // Fungsi Konfirmasi Keluar Aplikasi (Back Button)
  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: primaryDark),
            const SizedBox(width: 10),
            const Text("Keluar Aplikasi"),
          ],
        ),
        content: const Text("Apakah Anda yakin ingin menutup aplikasi E-Manifest?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("TIDAK", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("YA, KELUAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah anda yakin ingin mengakhiri sesi ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("BATAL", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope digunakan untuk menangkap tombol Back fisik
    return PopScope(
      canPop: false, // Kita handle manual konfirmasinya
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // Jika sedang mencari, tekan back akan menutup pencarian dulu
        if (_isSearching) {
          exitSearchMode();
          return;
        }

        // Tampilkan dialog konfirmasi keluar aplikasi
        final shouldExit = await _showExitConfirmation();
        if (shouldExit && context.mounted) {
          // Menutup aplikasi secara sungguhan di Android
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSearching ? _buildSearchView() : _buildMainView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: primaryDark.withOpacity(0.1),
                child: Icon(Icons.person, color: primaryDark),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Selamat Datang,", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const Text("Operator E-Manifest",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _handleLogout,
                icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
              )
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onTap: () => setState(() => _isSearching = true),
        decoration: InputDecoration(
          hintText: "Cari fitur atau layanan...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: primaryDark),
          suffixIcon: _isSearching
              ? IconButton(icon: const Icon(Icons.cancel, size: 20), onPressed: exitSearchMode)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        _buildBannerSlider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 30, 24, 15),
          child: Text("Menu Utama", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        _buildMenuGrid(),
        const SizedBox(height: 30),
        _buildFooterInfo(),
      ],
    );
  }

  Widget _buildBannerSlider() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: jumbotronImages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: AssetImage(jumbotronImages[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.bottomLeft,
                      child: const Text("Digitalizing Supply Chain\nLogistics Excellence",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              jumbotronImages.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 5),
                height: 6,
                width: _currentPage == index ? 20 : 6,
                decoration: BoxDecoration(
                    color: _currentPage == index ? primaryDark : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              )),
        )
      ],
    );
  }

  Widget _buildMenuGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1,
        ),
        itemCount: filteredMenuItems.length,
        itemBuilder: (context, index) {
          final item = filteredMenuItems[index];
          return InkWell(
            onTap: () => Navigator.pushNamed(context, item.route),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: primaryLight, size: 32),
                  const SizedBox(height: 10),
                  Text(item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Bantuan IT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Kontak IT Department untuk kendala sistem.",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    return filteredMenuItems.isEmpty
        ? const Center(child: Text("Menu tidak ditemukan"))
        : ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredMenuItems.length,
      itemBuilder: (context, index) {
        final item = filteredMenuItems[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade100)),
          child: ListTile(
            leading: Icon(item.icon, color: primaryDark),
            title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => Navigator.pushNamed(context, item.route),
          ),
        );
      },
    );
  }
}