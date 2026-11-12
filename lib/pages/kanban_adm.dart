import 'package:flutter/material.dart';
import 'package:emanifest/drawer/custom_drawer.dart';
import 'package:emanifest/component/tag_ok_autocomplete.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'history_combin_kanban.dart';
import 'dn_list.dart';
import 'shipping_prep_page.dart';
import 'dart:async';           // untuk Timer debounce
import 'package:flutter/services.dart'; // untuk HapticFeedback
class KanbanAdm extends StatefulWidget {
  @override
  _KanbanAdmPageState createState() => _KanbanAdmPageState();
}

class _KanbanAdmPageState extends State<KanbanAdm> {
  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  Timer? _debounce;
  List<dynamic> _historyKanban = [];
  final TextEditingController _customerKanbanController = TextEditingController();
  final TextEditingController _tagOkController = TextEditingController();

  final Color primaryDark = const Color(0xFF1565C0); // Blue 800
  final Color primaryLight = const Color(0xFF1E88E5); // Blue 600
  final Color bgColor = const Color(0xFFF5F7FA);



  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();

    _customerKanbanController.addListener(_checkIfBothFieldsAreFilled);
    _tagOkController.addListener(_checkIfBothFieldsAreFilled);
  }


  Future<void> fetchHistoryKanban() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/history-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'customer': 'ADM', 'quick': 'true'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _historyKanban = responseData['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _checkIfBothFieldsAreFilled() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final idLabel = _customerKanbanController.text.trim();
      final idKanban = _tagOkController.text.trim();
      if (idKanban.isNotEmpty && idLabel.isNotEmpty && !_isSubmitting) {
        _isSubmitting = true;
        _submitToApi(idKanban, idLabel).whenComplete(() => _isSubmitting = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _customerKanbanController.dispose();
    _tagOkController.dispose();
    super.dispose();
  }

  Future<void> _submitToApi(String idKanban, String idLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/adm-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'id_kanban': idKanban, 'id_label': idLabel},
      );

      final data = jsonDecode(response.body);
      bool isSuccess = data['status'];

      String detail = "${data['message']}\n\n"
          "DN : ${data['dn'] ?? '-'}\n"
          "Total : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}";

      _showDialog(isSuccess ? 'Sukses' : 'Gagal', detail, isSuccess);

      await fetchHistoryKanban();
      _customerKanbanController.clear();
      _tagOkController.clear();
    } catch (e) {
      _showDialog('Error', 'Kesalahan koneksi: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitMagelang() async {
    final idLabel = _customerKanbanController.text.trim();

    if (idLabel.isEmpty) {
      _showDialog('Gagal', 'Customer Kanban wajib diisi terlebih dahulu.', false);
      return;
    }

    if (_isSubmitting) return;
    _isSubmitting = true;

    final String idKanban = _tagOkController.text.trim();

    await _submitToApi(idKanban, idLabel);
    _isSubmitting = false;
  }

  void _showDialog(String title, String message, bool isSuccess) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      title: title,
      desc: message,
      customHeader: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSuccess ? Icons.check : Icons.close,
          color: isSuccess ? Colors.green : Colors.red,
          size: 50,
        ),
      ),
      btnOkOnPress: () {},
      btnOkColor: isSuccess ? Colors.green : Colors.red,
    ).show();
  }

  void _openScanner(BuildContext context, bool isCustomerKanban) {
    bool isProcessing = false;

    final cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
      facing: CameraFacing.back,
      returnImage: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.maxFinite,
                  height: 420,
                  child: Stack(
                    children: [
                      // ── Kamera full, tanpa overlay ───────────────────────────
                      MobileScanner(
                        controller: cameraController,
                        onDetect: (capture) {
                          if (isProcessing) return;
                          final String? code = capture.barcodes.firstOrNull?.rawValue;
                          if (code == null || code.isEmpty) return;

                          isProcessing = true;
                          HapticFeedback.mediumImpact();

                          cameraController.stop();
                          Navigator.of(context).pop(code);
                        },
                      ),

                      // ── Label instruksi ──────────────────────────────────────
                      Positioned(
                        bottom: 90,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isCustomerKanban
                                  ? 'Arahkan ke Customer Kanban'
                                  : 'Arahkan ke Tag OK / E-Kanban',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Tombol close ─────────────────────────────────────────
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              cameraController.dispose();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),

                      // ── Tombol flash ─────────────────────────────────────────
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => isFlashOn = !isFlashOn);
                              cameraController.toggleTorch();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isFlashOn
                                    ? Colors.yellow.withOpacity(0.3)
                                    : Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFlashOn ? Icons.flash_on : Icons.flash_off,
                                color: isFlashOn ? Colors.yellow : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      cameraController.dispose();
      if (value != null && value is String && value.isNotEmpty) {
        if (isCustomerKanban) {
          _customerKanbanController.text = value;
        } else {
          _tagOkController.text = value;
        }
      }
    });
  }

