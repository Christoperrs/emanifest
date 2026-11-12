import 'package:flutter/material.dart';
import 'package:emanifest/component/tag_ok_autocomplete.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Untuk efek blur (ImageFilter)
import 'history_combin_kanban.dart';
import 'dn_list.dart';
import 'shipping_prep_page.dart'; // Import halaman Shipping Preparation

class KanbanTmmin extends StatefulWidget {
  @override
  _KanbanTmminPageState createState() => _KanbanTmminPageState();
}

class _KanbanTmminPageState extends State<KanbanTmmin> {

  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<dynamic> _historyKanban = [];
  final TextEditingController _customerKanbanController = TextEditingController();
  final TextEditingController _tagOkController = TextEditingController();

  final Color primaryDark = const Color(0xFF0D47A1);
  final Color primaryLight = const Color(0xFF1976D2);
  final Color bgColor = const Color(0xFFF8F9FD);

  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();

    _customerKanbanController.addListener(_checkIfBothFieldsAreFilled);
    _tagOkController.addListener(_checkIfBothFieldsAreFilled);
  }

  @override
  void dispose() {
    _customerKanbanController.dispose();
    _tagOkController.dispose();
    super.dispose();
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
        body: {'customer': 'TMMIN', 'quick': 'true'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _historyKanban = responseData['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error Fetch History: $e');
    }
  }

  void _checkIfBothFieldsAreFilled() {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idKanban.isNotEmpty && idLabel.isNotEmpty && !_isSubmitting) {
      _isSubmitting = true;
      _submitToApi(idKanban, idLabel).whenComplete(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitToApi(String idKanban, String idLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/tmmin-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'id_kanban': idKanban, 'id_label': idLabel},
      );

      final data = jsonDecode(response.body);
      bool isSuccess = data['status'] == true;

      String dnOrBstnk = (data['dn'] ?? data['manifest_number'])?.toString() ?? '';
      if (dnOrBstnk.isEmpty && idLabel.startsWith('KBN') && idLabel.length >= 13) {
        dnOrBstnk = idLabel.substring(3, 13);
      }

      String messageHeader = '';
      if (data['mieruka_message'] != null &&
          data['mieruka_message'].toString().trim().isNotEmpty) {
        messageHeader = "${data['mieruka_message']}\n\n";
      } else if (data['cycle'] != null && data['delivery_date'] != null) {
        messageHeader = "Berhasil Update Scan Cycle ${data['cycle']} tanggal order ${data['delivery_date']}\n\n";
      } else {
        // Fallback pencarian info Cycle & Tanggal Order jika backend belum mengirimkannya
        try {
          if (dnOrBstnk.isNotEmpty) {
            final now = DateTime.now();
            final todayStr =
                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
            final checkUri = Uri.parse(
                'http://192.168.10.55/sto/combin-kanban/mieruka_shipping?customer=TMMIN&tanggal=$todayStr');
            final checkRes = await http.get(
              checkUri,
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 4));
            if (checkRes.statusCode == 200) {
              final checkJson = jsonDecode(checkRes.body);
              final List<dynamic> list = checkJson['data']?['data'] ?? [];
              final match = list.firstWhere(
                (item) => item['BSTNK']?.toString().contains(dnOrBstnk) == true,
                orElse: () => null,
              );
              if (match != null) {
                final c = match['CYCLE']?.toString() ??
                    match['cycle']?.toString() ??
                    '-';
                final d = match['BSTDK']?.toString() ??
                    match['bstdk']?.toString() ??
                    match['VDATU']?.toString() ??
                    '-';
                if (isSuccess) {
                  messageHeader =
                      "Berhasil Update Scan Cycle $c tanggal order $d\n\n";
                } else if (data['message']
                        ?.toString()
                        .contains('already verified') ==
                    true) {
                  messageHeader =
                      "Data Sudah Pernah Discan!\nCycle $c tanggal order $d\n\n";
                } else {
                  messageHeader = "Cycle $c tanggal order $d\n\n";
                }
              }
            }
          }
        } catch (_) {}

        if (messageHeader.isEmpty) {
          messageHeader = "${data['message'] ?? 'Data matched successfully.'}\n\n";
        }
      }

      String detail = "$messageHeader"
          "DN : ${dnOrBstnk.isNotEmpty ? dnOrBstnk : '-'}\n"
          "Total : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}";

      _showDialog(isSuccess ? 'Berhasil' : 'Gagal', detail, isSuccess);

      await fetchHistoryKanban();
      _customerKanbanController.clear();
      _tagOkController.clear();
    } catch (e) {
      _showDialog('Error', 'Kesalahan server: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitManual() async {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idLabel.isEmpty) {
      _showDialog('Gagal', 'Kanban Customer wajib diisi terlebih dahulu.', false);
      return;
    }

    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      await _submitToApi(idKanban, idLabel);
    } finally {
      _isSubmitting = false;
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

  void _openScanner(BuildContext context, bool isCustomerKanban) {
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
                  height: 400,
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
                          width: 250,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
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
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton(
                            icon: Icon(
                              isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                              size: 28,
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
        setState(() {
          if (isCustomerKanban) {
            _customerKanbanController.text = value;
          } else {
            _tagOkController.text = value;
          }
        });
      }
    });
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildHeaderBackground(),
          RefreshIndicator(
            onRefresh: fetchHistoryKanban,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 130, 20, 30),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildInputSection(),
                  const SizedBox(height: 20),
                  _buildNavigationButtons(),
                  const SizedBox(height: 30),
                  _buildRecentHistory(),
                ],
              ),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground() {
    return Column(
      children: [
        Container(
          height: 240,
          width: double.infinity,
          padding: const EdgeInsets.only(top: 50, left: 24, right: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDark, primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "TMMIN Kanban",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Automated Scanning System",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const Icon(Icons.factory_outlined, color: Colors.white24, size: 50),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildFieldLabel("Kanban Customer", Icons.qr_code_2),
          const SizedBox(height: 10),
          _buildModernTextField(
            controller: _customerKanbanController,
            hint: "Scan label TMMIN",
            onScan: () => _openScanner(context, true),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 1, color: Color(0xFFEEEEEE)),
          ),
          _buildFieldLabel("Tag OK / E-Kanban", Icons.document_scanner_outlined),
          const SizedBox(height: 10),
          TagOkAutocomplete(
            controller: _tagOkController,
            hint: "Scan / Ketik Tag OK (opsional jika klik Submit)",
            customer: "TMMIN",
            primaryDark: primaryDark,
            primaryLight: primaryLight,
            onScan: () => _openScanner(context, false),
            onChanged: (val) => _checkIfBothFieldsAreFilled(),
            onSubmitted: (val) => _checkIfBothFieldsAreFilled(),
          ),

          const SizedBox(height: 16),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _submitManual,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDark, primaryLight],
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

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryLight),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF444444)),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onScan,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(Icons.center_focus_weak, color: primaryDark),
            onPressed: onScan,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildNavCard("Riwayat", Icons.history_toggle_off, Colors.orange, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryCombinKanban(sourcePage: "TMMIN")));
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNavCard("Shipping", Icons.inventory_2_outlined, Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ShippingPrepPage(initialCustomer: 'TMMIN')));
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNavCard("DN List", Icons.local_shipping_outlined, Colors.teal, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DnList(source: 'TMMIN')));
          }),
        ),
      ],
    );
  }

  Widget _buildNavCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "5 Scan Terakhir",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
        ),
        const SizedBox(height: 15),
        _historyKanban.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _historyKanban.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (ctx, index) {
            final item = _historyKanban[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.qr_code_scanner, color: primaryDark, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Part - ${item['part']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text("${item['created_at']}",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.history_edu, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("Belum ada riwayat scan", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          color: Colors.black.withOpacity(0.2),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryDark, strokeWidth: 3),
                  const SizedBox(height: 15),
                  const Text("Mengolah Data...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}