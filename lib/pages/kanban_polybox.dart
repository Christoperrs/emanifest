import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'history_combin_kanban.dart';
import 'dn_list.dart';
import 'shipping_prep_cycle.dart';

class KanbanPolybox extends StatefulWidget {
  @override
  _KanbanPolyboxPageState createState() => _KanbanPolyboxPageState();
}

class _KanbanPolyboxPageState extends State<KanbanPolybox> {
  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<dynamic> _historyKanban = [];

  final TextEditingController _polyboxController = TextEditingController();

  final Color primaryDark = const Color(0xFF00695C);
  final Color primaryLight = const Color(0xFF00897B);
  final Color bgColor = const Color(0xFFF5F7FA);

  @override
  void dispose() {
    _polyboxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();
    _polyboxController.addListener(_checkIfFieldIsFilled);
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
        body: {'customer': 'POLYBOX', 'quick': 'true'},
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

  void _checkIfFieldIsFilled() {
    final idPolybox = _polyboxController.text.trim();

    if (idPolybox.isNotEmpty && !_isSubmitting) {
      _isSubmitting = true;
      _submitToApi(idPolybox).whenComplete(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitToApi(String idPolybox) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/polybox-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'id_label': idPolybox},
      );

      final data = jsonDecode(response.body);
      bool isSuccess = data['status'] ?? false;

      String detail = "${data['message']}\n\n"
          "DN : ${data['dn'] ?? '-'}\n"
          "Total : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}";

      _showDialog(isSuccess ? 'Sukses' : 'Gagal', detail, isSuccess);

      await fetchHistoryKanban();
      _polyboxController.clear();
    } catch (e) {
      _showDialog('Error', 'Kesalahan koneksi: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _openScanner(BuildContext context) {
    bool isProcessing = false;
    final cameraController = MobileScannerController();

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
                  height: 450,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: cameraController,
                        onDetect: (capture) async {
                          if (isProcessing) return;
                          final String? code = capture.barcodes.first.rawValue;
                          if (code != null) {
                            isProcessing = true;
                            await cameraController.stop();
                            Navigator.of(context).pop(code);
                          }
                        },
                      ),
                      Center(
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.tealAccent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10, right: 10,
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
                      Positioned(
                        bottom: 20, left: 0, right: 0,
                        child: Center(
                          child: IconButton(
                            iconSize: 32,
                            icon: Icon(
                              isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                isFlashOn = !isFlashOn;
                                cameraController.toggleTorch();
                              });
                            },
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
      if (value != null) {
        _polyboxController.text = value;
      }
    });
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
                        Text("Kanban Polybox",
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                        ),
                        SizedBox(height: 5),
                        Text("Proses Scan Polybox",
                            style: TextStyle(color: Colors.white70, fontSize: 14)
                        ),
                      ],
                    ),
                    const Icon(Icons.all_inbox, color: Colors.white24, size: 60),
                  ],
                ),
              ),
            ],
          ),

          // Main Content
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

          // Loading Overlay
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
          _buildInputHeader("Scan Polybox", Icons.inbox),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _polyboxController,
            hint: "Ketuk ikon scanner untuk scan QR Polybox",
            onScan: () => _openScanner(context),
          ),
          const SizedBox(height: 10),
          const Text(
            "* Data akan langsung diproses setelah scan berhasil",
            style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
          )
        ],
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
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryCombinKanban(sourcePage: "POLYBOX"))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            "Shipping",
            Icons.local_shipping,
            Colors.blue.shade700,
            Colors.blue.shade50,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShippingPrepCycle())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            "DN List",
            Icons.list_alt,
            Colors.green.shade700,
            Colors.green.shade50,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => DnList(source: 'POLYBOX'))),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
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
                    color: Colors.teal.shade50,
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