// Helper: overlay gelap di luar area scan
  Widget _buildScanOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.55),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper: bracket di sudut area scan
  Widget _buildCornerBracket(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    return Align(
      alignment: alignment,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Colors.greenAccent, width: 3) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Colors.greenAccent, width: 3) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Colors.greenAccent, width: 3) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Colors.greenAccent, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [

          Column(
            children: [
              Container(
                height: 220,
                padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryDark, primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "ADM Kanban",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Silakan scan barcode untuk memulai",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const Icon(Icons.qr_code_scanner, color: Colors.white24, size: 60),
                  ],
                ),
              ),
            ],
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
            child: Column(
              children: [
                _buildScanCard(context),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 25),
                _buildHistorySection(),
              ],
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryDark),
                          const SizedBox(height: 15),
                          const Text("Memproses Data...", style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputHeader("Customer Kanban", Icons.assignment_outlined),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _customerKanbanController,
            hint: "Scan Kanban Customer",
            onScan: () => _openScanner(context, true),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          _buildInputHeader("Tag OK / E-Kanban", Icons.check_circle_outline),
          const SizedBox(height: 8),
          TagOkAutocomplete(
            controller: _tagOkController,
            hint: "Scan / Ketik Tag OK (opsional untuk Magelang)",
            customer: "ADM",
            primaryDark: primaryDark,
            primaryLight: primaryLight,
            onScan: () => _openScanner(context, false),
            onChanged: (val) => _checkIfBothFieldsAreFilled(),
            onSubmitted: (val) => _checkIfBothFieldsAreFilled(),
          ),

          const SizedBox(height: 16),
          _buildMagelangSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildMagelangSubmitButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _submitMagelang,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primaryDark.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.send_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "SUBMIT VENDOR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onScan,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          suffixIcon: GestureDetector(
            onTap: onScan,
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code_scanner, color: primaryDark),
            ),
          ),
        ),
      ),
    );
  }

  // --- QUICK ACTIONS ---
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            "Riwayat",
            Icons.history,
            Colors.orange.shade700,
            Colors.orange.shade50,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryCombinKanban(sourcePage: "ADM"))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            "Shipping",
            Icons.inventory_2_outlined,
            Colors.blue.shade700,
            Colors.blue.shade50,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShippingPrepPage())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            "DN List",
            Icons.local_shipping_outlined,
            Colors.green.shade700,
            Colors.green.shade50,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => DnList(source: 'ADM'))),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, Color bg, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("Aktivitas Terakhir", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            Icon(Icons.access_time, size: 16, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        _historyKanban.isEmpty
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 10),
              const Text("Belum ada data scan", style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _historyKanban.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = _historyKanban[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: primaryDark),
                ),
                title: Text(
                  "Part - ${item['part']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item['created_at'] ?? '-', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),




            );
          },
        ),
      ],
    );
  }
}

